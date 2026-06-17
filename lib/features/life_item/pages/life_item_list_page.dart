import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/swipe_action_reveal.dart';
import '../../../data/database/app_database.dart';
import '../providers/life_item_providers.dart';
import '../widgets/life_item_card.dart';
import '../widgets/complete_action_sheet.dart';
import '../widgets/life_item_detail_sheet.dart';
import '../../bill/providers/bill_providers.dart';

enum _LifeItemFilter {
  all,
  overdue,
  today,
  next7Days,
  repeat,
  hasAmount,
  hasReminder,
  completed,
}

final lifeItemFilterProvider = StateProvider<_LifeItemFilter>(
  (ref) => _LifeItemFilter.all,
);

class LifeItemListPage extends ConsumerWidget {
  const LifeItemListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(lifeItemsProvider);
    final selectedFilter = ref.watch(lifeItemFilterProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('生活事项')),
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 64,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text('还没有事项', style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 8),
                  Text(
                    '点击右下角按钮创建第一个事项',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            );
          }

          final sorted = List<LifeItem>.from(items)
            ..sort((a, b) {
              final aPending = a.status == 'pending';
              final bPending = b.status == 'pending';
              if (aPending && !bPending) return -1;
              if (!aPending && bPending) return 1;
              final aOverdue =
                  a.status == 'pending' && DateFormatter.isOverdue(a.dueTime);
              final bOverdue =
                  b.status == 'pending' && DateFormatter.isOverdue(b.dueTime);
              if (aOverdue && !bOverdue) return -1;
              if (!aOverdue && bOverdue) return 1;
              return a.dueTime.compareTo(b.dueTime);
            });

          final filtered = _filterItems(sorted, selectedFilter);
          final counts = _LifeItemFilterCounts.from(sorted);

          return Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (event) =>
                SwipeRevealController.closeIfOutside(event.position),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 80),
              children: [
                _LifeItemFilterChips(
                  selectedFilter: selectedFilter,
                  counts: counts,
                  onChanged: (filter) {
                    ref.read(lifeItemFilterProvider.notifier).state = filter;
                  },
                ),
                if (filtered.isEmpty)
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.45,
                    child: Center(
                      child: Text(
                        '没有符合条件的事项',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  )
                else
                  ...filtered.map(
                    (item) => Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: LifeItemCard(
                        item: item,
                        onTap: () =>
                            showLifeItemDetailSheet(context, ref, item),
                        onComplete: () =>
                            _showCompleteAction(context, ref, item),
                        onDefer: () => _showDeferPicker(context, ref, item),
                        onReopen: () => _reopenItem(context, ref, item),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        key: const ValueKey('items-add-button'),
        onPressed: () => context.push('/items/new'),
        child: const Icon(Icons.add),
      ),
    );
  }

  List<LifeItem> _filterItems(
    List<LifeItem> items,
    _LifeItemFilter selectedFilter,
  ) {
    return switch (selectedFilter) {
      _LifeItemFilter.all => items,
      _LifeItemFilter.overdue =>
        items
            .where(
              (item) =>
                  item.status == 'pending' &&
                  DateFormatter.isOverdue(item.dueTime),
            )
            .toList(),
      _LifeItemFilter.today =>
        items.where((item) => DateFormatter.isToday(item.dueTime)).toList(),
      _LifeItemFilter.next7Days => items.where((item) {
        final now = DateTime.now();
        final start = DateTime(now.year, now.month, now.day);
        final end = start.add(const Duration(days: 8));
        return item.status == 'pending' &&
            !item.dueTime.isBefore(start) &&
            item.dueTime.isBefore(end);
      }).toList(),
      _LifeItemFilter.repeat =>
        items.where((item) => item.repeatRule != null).toList(),
      _LifeItemFilter.hasAmount =>
        items.where((item) => item.amount != null).toList(),
      _LifeItemFilter.hasReminder =>
        items.where((item) => item.remindTime != null).toList(),
      _LifeItemFilter.completed =>
        items.where((item) => item.status == 'completed').toList(),
    };
  }

  void _showCompleteAction(BuildContext context, WidgetRef ref, LifeItem item) {
    showCompleteActionSheet(
      context: context,
      item: item,
      onComplete: () async {
        await ref.read(lifeItemNotifierProvider.notifier).complete(item.id);
      },
      onCompleteAndBill: (amount, categoryId, note) async {
        await ref.read(lifeItemNotifierProvider.notifier).complete(item.id);
        await ref
            .read(billNotifierProvider.notifier)
            .createFromLifeItem(item, amount, categoryId, note);
      },
      onCompleteAndBillAndNext: (amount, categoryId, note) async {
        await ref
            .read(billNotifierProvider.notifier)
            .createFromLifeItem(item, amount, categoryId, note);
        await ref
            .read(lifeItemNotifierProvider.notifier)
            .completeAndGenerateNext(item.id);
      },
      onCompleteAndNext: () async {
        await ref
            .read(lifeItemNotifierProvider.notifier)
            .completeAndGenerateNext(item.id);
      },
      onDefer: () {
        _showDeferPicker(context, ref, item);
      },
      onCancel: () async {
        await ref.read(lifeItemNotifierProvider.notifier).cancel(item.id);
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已取消事项')));
      },
    );
  }

  void _showDeferPicker(BuildContext context, WidgetRef ref, LifeItem item) {
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

  Future<void> _reopenItem(
    BuildContext context,
    WidgetRef ref,
    LifeItem item,
  ) async {
    await ref.read(lifeItemNotifierProvider.notifier).reopen(item.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已重新打开事项')));
  }
}

class _LifeItemFilterCounts {
  final int overdue;
  final int today;
  final int next7Days;

  const _LifeItemFilterCounts({
    required this.overdue,
    required this.today,
    required this.next7Days,
  });

  factory _LifeItemFilterCounts.from(List<LifeItem> items) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 8));
    return _LifeItemFilterCounts(
      overdue: items
          .where(
            (item) =>
                item.status == 'pending' &&
                DateFormatter.isOverdue(item.dueTime),
          )
          .length,
      today: items.where((item) => DateFormatter.isToday(item.dueTime)).length,
      next7Days: items
          .where(
            (item) =>
                item.status == 'pending' &&
                !item.dueTime.isBefore(start) &&
                item.dueTime.isBefore(end),
          )
          .length,
    );
  }
}

