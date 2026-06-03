import '../enums/repeat_period.dart';

class RepeatRule {
  final RepeatPeriod period;
  final int? customDays;

  const RepeatRule({required this.period, this.customDays});

  String toStorageString() {
    if (period == RepeatPeriod.custom && customDays != null) {
      return 'every:${customDays!}:days';
    }
    return period.value;
  }

  static RepeatRule fromStorageString(String s) {
    if (s.startsWith('every:')) {
      final parts = s.split(':');
      return RepeatRule(
        period: RepeatPeriod.custom,
        customDays: int.tryParse(parts[1]),
      );
    }
    return RepeatRule(period: RepeatPeriod.fromString(s));
  }

  DateTime nextDate(DateTime from) {
    switch (period) {
      case RepeatPeriod.daily:
        return from.add(const Duration(days: 1));
      case RepeatPeriod.weekly:
        return from.add(const Duration(days: 7));
      case RepeatPeriod.monthly:
        return DateTime(from.year, from.month + 1, from.day);
      case RepeatPeriod.yearly:
        return DateTime(from.year + 1, from.month, from.day);
      case RepeatPeriod.custom:
        return from.add(Duration(days: customDays ?? 30));
    }
  }
}
