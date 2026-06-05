import '../../../data/database/app_database.dart';
import 'calendar_window.dart';

enum AgendaItemKind { lifeItem, billRecord }

class AgendaItemViewModel {
  const AgendaItemViewModel({
    required this.kind,
    required this.id,
    required this.date,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.amountType,
    required this.status,
    required this.isOverdue,
    required this.isCompleted,
    this.lifeItem,
    this.billRecord,
  });

  final AgendaItemKind kind;
  final int id;
  final DateTime date;
  final String title;
  final String subtitle;
  final int? amount;
  final String amountType;
  final String status;
  final bool isOverdue;
  final bool isCompleted;
  final LifeItem? lifeItem;
  final BillRecord? billRecord;

  factory AgendaItemViewModel.fromLifeItem(LifeItem item, DateTime today) {
    final dueDate = CalendarWindow.dateOnly(item.dueTime);
    final todayDate = CalendarWindow.dateOnly(today);
    final isCompleted = item.status == 'completed';
    final isOverdue = item.status == 'pending' && dueDate.isBefore(todayDate);
    final isBillItem =
        item.itemType == 'bill' ||
        item.amountType == 'income' ||
        item.amountType == 'expense';

    return AgendaItemViewModel(
      kind: AgendaItemKind.lifeItem,
      id: item.id,
      date: dueDate,
      title: item.title,
      subtitle: isBillItem ? '账单事项' : '待办事项',
      amount: item.amount,
      amountType: item.amountType,
      status: item.status,
      isOverdue: isOverdue,
      isCompleted: isCompleted,
      lifeItem: item,
    );
  }

  factory AgendaItemViewModel.fromBillRecord(BillRecord record) {
    return AgendaItemViewModel(
      kind: AgendaItemKind.billRecord,
      id: record.id,
      date: CalendarWindow.dateOnly(record.billTime),
      title: record.title,
      subtitle: '账单记录',
      amount: record.amount,
      amountType: record.amountType,
      status: 'recorded',
      isOverdue: false,
      isCompleted: true,
      billRecord: record,
    );
  }
}
