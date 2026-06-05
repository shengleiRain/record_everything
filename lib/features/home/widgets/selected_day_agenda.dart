import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money_formatter.dart';
import '../models/agenda_item_view_model.dart';
import 'agenda_row.dart';

class SelectedDayAgenda extends StatelessWidget {
  const SelectedDayAgenda({
    super.key,
    required this.selectedDate,
    required this.items,
  });

  final DateTime selectedDate;
  final List<AgendaItemViewModel> items;

  @override
  Widget build(BuildContext context) {
    final expense = items.fold<int>(0, (sum, item) {
      if (item.amountType != 'expense') return sum;
      return sum + (item.amount ?? 0);
    });
    final overdueCount = items.where((item) => item.isOverdue).length;

    return Container(
      key: const ValueKey('selected-day-agenda'),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '选中日期',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                '只显示${selectedDate.month}月${selectedDate.day}日',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${selectedDate.month}月${selectedDate.day}日 ${_weekdayLabel(selectedDate)}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '支出${MoneyFormatter.format(expense)} · ${items.length}项 · $overdueCount逾期',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Text(
                  '这天没有事项或账单',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.textHint),
                ),
              ),
            )
          else
            for (final item in items) ...[
              AgendaRow(item: item),
              if (item != items.last)
                Divider(height: 1, color: Colors.black.withValues(alpha: 0.06)),
            ],
        ],
      ),
    );
  }
}

String _weekdayLabel(DateTime date) {
  return const ['周一', '周二', '周三', '周四', '周五', '周六', '周日'][date.weekday - 1];
}
