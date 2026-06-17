import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/card_parts.dart';
import '../../core/widgets/swipe_action_reveal.dart';
import '../../domain/enums/item_status.dart';
import '../../domain/enums/project_status.dart';
import '../bill/providers/bill_providers.dart';
import '../bill/widgets/bill_detail_sheet.dart';
import '../life_item/providers/life_item_providers.dart';
import '../life_item/widgets/life_item_detail_sheet.dart';
import '../project/providers/project_providers.dart';
import '../project/widgets/project_name_chip.dart';
import 'search_service.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lifeItems = ref.watch(lifeItemsProvider).valueOrNull ?? const [];
    final bills = ref.watch(billRepoProvider).watchAll();
    final projects = ref.watch(projectsProvider).valueOrNull ?? const [];

    return Scaffold(
      appBar: AppBar(title: const Text('搜索')),
      body: StreamBuilder(
        stream: bills,
        builder: (context, snapshot) {
          final results = SearchService.search(
            query: _query,
            lifeItems: lifeItems,
            billRecords: snapshot.data ?? const [],
            projects: projects,
          );
          return Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (event) =>
                SwipeRevealController.closeIfOutside(event.position),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                TextField(
                  controller: _controller,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: '搜索事项、账单和项目',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
                const SizedBox(height: 12),
                if (_query.trim().isEmpty)
                  const Center(child: Text('输入关键词开始搜索'))
                else if (results.isEmpty)
                  const Center(child: Text('没有匹配结果'))
                else
                  for (final result in results)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _SearchResultRow(result: result),
                    ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SearchResultRow extends ConsumerWidget {
  const _SearchResultRow({required this.result});

  final SearchResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (icon, color) = switch (result.kind) {
      SearchResultKind.lifeItem => (Icons.event_note, AppColors.upcoming),
      SearchResultKind.billRecord => (Icons.receipt_long, AppColors.expense),
      SearchResultKind.project => (Icons.folder_outlined, Colors.blue),
    };

    final row = Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _open(context, ref),
        child: Stack(
          children: [
            CardLeftStripe(color: color),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.textHint.withValues(alpha: 0.4),
                ),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 66),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                  child: Row(
                    children: [
                      CardEntryIcon(icon: icon, color: color),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              result.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                ProjectNameChip(projectId: result.projectId),
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      result.subtitle,
                                      maxLines: 1,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: AppColors.textSecondary,
                                          ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final actions = <SwipeAction>[
      if (result.kind == SearchResultKind.lifeItem && _canMutateLifeItem) ...[
        SwipeAction(
          label: '完成',
          icon: Icons.check,
          color: AppColors.completed,
          onTap: () async {
            await ref
                .read(lifeItemNotifierProvider.notifier)
                .complete(result.id);
          },
        ),
        SwipeAction(
          label: '延期',
          icon: Icons.event_repeat,
          color: Colors.orange.shade800,
          onTap: () => _defer(context, ref),
        ),
      ],
      if (result.kind == SearchResultKind.billRecord) ...[
        SwipeAction(
          label: '编辑',
          icon: Icons.edit_outlined,
          color: AppColors.primary,
          onTap: () => context.push('/bills/${result.id}/edit'),
        ),
        SwipeAction(
          label: '删除',
          icon: Icons.delete_outline,
          color: AppColors.overdue,
          onTap: () => _confirmDeleteBill(context, ref),
        ),
      ],
      if (result.kind == SearchResultKind.project && _canEditProject)
        SwipeAction(
          label: '编辑',
          icon: Icons.edit_outlined,
          color: AppColors.primary,
          onTap: () => context.push('/projects/${result.id}/edit'),
        ),
    ];

    return SwipeActionReveal(actions: actions, child: row);
  }

  void _open(BuildContext context, WidgetRef ref) {
    switch (result.kind) {
      case SearchResultKind.lifeItem:
        final item = result.lifeItem;
        if (item != null) {
          showLifeItemDetailSheet(context, ref, item);
        }
      case SearchResultKind.billRecord:
        _openBill(context, ref);
      case SearchResultKind.project:
        context.push('/projects/${result.id}');
    }
  }

  Future<void> _openBill(BuildContext context, WidgetRef ref) async {
    final bill = result.billRecord;
    if (bill != null) {
      showBillDetailSheet(context, ref, bill);
      return;
    }
    final loaded = await ref.read(billRepoProvider).watchById(result.id).first;
    if (!context.mounted) return;
    showBillDetailSheet(context, ref, loaded);
  }

  Future<void> _defer(BuildContext context, WidgetRef ref) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      ref.read(lifeItemNotifierProvider.notifier).defer(result.id, picked);
    }
  }

  void _confirmDeleteBill(BuildContext context, WidgetRef ref) {
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
              ref.read(billNotifierProvider.notifier).delete(result.id);
              Navigator.of(dialogContext).pop();
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  bool get _canMutateLifeItem {
    final item = result.lifeItem;
    if (item == null || item.deletedAt != null) return false;
    return ItemStatus.fromString(item.status) == ItemStatus.pending;
  }

  bool get _canEditProject {
    final project = result.project;
    if (project == null || project.deletedAt != null) return false;
    return !ProjectStatus.fromString(project.projectStatus).isFinal;
  }
}
