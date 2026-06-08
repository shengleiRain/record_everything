import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/money_formatter.dart';
import '../providers/statistics_providers.dart';

class StatisticsPage extends ConsumerWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(statsMonthProvider);
    final income = ref.watch(statsIncomeProvider).valueOrNull ?? 0;
    final expense = ref.watch(statsExpenseProvider).valueOrNull ?? 0;
    final budget = ref.watch(statsBudgetProvider).valueOrNull ?? 0;
    final completed = ref.watch(statsCompletedCountProvider).valueOrNull ?? 0;
    final overdue = ref.watch(statsOverdueCountProvider).valueOrNull ?? 0;
    final forecast = ref.watch(statsForecastProvider).valueOrNull ?? 0;
    final balance = income - expense;
    final totalTasks = completed + overdue;
    final completionRate = totalTasks == 0
        ? 0
        : ((completed / totalTasks) * 100).round().clamp(0, 100);

    return Scaffold(
      appBar: AppBar(title: const Text('统计')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _MonthHeader(
            month: month,
            onPrevious: () => _changeMonth(ref, month, -1),
            onNext: () => _changeMonth(ref, month, 1),
          ),
          const SizedBox(height: 10),
          _SummaryGrid(
            cells: [
              _SummaryCellData(
                label: '结余',
                value: MoneyFormatter.format(balance),
                color: balance >= 0 ? AppColors.income : AppColors.expense,
              ),
              _SummaryCellData(
                label: '预算',
                value: budget == 0
                    ? '未设置'
                    : '${((expense / budget) * 100).round().clamp(0, 999)}%',
                color: AppColors.upcoming,
              ),
              _SummaryCellData(
                label: '完成率',
                value: '$completionRate%',
                color: AppColors.textPrimary,
              ),
              _SummaryCellData(
                label: '逾期',
                value: '$overdue',
                color: overdue > 0 ? AppColors.overdue : AppColors.textHint,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ChartCard(
            title: '收支趋势',
            trailing: expense == 0
                ? '暂无支出'
                : '支出占收入 ${_ratioText(expense, income)}',
            child: _BalanceBars(
              income: income,
              expense: expense,
              forecast: forecast,
            ),
          ),
          const SizedBox(height: 12),
          _ChartCard(
            title: '分类占比',
            trailing: '支出 ${MoneyFormatter.format(expense)}',
            child: Column(
              children: [
                _CategoryRow(
                  icon: '支',
                  label: '本月支出',
                  subtitle: '账单流水',
                  amount: MoneyFormatter.format(expense),
                  color: AppColors.expense,
                ),
                _CategoryRow(
                  icon: '收',
                  label: '本月收入',
                  subtitle: '收入流水',
                  amount: MoneyFormatter.format(income),
                  color: AppColors.income,
                ),
                _CategoryRow(
                  icon: '完',
                  label: '已完成事项',
                  subtitle: '当月事项完成',
                  amount: '$completed 个',
                  color: AppColors.completed,
                ),
                _CategoryRow(
                  icon: '逾',
                  label: '逾期事项',
                  subtitle: overdue > 0 ? '需要尽快处理' : '暂无逾期',
                  amount: '$overdue 个',
                  color: overdue > 0 ? AppColors.overdue : AppColors.textHint,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _ForecastCard(forecast: forecast, overdue: overdue),
          const SizedBox(height: 12),
          _BudgetRiskCard(expense: expense, budget: budget),
        ],
      ),
    );
  }

  void _changeMonth(WidgetRef ref, DateTime current, int delta) {
    ref.read(statsMonthProvider.notifier).state = DateTime(
      current.year,
      current.month + delta,
    );
  }
}

class _BudgetRiskCard extends StatelessWidget {
  const _BudgetRiskCard({required this.expense, required this.budget});

  final int expense;
  final int budget;

  @override
  Widget build(BuildContext context) {
    final message = budget <= 0
        ? '本月还没有设置预算；设置预算后，这里会展示超支风险。'
        : expense > budget
        ? '本月支出已超过预算 ${MoneyFormatter.format(expense - budget)}，建议检查高频支出分类。'
        : '本月预算剩余 ${MoneyFormatter.format(budget - expense)}，当前现金流风险可控。';
    return _ChartCard(
      title: '预算风险',
      trailing: budget <= 0 ? '未设置' : MoneyFormatter.format(budget),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.textSecondary,
          height: 1.5,
        ),
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.month,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: '上个月',
          icon: const Icon(Icons.chevron_left),
          onPressed: onPrevious,
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                DateFormatter.formatMonth(month),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                '趋势和风险提示',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: '下个月',
          icon: const Icon(Icons.chevron_right),
          onPressed: onNext,
        ),
      ],
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.cells});

  final List<_SummaryCellData> cells;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cells.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        childAspectRatio: 1.1,
      ),
      itemBuilder: (context, index) => _SummaryCell(data: cells[index]),
    );
  }
}

class _SummaryCell extends StatelessWidget {
  const _SummaryCell({required this.data});

  final _SummaryCellData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              data.label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              data.value,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: data.color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCellData {
  const _SummaryCellData({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.trailing,
    required this.child,
  });

  final String title;
  final String trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Text(
                trailing,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _BalanceBars extends StatelessWidget {
  const _BalanceBars({
    required this.income,
    required this.expense,
    required this.forecast,
  });

  final int income;
  final int expense;
  final int forecast;

  @override
  Widget build(BuildContext context) {
    final maxValue = [
      income,
      expense,
      forecast,
      1,
    ].reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 132,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _Bar(
            label: '收入',
            value: income,
            maxValue: maxValue,
            color: AppColors.income,
          ),
          _Bar(
            label: '支出',
            value: expense,
            maxValue: maxValue,
            color: AppColors.expense,
          ),
          _Bar(
            label: '预测',
            value: forecast,
            maxValue: maxValue,
            color: AppColors.upcoming,
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.color,
  });

  final String label;
  final int value;
  final int maxValue;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final height = 24 + (value / maxValue) * 52;

    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              MoneyFormatter.format(value),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 34,
            height: height,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.84),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(6),
              ),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.amount,
    required this.color,
  });

  final String icon;
  final String label;
  final String subtitle;
  final String amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 42),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              icon,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              amount,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ForecastCard extends StatelessWidget {
  const _ForecastCard({required this.forecast, required this.overdue});

  final int forecast;
  final int overdue;

  @override
  Widget build(BuildContext context) {
    final message = forecast > 0
        ? '未来固定支出预计 ${MoneyFormatter.format(forecast)}，建议预留现金流并优先处理临近到期事项。'
        : '未来固定支出暂无记录；新增周期账单后，这里会汇总接下来 30 天的预计支出。';

    return _ChartCard(
      title: '下月预测',
      trailing: overdue > 0 ? '逾期 $overdue 项' : '暂无逾期',
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.textSecondary,
          height: 1.5,
        ),
      ),
    );
  }
}

String _ratioText(int numerator, int denominator) {
  if (denominator <= 0) return '0%';
  return '${((numerator / denominator) * 100).round().clamp(0, 999)}%';
}
