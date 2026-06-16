import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/widgets/card_parts.dart';
import '../../../core/widgets/swipe_action_reveal.dart';
import '../../../data/database/app_database.dart';
import '../../project/widgets/project_name_chip.dart';

class LifeItemCard extends StatelessWidget {
  final LifeItem item;
  final VoidCallback? onTap;
  final VoidCallback? onComplete;
  final VoidCallback? onDefer;

  const LifeItemCard({
    super.key,
    required this.item,
    this.onTap,
    this.onComplete,
    this.onDefer,
  });

  @override
  Widget build(BuildContext context) {
    final daysLeft = DateFormatter.daysRemaining(item.dueTime);
    final isOverdue = daysLeft < 0 && item.status == 'pending';
    final isCompleted = item.status == 'completed';
    final statusColor = isOverdue
        ? AppColors.overdue
        : isCompleted
        ? AppColors.completed
        : AppColors.upcoming;
    final amountText = item.amount != null && item.amountType != 'none'
        ? MoneyFormatter.format(item.amount)
        : null;
    final subtitle = isCompleted
        ? '完成于 ${DateFormatter.formatDateTime(item.updatedAt)}'
        : [
            DateFormatter.formatDate(item.dueTime),
            DateFormatter.formatRelative(item.dueTime),
            if (item.repeatRule != null) '重复',
          ].join(' · ');

    final statusLabel = isCompleted
        ? '已完成'
        : isOverdue
        ? '逾期 ${item.dueTime.month}/${item.dueTime.day}'
        : null;

    final row = Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            CardLeftStripe(color: statusColor),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: cardBorderColor(
                    isOverdue: isOverdue,
                    isCompleted: isCompleted,
                  ),
                ),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 66),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                  child: Row(
                    children: [
                      CardEntryIcon(
                        icon: _leadingIcon(isOverdue, isCompleted),
                        color: statusColor,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    decoration: isCompleted
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color: isCompleted
                                        ? Theme.of(context).colorScheme.outline
                                        : null,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                ProjectNameChip(projectId: item.projectId),
                                Flexible(
                                  child: Text(
                                    subtitle,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (amountText != null || !isCompleted)
                        CardTrailingValue(
                          text:
                              amountText ?? _statusText(isOverdue, isCompleted),
                          color: amountText != null
                              ? _amountColor()
                              : statusColor,
                          fontSize: 15,
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (statusLabel != null)
              StatusCornerBadge(label: statusLabel, color: statusColor),
          ],
        ),
      ),
    );

    final actions = <SwipeAction>[
      if (!isCompleted && onComplete != null)
        SwipeAction(
          label: '完成',
          icon: Icons.check,
          color: AppColors.completed,
          onTap: onComplete!,
        ),
      if (!isCompleted && onDefer != null)
        SwipeAction(
          label: '延期',
          icon: Icons.event_repeat,
          color: Colors.orange.shade800,
          onTap: onDefer!,
        ),
    ];

    if (actions.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: row,
      );
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SwipeActionReveal(actions: actions, child: row),
    );
  }

  IconData _leadingIcon(bool isOverdue, bool isCompleted) {
    if (isOverdue) return Icons.warning_amber_rounded;
    if (isCompleted) return Icons.check_circle;
    return Icons.radio_button_unchecked;
  }

  String _statusText(bool isOverdue, bool isCompleted) {
    if (isCompleted) return '已完成';
    if (isOverdue) return '逾期';
    return '待办';
  }

  Color _amountColor() {
    return item.amountType == 'income' ? AppColors.income : AppColors.expense;
  }
}
