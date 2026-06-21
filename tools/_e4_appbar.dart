import 'dart:io';

void main() {
  final replacements = <List<String>>[
    // life_item pages
    ['lib/features/life_item/pages/life_item_list_page.dart',
     "AppBar(title: const Text('事项'))",
     'AppBar(title: Text(context.l.page_items))'],
    ['lib/features/life_item/pages/life_item_list_page.dart',
     "AppBar(title: const Text('回收站'))",
     'AppBar(title: Text(context.l.page_recycle))'],
    // bill_edit
    ['lib/features/bill/pages/bill_edit_page.dart',
     "AppBar(title: const Text('编辑账单'))",
     'AppBar(title: Text(context.l.page_billEdit))'],
    ['lib/features/bill/pages/bill_edit_page.dart',
     "AppBar(title: const Text('新建账单'))",
     'AppBar(title: Text(context.l.page_billNew))'],
    ['lib/features/bill/pages/bill_edit_page.dart',
     "title: const Text('账单（只读）')",
     "title: Text(context.l.page_billReadonly)"],
    // item_edit
    ['lib/features/life_item/pages/life_item_edit_page.dart',
     "AppBar(title: const Text('编辑事项'))",
     'AppBar(title: Text(context.l.page_itemEdit))'],
    ['lib/features/life_item/pages/life_item_edit_page.dart',
     "AppBar(title: const Text('新建事项'))",
     'AppBar(title: Text(context.l.page_itemNew))'],
    ['lib/features/life_item/pages/life_item_edit_page.dart',
     "title: const Text('事项（只读）')",
     "title: Text(context.l.page_itemReadonly)"],
    // category_management
    ['lib/features/settings/pages/category_management_page.dart',
     "AppBar(title: const Text('分类管理'))",
     'AppBar(title: Text(context.l.page_categories))'],
    // data_safety
    ['lib/features/settings/pages/data_safety_page.dart',
     "title: const Text('数据安全')",
     'title: Text(context.l.page_dataSafety)'],
    // webdav
    ['lib/features/settings/pages/webdav_settings_page.dart',
     "title: const Text('WebDAV 同步')",
     'title: Text(context.l.page_webdav)'],
    // ai assistant
    ['lib/features/smart_entry/pages/ai_assistant_settings_page.dart',
     "title: const Text('AI 助手')",
     'title: Text(context.l.page_aiAssistant)'],
  ];

  for (final r in replacements) {
    final f = File(r[0]);
    if (!f.existsSync()) {
      print('SKIP (missing): ${r[0]}');
      continue;
    }
    var c = f.readAsStringSync();
    final before = c;
    c = c.replaceAll(r[1], r[2]);
    if (c != before) {
      // Add l10n import if missing
      if (!c.contains("l10n/l10n.dart")) {
        c = c.replaceFirst(
          "import 'package:flutter_riverpod/flutter_riverpod.dart';",
          "import 'package:flutter_riverpod/flutter_riverpod.dart';\nimport 'package:record_everything/l10n/l10n.dart';",
        );
      }
      f.writeAsStringSync(c, flush: true);
      print('patched: ${r[0]}');
    } else {
      print('NF: ${r[0]} (pattern: ${r[1].substring(0, 20)}...)');
    }
  }
}
