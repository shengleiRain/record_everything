import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/toast.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/widgets/card_parts.dart';
import '../../../core/widgets/deleted_entity_banner.dart';
import '../../../core/widgets/section_card.dart';
import '../../../core/widgets/swipe_action_reveal.dart';
import '../../../data/database/app_database.dart';
import '../../../domain/enums/project_status.dart';
import '../../bill/widgets/bill_detail_sheet.dart';
import '../../bill/providers/bill_providers.dart';
import '../../life_item/providers/life_item_providers.dart';
import '../../life_item/widgets/life_item_detail_sheet.dart';
import '../providers/project_providers.dart';
import '../widgets/project_event_sheet.dart';

class ProjectDetailPage extends ConsumerWidget {
  const ProjectDetailPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final idStr = GoRouterState.of(context).pathParameters['id'];
    final id = int.tryParse(idStr ?? '');
    if (id == null) {
      return const Scaffold(body: Center(child: Text('无效项目ID')));
    }

    final projectAsync = ref.watch(projectByIdProvider(id));

    return projectAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('加载失败: $e'))),
      data: (project) => _ProjectDetailBody(project: project),
    );
  }
}

class _ProjectDetailBody extends ConsumerWidget {
  const _ProjectDetailBody({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDeleted = project.deletedAt != null;
    final isReadonly =
        ProjectStatus.fromString(project.projectStatus).isFinal || isDeleted;
    final incomeAsync = ref.watch(projectIncomeProvider(project.id));
    final expenseAsync = ref.watch(projectExpenseProvider(project.id));
    final itemsAsync = ref.watch(projectLifeItemsProvider(project.id));
    final billsAsync = ref.watch(projectBillsProvider(project.id));

    final income = incomeAsync.valueOrNull ?? 0;
    final expense = expenseAsync.valueOrNull ?? 0;
    final pendingReceivable = calculateProjectPendingReceivable(
      items: itemsAsync.valueOrNull ?? const [],
      bills: billsAsync.valueOrNull ?? const [],
    );

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Text(project.title),
        actions: [
          if (!isDeleted) ...[
            if (!isReadonly)
              IconButton(
                tooltip: '编辑项目',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => context.push('/projects/${project.id}/edit'),
              ),
            IconButton(
              key: const ValueKey('project-detail-delete'),
              tooltip: '删除项目',
              color: Theme.of(context).colorScheme.error,
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDelete(context, ref),
            ),
            IconButton(
              key: const ValueKey('project-detail-more-actions'),
              tooltip: '更多项目操作',
              icon: const Icon(Icons.more_horiz),
              onPressed: () => _showQuickActionsSheet(context, ref),
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          if (isDeleted)
            DeletedEntityBanner(
              entityLabel: '项目',
              onRestore: () => ref
                  .read(projectNotifierProvider.notifier)
                  .restore(project.id),
            ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Listener(
                      behavior: HitTestBehavior.translucent,
                      onPointerDown: (event) {
                        SwipeRevealController.closeIfOutside(event.position);
                      },
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                        children: [
                          SectionCard(
                            title: '财务概览',
                            child: _FinancialOverview(
                              income: income,
                              pendingReceivable: pendingReceivable,
                              expense: expense,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _ProjectSummaryCard(project: project),
                          const SizedBox(height: 12),
                          const _SectionHeader(title: '时间线'),
                          const SizedBox(height: 8),
                          _ProjectFlowPanel(
                            itemsAsync: itemsAsync,
                            billsAsync: billsAsync,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showQuickActionsSheet(BuildContext context, WidgetRef ref) {
    final current = ProjectStatus.fromString(project.projectStatus);
    final nextStatus = current.nextStatus;
    final isDeleted = project.deletedAt != null;
    final canEditProject = !isDeleted && !current.isFinal;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Text(
                '快捷操作',
                style: Theme.of(
                  sheetContext,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              if (!isDeleted) ...[
                if (canEditProject) ...[
                  _ActionTile(
                    key: const ValueKey('project-detail-action-add-item'),
                    icon: Icons.add_task,
                    label: '添加项目事项',
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      context.push(
                        '/items/new',
                        extra: {'projectId': project.id},
                      );
                    },
                  ),
                  _ActionTile(
                    key: const ValueKey('project-detail-action-add-bill'),
                    icon: Icons.receipt_long,
                    label: '记一笔独立账单',
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      context.push(
                        '/bills/new',
                        extra: {'projectId': project.id},
                      );
                    },
                  ),
                  _ActionTile(
                    icon: Icons.note_add_outlined,
                    label: '添加项目事件',
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      showProjectEventSheet(context, ref, project.id);
                    },
                  ),
                ],
                // 推进状态（如 进行中 → 已完成）
                if (nextStatus != null)
                  _ActionTile(
                    icon: current == ProjectStatus.active
                        ? Icons.check
                        : Icons.swap_horiz,
                    label: current.advanceLabel,
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _changeStatus(ref, nextStatus);
                    },
                  ),
                // 归档（仅已完成可归档）
                if (current == ProjectStatus.completed)
                  _ActionTile(
                    icon: Icons.archive_outlined,
                    label: '归档项目',
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _changeStatus(ref, ProjectStatus.archived);
                    },
                  ),
                // 取消项目（非终态可取消）
                if (!current.isFinal)
                  _ActionTile(
                    icon: Icons.cancel_outlined,
                    label: '取消项目',
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _changeStatus(ref, ProjectStatus.cancelled);
                    },
                  ),
                // 重新激活（终态可重开为进行中）
                if (current.isFinal)
                  _ActionTile(
                    icon: Icons.restart_alt,
                    label: '重新激活',
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _changeStatus(ref, ProjectStatus.active);
                    },
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除项目'),
        content: const Text('删除后可在回收站恢复，关联的事项和账单将保留。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref
                  .read(projectNotifierProvider.notifier)
                  .delete(project.id);
              if (!context.mounted) return;
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/home');
              }
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  /// 统一的项目状态变更入口：更新状态并写一条 status_change 事件日志，
  /// 保证状态流转与审计记录始终一致。所有状态变更（推进/取消/重开/归档）
  /// 都走这里，禁止在编辑页直接改状态。
  Future<void> _changeStatus(WidgetRef ref, ProjectStatus next) async {
    await ref
        .read(projectNotifierProvider.notifier)
        .changeStatus(project: project, next: next);
  }
}

@visibleForTesting
int calculateProjectPendingReceivable({
  required List<LifeItem> items,
  required List<BillRecord> bills,
}) {
  final settledItemIds = bills
      .where((bill) => bill.lifeItemId != null && bill.amountType == 'income')
      .map((bill) => bill.lifeItemId!)
      .toSet();
  return items
      .where(
        (item) =>
            item.amountType == 'income' &&
            item.status == 'pending' &&
            item.amount != null &&
            !settledItemIds.contains(item.id),
      )
      .fold<int>(0, (sum, item) => sum + item.amount!);
}

@visibleForTesting
String? buildProjectFlowMetaText({
  required LifeItem? item,
  required BillRecord? bill,
  required BillRecord? linkedBill,
  required bool isBill,
}) {
  if (isBill) {
    final record = bill;
    if (record == null) return null;
    final action = record.amountType == 'income' ? '已收款' : '已付款';
    return '$action${_flowTimeSuffix(record.billTime)}';
  }

  final lifeItem = item;
  if (lifeItem == null) return null;
  if (lifeItem.amountType == 'income' || lifeItem.amountType == 'expense') {
    final action = lifeItem.amountType == 'income' ? '收款' : '付款';
    if (linkedBill != null) {
      return '已$action${_flowTimeSuffix(linkedBill.billTime)}';
    }
    if (lifeItem.status == 'completed') {
      return '已$action';
    }
    return '预计$action${_flowTimeSuffix(lifeItem.dueTime)}';
  }

  return null;
}

String _flowTimeSuffix(DateTime time) {
  if (time.hour == 0 && time.minute == 0) return '';
  return ' ${_flowTwo(time.hour)}:${_flowTwo(time.minute)}';
}

String _flowTwo(int value) => value.toString().padLeft(2, '0');

class _FinancialOverview extends StatelessWidget {
  const _FinancialOverview({
    required this.income,
    required this.pendingReceivable,
    required this.expense,
  });

  final int income;
  final int pendingReceivable;
  final int expense;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            label: '已收',
            value: MoneyFormatter.formatInt(income),
            color: AppColors.income(context),
            backgroundColor: AppColors.income(context).withValues(alpha: 0.12),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricCard(
            label: '待收',
            value: MoneyFormatter.formatInt(pendingReceivable),
            color: AppColors.upcoming(context),
            backgroundColor: AppColors.upcoming(context).withValues(alpha: 0.12),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricCard(
            label: '支出',
            value: MoneyFormatter.formatInt(expense),
            color: AppColors.expense(context),
            backgroundColor: AppColors.expense(context).withValues(alpha: 0.12),
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.color,
    required this.backgroundColor,
  });

  final String label;
  final String value;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            _ScaledMoneyText(
              value: value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScaledMoneyText extends StatelessWidget {
  const _ScaledMoneyText({required this.value, this.style});

  final String value;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(value, maxLines: 1, style: style),
      ),
    );
  }
}

class _ProjectSummaryCard extends StatelessWidget {
  const _ProjectSummaryCard({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _SummaryItem(
                  label: '客户/参与人',
                  value: project.participant,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: _SummaryItem(
                  label: '关键日期',
                  value: project.startDate == null
                      ? null
                      : DateFormatter.formatDate(project.startDate!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: AppColors.border(context)),
          const SizedBox(height: 12),
          _SummaryItem(label: '备注', value: project.note, maxLines: 3),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.label,
    required this.value,
    this.maxLines = 2,
  });

  final String label;
  final String? value;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final text = value == null || value!.trim().isEmpty ? '—' : value!.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary(context)),
        ),
        const SizedBox(height: 3),
        Text(
          text,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _ProjectFlowPanel extends StatelessWidget {
  const _ProjectFlowPanel({required this.itemsAsync, required this.billsAsync});

  final AsyncValue<List<LifeItem>> itemsAsync;
  final AsyncValue<List<BillRecord>> billsAsync;

  @override
  Widget build(BuildContext context) {
    return itemsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Text('加载失败: $e'),
      data: (items) => billsAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Text('加载失败: $e'),
        data: (bills) {
          final entries = buildProjectFlowEntries(items: items, bills: bills);
          if (entries.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  '暂无项目事项或独立账单',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary(context),
                  ),
                ),
              ),
            );
          }
          return Stack(
            children: [
              Positioned(
                left: 35,
                top: 6,
                bottom: 6,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.border(context),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const SizedBox(width: 2),
                ),
              ),
              Column(
                children: [
                  for (var index = 0; index < entries.length; index++) ...[
                    _ProjectFlowCard(entry: entries[index]),
                    if (index != entries.length - 1) const SizedBox(height: 8),
                  ],
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

@visibleForTesting
List<ProjectFlowEntry> buildProjectFlowEntries({
  required List<LifeItem> items,
  required List<BillRecord> bills,
}) {
  final linkedBills = <int, BillRecord>{};
  final sortedLinkedBills =
      bills.where((bill) => bill.lifeItemId != null).toList(growable: false)
        ..sort((a, b) => a.billTime.compareTo(b.billTime));
  for (final bill in sortedLinkedBills) {
    linkedBills[bill.lifeItemId!] = bill;
  }

  final entries = <ProjectFlowEntry>[
    for (final item in items)
      ProjectFlowEntry.item(item, linkedBill: linkedBills[item.id]),
    for (final bill in bills.where((bill) => bill.lifeItemId == null))
      ProjectFlowEntry.bill(bill),
  ];

  entries.sort((a, b) {
    final byTime = a.sortTime.compareTo(b.sortTime);
    if (byTime != 0) return byTime;
    return a.title.compareTo(b.title);
  });
  return entries;
}

enum ProjectFlowEntryKind { item, bill }

class ProjectFlowEntry {
  const ProjectFlowEntry._({
    required this.kind,
    this.item,
    this.bill,
    this.linkedBill,
  });

  factory ProjectFlowEntry.item(LifeItem item, {BillRecord? linkedBill}) =>
      ProjectFlowEntry._(
        kind: ProjectFlowEntryKind.item,
        item: item,
        linkedBill: linkedBill,
      );

  factory ProjectFlowEntry.bill(BillRecord bill) =>
      ProjectFlowEntry._(kind: ProjectFlowEntryKind.bill, bill: bill);

  final ProjectFlowEntryKind kind;
  final LifeItem? item;
  final BillRecord? bill;
  final BillRecord? linkedBill;

  DateTime get sortTime => switch (kind) {
    ProjectFlowEntryKind.item => linkedBill?.billTime ?? item!.dueTime,
    ProjectFlowEntryKind.bill => bill!.billTime,
  };

  String get title => switch (kind) {
    ProjectFlowEntryKind.item => item!.title,
    ProjectFlowEntryKind.bill => bill!.title,
  };

  int? get displayAmount => switch (kind) {
    ProjectFlowEntryKind.item => linkedBill?.amount ?? item!.amount,
    ProjectFlowEntryKind.bill => bill!.amount,
  };

  String get displayAmountType => switch (kind) {
    ProjectFlowEntryKind.item => linkedBill?.amountType ?? item!.amountType,
    ProjectFlowEntryKind.bill => bill!.amountType,
  };
}

class _ProjectFlowCard extends ConsumerWidget {
  const _ProjectFlowCard({required this.entry});

  final ProjectFlowEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = _buildData(context);
    final actions = _quickActions(context, ref, data);
    final isBill = entry.kind == ProjectFlowEntryKind.bill;

    return SwipeActionReveal(
      actions: actions,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _DatePill(date: data.date),
          const SizedBox(width: 8),
          Expanded(
            child: Material(
              color: AppColors.surface(context),
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                key: ValueKey(
                  isBill
                      ? 'project-flow-card-bill-${entry.bill!.id}'
                      : 'project-flow-card-item-${entry.item!.id}',
                ),
                borderRadius: BorderRadius.circular(8),
                onTap: () => _showDetailSheet(context, ref, data),
                child: Stack(
                  children: [
                    CardLeftStripe(color: data.visual.color),
                    if (isBill) const BillFoldCorner(),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: data.borderColor),
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 66),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                          child: Align(
                            alignment: Alignment.center,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                CardEntryIcon(
                                  icon: data.visual.icon,
                                  color: data.visual.color,
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        entry.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                      if (data.metaText != null) ...[
                                        const SizedBox(height: 5),
                                        Text(
                                          data.metaText!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: AppColors.textSecondary(context),
                                                fontWeight: FontWeight.w500,
                                              ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (data.trailingText != null) ...[
                                  const SizedBox(width: 8),
                                  CardTrailingValue(
                                    text: data.trailingText!,
                                    color: data.trailingColor,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (data.statusLabel != null)
                      StatusCornerBadge(
                        label: data.statusLabel!,
                        color: data.statusColor,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  _FlowCardData _buildData(BuildContext context) {
    final isBill = entry.kind == ProjectFlowEntryKind.bill;
    final item = entry.item;
    final bill = entry.bill;
    final linkedBill = entry.linkedBill;
    final amountType = entry.displayAmountType;
    final amount = entry.displayAmount;
    final isCompleted = item?.status == 'completed';
    final isOverdue =
        item?.status == 'pending' && DateFormatter.isOverdue(item!.dueTime);
    final isSettled = isBill || linkedBill != null || isCompleted;
    final visual = _entryVisual(
      context,
      amountType: amountType,
      isBill: isBill,
      isSettled: isSettled,
      isOverdue: isOverdue,
    );
    final hasAmount = amount != null && amountType != 'none';

    return _FlowCardData(
      entry: entry,
      date: entry.sortTime,
      visual: visual,
      trailingText: _trailingText(amount: amount, amountType: amountType),
      trailingColor: _trailingColor(
        context,
        amountType: amountType,
        isSettled: isSettled,
        hasAmount: hasAmount,
      ),
      metaText: _metaText(
        item: item,
        bill: bill,
        linkedBill: linkedBill,
        isBill: isBill,
      ),
      statusLabel: _statusLabel(item),
      statusColor: _statusColor(context, item),
      borderColor: isOverdue
          ? AppColors.overdue(context).withValues(alpha: 0.28)
          : isCompleted
          ? AppColors.completed(context).withValues(alpha: 0.24)
          : AppColors.border(context),
    );
  }

  _FlowVisual _entryVisual(
    BuildContext context, {
    required String amountType,
    required bool isBill,
    required bool isSettled,
    required bool isOverdue,
  }) {
    if (isOverdue) {
      return _FlowVisual(
        icon: Icons.error_outline,
        color: AppColors.overdue(context),
      );
    }
    if (isBill) {
      final color = amountType == 'income' ? AppColors.income(context) : AppColors.expense(context);
      return _FlowVisual(icon: Icons.receipt_long_outlined, color: color);
    }

    if ((amountType == 'income' || amountType == 'expense') && !isSettled) {
      return _FlowVisual(
        icon: Icons.schedule_outlined,
        color: AppColors.upcoming(context),
      );
    }
    if (amountType == 'income') {
      return _FlowVisual(
        icon: Icons.payments_outlined,
        color: AppColors.income(context),
      );
    }
    if (amountType == 'expense') {
      return _FlowVisual(
        icon: Icons.outbox_outlined,
        color: AppColors.expense(context),
      );
    }
    return _FlowVisual(
      icon: Icons.event_note_outlined,
      color: Theme.of(context).colorScheme.primary,
    );
  }

  String? _trailingText({required int? amount, required String amountType}) {
    if (amount == null || amountType == 'none') return null;
    if (amountType == 'income') return '+${MoneyFormatter.formatInt(amount)}';
    return '-${MoneyFormatter.formatInt(amount.abs())}';
  }

  Color _trailingColor(
    BuildContext context, {
    required String amountType,
    required bool isSettled,
    required bool hasAmount,
  }) {
    if (!hasAmount) return AppColors.textSecondary(context);
    if (!isSettled) return AppColors.upcoming(context);
    if (amountType == 'income') return AppColors.income(context);
    return AppColors.expense(context);
  }

  String? _metaText({
    required LifeItem? item,
    required BillRecord? bill,
    required BillRecord? linkedBill,
    required bool isBill,
  }) => buildProjectFlowMetaText(
    item: item,
    bill: bill,
    linkedBill: linkedBill,
    isBill: isBill,
  );

  String? _statusLabel(LifeItem? item) {
    if (item == null) return null;
    if (item.status == 'completed') return '已完成';
    if (item.status == 'pending' && DateFormatter.isOverdue(item.dueTime)) {
      return '逾期 ${_formatMonthDay(item.dueTime)}';
    }
    return null;
  }

  Color _statusColor(BuildContext context, LifeItem? item) {
    if (item?.status == 'completed') return AppColors.primary(context);
    return AppColors.overdue(context);
  }

  String _formatMonthDay(DateTime time) =>
      '${_two(time.month)}/${_two(time.day)}';

  String _two(int value) => value.toString().padLeft(2, '0');

  List<SwipeAction> _quickActions(
    BuildContext context,
    WidgetRef ref,
    _FlowCardData data,
  ) {
    final item = data.entry.item;
    final bill = data.entry.bill;
    if (item != null) {
      final linkedBill = data.entry.linkedBill;
      final isFinancial =
          item.amountType == 'income' || item.amountType == 'expense';
      if (linkedBill != null) {
        return [
          SwipeAction(
            label: '删账单',
            icon: Icons.delete_outline,
            color: AppColors.overdue(context),
            onTap: () => _confirmDeleteBill(context, ref, linkedBill),
          ),
        ];
      }
      if (item.status == 'completed' || item.status == 'cancelled') {
        return [
          if (isFinancial && item.status == 'completed')
            SwipeAction(
              label: '补账',
              icon: Icons.receipt_long,
              color: item.amountType == 'income'
                  ? AppColors.income(context)
                  : AppColors.expense(context),
              onTap: () => _openBillForItem(context, item),
            ),
          SwipeAction(
            label: '重新打开',
            icon: Icons.restart_alt,
            color: Colors.blue,
            onTap: () => _reopenItem(context, ref, item),
          ),
          SwipeAction(
            label: '删除',
            icon: Icons.delete_outline,
            color: AppColors.overdue(context),
            onTap: () => _confirmDeleteItem(context, ref, item),
          ),
        ];
      }
      if (isFinancial) {
        final label = item.amountType == 'income' ? '收款' : '付款';
        return [
          SwipeAction(
            label: label,
            icon: item.amountType == 'income'
                ? Icons.payments_outlined
                : Icons.outbox_outlined,
            color: item.amountType == 'income'
                ? AppColors.income(context)
                : AppColors.expense(context),
            onTap: () => _openBillForItem(context, item),
          ),
          SwipeAction(
            label: '延期',
            icon: Icons.event_repeat,
            color: AppColors.upcoming(context),
            onTap: () => _deferItem(context, ref, item),
          ),
        ];
      }
      return [
        SwipeAction(
          label: '完成',
          icon: Icons.check,
          color: AppColors.completed(context),
          onTap: () => _completeItem(context, ref, item),
        ),
        SwipeAction(
          label: '延期',
          icon: Icons.event_repeat,
          color: AppColors.upcoming(context),
          onTap: () => _deferItem(context, ref, item),
        ),
      ];
    }

    return [
      SwipeAction(
        label: '删除',
        icon: Icons.delete_outline,
        color: AppColors.overdue(context),
        onTap: () => _confirmDeleteBill(context, ref, bill!),
      ),
    ];
  }

  Future<void> _completeItem(
    BuildContext context,
    WidgetRef ref,
    LifeItem item,
  ) async {
    await ref.read(lifeItemNotifierProvider.notifier).complete(item.id);
    if (!context.mounted) return;
    Toast.info(context, '已完成事项');
  }

  Future<void> _reopenItem(
    BuildContext context,
    WidgetRef ref,
    LifeItem item,
  ) async {
    await ref.read(lifeItemNotifierProvider.notifier).reopen(item.id);
    if (!context.mounted) return;
    Toast.info(context, '已重新打开事项');
  }

  Future<void> _deferItem(
    BuildContext context,
    WidgetRef ref,
    LifeItem item,
  ) async {
    final now = DateTime.now();
    final initial = item.dueTime.isAfter(now)
        ? item.dueTime.add(const Duration(days: 1))
        : now.add(const Duration(days: 1));
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(initial.year, initial.month, initial.day),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked == null) return;
    await ref.read(lifeItemNotifierProvider.notifier).defer(item.id, picked);
    if (!context.mounted) return;
    Toast.info(context, '已延期事项');
  }

  void _confirmDeleteItem(BuildContext context, WidgetRef ref, LifeItem item) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除事项'),
        content: Text('确定删除“${item.title}”？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(lifeItemNotifierProvider.notifier).delete(item.id);
              Navigator.of(dialogContext).pop();
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _openBillForItem(BuildContext context, LifeItem item) {
    context.push(
      '/bills/new',
      extra: {
        'projectId': item.projectId,
        'lifeItemId': item.id,
        'title': item.title,
        'amount': item.amount,
        'amountType': item.amountType,
      },
    );
  }

  void _confirmDeleteBill(
    BuildContext context,
    WidgetRef ref,
    BillRecord bill,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除账单'),
        content: Text('确定删除“${bill.title}”？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(billNotifierProvider.notifier).delete(bill.id);
              Navigator.of(dialogContext).pop();
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _showDetailSheet(
    BuildContext context,
    WidgetRef ref,
    _FlowCardData data,
  ) {
    final item = data.entry.item;
    final bill = data.entry.bill;
    if (item != null) {
      showLifeItemDetailSheet(context, ref, item);
      return;
    }
    if (bill != null) {
      showBillDetailSheet(context, ref, bill);
    }
  }
}

class _FlowCardData {
  const _FlowCardData({
    required this.entry,
    required this.date,
    required this.visual,
    required this.trailingText,
    required this.trailingColor,
    required this.metaText,
    required this.statusLabel,
    required this.statusColor,
    required this.borderColor,
  });

  final ProjectFlowEntry entry;
  final DateTime date;
  final _FlowVisual visual;
  final String? trailingText;
  final Color trailingColor;
  final String? metaText;
  final String? statusLabel;
  final Color statusColor;
  final Color borderColor;
}

class _FlowVisual {
  const _FlowVisual({required this.icon, required this.color});

  final IconData icon;
  final Color color;
}

class _DatePill extends StatelessWidget {
  const _DatePill({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.background(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: SizedBox(
        width: 72,
        height: 56,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                _weekdayLabel(date),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _weekdayLabel(DateTime date) => switch (date.weekday) {
    DateTime.monday => '周一',
    DateTime.tuesday => '周二',
    DateTime.wednesday => '周三',
    DateTime.thursday => '周四',
    DateTime.friday => '周五',
    DateTime.saturday => '周六',
    _ => '周日',
  };
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }
}
