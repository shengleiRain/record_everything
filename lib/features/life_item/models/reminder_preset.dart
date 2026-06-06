enum ReminderPreset {
  none('不提醒'),
  dueDayMorning('当天 9:00'),
  dayBeforeMorning('提前一天 9:00'),
  custom('自定义时间');

  const ReminderPreset(this.label);

  final String label;

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
