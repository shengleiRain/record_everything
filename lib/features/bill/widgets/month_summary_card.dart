import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money_formatter.dart';

class MonthSummaryCard extends StatelessWidget {
  final int income;
  final int expense;
  final int budgetAmount;

  const MonthSummaryCard({
    super.key,
    required this.income,
    required this.expense,
    this.budgetAmount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final balance = income - expense;
    final budgetRate = budgetAmount <= 0 ? 0.0 : expense / budgetAmount;
    final progress = budgetRate.clamp(0.0, 1.0);
    final budgetText = budgetAmount <= 0
        ? '未设置预算'
        : '预算使用 ${(budgetRate * 100).round()}%';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _SummaryMetric(
                  label: '本月支出',
                  value: MoneyFormatter.format(expense),
                  color: AppColors.expense(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryMetric(
                  label: '本月收入',
                  value: MoneyFormatter.format(income),
                  color: AppColors.income(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              color: AppColors.primary(context),
              backgroundColor: AppColors.primary(context).withValues(alpha: 0.12),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                budgetText,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '结余 ${MoneyFormatter.format(balance)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: balance >= 0 ? AppColors.income(context) : AppColors.expense(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary(context),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
