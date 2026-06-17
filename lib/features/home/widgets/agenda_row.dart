import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/widgets/card_parts.dart';
import '../../../core/widgets/swipe_action_reveal.dart';
import '../../project/widgets/project_name_chip.dart';
import '../models/agenda_item_view_model.dart';

class AgendaRow extends StatelessWidget {
  const AgendaRow({
    super.key,
    required this.item,
    this.onTap,
    this.onComplete,
    this.onDefer,
    this.onEdit,
    this.onDelete,
  });

  final AgendaItemViewModel item;
  final VoidCallback? onTap;

  /// Per-kind swipe-revealed actions. Only the actions relevant to the row's
  /// [AgendaItemKind] are surfaced; callers wire them up with the appropriate
  /// provider calls.
  final VoidCallback? onComplete;
  final VoidCallback? onDefer;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final color = _accentColor;

    final row = Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppColors.cardRadiusSmall),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppColors.cardRadiusSmall),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 66),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                child: Row(
                  children: [
                    CardEntryIcon(
                      icon: _icon,
                      color: color,
                      size: 32,
                      iconSize: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              ProjectNameChip(projectId: _projectId),
                              if (_metaText.isNotEmpty)
                                Flexible(
                                  child: Text(
                                    _metaText,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    CardTrailingValue(text: _trailingText, color: color),
                  ],
                ),
              ),
              CardLeftStripe(color: color),
              if (_statusLabel != null)
                StatusCornerBadge(label: _statusLabel!, color: color),
            ],
          ),
        ),
      ),
    );

    final actions = <SwipeAction>[
      if (item.kind == AgendaItemKind.lifeItem && !item.isCompleted) ...[
        if (onComplete != null)
          SwipeAction(
            label: '完成',
            icon: Icons.check,
            color: AppColors.completed,
            onTap: onComplete!,
          ),
        if (onDefer != null)
          SwipeAction(
            label: '延期',
            icon: Icons.event_repeat,
            color: Colors.orange.shade800,
            onTap: onDefer!,
          ),
      ],
      if (item.kind == AgendaItemKind.billRecord) ...[
        if (onEdit != null)
          SwipeAction(
            label: '编辑',
            icon: Icons.edit_outlined,
            color: AppColors.primary,
            onTap: onEdit!,
          ),
        if (onDelete != null)
          SwipeAction(
            label: '删除',
            icon: Icons.delete_outline,
            color: AppColors.overdue,
            onTap: onDelete!,
          ),
      ],
      if (item.kind == AgendaItemKind.project && onEdit != null)
        SwipeAction(
          label: '编辑',
          icon: Icons.edit_outlined,
          color: AppColors.primary,
          onTap: onEdit!,
        ),
    ];

    if (actions.isEmpty) return row;
    return SwipeActionReveal(actions: actions, child: row);
  }

  IconData get _icon {
    if (item.isOverdue) return Icons.warning_amber_rounded;
    if (item.kind == AgendaItemKind.billRecord) return Icons.receipt_long;
    if (item.kind == AgendaItemKind.project) return Icons.folder_outlined;
    if (item.isCompleted) return Icons.check_circle;
    return Icons.radio_button_unchecked;
  }

  Color get _accentColor {
    if (item.isOverdue) return AppColors.overdue;
    if (item.amountType == 'income') return AppColors.income;
    if (item.amountType == 'expense') return AppColors.expense;
    if (item.isCompleted) return AppColors.completed;
    if (item.kind == AgendaItemKind.project) return Colors.blue;
    return AppColors.upcoming;
  }

  String get _trailingText {
    final amount = item.amount;
    if (amount != null) return MoneyFormatter.format(amount);
    if (item.isOverdue) return '逾期';
    // A completed life item is already marked by the bottom-right corner
    // badge; do not duplicate "已完成" on the trailing side.
    if (item.kind == AgendaItemKind.lifeItem && item.isCompleted) return '';
    if (item.status == 'recorded') return '已记录';
    return '待处理';
  }

  String? get _statusLabel {
    if (item.kind == AgendaItemKind.lifeItem && item.isCompleted) {
      return '已完成';
    }
    if (item.isOverdue) {
      final d = item.lifeItem?.dueTime ?? item.date;
      return '逾期 ${d.month}/${d.day}';
    }
    return null;
  }

  /// The bound project id, if any (resolved from the wrapped entity).
  int? get _projectId {
    switch (item.kind) {
      case AgendaItemKind.lifeItem:
        return item.lifeItem?.projectId;
      case AgendaItemKind.billRecord:
        return item.billRecord?.projectId;
      case AgendaItemKind.project:
        return null;
    }
  }

  /// Meaningful subtitle text (dates/times), replacing the old static labels
  /// like "待办事项" / "账单记录". Empty string when there is nothing useful
  /// to show — then only the project chip renders.
  String get _metaText {
    switch (item.kind) {
      case AgendaItemKind.lifeItem:
        final lifeItem = item.lifeItem;
        if (lifeItem == null) return '';
        if (item.isCompleted) {
          return '完成于 ${lifeItem.updatedAt.month}/${lifeItem.updatedAt.day}';
        }
        return [
          DateFormatter.formatRelative(lifeItem.dueTime),
          if (lifeItem.repeatRule != null) '重复',
        ].join(' · ');
      case AgendaItemKind.billRecord:
        final bill = item.billRecord;
        if (bill == null) return '';
        final time = DateFormat('HH:mm').format(bill.billTime);
        final note = bill.note?.trim();
        if (note != null && note.isNotEmpty) return '$note · $time';
        return time;
      case AgendaItemKind.project:
        return '';
    }
  }
}
