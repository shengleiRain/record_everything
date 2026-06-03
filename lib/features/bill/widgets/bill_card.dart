import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/database/app_database.dart';

class BillCard extends StatelessWidget {
  final BillRecord bill;
  final VoidCallback? onTap;

  const BillCard({super.key, required this.bill, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isIncome = bill.amountType == 'income';

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: (isIncome ? AppColors.income : AppColors.expense).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                  color: isIncome ? AppColors.income : AppColors.expense,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(bill.title, style: Theme.of(context).textTheme.bodyLarge),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(DateFormatter.formatDate(bill.billTime), style: Theme.of(context).textTheme.bodyMedium),
                        if (bill.lifeItemId != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('来自事项', style: TextStyle(fontSize: 10, color: AppColors.primary)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                isIncome ? MoneyFormatter.formatIncome(bill.amount) : MoneyFormatter.formatExpense(bill.amount),
                style: TextStyle(
                  color: isIncome ? AppColors.income : AppColors.expense,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
