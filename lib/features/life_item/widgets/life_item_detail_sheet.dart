import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/toast.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/widgets/card_parts.dart';
import '../../../core/widgets/sheet_action_layout.dart';
import '../../../data/database/app_database.dart';
import '../../../domain/enums/item_status.dart';
import '../../../domain/enums/repeat_period.dart';
import '../../../domain/models/repeat_rule.dart';
import '../../bill/providers/bill_providers.dart';
import '../../project/widgets/project_name_chip.dart';
import '../providers/life_item_providers.dart';
import 'complete_action_sheet.dart';

Future<void> showLifeItemDetailSheet(
  BuildContext context,
  WidgetRef ref,
  LifeItem item,
) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      final status = ItemStatus.fromString(item.status);
      final isDeleted = item.deletedAt != null;
      final canEdit = !isDeleted && !status.isFinal;
      final isPending = status == ItemStatus.pending && !isDeleted;
      final canReopen =
          !isDeleted &&
          (status == ItemStatus.completed || status == ItemStatus.cancelled);
      final isOverdue =
          DateFormatter.isOverdue(item.dueTime) && status == ItemStatus.pending;
      final amountText = _formatAmountValue(item.amount, item.amountType);
      final amountColor = _amountColor(context, item.amountType);

      return SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SheetHeader(
                  title: item.title,
                  subtitle: item.amountType == 'none' ? '事项' : '账务事项',
                  icon: isOverdue
                      ? Icons.warning_amber_rounded
                      : status == ItemStatus.completed
                      ? Icons.check_circle
                      : Icons.event_note_outlined,
                  accent: isOverdue
                      ? AppColors.overdue(context)
                      : status == ItemStatus.completed
                      ? AppColors.completed(context)
                      : AppColors.upcoming(context),
                  trailingText: amountText,
                  trailingColor: amountColor,
                ),
                const SizedBox(height: 12),
                _DetailInfoRow(label: '状态', value: status.label),
                _DetailInfoRow(
                  label: _statusTimeLabel(status, isDeleted),
                  value: _statusTimeValue(item, status, isDeleted),
                  valueColor: isOverdue ? AppColors.overdue(context) : null,
                ),
                if (item.remindTime != null)
                  _DetailInfoRow(
                    label: '提醒',
                    value: DateFormatter.formatDateTime(item.remindTime!),
                  ),
                _DetailInfoRow(
                  label: '重复规则',
                  value: item.repeatRule == null
                      ? '不重复'
                      : _formatRepeatRule(item.repeatRule!),
                ),
                if (amountText != null)
                  _DetailInfoRow(
                    label: '预计金额',
                    value: amountText,
                    valueColor: amountColor,
                  ),
                if (item.description?.trim().isNotEmpty == true)
                  _DetailInfoRow(label: '备注', value: item.description!.trim()),
                if (item.projectId != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      SizedBox(
                        width: 72,
                        child: Text(
                          '归属项目',
                          style: TextStyle(color: AppColors.textSecondary(context)),
                        ),
                      ),
                      ProjectNameChip(
                        projectId: item.projectId,
                        expanded: true,
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                if (isDeleted)
                  _DetailActionRow(
                    children: [
                      FilledButton.icon(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          ref.read(lifeItemRepoProvider).restoreItem(item.id);
                        },
                        icon: const Icon(Icons.restore),
                        label: const Text('恢复事项'),
                      ),
                    ],
                  )
                else if (isPending)
                  _PendingActionRow(
                    item: item,
                    canEdit: canEdit,
                    onEdit: () {
                      Navigator.of(sheetContext).pop();
                      context.push('/items/${item.id}/edit');
                    },
                    onComplete: () => _showCompleteAction(context, ref, item),
                    onDefer: () => _defer(context, ref, item),
                    onDelete: () =>
                        _confirmDelete(sheetContext, context, ref, item),
                  )
                else if (canReopen)
                  _DetailActionRow(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          await ref
                              .read(lifeItemNotifierProvider.notifier)
                              .reopen(item.id);
                          if (!context.mounted) return;
                          Navigator.of(sheetContext).pop();
                          Toast.info(context, '已重新打开事项');
                        },
                        icon: const Icon(Icons.restart_alt),
                        label: const Text('重新打开'),
                      ),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.overdue(context),
                        ),
                        onPressed: () =>
                            _confirmDelete(sheetContext, context, ref, item),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('删除'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

String _formatRepeatRule(String rule) {
  final repeatRule = RepeatRule.fromStorageString(rule);
  if (repeatRule.period == RepeatPeriod.custom) {
    return '每 ${repeatRule.customDays} 天';
  }
  return repeatRule.period.label;
}

String? _formatAmountValue(int? amount, String amountType) {
  if (amount == null || amountType == 'none') return null;
  if (amountType == 'income') return MoneyFormatter.formatIncome(amount);
  return MoneyFormatter.formatExpense(amount);
}

String _statusTimeLabel(ItemStatus status, bool isDeleted) {
  if (isDeleted) return '删除时间';
  return switch (status) {
    ItemStatus.completed => '完成时间',
    ItemStatus.cancelled => '取消时间',
    ItemStatus.archived => '归档时间',
    ItemStatus.pending => '到期时间',
  };
}

String _statusTimeValue(LifeItem item, ItemStatus status, bool isDeleted) {
  final deletedAt = item.deletedAt;
  if (isDeleted && deletedAt != null) {
    return DateFormatter.formatDateTime(deletedAt);
  }
  if (status.isFinal) {
    return DateFormatter.formatDateTime(item.updatedAt);
  }
  return DateFormatter.formatDateTimeWithRelative(item.dueTime);
}

Color? _amountColor(BuildContext context, String amountType) {
  if (amountType == 'income') return AppColors.income(context);
  if (amountType == 'expense') return AppColors.expense(context);
  return null;
}

void _showCompleteAction(BuildContext context, WidgetRef ref, LifeItem item) {
  showCompleteActionSheet(
    context: context,
    item: item,
    onComplete: () async {
      await ref.read(lifeItemNotifierProvider.notifier).complete(item.id);
      if (context.mounted) Navigator.pop(context);
    },
    onCompleteAndBill: (amount, categoryId, note) async {
      await ref.read(lifeItemNotifierProvider.notifier).complete(item.id);
      await ref
          .read(billNotifierProvider.notifier)
          .createFromLifeItem(item, amount, categoryId, note);
      if (context.mounted) Navigator.pop(context);
    },
    onCompleteAndBillAndNext: (amount, categoryId, note) async {
      await ref
          .read(billNotifierProvider.notifier)
          .createFromLifeItem(item, amount, categoryId, note);
      await ref
          .read(lifeItemNotifierProvider.notifier)
          .completeAndGenerateNext(item.id);
      if (context.mounted) Navigator.pop(context);
    },
    onCompleteAndNext: () async {
      await ref
          .read(lifeItemNotifierProvider.notifier)
          .completeAndGenerateNext(item.id);
      if (context.mounted) Navigator.pop(context);
    },
    onDefer: () => _defer(context, ref, item),
    onCancel: () async {
      await ref.read(lifeItemNotifierProvider.notifier).cancel(item.id);
      if (!context.mounted) return;
      Navigator.pop(context);
      Toast.info(context, '已取消事项');
    },
  );
}

Future<void> _defer(BuildContext context, WidgetRef ref, LifeItem item) async {
  final now = DateTime.now();
  final initial = item.dueTime.isAfter(now)
      ? item.dueTime.add(const Duration(days: 1))
      : now.add(const Duration(days: 1));
  final picked = await showDatePicker(
    context: context,
    initialDate: DateTime(initial.year, initial.month, initial.day),
    firstDate: DateTime(now.year, now.month, now.day),
    lastDate: now.add(const Duration(days: 365)),
  );
  if (picked == null) return;
  await ref.read(lifeItemNotifierProvider.notifier).defer(item.id, picked);
  if (!context.mounted) return;
  Toast.info(context, '已延期事项');
}

void _confirmDelete(
  BuildContext sheetContext,
  BuildContext parentContext,
  WidgetRef ref,
  LifeItem item,
) {
  Navigator.of(sheetContext).pop();
  showDialog(
    context: parentContext,
    builder: (dialogContext) => AlertDialog(
      title: const Text('确认删除'),
      content: const Text('删除后可在回收站恢复，确认要删除这个事项吗？'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            ref.read(lifeItemNotifierProvider.notifier).delete(item.id);
            Navigator.of(dialogContext).pop();
          },
          child: const Text('删除'),
        ),
      ],
    ),
  );
}

