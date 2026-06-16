import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/widgets/card_parts.dart';
import '../../project/widgets/project_name_chip.dart';
import '../providers/bill_providers.dart';
import '../../../data/database/app_database.dart';

/// Shows a bottom-sheet detail for a bill record, mirroring the project detail
/// page's per-entry sheet. Replaces the old "tap → navigate to /bills/:id"
/// behaviour for bill cards across list/home/search pages.
Future<void> showBillDetailSheet(
  BuildContext context,
  WidgetRef ref,
  BillRecord bill,
) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      final isIncome = bill.amountType == 'income';
      final accent = isIncome ? AppColors.income : AppColors.expense;
      return SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SheetHeader(
                  title: bill.title,
                  accent: accent,
                  icon: isIncome
                      ? Icons.payments_outlined
                      : Icons.receipt_long_outlined,
                  amount: bill.amountType == 'income'
                      ? MoneyFormatter.formatIncome(bill.amount)
                      : MoneyFormatter.formatExpense(bill.amount),
                ),
                const SizedBox(height: 12),
                _DetailInfoRow(
                  label: '记账时间',
                  value: DateFormatter.formatDateTime(bill.billTime),
                ),
                _DetailInfoRow(
                  label: '类型',
                  value: isIncome ? '收入' : '支出',
                ),
                if (bill.note?.trim().isNotEmpty == true)
                  _DetailInfoRow(label: '备注', value: bill.note!.trim()),
                if (bill.projectId != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const SizedBox(
                        width: 72,
                        child: Text(
                          '归属项目',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                      ProjectNameChip(projectId: bill.projectId),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          context.push('/bills/${bill.id}');
                        },
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('编辑'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.overdue,
                        ),
                        onPressed: () => _confirmDelete(
                          sheetContext,
                          context,
                          ref,
                          bill,
                        ),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('删除'),
                      ),
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

void _confirmDelete(
  BuildContext sheetContext,
  BuildContext parentContext,
  WidgetRef ref,
  BillRecord bill,
) {
  Navigator.of(sheetContext).pop();
  showDialog(
    context: parentContext,
    builder: (dialogContext) => AlertDialog(
      title: const Text('确认删除'),
      content: const Text('删除后可在回收站恢复，确认要删除这条账单吗？'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            ref.read(billNotifierProvider.notifier).delete(bill.id);
            Navigator.of(dialogContext).pop();
          },
          child: const Text('删除'),
        ),
      ],
    ),
  );
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.title,
    required this.accent,
    required this.icon,
    required this.amount,
  });

  final String title;
  final Color accent;
  final IconData icon;
  final String amount;

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
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                '账单',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        Text(
          amount,
          style: TextStyle(
            color: accent,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
      ],
    );
  }
}

class _DetailInfoRow extends StatelessWidget {
  const _DetailInfoRow({required this.label, required this.value});

  final String label;
  final String value;

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
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
