import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money_formatter.dart';

class OverviewCard extends StatelessWidget {
  final int income;
  final int expense;
  final int balance;
  final int forecast;

  const OverviewCard({
    super.key,
    required this.income,
    required this.expense,
    required this.balance,
    required this.forecast,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('本月概览', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _StatItem(
                    label: '收入',
                    value: MoneyFormatter.format(income),
                    color: AppColors.income,
                  ),
                ),
                Expanded(
                  child: _StatItem(
                    label: '支出',
                    value: MoneyFormatter.format(expense),
                    color: AppColors.expense,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatItem(
                    label: '结余',
                    value: MoneyFormatter.format(balance),
                    color: AppColors.primary,
                  ),
                ),
                Expanded(
                  child: _StatItem(
                    label: '预计支出',
                    value: MoneyFormatter.format(forecast),
                    color: AppColors.upcoming,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }
}
