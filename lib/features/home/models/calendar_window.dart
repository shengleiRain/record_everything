class CalendarWindow {
  const CalendarWindow._();

  static DateTime dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static bool isSameDate(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;

  static DateTime startOfSundayWeek(DateTime date) {
    final normalized = dateOnly(date);
    final daysSinceSunday = normalized.weekday % DateTime.daysPerWeek;
    return normalized.subtract(Duration(days: daysSinceSunday));
  }

  static List<DateTime> weekFor(DateTime date) {
    final start = startOfSundayWeek(date);
    return List.generate(
      DateTime.daysPerWeek,
      (index) => start.add(Duration(days: index)),
    );
  }

  static List<DateTime> monthGridFor(DateTime date) {
    final month = dateOnly(date);
    final firstOfMonth = DateTime(month.year, month.month);
    final lastOfMonth = DateTime(month.year, month.month + 1, 0);
    final start = startOfSundayWeek(firstOfMonth);
    final end = startOfSundayWeek(
      lastOfMonth,
    ).add(const Duration(days: DateTime.daysPerWeek - 1));
    final days = end.difference(start).inDays + 1;

    return List.generate(days, (index) => start.add(Duration(days: index)));
  }

  static DateTime addWeeks(DateTime date, int weeks) =>
      dateOnly(date).add(Duration(days: weeks * DateTime.daysPerWeek));

  static DateTime addMonths(DateTime date, int months) {
    final normalized = dateOnly(date);
    final targetMonth = DateTime(normalized.year, normalized.month + months);
    final lastDayOfTargetMonth = DateTime(
      targetMonth.year,
      targetMonth.month + 1,
      0,
    ).day;
    final targetDay = normalized.day.clamp(1, lastDayOfTargetMonth);

    return DateTime(targetMonth.year, targetMonth.month, targetDay);
  }
}
