import 'package:flutter/material.dart';

import '../../domain/enums/amount_type.dart';
import '../../domain/enums/bill_amount_type.dart';
import '../../domain/enums/item_status.dart';
import '../../domain/enums/project_event_type.dart';
import '../../domain/enums/project_status.dart';
import '../../domain/enums/repeat_period.dart';
import '../features/life_item/models/reminder_preset.dart';
import 'generated/app_localizations.dart';

/// BuildContext 上访问 [AppLocalizations] 的便捷扩展。
/// 用法：`context.l.common_save`。spec §4.5。
extension L10nContext on BuildContext {
  AppLocalizations get l => AppLocalizations.of(this);
}

/// 枚举/动态 key 翻译访问扩展。spec §5.1。
///
/// 枚举标签：`context.l.projectStatus(item.status)`。
/// 动态 key（如分类 builtin_key）：`context.l.getByKey('cat_food')`。
extension L10nEnum on AppLocalizations {
  String projectStatus(ProjectStatus s) => _byKey(s.l10nKey)!;
  String itemStatus(ItemStatus s) => _byKey(s.l10nKey)!;
  String amountType(AmountType s) => _byKey(s.l10nKey)!;
  String billAmountType(BillAmountType s) => _byKey(s.l10nKey)!;
  String projectEventType(ProjectEventType s) => _byKey(s.l10nKey)!;
  String repeatPeriod(RepeatPeriod s) => _byKey(s.l10nKey)!;
  String reminderPreset(ReminderPreset s) => _byKey(s.l10nKey)!;

  /// 按字符串 key 查找翻译。用于分类 builtin_key 等动态 key 场景。
  /// 未找到时返回 null（调用方负责兜底）。
  String? getByKey(String key) => _keyMap[key]?.call(this);

  String? _byKey(String key) => getByKey(key);
}

typedef _Tr = String Function(AppLocalizations l);

/// key → 翻译 getter 映射表。新增 ARB key 时在此同步登记。
/// 覆盖枚举 key；分类 key（cat_*）由 [categoryDisplayName] 单独维护。
final Map<String, _Tr> _keyMap = <String, _Tr>{
  // ProjectStatus
  'enum_projectStatus_active': (l) => l.enum_projectStatus_active,
  'enum_projectStatus_completed': (l) => l.enum_projectStatus_completed,
  'enum_projectStatus_cancelled': (l) => l.enum_projectStatus_cancelled,
  'enum_projectStatus_archived': (l) => l.enum_projectStatus_archived,
  'enum_projectStatus_advance_complete': (l) =>
      l.enum_projectStatus_advance_complete,
  'enum_projectStatus_advance_generic': (l) =>
      l.enum_projectStatus_advance_generic,
  // ItemStatus
  'enum_itemStatus_pending': (l) => l.enum_itemStatus_pending,
  'enum_itemStatus_completed': (l) => l.enum_itemStatus_completed,
  'enum_itemStatus_cancelled': (l) => l.enum_itemStatus_cancelled,
  'enum_itemStatus_archived': (l) => l.enum_itemStatus_archived,
  // AmountType
  'enum_amountType_none': (l) => l.enum_amountType_none,
  'enum_amountType_income': (l) => l.enum_amountType_income,
  'enum_amountType_expense': (l) => l.enum_amountType_expense,
  // BillAmountType
  'enum_billAmountType_income': (l) => l.enum_billAmountType_income,
  'enum_billAmountType_expense': (l) => l.enum_billAmountType_expense,
  // ProjectEventType
  'enum_projectEventType_note': (l) => l.enum_projectEventType_note,
  'enum_projectEventType_status_change': (l) =>
      l.enum_projectEventType_status_change,
  'enum_projectEventType_communication': (l) =>
      l.enum_projectEventType_communication,
  'enum_projectEventType_milestone': (l) => l.enum_projectEventType_milestone,
  'enum_projectEventType_delivery': (l) => l.enum_projectEventType_delivery,
  'enum_projectEventType_other': (l) => l.enum_projectEventType_other,
  // RepeatPeriod
  'enum_repeatPeriod_daily': (l) => l.enum_repeatPeriod_daily,
  'enum_repeatPeriod_weekly': (l) => l.enum_repeatPeriod_weekly,
  'enum_repeatPeriod_monthly': (l) => l.enum_repeatPeriod_monthly,
  'enum_repeatPeriod_yearly': (l) => l.enum_repeatPeriod_yearly,
  'enum_repeatPeriod_custom': (l) => l.enum_repeatPeriod_custom,
  // ReminderPreset
  'enum_reminderPreset_none': (l) => l.enum_reminderPreset_none,
  'enum_reminderPreset_dueDayMorning': (l) => l.enum_reminderPreset_dueDayMorning,
  'enum_reminderPreset_dayBeforeMorning': (l) =>
      l.enum_reminderPreset_dayBeforeMorning,
  'enum_reminderPreset_custom': (l) => l.enum_reminderPreset_custom,
};
