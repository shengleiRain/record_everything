import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/database/app_database.dart';
import '../providers/life_item_providers.dart';
import '../widgets/life_item_card.dart';
import '../widgets/complete_action_sheet.dart';
import '../../bill/providers/bill_providers.dart';

class LifeItemListPage extends ConsumerWidget {
  const LifeItemListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(lifeItemsProvider);

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
              final aOverdue =
                  a.status == 'pending' && DateFormatter.isOverdue(a.dueTime);
              final bOverdue =
                  b.status == 'pending' && DateFormatter.isOverdue(b.dueTime);
              if (aOverdue && !bOverdue) return -1;
              if (!aOverdue && bOverdue) return 1;
              return a.dueTime.compareTo(b.dueTime);
            });

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: sorted.length,
            itemBuilder: (context, index) {
              final item = sorted[index];
              return LifeItemCard(
                item: item,
                onTap: () => context.push('/items/${item.id}'),
                onComplete: () => _showCompleteAction(context, ref, item),
                onDefer: () => _showDeferPicker(context, ref, item),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/items/new'),
        child: const Icon(Icons.add),
      ),
    );
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
    );
  }

  void _showDeferPicker(BuildContext context, WidgetRef ref, LifeItem item) {
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
  }
}
