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

  @override
  String get enum_projectStatus_active => 'In Progress';

  @override
  String get enum_projectStatus_completed => 'Completed';

  @override
  String get enum_projectStatus_cancelled => 'Cancelled';

  @override
  String get enum_projectStatus_archived => 'Archived';

  @override
  String get enum_projectStatus_advance_complete => 'Mark Complete';

  @override
  String get enum_projectStatus_advance_generic => 'Advance';

  @override
  String get enum_itemStatus_pending => 'Pending';

  @override
  String get enum_itemStatus_completed => 'Completed';

  @override
  String get enum_itemStatus_cancelled => 'Cancelled';

  @override
  String get enum_itemStatus_archived => 'Archived';

  @override
  String get enum_amountType_none => 'No amount';

  @override
  String get enum_amountType_income => 'Income';

  @override
  String get enum_amountType_expense => 'Expense';

  @override
  String get enum_billAmountType_income => 'Income';

  @override
  String get enum_billAmountType_expense => 'Expense';

  @override
  String get enum_projectEventType_note => 'Note';

  @override
  String get enum_projectEventType_status_change => 'Status Change';

  @override
  String get enum_projectEventType_communication => 'Communication';

  @override
  String get enum_projectEventType_milestone => 'Milestone';

  @override
  String get enum_projectEventType_delivery => 'Delivery';

  @override
  String get enum_projectEventType_other => 'Other';

  @override
  String get enum_repeatPeriod_daily => 'Daily';

  @override
  String get enum_repeatPeriod_weekly => 'Weekly';

  @override
  String get enum_repeatPeriod_monthly => 'Monthly';

  @override
  String get enum_repeatPeriod_yearly => 'Yearly';

  @override
  String get enum_repeatPeriod_custom => 'Custom';

  @override
  String get enum_reminderPreset_none => 'No reminder';

  @override
  String get enum_reminderPreset_dueDayMorning => 'Due day 9:00 AM';

  @override
  String get enum_reminderPreset_dayBeforeMorning => '1 day before 9:00 AM';

  @override
  String get enum_reminderPreset_custom => 'Custom time';
}
