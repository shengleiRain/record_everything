import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/database/app_database.dart';

class LifeItemCard extends StatelessWidget {
  final LifeItem item;
  final VoidCallback? onTap;
  final VoidCallback? onComplete;
  final VoidCallback? onDefer;

  const LifeItemCard({super.key, required this.item, this.onTap, this.onComplete, this.onDefer});

  @override
  Widget build(BuildContext context) {
    final daysLeft = DateFormatter.daysRemaining(item.dueTime);
    final isOverdue = daysLeft < 0 && item.status == 'pending';
    final statusColor = isOverdue
        ? AppColors.overdue
        : daysLeft <= 3
            ? AppColors.upcoming
            : AppColors.completed;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.title,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            decoration: item.status == 'completed' ? TextDecoration.lineThrough : null,
                          ),
                    ),
                  ),
                  if (item.amount != null && item.amountType != 'none')
                    Text(
                      MoneyFormatter.format(item.amount),
                      style: TextStyle(
                        color: item.amountType == 'income' ? AppColors.income : AppColors.expense,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: statusColor),
                  const SizedBox(width: 4),
                  Text(DateFormatter.formatDate(item.dueTime), style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      DateFormatter.formatRelative(item.dueTime),
                      style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                  const Spacer(),
                  if (item.repeatRule != null)
                    const Icon(Icons.repeat, size: 16, color: AppColors.textHint),
                ],
              ),
              if (item.status == 'pending') ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: onDefer, child: const Text('延期')),
                    const SizedBox(width: 8),
                    FilledButton.tonal(onPressed: onComplete, child: const Text('完成')),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
