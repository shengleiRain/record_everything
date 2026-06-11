import 'package:flutter/material.dart';
import '../../../core/utils/money_formatter.dart';

class ProjectFinancialBar extends StatelessWidget {
  const ProjectFinancialBar({
    super.key,
    required this.totalAmount,
    required this.incomeReceived,
  });

  final int? totalAmount;
  final int incomeReceived;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = totalAmount ?? 0;
    final progress = total > 0 ? (incomeReceived / total).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '收款进度',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            Text(
              '${MoneyFormatter.formatInt(incomeReceived)} / ${total > 0 ? MoneyFormatter.formatInt(total) : "未设置"}',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }
}
