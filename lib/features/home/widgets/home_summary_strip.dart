import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money_formatter.dart';

class HomeSummaryStrip extends StatelessWidget {
  const HomeSummaryStrip({
    super.key,
    required this.monthlyExpense,
    required this.monthlyIncome,
    required this.pendingCount,
    required this.overdueCount,
  });

  final int monthlyExpense;
  final int monthlyIncome;
  final int pendingCount;
  final int overdueCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SummaryCell(
              label: '本月支出',
              value: MoneyFormatter.format(monthlyExpense),
              color: AppColors.expense(context),
            ),
          ),
          Expanded(
            child: _SummaryCell(
              label: '收入',
              value: MoneyFormatter.format(monthlyIncome),
              color: AppColors.income(context),
            ),
          ),
          Expanded(
            child: _SummaryCell(
              label: '待办',
              value: '$pendingCount',
              color: AppColors.textPrimary(context),
            ),
          ),
          Expanded(
            child: _SummaryCell(
              label: '逾期',
              value: '$overdueCount',
              color: overdueCount > 0 ? AppColors.upcoming(context) : AppColors.textHint(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCell extends StatelessWidget {
  const _SummaryCell({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary(context)),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
