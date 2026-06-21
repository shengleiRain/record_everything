// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => '生活事项';

  @override
  String get common_save => '保存';

  @override
  String get common_cancel => '取消';

  @override
  String get common_delete => '删除';

  @override
  String get common_confirm => '确认';

  @override
  String get common_retry => '重试';

  @override
  String get common_ok => '确定';

  @override
  String get settings_themeTitle => '主题';

  @override
  String get settings_themeMode_system => '跟随系统';

  @override
  String get settings_themeMode_light => '浅色';

  @override
  String get settings_themeMode_dark => '深色';

  @override
  String get settings_languageTitle => '语言';

  @override
  String get settings_language_system => '跟随系统';

  @override
  String get settings_language_zh => '简体中文';

  @override
  String get settings_language_en => 'English';

  @override
  String get enum_projectStatus_active => '进行中';

  @override
  String get enum_projectStatus_completed => '已完成';

  @override
  String get enum_projectStatus_cancelled => '已取消';

  @override
  String get enum_projectStatus_archived => '已归档';

  @override
  String get enum_projectStatus_advance_complete => '标记完成';

  @override
  String get enum_projectStatus_advance_generic => '推进状态';

  @override
  String get enum_itemStatus_pending => '待处理';

  @override
  String get enum_itemStatus_completed => '已完成';

  @override
  String get enum_itemStatus_cancelled => '已取消';

  @override
  String get enum_itemStatus_archived => '已归档';

  @override
  String get enum_amountType_none => '无金额';

  @override
  String get enum_amountType_income => '收入';

  @override
  String get enum_amountType_expense => '支出';

  @override
  String get enum_billAmountType_income => '收入';

  @override
  String get enum_billAmountType_expense => '支出';

  @override
  String get enum_projectEventType_note => '备注';

  @override
  String get enum_projectEventType_status_change => '状态变更';

  @override
  String get enum_projectEventType_communication => '沟通记录';

  @override
  String get enum_projectEventType_milestone => '里程碑';

  @override
  String get enum_projectEventType_delivery => '交付记录';

  @override
  String get enum_projectEventType_other => '其他';

  @override
  String get enum_repeatPeriod_daily => '每天';

  @override
  String get enum_repeatPeriod_weekly => '每周';

  @override
  String get enum_repeatPeriod_monthly => '每月';

  @override
  String get enum_repeatPeriod_yearly => '每年';

  @override
  String get enum_repeatPeriod_custom => '自定义';

  @override
  String get enum_reminderPreset_none => '不提醒';

  @override
  String get enum_reminderPreset_dueDayMorning => '当天 9:00';

  @override
  String get enum_reminderPreset_dayBeforeMorning => '提前一天 9:00';

  @override
  String get enum_reminderPreset_custom => '自定义时间';
}
