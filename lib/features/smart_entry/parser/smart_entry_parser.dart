import '../models/draft_item.dart';
import 'local_rule_engine.dart';

/// 智能录入解析管道入口。spec §5.1。
///
/// 当前实现：预处理 → 分句 → 本地规则引擎 → 装配 EntryDraft。
/// 云端兜底分支在切片7接入（见 _maybeCloudEnhance 钩子）。
class SmartEntryParser {
  SmartEntryParser({DateTime? now}) : _engine = LocalRuleEngine(now: now);

  SmartEntryParser.forTest({required DateTime now})
    : _engine = LocalRuleEngine(now: now);

  final LocalRuleEngine _engine;

  /// 解析文本输入。
  /// [source] 标记数据来源；[ocrFullText] 仅 OCR 来源携带原文。
  Future<EntryDraft> parse(
    String input, {
    DraftSource source = DraftSource.nl,
    String? ocrFullText,
  }) async {
    final items = _engine.parseAll(input);
    // 切片7在此处插入：若存在低置信项或空段且云开启，调 CloudParser 兜底。
    await _maybeCloudEnhance(items, input);
    return EntryDraft(
      items: items,
      source: source,
      rawInput: input,
      ocrFullText: ocrFullText,
    );
  }

  /// 云端兜底钩子。切片1返回空实现；切片7实现真正的云端调用。
  Future<void> _maybeCloudEnhance(List<DraftItem> items, String input) async {
    // no-op for now (slice 1). 云端分支在切片7接入。
  }
}