class _PendingActionRow extends StatelessWidget {
  const _PendingActionRow({
    required this.item,
    required this.canEdit,
    required this.onEdit,
    required this.onComplete,
    required this.onDefer,
    required this.onDelete,
  });

  final LifeItem item;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onComplete;
  final VoidCallback onDefer;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final primaryLabel = item.amount != null && item.amountType != 'none'
        ? '完成/记账'
        : '完成';
    return SheetActionLayout(
      children: [
        if (canEdit)
          OutlinedButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('编辑'),
          ),
        FilledButton.icon(
          onPressed: onComplete,
          icon: const Icon(Icons.check),
          label: Text(primaryLabel),
        ),
        OutlinedButton.icon(
          onPressed: onDefer,
          icon: const Icon(Icons.schedule),
          label: const Text('延期'),
        ),
        OutlinedButton.icon(
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline),
          label: const Text('删除'),
        ),
      ],
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.trailingText,
    required this.trailingColor,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final String? trailingText;
  final Color? trailingColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CardEntryIcon(icon: icon, color: accent),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary(context)),
              ),
            ],
          ),
        ),
        if (trailingText != null)
          Text(
            trailingText!,
            style: TextStyle(
              color: trailingColor ?? AppColors.textPrimary(context),
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
      ],
    );
  }
}

class _DetailInfoRow extends StatelessWidget {
  const _DetailInfoRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary(context)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: valueColor ?? AppColors.textPrimary(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailActionRow extends StatelessWidget {
  const _DetailActionRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SheetActionLayout(children: children);
  }
}
