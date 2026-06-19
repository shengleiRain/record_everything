import '../constants/smart_entry_keywords.dart';
import '../models/draft_item.dart';
import 'preprocessor.dart';
import 'splitter.dart';

/// 本地规则引擎：把单段文本解析成 0..n 个 DraftItem。
///
/// 四类抽取：金额、时间、分类、事项/账单判定（spec §5.2）。
/// 通过 `now` 注入当前时间，保证可测。
class LocalRuleEngine {
  LocalRuleEngine({DateTime? now, DraftSource source = DraftSource.nl})
    : now = now ?? DateTime.now(),
      defaultSource = source;

  final DateTime now;
  final DraftSource defaultSource;

  static const _pre = Preprocessor();
  static const _split = Splitter();

  /// 解析整段（可能多句）输入，返回多个 DraftItem。
  List<DraftItem> parseAll(String input) {
    final norm = _pre.normalize(input);
    final segments = _split.split(norm);
    return [
      for (final seg in segments) ...parse(seg),
    ];
  }

  /// 解析单段（一句），返回 0..n 个 DraftItem（一句通常 1 个）。
  List<DraftItem> parse(String segment) {
    final seg = segment.trim();
    if (seg.isEmpty) return const [];

    final amount = _extractAmount(seg);
    final time = _extractTime(seg);
    final categoryGuess = _extractCategory(seg);
    final repeatRule = _extractRepeatRule(seg);
    final kind = _judgeKind(seg, amount, repeatRule);

    if (kind == null) return const [];

    final isIncome = incomeVerbs.any(seg.contains);

    final title = _extractTitle(seg);

    final amountType = kind == DraftKind.bill
        ? (isIncome
              ? DraftAmountType.income
              : DraftAmountType.expense)
        : (isIncome
              ? DraftAmountType.income
              : (amount == null
                    ? DraftAmountType.none
                    : DraftAmountType.expense));

    // 置信度粗算
    double conf = 0.5;
    if (kind == DraftKind.bill && amount != null) conf += 0.3;
    if (time != null) conf += 0.15;
    if (categoryGuess != null) conf += 0.1;
    if (kind == DraftKind.lifeItem &&
        (taskVerbs.any(seg.contains) || repeatRule != null)) {
      conf += 0.25;
    }

    final notes = <String>[];
    if (kind == DraftKind.bill && amount == null) {
      notes.add('未识别到金额，请补充');
    }
    if (time == null) notes.add('未识别到时间，默认为现在');

    return [
      DraftItem(
        kind: kind,
        title: title,
        amountCents: amount,
        amountType: amountType,
        time: time ?? now,
        remindTime: null,
        repeatRule: kind == DraftKind.lifeItem ? repeatRule : null,
        categoryId: null,
        categoryGuess: categoryGuess,
        confidence: conf.clamp(0.0, 0.99),
        parseNotes: notes,
        source: defaultSource,
      ),
    ];
  }

  /// 小票/账单关键字后的金额优先（"合计 25.00"、"实付 ¥12"、"Total 99"）。
  static final _receiptAmountPattern = RegExp(
    r'(?:合计|实付|实收|总额|总金额|应付|应付款|Total|Amount)\s*[:：]?\s*(?:[￥¥]|RMB|人民币)?\s*(\d+(?:\.\d+)?)',
    caseSensitive: false,
  );

  int? _extractAmount(String seg) {
    // OCR 小票特化：优先抓 "合计/实付/Total" 后的数字。
    final receipt = _receiptAmountPattern.firstMatch(seg);
    if (receipt != null) {
      final rn = double.tryParse(receipt.group(1)!);
      if (rn != null) return (rn * 100).round();
    }
    final m = amountPattern.firstMatch(seg);
    if (m == null) return null;
    final n = double.tryParse(m.group(1)!);
    if (n == null) return null;
    return (n * 100).round(); // 元 → 分
  }

