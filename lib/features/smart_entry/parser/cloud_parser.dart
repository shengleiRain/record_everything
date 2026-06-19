import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/draft_item.dart';

/// 云端大模型解析抽象。spec §5.4 / §8.3。
/// 强制结构化 JSON 输出，只返回 category_guess 文本，分类匹配留给本地。
abstract class CloudParser {
  Future<List<DraftItem>> parse(String text, {required DraftSource source});
}

/// 不调用云端的占位实现（用户未配置或关闭时用）。
class NoopCloudParser implements CloudParser {
  const NoopCloudParser();

  @override
  Future<List<DraftItem>> parse(
    String text, {
    required DraftSource source,
  }) async => const [];
}

/// 通义千问实现。可作其他厂商（智谱/DeepSeek/自定义 OpenAI 兼容）的模板。
class QwenCloudParser implements CloudParser {
  QwenCloudParser({
    required this.apiKey,
    required this.model,
    http.Client? client,
    this.baseUrl = 'https://dashscope.aliyuncs.com/compatible-mode/v1',
    this.timeout = const Duration(seconds: 10),
  }) : _client = client ?? http.Client();

  final String apiKey;
  final String model;
  final String baseUrl;
  final Duration timeout;
  final http.Client _client;

  static const _systemPrompt = '''你是生活记录解析助手。把用户输入解析为结构化的生活事项或账单。
只返回 JSON，格式：{"items":[{"kind":"bill|lifeItem","title":"","amount_cents":0,"amount_type":"expense|income|none","time":"ISO8601","remind_time":"ISO8601|null","repeat_rule":"daily|weekly|monthly|yearly|null","category_guess":"餐饮","confidence":0.9}]}。
金额单位是分。时间用 ISO8601，相对时间要换算成绝对时间。category_guess 只给中文文本。''';

  @override
  Future<List<DraftItem>> parse(
    String text, {
    required DraftSource source,
  }) async {
    try {
      final resp = await _client
          .post(
            Uri.parse('$baseUrl/chat/completions'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode({
              'model': model,
              'messages': [
                {'role': 'system', 'content': _systemPrompt},
                {'role': 'user', 'content': text},
              ],
              'response_format': {'type': 'json_object'},
            }),
          )
          .timeout(timeout);

      if (resp.statusCode != 200) return const [];
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final content =
          (body['choices'] as List).first['message']['content'] as String;
      final parsed = jsonDecode(content) as Map<String, dynamic>;
      final items = parsed['items'] as List? ?? [];
      return items
          .map((e) => _fromJson(e as Map<String, dynamic>, source))
          .whereType<DraftItem>()
          .toList();
    } catch (_) {
      return const [];
    }
  }

  DraftItem? _fromJson(Map<String, dynamic> j, DraftSource source) {
    try {
      final kindStr = j['kind'] as String? ?? 'bill';
      final kind =
          kindStr == 'lifeItem' ? DraftKind.lifeItem : DraftKind.bill;
      final amountTypeStr = j['amount_type'] as String? ?? 'expense';
      final amountType = DraftAmountTypeX.fromString(amountTypeStr);
      final timeStr = j['time'] as String?;
      final time = timeStr != null ? DateTime.parse(timeStr) : DateTime.now();
      final remindStr = j['remind_time'] as String?;
      return DraftItem(
        kind: kind,
        title: j['title'] as String? ?? '未命名',
        amountCents: j['amount_cents'] as int?,
        amountType: amountType,
        time: time,
        remindTime: remindStr == null ? null : DateTime.tryParse(remindStr),
        repeatRule: j['repeat_rule'] as String?,
        categoryGuess: j['category_guess'] as String?,
        confidence: (j['confidence'] as num?)?.toDouble() ?? 0.7,
        source: source,
      );
    } catch (_) {
      return null;
    }
  }
}
