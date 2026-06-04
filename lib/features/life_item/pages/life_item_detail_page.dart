import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../domain/enums/item_type.dart';
import '../../../domain/enums/amount_type.dart';
import '../../../domain/enums/item_status.dart';
import '../../../domain/enums/repeat_period.dart';
import '../../../domain/models/repeat_rule.dart';
import '../providers/life_item_providers.dart';
import '../widgets/complete_action_sheet.dart';
import '../../bill/providers/bill_providers.dart';

class LifeItemDetailPage extends ConsumerWidget {
  const LifeItemDetailPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id =
        int.tryParse(GoRouterState.of(context).pathParameters['id'] ?? '') ?? 0;
    final itemAsync = ref.watch(lifeItemByIdProvider(id));

    return itemAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('加载失败: $e'))),
      data: (item) => Scaffold(
        appBar: AppBar(
          title: const Text('事项详情'),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => context.push('/items/$id/edit'),
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _confirmDelete(context, ref, id),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(item.title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            _InfoRow(
              label: '状态',
              value: ItemStatus.fromString(item.status).label,
            ),
            _InfoRow(
              label: '类型',
              value: ItemType.fromString(item.itemType).label,
            ),
            _InfoRow(
              label: '日期',
              value: DateFormatter.formatDate(item.dueTime),
            ),
            _InfoRow(
              label: '剩余',
              value: DateFormatter.formatRelative(item.dueTime),
              valueColor:
                  DateFormatter.isOverdue(item.dueTime) &&
                      item.status == 'pending'
                  ? AppColors.overdue
                  : null,
            ),
            if (item.amount != null && item.amountType != 'none')
              _InfoRow(
                label: AmountType.fromString(item.amountType).label,
                value: MoneyFormatter.format(item.amount),
                valueColor: item.amountType == 'income'
                    ? AppColors.income
                    : AppColors.expense,
              ),
            if (item.repeatRule != null)
              _InfoRow(label: '重复', value: _formatRepeatRule(item.repeatRule!)),
            if (item.description != null && item.description!.isNotEmpty)
              _InfoRow(label: '备注', value: item.description!),
            const SizedBox(height: 32),
            if (item.status == 'pending')
              FilledButton.icon(
                onPressed: () => _showCompleteAction(context, ref, item),
                icon: const Icon(Icons.check),
                label: const Text('完成'),
              ),
          ],
        ),
      ),
    );
  }

  String _formatRepeatRule(String rule) {
    final r = RepeatRule.fromStorageString(rule);
    if (r.period == RepeatPeriod.custom) return '每 ${r.customDays} 天';
    return r.period.label;
  }

  void _showCompleteAction(BuildContext context, WidgetRef ref, dynamic item) {
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
      onDefer: () {
        showDatePicker(
          context: context,
          initialDate: item.dueTime.add(const Duration(days: 1)),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        ).then((date) {
          if (date != null) {
            ref.read(lifeItemNotifierProvider.notifier).defer(item.id, date);
          }
        });
      },
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, int id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('删除后无法恢复，确认要删除这个事项吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(lifeItemNotifierProvider.notifier).delete(id);
              Navigator.pop(ctx);
              context.pop();
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: valueColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
