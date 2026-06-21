import 'dart:io';

void main() {
  // === E6: Add English keywords to smart_entry_keywords.dart ===
  final kwFile = File('lib/features/smart_entry/constants/smart_entry_keywords.dart');
  var kw = kwFile.readAsStringSync();

  // Add English categoryKeywords and locale selector
  final englishKeywords = '''

// ===== English category keywords =====

/// 英文关键词 → categoryGuess 文本。spec §5.3。
const categoryKeywordsEn = <String, String>{
  'breakfast': '餐饮',
  'lunch': '餐饮',
  'dinner': '餐饮',
  'coffee': '餐饮',
  'pizza': '餐饮',
  'takeout': '餐饮',
  'snack': '餐饮',
  'meal': '餐饮',
  'grocery': '餐饮',
  'uber': '交通',
  'taxi': '交通',
  'gas': '交通',
  'parking': '交通',
  'subway': '交通',
  'bus': '交通',
  'train': '交通',
  'flight': '交通',
  'rent': '住房',
  'electricity': '住房',
  'water': '住房',
  'phone': '通讯',
  'internet': '通讯',
  'salary': '工资',
  'bonus': '工资',
  'refund': '工资',
  'reimbursement': '工资',
  'movie': '娱乐',
  'game': '娱乐',
  'netflix': '娱乐',
  'spotify': '娱乐',
  'subscription': '订阅',
  'amazon': '购物',
  'shopping': '购物',
};

/// 按语言选择分类关键词表。
Map<String, String> categoryKeywordsFor(String languageCode) {
  return languageCode == 'en' ? categoryKeywordsEn : categoryKeywords;
}
''';

  // Replace the closing of categoryKeywords block and add English version
  if (!kw.contains('categoryKeywordsEn')) {
    kw = kw.replaceFirst(
      "};\n",
      "};\n$englishKeywords",
      kw.lastIndexOf('};'),  // last }; is categoryKeywords
    );
    kwFile.writeAsStringSync(kw, flush: true);
    print('patched: smart_entry_keywords.dart');
  } else {
    print('skip: smart_entry_keywords.dart (already has English)');
  }

  // === E6: Add languageCode to LocalRuleEngine ===
  final engineFile = File('lib/features/smart_entry/parser/local_rule_engine.dart');
  var engine = engineFile.readAsStringSync();

  if (!engine.contains('languageCode')) {
    // Add languageCode field
    engine = engine.replaceFirst(
      "class LocalRuleEngine {\n  LocalRuleEngine({DateTime? now, DraftSource source = DraftSource.nl})\n    : now = now ?? DateTime.now(),\n      defaultSource = source;",
      "class LocalRuleEngine {\n  LocalRuleEngine({DateTime? now, DraftSource source = DraftSource.nl, this.languageCode = 'zh'})\n    : now = now ?? DateTime.now(),\n      defaultSource = source;",
    );
    engine = engine.replaceFirst(
      "  final DateTime now;\n  final DraftSource defaultSource;",
      "  final DateTime now;\n  final DraftSource defaultSource;\n  final String languageCode;",
    );
    // Update _extractCategory to use locale-based keywords
    engine = engine.replaceFirst(
      "  String? _extractCategory(String seg) {\n    for (final entry in categoryKeywords.entries) {",
      "  String? _extractCategory(String seg) {\n    final keywords = categoryKeywordsFor(languageCode);\n    for (final entry in keywords.entries) {",
    );
    engineFile.writeAsStringSync(engine, flush: true);
    print('patched: local_rule_engine.dart');
  } else {
    print('skip: local_rule_engine.dart (already has languageCode)');
  }

  // === E6: Add languageCode to SmartEntryParser ===
  final parserFile = File('lib/features/smart_entry/parser/smart_entry_parser.dart');
  var parser = parserFile.readAsStringSync();

  if (!parser.contains('languageCode')) {
    parser = parser.replaceFirst(
      "  SmartEntryParser({\n    DateTime? now,\n    CloudParser cloud = const NoopCloudParser(),\n  }) : _engine = LocalRuleEngine(now: now),",
      "  SmartEntryParser({\n    DateTime? now,\n    CloudParser cloud = const NoopCloudParser(),\n    String languageCode = 'zh',\n  }) : _engine = LocalRuleEngine(now: now, languageCode: languageCode),",
    );
    parser = parser.replaceFirst(
      "  SmartEntryParser.forTest({required DateTime now})\n    : _engine = LocalRuleEngine(now: now),",
      "  SmartEntryParser.forTest({required DateTime now, String languageCode = 'zh'})\n    : _engine = LocalRuleEngine(now: now, languageCode: languageCode),",
    );
    parserFile.writeAsStringSync(parser, flush: true);
    print('patched: smart_entry_parser.dart');
  } else {
    print('skip: smart_entry_parser.dart (already has languageCode)');
  }

  // === E6: Update smart_entry_providers.dart to pass locale ===
  final provFile = File('lib/features/smart_entry/providers/smart_entry_providers.dart');
  var prov = provFile.readAsStringSync();

  if (!prov.contains('localeProvider')) {
    prov = prov.replaceFirst(
      "import 'package:flutter_riverpod/flutter_riverpod.dart';",
      "import 'package:flutter_riverpod/flutter_riverpod.dart';\nimport '../../settings/providers/settings_providers.dart';",
    );
    prov = prov.replaceFirst(
      "  return SmartEntryParser(cloud: cloud);",
      "  final locale = ref.watch(localeProvider);\n  return SmartEntryParser(cloud: cloud, languageCode: locale.languageCode);",
    );
    provFile.writeAsStringSync(prov, flush: true);
    print('patched: smart_entry_providers.dart');
  } else {
    print('skip: smart_entry_providers.dart (already has localeProvider)');
  }

  // === E7: Widget date label locale ===
  final widgetFile = File('lib/features/home/services/widget_sync_service.dart');
  var widget = widgetFile.readAsStringSync();

  if (!widget.contains('DateFormat') || !widget.contains('localeProvider')) {
    // Add imports
    widget = widget.replaceFirst(
      "import 'package:flutter_riverpod/flutter_riverpod.dart';",
      "import 'package:flutter_riverpod/flutter_riverpod.dart';\nimport 'package:intl/intl.dart';",
    );
    if (!widget.contains("settings_providers.dart")) {
      widget = widget.replaceFirst(
        "import 'package:flutter_riverpod/flutter_riverpod.dart';",
        "import 'package:flutter_riverpod/flutter_riverpod.dart';\nimport '../../settings/providers/settings_providers.dart';",
      );
    }
    widgetFile.writeAsStringSync(widget, flush: true);
    print('patched: widget_sync_service.dart (imports)');
  } else {
    print('skip: widget_sync_service.dart (already has DateFormat/locale)');
  }
}
