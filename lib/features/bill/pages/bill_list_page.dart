import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/swipe_action_reveal.dart';
import '../../../data/database/app_database.dart';
import '../providers/bill_providers.dart';
import '../widgets/bill_day_group.dart';
import '../widgets/bill_detail_sheet.dart';
import '../widgets/month_summary_card.dart';

enum _BillFilter { all, expense, income, subscription }

class BillListPage extends ConsumerStatefulWidget {
  const BillListPage({super.key});

  @override
  ConsumerState<BillListPage> createState() => _BillListPageState();
}

class _BillListPageState extends ConsumerState<BillListPage> {
  _BillFilter _filter = _BillFilter.all;

  @override
  Widget build(BuildContext context) {
    final month = ref.watch(currentMonthProvider);
    final billsAsync = ref.watch(billsByMonthProvider);
    final incomeAsync = ref.watch(monthlyIncomeProvider);
    final expenseAsync = ref.watch(monthlyExpenseProvider);
    final budgetAsync = ref.watch(monthlyBudgetProvider);
    final income = incomeAsync.valueOrNull ?? 0;
    final expense = expenseAsync.valueOrNull ?? 0;
    final budget = budgetAsync.valueOrNull ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('账单')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: Row(
              children: [
                IconButton(
                  key: const ValueKey('bills-previous-month'),
                  tooltip: '上个月',
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _changeMonth(ref, month, -1),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      DateFormatter.formatMonth(month),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  key: const ValueKey('bills-next-month'),
                  tooltip: '下个月',
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _changeMonth(ref, month, 1),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: MonthSummaryCard(
              income: income,
              expense: expense,
              budgetAmount: budget,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 38,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              children: [
                _FilterChip(
                  key: const ValueKey('bills-filter-all'),
                  label: '全部',
                  selected: _filter == _BillFilter.all,
                  onSelected: () => _selectFilter(_BillFilter.all),
                ),
                _FilterChip(
                  key: const ValueKey('bills-filter-expense'),
                  label: '支出',
                  selected: _filter == _BillFilter.expense,
                  onSelected: () => _selectFilter(_BillFilter.expense),
                ),
                _FilterChip(
                  key: const ValueKey('bills-filter-income'),
                  label: '收入',
                  selected: _filter == _BillFilter.income,
                  onSelected: () => _selectFilter(_BillFilter.income),
                ),
                _FilterChip(
                  key: const ValueKey('bills-filter-subscription'),
                  label: '订阅',
                  selected: _filter == _BillFilter.subscription,
                  onSelected: () => _selectFilter(_BillFilter.subscription),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: billsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('加载失败: $e')),
              data: (bills) {
                final filtered = _filterBills(bills);
                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 64,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '本月还没有账单',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '点击右下角按钮记录第一笔账单',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  );
                }
                final groups = _groupBillsByDay(filtered);
                return Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: (event) =>
                      SwipeRevealController.closeIfOutside(event.position),
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: groups.length,
                    itemBuilder: (context, index) => BillDayGroup(
                      date: groups[index].date,
                      bills: groups[index].bills,
                      onBillTap: (bill) =>
                          showBillDetailSheet(context, ref, bill),
                      onBillEdit: (bill) =>
                          context.push('/bills/${bill.id}/edit'),
                      onBillDelete: (bill) => _confirmDelete(bill),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        key: const ValueKey('bills-add-button'),
        onPressed: () => context.push('/bills/new'),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _changeMonth(WidgetRef ref, DateTime current, int delta) {
    ref.read(currentMonthProvider.notifier).state = DateTime(
      current.year,
      current.month + delta,
    );
  }

  void _selectFilter(_BillFilter filter) {
    setState(() => _filter = filter);
  }

  List<BillRecord> _filterBills(List<BillRecord> bills) {
    return switch (_filter) {
      _BillFilter.all => bills,
      _BillFilter.expense =>
        bills
            .where((bill) => bill.amountType == 'expense')
            .toList(growable: false),
      _BillFilter.income =>
        bills
            .where((bill) => bill.amountType == 'income')
            .toList(growable: false),
      _BillFilter.subscription =>
        bills
            .where((bill) => _looksLikeSubscription(bill))
            .toList(growable: false),
    };
  }

  List<_BillDayBucket> _groupBillsByDay(List<BillRecord> bills) {
    final sorted = [...bills]..sort((a, b) => b.billTime.compareTo(a.billTime));
    final buckets = <DateTime, List<BillRecord>>{};
    for (final bill in sorted) {
      final day = DateTime(
        bill.billTime.year,
        bill.billTime.month,
        bill.billTime.day,
      );
      buckets.putIfAbsent(day, () => []).add(bill);
    }
    final days = buckets.keys.toList()..sort((a, b) => b.compareTo(a));
    return [
      for (final day in days) _BillDayBucket(date: day, bills: buckets[day]!),
    ];
  }

  bool _looksLikeSubscription(BillRecord bill) {
    final text = '${bill.title} ${bill.note ?? ''}'.toLowerCase();
    return text.contains('订阅') ||
        text.contains('会员') ||
        text.contains('subscription');
  }

  void _confirmDelete(BillRecord bill) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('删除后可在回收站恢复，确认要删除这条账单吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(billNotifierProvider.notifier).delete(bill.id);
              Navigator.of(dialogContext).pop();
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _FilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
        selectedColor: AppColors.primary(context).withValues(alpha: 0.14),
        backgroundColor: AppColors.surface(context),
        labelStyle: TextStyle(
          color: selected ? AppColors.primaryDark : AppColors.textSecondary(context),
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
        side: BorderSide(
          color: selected
              ? AppColors.primary(context).withValues(alpha: 0.36)
              : AppColors.textHint(context).withValues(alpha: 0.35),
        ),
      ),
    );
  }
}

class _BillDayBucket {
  final DateTime date;
  final List<BillRecord> bills;

  const _BillDayBucket({required this.date, required this.bills});
}
