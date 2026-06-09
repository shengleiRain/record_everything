import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/database/app_database.dart';
import '../../../domain/enums/item_type.dart';
import '../../../domain/enums/item_status.dart';
import '../../../domain/enums/repeat_period.dart';
import '../../../domain/models/repeat_rule.dart';
import '../../../core/utils/dialog_helper.dart';
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
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('事项详情'),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => context.push('/items/$id/edit'),
            ),
            IconButton(
              tooltip: '添加到系统日历',
              icon: const Icon(Icons.event_available_outlined),
              onPressed: () => _addToCalendar(context, ref, item),
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
            _HeroCard(
              type: ItemType.fromString(item.itemType).label,
              title: item.title,
              description: item.description,
              isOverdue:
                  DateFormatter.isOverdue(item.dueTime) &&
                  item.status == 'pending',
            ),
            const SizedBox(height: 16),
            _MetadataGrid(
              entries: [
                _MetadataEntry(
                  label: '到期时间',
                  value:
                      '${DateFormatter.formatDate(item.dueTime)}\n${DateFormatter.formatRelative(item.dueTime)}',
                  valueColor:
                      DateFormatter.isOverdue(item.dueTime) &&
                          item.status == 'pending'
                      ? AppColors.overdue
                      : null,
                ),
                _MetadataEntry(
                  label: '预计金额',
                  value: _formatAmountValue(item.amount, item.amountType),
                  valueColor: item.amount != null && item.amountType != 'none'
                      ? (item.amountType == 'income'
                            ? AppColors.income
                            : AppColors.expense)
                      : null,
                ),
                _MetadataEntry(
                  label: '重复规则',
                  value: item.repeatRule != null
                      ? _formatRepeatRule(item.repeatRule!)
                      : '不重复',
                ),
                _MetadataEntry(
                  label: '状态/分类',
                  value:
                      '${ItemStatus.fromString(item.status).label}\n${ItemType.fromString(item.itemType).label}',
                ),
              ],
            ),
            if (item.status == 'pending') ...[
              const SizedBox(height: 16),
              _ActionPanel(
                primaryLabel: item.amount != null && item.amountType != 'none'
                    ? '完成并记账'
                    : '完成',
                onComplete: () => _showCompleteAction(context, ref, item),
                onDefer: () => _defer(context, ref, item),
              ),
            ],
            const SizedBox(height: 24),
            const _HistorySection(),
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

  String _formatAmountValue(int? amount, String amountType) {
    if (amount == null || amountType == 'none') return '无金额';
    if (amountType == 'income') {
      return '收入\n${MoneyFormatter.formatIncome(amount)}';
    }
    return '支出\n${MoneyFormatter.formatExpense(amount)}';
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
        _defer(context, ref, item);
      },
    );
  }

  Future<void> _addToCalendar(
    BuildContext context,
    WidgetRef ref,
    LifeItem item,
  ) async {
    try {
      await ref
          .read(lifeItemNotifierProvider.notifier)
          .requestCreateCalendarEvent(item);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已打开系统日历创建日程')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('打开系统日历失败: $error')));
      }
    }
  }

  void _defer(BuildContext context, WidgetRef ref, dynamic item) {
    showDatePicker(
      context: context,
      initialDate: item.dueTime.add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    ).then((date) {
      if (date != null && context.mounted) {
        ref.read(lifeItemNotifierProvider.notifier).defer(item.id, date);
      }
    });
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
              ctx.safePop();
              if (context.mounted) context.pop();
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.type,
    required this.title,
    required this.description,
    required this.isOverdue,
  });

  final String type;
  final String title;
  final String? description;
  final bool isOverdue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Chip(
              visualDensity: VisualDensity.compact,
              avatar: Icon(
                isOverdue ? Icons.warning_amber_rounded : Icons.event_note,
                size: 18,
              ),
              label: Text(type),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            if (description != null && description!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                description!,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetadataGrid extends StatelessWidget {
  const _MetadataGrid({required this.entries});

  final List<_MetadataEntry> entries;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: entries.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.45,
      ),
      itemBuilder: (context, index) => _MetadataTile(entry: entries[index]),
    );
  }
}

class _MetadataEntry {
  const _MetadataEntry({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;
}

class _MetadataTile extends StatelessWidget {
  const _MetadataTile({required this.entry});

  final _MetadataEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              entry.label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              entry.value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                color: entry.valueColor ?? AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionPanel extends StatelessWidget {
  const _ActionPanel({
    required this.primaryLabel,
    required this.onComplete,
    required this.onDefer,
  });

  final String primaryLabel;
  final VoidCallback onComplete;
  final VoidCallback onDefer;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: onComplete,
            icon: const Icon(Icons.check),
            label: Text(primaryLabel),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onDefer,
            icon: const Icon(Icons.schedule),
            label: const Text('延期'),
          ),
        ),
      ],
    );
  }
}

class _HistorySection extends StatelessWidget {
  const _HistorySection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '历史记录',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '暂无历史记录',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
