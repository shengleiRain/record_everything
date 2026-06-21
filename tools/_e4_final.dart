import 'dart:io';

void main() {
  final fixes = <Map<String, String>>[
    // life_item_list_page
    {'file': 'lib/features/life_item/pages/life_item_list_page.dart',
     'from': "AppBar(title: const Text('生活事项'))",
     'to': "AppBar(title: Text(context.l.page_itemList))"},
    // webdav_settings_page
    {'file': 'lib/features/settings/pages/webdav_settings_page.dart',
     'from': "AppBar(title: const Text('WebDAV 同步配置'))",
     'to': "AppBar(title: Text(context.l.page_webdavConfig))"},
    // life_item_edit_page dynamic titles
    {'file': 'lib/features/life_item/pages/life_item_edit_page.dart',
     'from': "_isEdit ? '事项' : '新建事项'}（只读）'",
     'to': "_isEdit ? context.l.page_itemEdit : context.l.page_itemNew}（只读）'"},
    {'file': 'lib/features/life_item/pages/life_item_edit_page.dart',
     'from': "(_isEdit ? '编辑事项' : '新建事项'),",
     'to': "(_isEdit ? context.l.page_itemEdit : context.l.page_itemNew),"},
  ];

  for (final r in fixes) {
    final f = File(r['file']!);
    var c = f.readAsStringSync();
    final before = c;
    c = c.replaceAll(r['from']!, r['to']!);
    if (c != before) {
      // Add l10n import if missing
      if (!c.contains("l10n/l10n.dart")) {
        c = c.replaceFirst(
          "import 'package:flutter_riverpod/flutter_riverpod.dart';",
          "import 'package:flutter_riverpod/flutter_riverpod.dart';\nimport 'package:record_everything/l10n/l10n.dart';",
        );
      }
      f.writeAsStringSync(c, flush: true);
      print('patched: ${r['file']}');
    } else {
      print('NF: ${r['file']}');
    }
  }
}
