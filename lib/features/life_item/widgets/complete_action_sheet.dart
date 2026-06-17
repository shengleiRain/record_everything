import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/dialog_helper.dart';
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
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.title,
            style: Theme.of(sheetContext).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          if (isRecurring)
            ListTile(
              leading: const Icon(Icons.autorenew, color: AppColors.primary),
              title: const Text('完成并生成下一轮'),
              subtitle: const Text('自动创建下一个周期事项'),
              onTap: () {
                if (hasAmount) {
                  sheetContext.safePop();
                  _showBillDialog(context, item, onCompleteAndBillAndNext);
                } else {
                  sheetContext.safePop();
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
                sheetContext.safePop();
                _showBillDialog(context, item, onCompleteAndBill);
              },
            ),
          ListTile(
            leading: const Icon(Icons.check_circle, color: AppColors.completed),
            title: const Text('仅完成'),
            onTap: () {
              sheetContext.safePop();
              onComplete();
            },
          ),
          ListTile(
            leading: const Icon(Icons.schedule, color: AppColors.upcoming),
            title: const Text('延期'),
            onTap: () {
              sheetContext.safePop();
              onDefer();
            },
          ),
          ListTile(
            leading: const Icon(
              Icons.cancel_outlined,
              color: AppColors.textHint,
            ),
            title: const Text('取消事项'),
            onTap: () => sheetContext.safePop(),
          ),
        ],
      ),
    ),
  );
}

Future<void> _showBillDialog(
  BuildContext context,
  LifeItem item,
  void Function(int amount, int? categoryId, String? note) onSubmit,
) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => _CompleteBillDialog(
      item: item,
      onSubmit: onSubmit,
    ),
  );
}

/// 记账详情弹窗。
///
/// 控制器由 [State] 管理，其生命周期与弹窗 widget 完全一致。这样控制器只会在
/// 弹窗的关闭动画结束、widget 真正从树中移除时才被 dispose，避免在退出动画
/// 期间 TextField 仍访问已 dispose 的 TextEditingController 而抛出
/// "A TextEditingController was used after being disposed"。
class _CompleteBillDialog extends StatefulWidget {
  const _CompleteBillDialog({required this.item, required this.onSubmit});

  final LifeItem item;
  final void Function(int amount, int? categoryId, String? note) onSubmit;

  @override
  State<_CompleteBillDialog> createState() => _CompleteBillDialogState();
}

class _CompleteBillDialogState extends State<_CompleteBillDialog> {
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  int _amount = 0;

  @override
  void initState() {
    super.initState();
    _amount = widget.item.amount ?? 0;
    _amountController = TextEditingController(
      text: ((widget.item.amount ?? 0) / 100).toStringAsFixed(2),
    );
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('记账详情'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: '金额',
              prefixText: '¥',
              hintText: MoneyFormatter.format(widget.item.amount),
            ),
            onChanged: (v) {
              final parsed = MoneyFormatter.parse(v);
              if (parsed != null) _amount = parsed;
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(labelText: '备注'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            widget.onSubmit(_amount, widget.item.categoryId, _noteController.text);
            Navigator.of(context).maybePop();
          },
          child: const Text('确认'),
        ),
      ],
    );
  }
}