class _LifeItemFilterChips extends StatelessWidget {
  final _LifeItemFilter selectedFilter;
  final _LifeItemFilterCounts counts;
  final ValueChanged<_LifeItemFilter> onChanged;

  const _LifeItemFilterChips({
    required this.selectedFilter,
    required this.counts,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          _chip(context, _LifeItemFilter.all, '全部', 'items-filter-all'),
          _chip(
            context,
            _LifeItemFilter.overdue,
            '逾期 ${counts.overdue}',
            'items-filter-overdue',
          ),
          _chip(
            context,
            _LifeItemFilter.today,
            '今天 ${counts.today}',
            'items-filter-today',
          ),
          _chip(
            context,
            _LifeItemFilter.next7Days,
            '未来7天 ${counts.next7Days}',
            'items-filter-next7',
          ),
          _chip(context, _LifeItemFilter.repeat, '重复', 'items-filter-repeat'),
          _chip(
            context,
            _LifeItemFilter.hasAmount,
            '有金额',
            'items-filter-amount',
          ),
          _chip(
            context,
            _LifeItemFilter.hasReminder,
            '有提醒',
            'items-filter-reminder',
          ),
          _chip(
            context,
            _LifeItemFilter.completed,
            '已完成',
            'items-filter-completed',
          ),
        ],
      ),
    );
  }

  Widget _chip(
    BuildContext context,
    _LifeItemFilter filter,
    String label,
    String keyName,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        key: ValueKey(keyName),
        label: Text(label),
        selected: selectedFilter == filter,
        onSelected: (_) => onChanged(filter),
        showCheckmark: false,
      ),
    );
  }
}
