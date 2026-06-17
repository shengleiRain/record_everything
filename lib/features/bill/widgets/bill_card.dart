import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/widgets/card_parts.dart';
import '../../../core/widgets/swipe_action_reveal.dart';
import '../../../data/database/app_database.dart';
import '../../project/widgets/project_name_chip.dart';

class BillCard extends StatelessWidget {
  final BillRecord bill;
  final VoidCallback? onTap;

  /// Optional swipe-revealed actions. When both are null the card renders as
  /// a plain tappable row (matching the historical behaviour). When provided
  /// the row is wrapped in [SwipeActionReveal] and gains the standard accent
  /// stripe + bill fold corner, aligning it with the project detail timeline.
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const BillCard({
    super.key,
    required this.bill,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isIncome = bill.amountType == 'income';
    final accent = isIncome ? AppColors.income : AppColors.expense;

    final row = _BillRow(bill: bill, accent: accent, onTap: onTap);

    final actions = <SwipeAction>[
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
    ];

    if (actions.isEmpty) return row;
    return SwipeActionReveal(actions: actions, child: row);
  }
}

class _BillRow extends StatelessWidget {
  const _BillRow({required this.bill, required this.accent, this.onTap});

  final BillRecord bill;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('HH:mm').format(bill.billTime);
    final linkedToItem = bill.lifeItemId != null;
    final note = bill.note?.trim();
    // Subtitle segments keep only meaningful content: note (if any) + time.
    final metaSegments = <String>[
      if (note != null && note.isNotEmpty) note,
      time,
    ];

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppColors.cardRadiusSmall),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppColors.cardRadiusSmall),
        child: Stack(
          children: [
            CardLeftStripe(color: accent),
            if (linkedToItem) const BillFoldCorner(),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppColors.cardRadiusSmall),
                border: Border.all(color: AppColors.border),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 66),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                  child: Row(
                    children: [
                      CardEntryIcon(
                        icon: bill.amountType == 'income'
                            ? Icons.payments_outlined
                            : Icons.receipt_long_outlined,
                        color: accent,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              bill.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                ProjectNameChip(projectId: bill.projectId),
                                if (metaSegments.isNotEmpty) ...[
                                  Flexible(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        metaSegments.join(' · '),
                                        maxLines: 1,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: AppColors.textSecondary,
                                              fontWeight: FontWeight.w500,
                                            ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      CardTrailingValue(
                        text: bill.amountType == 'income'
                            ? MoneyFormatter.formatIncome(bill.amount)
                            : MoneyFormatter.formatExpense(bill.amount),
                        color: accent,
                        fontSize: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
