import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../data/database/app_database.dart';

void showCompleteActionSheet({
  required BuildContext context,
  required LifeItem item,
  required VoidCallback onComplete,
  required void Function(int amount, int? categoryId, String? note)
  onCompleteAndBill,
  required void Function(int amount, int? categoryId, String? note)
  onCompleteAndBillAndNext,
  required VoidCallback onCompleteAndNext,
  required VoidCallback onDefer,
}) {
  final hasAmount = item.amount != null && item.amountType != 'none';
  final isRecurring = item.repeatRule != null;

  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          if (isRecurring)
            ListTile(
              leading: const Icon(Icons.autorenew, color: AppColors.primary),
              title: const Text('完成并生成下一轮'),
              subtitle: const Text('自动创建下一个周期事项'),
              onTap: () {
                if (hasAmount) {
                  Navigator.pop(context);
                  _showBillDialog(context, item, onCompleteAndBillAndNext);
                } else {
                  Navigator.pop(context);
                  onCompleteAndNext();
                }
              },
            ),
          if (hasAmount)
            ListTile(
              leading: Icon(Icons.receipt_long, color: AppColors.income),
              title: const Text('完成并记账'),
              subtitle: Text('记录 ${MoneyFormatter.format(item.amount)}'),
              onTap: () {
                Navigator.pop(context);
                _showBillDialog(context, item, onCompleteAndBill);
              },
            ),
          ListTile(
            leading: const Icon(Icons.check_circle, color: AppColors.completed),
            title: const Text('仅完成'),
            onTap: () {
              Navigator.pop(context);
              onComplete();
            },
          ),
          ListTile(
            leading: const Icon(Icons.schedule, color: AppColors.upcoming),
            title: const Text('延期'),
            onTap: () {
              Navigator.pop(context);
              onDefer();
            },
          ),
          ListTile(
            leading: const Icon(
              Icons.cancel_outlined,
              color: AppColors.textHint,
            ),
            title: const Text('取消事项'),
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    ),
  );
}

void _showBillDialog(
  BuildContext context,
  LifeItem item,
  void Function(int amount, int? categoryId, String? note) onSubmit,
) {
  final amountController = TextEditingController(
    text: ((item.amount ?? 0) / 100).toStringAsFixed(2),
  );
  final noteController = TextEditingController();
  int amount = item.amount ?? 0;

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('记账详情'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: '金额',
              prefixText: '¥',
              hintText: MoneyFormatter.format(item.amount),
            ),
            onChanged: (v) {
              final parsed = MoneyFormatter.parse(v);
              if (parsed != null) amount = parsed;
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: noteController,
            decoration: const InputDecoration(labelText: '备注'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            onSubmit(amount, item.categoryId, noteController.text);
            Navigator.pop(context);
          },
          child: const Text('确认'),
        ),
      ],
    ),
  );
}
