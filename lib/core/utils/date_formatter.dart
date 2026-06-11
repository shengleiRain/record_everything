import 'package:intl/intl.dart';

class DateFormatter {
  static String formatDate(DateTime? date) {
    if (date == null) return '--';
    return DateFormat('yyyy-MM-dd').format(date);
  }

  static String formatMonth(DateTime date) {
    return DateFormat('yyyy年MM月').format(date);
  }

  static String formatRelative(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = target.difference(today).inDays;

    if (diff == 0) return '今天';
    if (diff == 1) return '明天';
    if (diff == -1) return '昨天';
    if (diff > 0 && diff <= 7) return '$diff天后';
    if (diff < 0) return '已逾期${-diff}天';
    return DateFormat('MM-dd').format(date);
  }

  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  static bool isOverdue(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    return target.isBefore(today);
  }

  static bool isWithinDays(DateTime date, int days) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final future = today.add(Duration(days: days));
    return !target.isBefore(today) && !target.isAfter(future);
  }

  static int daysRemaining(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    return target.difference(today).inDays;
  }

  static String formatDateTime(DateTime date) {
    return DateFormat('yyyy-MM-dd HH:mm').format(date);
  }
}
