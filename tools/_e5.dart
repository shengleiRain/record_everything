import 'dart:io';

void main() {
  final f = File('lib/features/settings/pages/settings_page.dart');
  var c = f.readAsStringSync();

  // _AppearanceGroup labels
  c = c.replaceAll("'观'", "context.l.settings_themeTitle.substring(0, 1)");  // icon char
  c = c.replaceAll("'主题'", "context.l.settings_themeTitle");
  c = c.replaceAll("'跟随系统'", "context.l.settings_themeMode_system");
  c = c.replaceAll("'浅色'", "context.l.settings_themeMode_light");
  c = c.replaceAll("'深色'", "context.l.settings_themeMode_dark");

  // _LanguageGroup labels
  c = c.replaceAll("'语'", "context.l.settings_languageTitle.substring(0, 1)");  // icon char
  c = c.replaceAll("'语言'", "context.l.settings_languageTitle");
  // Language dropdown uses native names, keep as-is (简体中文, English)

  f.writeAsStringSync(c, flush: true);
  print('done');
}
