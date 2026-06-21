import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money_formatter.dart';
import '../models/draft_item.dart';

/// 单条草稿卡片。支持 inline 编辑标题、删除。spec §7.2。
class DraftItemCard extends StatelessWidget {
  const DraftItemCard({
    super.key,
    required this.item,
    required this.onChanged,
    required this.onDeleted,
  });

  final DraftItem item;
  final ValueChanged<DraftItem> onChanged;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    final low = item.isLowConfidence;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: low
              ? Colors.orange.withValues(alpha: 0.5)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            if (low)
              Container(
                width: 4,
                color: Colors.orange,
                margin: const EdgeInsets.symmetric(vertical: 8),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          item.kind == DraftKind.bill
                              ? Icons.payments_outlined
                              : Icons.check_circle_outline,
                          size: 18,
                          color: AppColors.primary(context),
                        ),
                        const SizedBox(width: 6),
                        if (low)
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(
                              Icons.warning_amber_rounded,
                              size: 16,
                              color: Colors.orange,
                            ),
                          ),
                        Expanded(
                          child: TextFormField(
                            initialValue: item.title,
                            decoration: const InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                            onChanged: (v) => onChanged(item.copyWith(title: v)),
                          ),
                        ),
                        IconButton(
                          key: const ValueKey('draft-card-delete'),
                          icon: const Icon(Icons.close, size: 18),
                          visualDensity: VisualDensity.compact,
                          onPressed: onDeleted,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        _chip(
                          context,
                          item.amountCents == null
                              ? '无金额'
                              : MoneyFormatter.format(item.amountCents),
                        ),
                        _chip(context, _kindLabel()),
                        _chip(context, _timeLabel()),
                      ],
                    ),
                    if (item.parseNotes.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        item.parseNotes.join('；'),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: AppColors.primaryLight,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(text, style: TextStyle(fontSize: 12, color: AppColors.primary(context))),
  );

  String _kindLabel() {
    switch (item.amountType) {
      case DraftAmountType.income:
        return '收入';
      case DraftAmountType.expense:
        return '支出';
      case DraftAmountType.none:
        return item.kind == DraftKind.bill ? '支出' : '事项';
    }
  }

  String _timeLabel() {
    final t = item.time;
    return '${t.month}/${t.day} '
        '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}';
  }
}
