import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/widgets/card_parts.dart';
import '../../../core/widgets/swipe_action_reveal.dart';
import '../../../data/database/app_database.dart';
import '../../../domain/enums/item_status.dart';
import '../../project/widgets/project_name_chip.dart';

class LifeItemCard extends StatelessWidget {
  final LifeItem item;
  final VoidCallback? onTap;
  final VoidCallback? onComplete;
  final VoidCallback? onDefer;
  final VoidCallback? onReopen;

  const LifeItemCard({
    super.key,
    required this.item,
    this.onTap,
    this.onComplete,
    this.onDefer,
    this.onReopen,
  });

  @override
  Widget build(BuildContext context) {
    final daysLeft = DateFormatter.daysRemaining(item.dueTime);
    final status = ItemStatus.fromString(item.status);
    final isOverdue = daysLeft < 0 && status == ItemStatus.pending;
    final isCompleted = status == ItemStatus.completed;
    final isCancelled = status == ItemStatus.cancelled;
    final statusColor = isOverdue
        ? AppColors.overdue(context)
        : isCompleted
        ? AppColors.completed(context)
        : isCancelled
        ? AppColors.textHint(context)
        : AppColors.upcoming(context);
    final amountText = item.amount != null && item.amountType != 'none'
        ? MoneyFormatter.format(item.amount)
        : null;
    final subtitleDate =
        status == ItemStatus.completed || status == ItemStatus.cancelled
        ? DateFormatter.formatDateTime(item.updatedAt)
        : DateFormatter.formatDate(item.dueTime);
    final relativeDueDate = DateFormatter.formatRelative(item.dueTime);
    final subtitleExtras = <String>[
      if (status == ItemStatus.pending &&
          relativeDueDate !=
              DateFormatter.formatDate(item.dueTime).substring(5))
        relativeDueDate,
      if (status == ItemStatus.pending && item.repeatRule != null) '重复',
    ];

    final statusLabel = switch (status) {
      ItemStatus.completed => '已完成',
      ItemStatus.cancelled => '已取消',
      _ when isOverdue => '逾期 ${item.dueTime.month}/${item.dueTime.day}',
      _ => null,
    };

    final row = Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(AppColors.cardRadiusSmall),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppColors.cardRadiusSmall),
        child: Stack(
          children: [
            CardLeftStripe(color: statusColor),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppColors.cardRadiusSmall),
                border: Border.all(
                  color: cardBorderColor(
                    context,
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
                            ProjectNameLine(
                              projectId: item.projectId,
                              padding: const EdgeInsets.only(top: 4),
                            ),
                            const SizedBox(height: 4),
                            _subtitleLine(
                              context,
                              dateText: subtitleDate,
                              trailingSegments: subtitleExtras,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (amountText != null || status == ItemStatus.pending)
                        CardTrailingValue(
                          text: amountText ?? _statusText(isOverdue),
                          color: amountText != null
                              ? _amountColor(context)
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

    final canReopen =
        status == ItemStatus.completed || status == ItemStatus.cancelled;
    final canMutate = status == ItemStatus.pending;

    final actions = <SwipeAction>[
      if (canMutate && onComplete != null)
        SwipeAction(
          label: '完成',
          icon: Icons.check,
          color: AppColors.completed(context),
          onTap: onComplete!,
        ),
      if (canMutate && onDefer != null)
        SwipeAction(
          label: '延期',
          icon: Icons.event_repeat,
          color: Colors.orange.shade800,
          onTap: onDefer!,
        ),
      if (canReopen && onReopen != null)
        SwipeAction(
          label: '重新打开',
          icon: Icons.restart_alt,
          color: Colors.blue,
          onTap: onReopen!,
        ),
    ];

    if (actions.isEmpty) return row;
    return SwipeActionReveal(actions: actions, child: row);
  }

  Widget _subtitleLine(
    BuildContext context, {
    required String dateText,
    required List<String> trailingSegments,
  }) {
    final textStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary(context));

    return Row(
      children: [
        Text(
          dateText,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.visible,
          style: textStyle,
        ),
        if (trailingSegments.isNotEmpty)
          Flexible(
            child: Text(
              ' · ${trailingSegments.join(' · ')}',
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: textStyle,
            ),
          ),
      ],
    );
  }

  IconData _leadingIcon(bool isOverdue, bool isCompleted) {
    if (isOverdue) return Icons.warning_amber_rounded;
    if (isCompleted) return Icons.check_circle;
    return Icons.radio_button_unchecked;
  }

  String _statusText(bool isOverdue) {
    if (isOverdue) return '逾期';
    return '待办';
  }

  Color _amountColor(BuildContext context) {
    return item.amountType == 'income' ? AppColors.income(context) : AppColors.expense(context);
  }
}
