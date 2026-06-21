/// 提醒预设。i18n：标签通过 [l10nKey] 在显示层翻译。spec §5.1。
enum ReminderPreset {
  none,
  dueDayMorning,
  dayBeforeMorning,
  custom;

  String get l10nKey => 'enum_reminderPreset_$name';

  DateTime? remindTimeFor(DateTime dueTime, {DateTime? customTime}) {
    return switch (this) {
      ReminderPreset.none => null,
      ReminderPreset.custom => customTime,
      ReminderPreset.dueDayMorning => DateTime(
        dueTime.year,
        dueTime.month,
        dueTime.day,
        9,
      ),
      ReminderPreset.dayBeforeMorning => DateTime(
        dueTime.year,
        dueTime.month,
        dueTime.day - 1,
        9,
      ),
    };
  }

  static ReminderPreset fromRemindTime(DateTime? remindTime, DateTime dueTime) {
    if (remindTime == null) return ReminderPreset.none;
    if (remindTime == ReminderPreset.dayBeforeMorning.remindTimeFor(dueTime)) {
      return ReminderPreset.dayBeforeMorning;
    }
    if (remindTime == ReminderPreset.dueDayMorning.remindTimeFor(dueTime)) {
      return ReminderPreset.dueDayMorning;
    }
    return ReminderPreset.custom;
  }
}
