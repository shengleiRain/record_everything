import 'agenda_item_view_model.dart';
import 'calendar_window.dart';

class DayBucketViewModel {
  const DayBucketViewModel({
    required this.date,
    required this.isSelected,
    required this.isInVisibleMonth,
    required this.itemCount,
    required this.overdueCount,
    required this.income,
    required this.expense,
  });

  final DateTime date;
  final bool isSelected;
  final bool isInVisibleMonth;
  final int itemCount;
  final int overdueCount;
  final int income;
  final int expense;

  String get compactLabel {
    if (overdueCount > 0) return '逾期';
    if (expense > 0) return '¥${_roundedYuan(expense)}';
    if (income > 0) return '+¥${_roundedYuan(income)}';
    if (itemCount > 0) return '$itemCount项';
    return '空';
  }

  factory DayBucketViewModel.fromItems({
    required DateTime date,
    required DateTime selectedDate,
    required DateTime visibleAnchorDate,
    required List<AgendaItemViewModel> items,
  }) {
    final normalizedDate = CalendarWindow.dateOnly(date);
    var overdueCount = 0;
    var income = 0;
    var expense = 0;

    for (final item in items) {
      if (item.isOverdue) overdueCount += 1;

      final amount = item.amount ?? 0;
      if (amount <= 0) continue;

      if (item.amountType == 'income') {
        income += amount;
      } else if (item.amountType == 'expense') {
        expense += amount;
      }
    }

    return DayBucketViewModel(
      date: normalizedDate,
      isSelected: CalendarWindow.isSameDate(normalizedDate, selectedDate),
      isInVisibleMonth:
          normalizedDate.year == visibleAnchorDate.year &&
          normalizedDate.month == visibleAnchorDate.month,
      itemCount: items.length,
      overdueCount: overdueCount,
      income: income,
      expense: expense,
    );
  }
}

int _roundedYuan(int cents) => (cents / 100).round();
