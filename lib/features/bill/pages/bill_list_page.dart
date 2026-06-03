import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/money_formatter.dart';
import '../providers/bill_providers.dart';
import '../widgets/bill_card.dart';

class BillListPage extends ConsumerWidget {
  const BillListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(currentMonthProvider);
    final billsAsync = ref.watch(billsByMonthProvider);
    final incomeAsync = ref.watch(monthlyIncomeProvider);
    final expenseAsync = ref.watch(monthlyExpenseProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('账单')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _changeMonth(ref, month, -1),
                ),
                Text(DateFormatter.formatMonth(month), style: Theme.of(context).textTheme.titleMedium),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _changeMonth(ref, month, 1),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _SummaryItem(label: '收入', value: MoneyFormatter.format(incomeAsync.valueOrNull ?? 0), color: AppColors.income),
                _SummaryItem(label: '支出', value: MoneyFormatter.format(expenseAsync.valueOrNull ?? 0), color: AppColors.expense),
                _SummaryItem(label: '结余', value: MoneyFormatter.format((incomeAsync.valueOrNull ?? 0) - (expenseAsync.valueOrNull ?? 0)), color: AppColors.primary),
              ],
            ),
          ),
          const Divider(height: 24),
          Expanded(
            child: billsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('加载失败: $e')),
              data: (bills) {
                if (bills.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 64, color: Theme.of(context).colorScheme.outline),
                        const SizedBox(height: 16),
                        Text('本月还没有账单', style: Theme.of(context).textTheme.bodyLarge),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: bills.length,
                  itemBuilder: (context, index) => BillCard(
                    bill: bills[index],
                    onTap: () => context.push('/bills/${bills[index].id}/edit'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/bills/new'),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _changeMonth(WidgetRef ref, DateTime current, int delta) {
    ref.read(currentMonthProvider.notifier).state = DateTime(current.year, current.month + delta);
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SummaryItem({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 14)),
        ],
      ),
    );
  }
}
