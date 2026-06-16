import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/swipe_action_reveal.dart';
import '../../bill/providers/bill_providers.dart';
import '../../bill/widgets/bill_detail_sheet.dart';
import '../../life_item/providers/life_item_providers.dart';
import '../../life_item/widgets/complete_action_sheet.dart';
import '../models/agenda_item_view_model.dart';
import 'agenda_row.dart';

class SelectedDayAgenda extends ConsumerWidget {
  const SelectedDayAgenda({
    super.key,
    required this.selectedDate,
    required this.items,
  });

  final DateTime selectedDate;
  final List<AgendaItemViewModel> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Listener(
      key: const ValueKey('selected-day-agenda'),
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) =>
          SwipeRevealController.closeIfOutside(event.position),
      child: items.isEmpty
          ? Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
              child: Center(
                child: Text(
                  '这天没有事项或账单',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    AgendaRow(
                      item: items[i],
                      onTap: () => _openItem(context, ref, items[i]),
                      onComplete: items[i].kind == AgendaItemKind.lifeItem
                          ? () => _showCompleteAction(context, ref, items[i])
                          : null,
                      onDefer: items[i].kind == AgendaItemKind.lifeItem
                          ? () => _showDeferPicker(context, ref, items[i])
                          : null,
                      onEdit: items[i].kind == AgendaItemKind.billRecord
                          ? () => context.push('/bills/${items[i].id}')
                          : items[i].kind == AgendaItemKind.project
                          ? () => context.push('/projects/${items[i].id}/edit')
                          : null,
                      onDelete: items[i].kind == AgendaItemKind.billRecord
                          ? () => _confirmDeleteBill(context, ref, items[i])
                          : null,
                    ),
                    if (i != items.length - 1) const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
    );
  }

  void _openItem(
    BuildContext context,
    WidgetRef ref,
    AgendaItemViewModel item,
  ) {
    switch (item.kind) {
      case AgendaItemKind.lifeItem:
        context.push('/items/${item.id}');
      case AgendaItemKind.billRecord:
        final bill = item.billRecord;
        if (bill != null) {
          showBillDetailSheet(context, ref, bill);
        } else {
          context.push('/bills/${item.id}');
        }
      case AgendaItemKind.project:
        context.push('/projects/${item.id}');
    }
  }

  void _showCompleteAction(
    BuildContext context,
    WidgetRef ref,
    AgendaItemViewModel item,
  ) {
    final lifeItem = item.lifeItem;
    if (lifeItem == null) {
      context.push('/items/${item.id}');
      return;
    }
    showCompleteActionSheet(
      context: context,
      item: lifeItem,
      onComplete: () async {
        await ref.read(lifeItemNotifierProvider.notifier).complete(lifeItem.id);
      },
      onCompleteAndBill: (amount, categoryId, note) async {
        await ref.read(lifeItemNotifierProvider.notifier).complete(lifeItem.id);
        await ref
            .read(billNotifierProvider.notifier)
            .createFromLifeItem(lifeItem, amount, categoryId, note);
      },
      onCompleteAndBillAndNext: (amount, categoryId, note) async {
        await ref
            .read(billNotifierProvider.notifier)
            .createFromLifeItem(lifeItem, amount, categoryId, note);
        await ref
            .read(lifeItemNotifierProvider.notifier)
            .completeAndGenerateNext(lifeItem.id);
      },
      onCompleteAndNext: () async {
        await ref
            .read(lifeItemNotifierProvider.notifier)
            .completeAndGenerateNext(lifeItem.id);
      },
      onDefer: () {
        _showDeferPicker(context, ref, item);
      },
    );
  }

  void _showDeferPicker(
    BuildContext context,
    WidgetRef ref,
    AgendaItemViewModel item,
  ) {
    final lifeItem = item.lifeItem;
    if (lifeItem == null) return;
    showDatePicker(
      context: context,
      initialDate: lifeItem.dueTime.add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    ).then((date) {
      if (date != null) {
        ref.read(lifeItemNotifierProvider.notifier).defer(lifeItem.id, date);
      }
    });
  }

  void _confirmDeleteBill(
    BuildContext context,
    WidgetRef ref,
    AgendaItemViewModel item,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('删除后可在回收站恢复，确认要删除这条账单吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(billNotifierProvider.notifier).delete(item.id);
              Navigator.of(dialogContext).pop();
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
