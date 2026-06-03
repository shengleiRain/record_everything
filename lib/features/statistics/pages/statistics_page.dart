import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../providers/statistics_providers.dart';

class StatisticsPage extends ConsumerWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(statsMonthProvider);
    final incomeAsync = ref.watch(statsIncomeProvider);
    final expenseAsync = ref.watch(statsExpenseProvider);
    final completedAsync = ref.watch(statsCompletedCountProvider);
    final overdueAsync = ref.watch(statsOverdueCountProvider);
    final forecastAsync = ref.watch(statsForecastProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('统计')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
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
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _StatRow(label: '本月收入', value: MoneyFormatter.format(incomeAsync.valueOrNull ?? 0), color: AppColors.income),
                  const SizedBox(height: 12),
                  _StatRow(label: '本月支出', value: MoneyFormatter.format(expenseAsync.valueOrNull ?? 0), color: AppColors.expense),
                  const Divider(height: 24),
                  _StatRow(
                    label: '本月结余',
                    value: MoneyFormatter.format((incomeAsync.valueOrNull ?? 0) - (expenseAsync.valueOrNull ?? 0)),
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('事项统计', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  _StatRow(label: '已完成事项', value: '${completedAsync.valueOrNull ?? 0} 个', color: AppColors.completed),
                  const SizedBox(height: 8),
                  _StatRow(label: '逾期事项', value: '${overdueAsync.valueOrNull ?? 0} 个', color: AppColors.overdue),
                  const SizedBox(height: 8),
                  _StatRow(label: '未来30天预计支出', value: MoneyFormatter.format(forecastAsync.valueOrNull ?? 0), color: AppColors.upcoming),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _changeMonth(WidgetRef ref, DateTime current, int delta) {
    ref.read(statsMonthProvider.notifier).state = DateTime(current.year, current.month + delta);
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatRow({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 16)),
      ],
    );
  }
}