  DateTime? _extractTime(String seg) {
    // 绝对日期：2026-06-19 / 2026/6/19 / 6月19日
    final abs = RegExp(
      r'(\d{4})[-/](\d{1,2})[-/](\d{1,2})',
    ).firstMatch(seg);
    if (abs != null) {
      final d = DateTime(
        int.parse(abs.group(1)!),
        int.parse(abs.group(2)!),
        int.parse(abs.group(3)!),
      );
      return _withTime(d, seg);
    }
    final cnDate = RegExp(r'(\d{1,2})月(\d{1,2})日').firstMatch(seg);
    if (cnDate != null) {
      final d = DateTime(
        now.year,
        int.parse(cnDate.group(1)!),
        int.parse(cnDate.group(2)!),
      );
      return _withTime(d, seg);
    }

    // 相对日期
    int? addDays;
    if (seg.contains('今天')) {
      addDays = 0;
    } else if (seg.contains('明天')) {
      addDays = 1;
    } else if (seg.contains('后天')) {
      addDays = 2;
    } else if (seg.contains('大后天')) {
      addDays = 3;
    }
    if (addDays != null) {
      final d = now.add(Duration(days: addDays));
      return _withTime(DateTime(d.year, d.month, d.day), seg);
    }

    // 仅时间无日期 → 今天
    return _maybeTimeOnly(seg);
  }

  DateTime _withTime(DateTime day, String seg) {
    final hasAm = seg.contains('上午');
    final hasPm = seg.contains('下午');
    final t = RegExp(r'(\d{1,2})\s*[点:：时]\s*(\d{1,2})?').firstMatch(seg);
    if (t != null) {
      var h = int.parse(t.group(1)!);
      final min = t.group(2) == null ? 0 : int.parse(t.group(2)!);
      // 下午/晚上的小时若无 AM/PM 标记且 ≤12，加 12（"下午3点"→15）。
      // 12 点本身不重复加（"下午12点"=12）。
      if (hasPm && h < 12) h += 12;
      return DateTime(day.year, day.month, day.day, h, min);
    }
    if (hasAm) {
      return DateTime(day.year, day.month, day.day, 9);
    }
    if (hasPm) {
      return DateTime(day.year, day.month, day.day, 14);
    }
    if (seg.contains('晚上') || seg.contains('晚')) {
      return DateTime(day.year, day.month, day.day, 19);
    }
    return day;
  }

  DateTime? _maybeTimeOnly(String seg) {
    final t = RegExp(r'(\d{1,2})\s*[点:：时]\s*(\d{1,2})?').firstMatch(seg);
    if (t == null) return null;
    final h = int.parse(t.group(1)!);
    final min = t.group(2) == null ? 0 : int.parse(t.group(2)!);
    return DateTime(now.year, now.month, now.day, h, min);
  }

  String? _extractRepeatRule(String seg) {
    if (seg.contains('每天') || seg.contains('每日')) return 'daily';
    if (seg.contains('每周') || seg.contains('每星期')) return 'weekly';
    if (RegExp(r'每月\d{1,2}号?').hasMatch(seg) ||
        RegExp(r'每月\d{1,2}日').hasMatch(seg)) {
      return 'monthly';
    }
    if (seg.contains('每年')) return 'yearly';
    return null;
  }

  String? _extractCategory(String seg) {
    for (final entry in categoryKeywords.entries) {
      if (seg.contains(entry.key)) return entry.value;
    }
    return null;
  }

  String _extractTitle(String seg) {
    // 去掉金额、时间、单位、动词，剩余中文片段作为标题
    var t = seg
        .replaceAll(amountPattern, '')
        .replaceAll(RegExp(r'\d{1,2}\s*[点:：时]\s*\d{0,2}'), '')
        .replaceAll(RegExp(r'\d{4}[-/]\d{1,2}[-/]\d{1,2}'), '')
        .replaceAll(RegExp(r'\d{1,2}月\d{1,2}日'), '');
    for (final w in [
      ...expenseVerbs,
      ...incomeVerbs,
      ...currencyMarkers,
      '今天',
      '明天',
      '后天',
      '大后天',
      '上午',
      '下午',
      '晚上',
      '每天',
      '每周',
      '每月',
      '每年',
    ]) {
      t = t.replaceAll(w, '');
    }
    t = t.replaceAll(RegExp(r'\s+'), '').trim();
    return t.isEmpty ? '未命名' : t;
  }

  DraftKind? _judgeKind(String seg, int? amount, String? repeatRule) {
    final hasExpense = expenseVerbs.any(seg.contains) ||
        currencyMarkers.any(seg.contains);
    final hasIncome = incomeVerbs.any(seg.contains);
    final hasTask = taskVerbs.any(seg.contains);

    if ((hasExpense || hasIncome) && amount != null) {
      return DraftKind.bill;
    }
    if (hasTask || repeatRule != null) {
      return DraftKind.lifeItem;
    }
    if (amount != null) {
      return DraftKind.bill; // 仅金额默认支出账单
    }
    if (hasExpense || hasIncome) {
      return DraftKind.bill; // 有消费/收入动词即便金额没抓到也判账单
    }
    return null; // 都不含 → 交给云端兜底
  }
}
