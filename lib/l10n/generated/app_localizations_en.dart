// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Life Items';

  @override
  String get common_save => 'Save';

  @override
  String get common_cancel => 'Cancel';

  @override
  String get common_delete => 'Delete';

  @override
  String get common_confirm => 'Confirm';

  @override
  String get common_retry => 'Retry';

  @override
  String get common_ok => 'OK';

  @override
  String get settings_themeTitle => 'Theme';

  @override
  String get settings_themeMode_system => 'Follow system';

  @override
  String get settings_themeMode_light => 'Light';

  @override
  String get settings_themeMode_dark => 'Dark';

  @override
  String get settings_languageTitle => 'Language';

  @override
  String get settings_language_system => 'Follow system';

  @override
  String get settings_language_zh => '简体中文';

  @override
  String get settings_language_en => 'English';
}
