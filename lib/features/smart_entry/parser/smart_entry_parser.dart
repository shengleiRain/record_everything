import '../models/draft_item.dart';
import 'cloud_parser.dart';
import 'local_rule_engine.dart';

/// 智能录入解析管道入口。spec §5.1。
///
/// 预处理 → 分句 → 本地规则引擎 → 装配 EntryDraft。
/// 低置信项或空结果时走云端兜底（BYOK，可开关）。
class SmartEntryParser {
  SmartEntryParser({
    DateTime? now,
    CloudParser cloud = const NoopCloudParser(),
    String languageCode = 'zh',
  }) : _engine = LocalRuleEngine(now: now, languageCode: languageCode),
       _cloud = cloud;

  SmartEntryParser.forTest({required DateTime now, String languageCode = 'zh'})
    : _engine = LocalRuleEngine(now: now, languageCode: languageCode),
      _cloud = const NoopCloudParser();

  final LocalRuleEngine _engine;
  final CloudParser _cloud;

  /// 解析文本输入。
  /// [source] 标记数据来源；[ocrFullText] 仅 OCR 来源携带原文。
  Future<EntryDraft> parse(
    String input, {
    DraftSource source = DraftSource.nl,
    String? ocrFullText,
  }) async {
    var items = _engine.parseAll(input);
    items = await _maybeCloudEnhance(items, input, source);
    return EntryDraft(
      items: items,
      source: source,
      rawInput: input,
      ocrFullText: ocrFullText,
    );
  }

  /// 存在低置信项或空结果时，重跑云端；失败降级返回本地结果。spec §5.3/§5.5。
  Future<List<DraftItem>> _maybeCloudEnhance(
    List<DraftItem> items,
    String input,
    DraftSource source,
  ) async {
    final needCloud = items.isEmpty || items.any((i) => i.isLowConfidence);
    if (!needCloud) return items;
    try {
      final cloudItems = await _cloud
          .parse(input, source: source)
          .timeout(const Duration(seconds: 10));
      if (cloudItems.isEmpty) return items;
      return cloudItems; // 云端结果覆盖本地低置信段
    } catch (_) {
      return items; // 降级
    }
  }
}
