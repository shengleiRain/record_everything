import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../data/database/app_database.dart';
import 'bill_card.dart';

class BillDayGroup extends StatelessWidget {
  final DateTime date;
  final List<BillRecord> bills;
  final ValueChanged<BillRecord>? onBillTap;
  final ValueChanged<BillRecord>? onBillEdit;
  final ValueChanged<BillRecord>? onBillDelete;

  const BillDayGroup({
    super.key,
    required this.date,
    required this.bills,
    this.onBillTap,
    this.onBillEdit,
    this.onBillDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 8, 2, 8),
            child: Row(
              children: [
                Text(
                  _formatDayHeader(date),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  '${bills.length}笔 · ${_formatNetAmount(bills)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              for (var index = 0; index < bills.length; index++) ...[
                BillCard(
                  bill: bills[index],
                  onTap: onBillTap == null
                      ? null
                      : () => onBillTap!(bills[index]),
                  onEdit: onBillEdit == null
                      ? null
                      : () => onBillEdit!(bills[index]),
                  onDelete: onBillDelete == null
                      ? null
                      : () => onBillDelete!(bills[index]),
                ),
                if (index != bills.length - 1) const SizedBox(height: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

String _formatDayHeader(DateTime date) {
  const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  return '${date.month}月${date.day}日 ${weekdays[date.weekday - 1]}';
}

String _formatNetAmount(List<BillRecord> bills) {
  final income = bills
      .where((bill) => bill.amountType == 'income')
      .fold<int>(0, (sum, bill) => sum + bill.amount);
  final expense = bills
      .where((bill) => bill.amountType == 'expense')
      .fold<int>(0, (sum, bill) => sum + bill.amount);
  final net = income - expense;
  if (net > 0) return '+${MoneyFormatter.format(net)}';
  if (net < 0) return MoneyFormatter.format(net);
  return MoneyFormatter.format(0);
}
