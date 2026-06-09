import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../data/database/app_database.dart';

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
    final subtitle = [
      DateFormatter.formatDate(item.dueTime),
      DateFormatter.formatRelative(item.dueTime),
      if (item.repeatRule != null) '重复',
    ].join(' · ');

    return Container(
      key: ValueKey('life-item-card-${item.id}'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(_leadingIcon(isOverdue, isCompleted), color: statusColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
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
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 88),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          amountText ?? _statusText(isOverdue, isCompleted),
                          textAlign: TextAlign.right,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: amountText != null
                                ? _amountColor()
                                : statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    if (!isCompleted && (onComplete != null || onDefer != null))
                      _LifeItemActionMenu(
                        onComplete: onComplete,
                        onDefer: onDefer,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
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

class _LifeItemActionMenu extends StatelessWidget {
  final VoidCallback? onComplete;
  final VoidCallback? onDefer;

  const _LifeItemActionMenu({this.onComplete, this.onDefer});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_LifeItemAction>(
      key: const ValueKey('life-item-action-menu'),
      icon: const Icon(Icons.more_vert),
      tooltip: '更多操作',
      padding: EdgeInsets.zero,
      onSelected: (action) {
        switch (action) {
          case _LifeItemAction.complete:
            onComplete?.call();
          case _LifeItemAction.defer:
            onDefer?.call();
        }
      },
      itemBuilder: (context) => [
        if (onDefer != null)
          const PopupMenuItem(value: _LifeItemAction.defer, child: Text('延期')),
        if (onComplete != null)
          const PopupMenuItem(
            value: _LifeItemAction.complete,
            child: Text('完成'),
          ),
      ],
    );
  }
}

enum _LifeItemAction { complete, defer }
