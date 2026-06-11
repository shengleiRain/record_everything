import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money_formatter.dart';
import '../models/agenda_item_view_model.dart';

class AgendaRow extends StatelessWidget {
  const AgendaRow({super.key, required this.item, this.onTap});

  final AgendaItemViewModel item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = _accentColor;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_icon, color: color, size: 20),
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
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  _trailingText,
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData get _icon {
    if (item.isOverdue) return Icons.warning_amber_rounded;
    if (item.kind == AgendaItemKind.billRecord) return Icons.receipt_long;
    if (item.kind == AgendaItemKind.project) return Icons.folder_outlined;
    if (item.isCompleted) return Icons.check_circle;
    return Icons.radio_button_unchecked;
  }

  Color get _accentColor {
    if (item.isOverdue) return AppColors.upcoming;
    if (item.amountType == 'income') return AppColors.income;
    if (item.amountType == 'expense') return AppColors.expense;
    if (item.isCompleted) return AppColors.completed;
    return AppColors.textSecondary;
  }

  String get _trailingText {
    final amount = item.amount;
    if (amount != null) return MoneyFormatter.format(amount);
    if (item.isOverdue) return '逾期';
    if (item.isCompleted) return '已完成';
    if (item.status == 'recorded') return '已记录';
    return '待处理';
  }
}
