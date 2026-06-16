import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/widgets/card_parts.dart';
import '../../../core/widgets/swipe_action_reveal.dart';
import '../../../data/database/app_database.dart';
import '../../../domain/enums/project_event_type.dart';
import '../../../domain/enums/project_status.dart';
import '../../bill/providers/bill_providers.dart';
import '../../life_item/providers/life_item_providers.dart';
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(project.title),
        actions: [
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
      ),
      body: LayoutBuilder(
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
                    _SectionCard(
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
    );
  }

  void _showQuickActionsSheet(BuildContext context, WidgetRef ref) {
    final nextStatus = _nextStatus(project.projectStatus);
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
              _ActionTile(
                key: const ValueKey('project-detail-action-add-item'),
                icon: Icons.add_task,
                label: '添加项目事项',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  context.push('/items/new', extra: {'projectId': project.id});
                },
              ),
              _ActionTile(
                key: const ValueKey('project-detail-action-add-bill'),
                icon: Icons.receipt_long,
                label: '记一笔独立账单',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  context.push('/bills/new', extra: {'projectId': project.id});
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
              if (nextStatus != null)
                _ActionTile(
                  icon: _statusAdvanceIcon(project.projectStatus),
                  label: _statusAdvanceLabel(project.projectStatus),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _advanceStatus(ref);
                  },
                ),
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
        content: const Text('确定删除此项目？关联的事项和账单将保留。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
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

  Future<void> _advanceStatus(WidgetRef ref) async {
    final next = _nextStatus(project.projectStatus);
    if (next == null) return;
    final previous = ProjectStatus.fromString(project.projectStatus);
    final now = DateTime.now();
    await ref
        .read(projectNotifierProvider.notifier)
        .update(project.copyWith(projectStatus: next.value, updatedAt: now));
    await ref
        .read(projectNotifierProvider.notifier)
        .addEvent(
          projectId: project.id,
          eventType: ProjectEventType.statusChange.value,
          title: '状态变更: ${previous.label} -> ${next.label}',
          description: '项目状态从 ${previous.label} 变为 ${next.label}',
          eventTime: now,
          isSystem: true,
        );
  }

  ProjectStatus? _nextStatus(String current) => switch (current) {
    'planned' => ProjectStatus.active,
    'active' => ProjectStatus.completed,
    'waiting' => ProjectStatus.completed,
    'completed' => ProjectStatus.archived,
    _ => null,
  };

  IconData _statusAdvanceIcon(String current) => switch (current) {
    'planned' => Icons.play_arrow,
    'active' => Icons.check,
    'waiting' => Icons.check,
    'completed' => Icons.archive_outlined,
    _ => Icons.swap_horiz,
  };

  String _statusAdvanceLabel(String current) => switch (current) {
    'planned' => '开始执行',
    'active' => '标记完成',
    'waiting' => '标记完成',
    'completed' => '归档',
    _ => '推进状态',
  };
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
            color: Colors.green,
            backgroundColor: const Color(0xFFE5F5EC),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricCard(
            label: '待收',
            value: MoneyFormatter.formatInt(pendingReceivable),
            color: Colors.orange.shade800,
            backgroundColor: const Color(0xFFFFF0DC),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricCard(
            label: '支出',
            value: MoneyFormatter.formatInt(expense),
            color: Colors.red.shade700,
            backgroundColor: const Color(0xFFFEE8E5),
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
    return _SectionCard(
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
          Divider(height: 1, color: Colors.black.withValues(alpha: 0.08)),
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
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
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
                    color: AppColors.textSecondary,
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
                    color: Colors.black.withValues(alpha: 0.08),
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
              color: AppColors.surface,
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
                                                color: AppColors.textSecondary,
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
      itemType: item?.itemType,
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
      statusColor: _statusColor(item),
      borderColor: isOverdue
          ? AppColors.overdue.withValues(alpha: 0.28)
          : isCompleted
          ? AppColors.completed.withValues(alpha: 0.24)
          : Colors.black.withValues(alpha: 0.08),
    );
  }

  _FlowVisual _entryVisual(
    BuildContext context, {
    required String amountType,
    required String? itemType,
    required bool isBill,
    required bool isSettled,
    required bool isOverdue,
  }) {
    if (isOverdue) {
      return const _FlowVisual(
        icon: Icons.error_outline,
        color: AppColors.overdue,
      );
    }
    if (isBill) {
      final color = amountType == 'income' ? Colors.green : Colors.red.shade700;
      return _FlowVisual(icon: Icons.receipt_long_outlined, color: color);
    }

    if ((amountType == 'income' || amountType == 'expense') && !isSettled) {
      return _FlowVisual(
        icon: Icons.schedule_outlined,
        color: Colors.orange.shade800,
      );
    }
    if (amountType == 'income') {
      return const _FlowVisual(
        icon: Icons.payments_outlined,
        color: Colors.green,
      );
    }
    if (amountType == 'expense') {
      return _FlowVisual(
        icon: Icons.outbox_outlined,
        color: Colors.red.shade700,
      );
    }
    return switch (itemType) {
      'delivery' => const _FlowVisual(
        icon: Icons.local_shipping_outlined,
        color: Colors.teal,
      ),
      'milestone' => _FlowVisual(
        icon: Icons.flag_outlined,
        color: Colors.amber.shade800,
      ),
      _ => _FlowVisual(
        icon: Icons.event_note_outlined,
        color: Theme.of(context).colorScheme.primary,
      ),
    };
  }

  String? _trailingText({required int? amount, required String amountType}) {
    if (amount == null || amountType == 'none') return null;
    if (amountType == 'income') return '+${MoneyFormatter.formatInt(amount)}';
    return '-${MoneyFormatter.formatInt(amount.abs())}';
  }

  Color _trailingColor({
    required String amountType,
    required bool isSettled,
    required bool hasAmount,
  }) {
    if (!hasAmount) return AppColors.textSecondary;
    if (!isSettled) return Colors.orange.shade800;
    if (amountType == 'income') return Colors.green;
    return Colors.red.shade700;
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

  Color _statusColor(LifeItem? item) {
    if (item?.status == 'completed') return AppColors.primary;
    return AppColors.overdue;
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
            color: AppColors.overdue,
            onTap: () => _confirmDeleteBill(context, ref, linkedBill),
          ),
        ];
      }
      if (item.status == 'completed') {
        return [
          if (isFinancial)
            SwipeAction(
              label: '补账',
              icon: Icons.receipt_long,
              color: item.amountType == 'income'
                  ? AppColors.income
                  : AppColors.expense,
              onTap: () => _openBillForItem(context, item),
            ),
          SwipeAction(
            label: '删除',
            icon: Icons.delete_outline,
            color: AppColors.overdue,
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
                ? AppColors.income
                : AppColors.expense,
            onTap: () => _openBillForItem(context, item),
          ),
          SwipeAction(
            label: '延期',
            icon: Icons.event_repeat,
            color: Colors.orange.shade800,
            onTap: () => _deferItem(context, ref, item),
          ),
        ];
      }
      return [
        SwipeAction(
          label: '完成',
          icon: Icons.check,
          color: AppColors.completed,
          onTap: () => _completeItem(context, ref, item),
        ),
        SwipeAction(
          label: '延期',
          icon: Icons.event_repeat,
          color: Colors.orange.shade800,
          onTap: () => _deferItem(context, ref, item),
        ),
      ];
    }

    return [
      SwipeAction(
        label: '删除',
        icon: Icons.delete_outline,
        color: AppColors.overdue,
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已完成事项')));
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已延期事项')));
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
    final linkedBill = data.entry.linkedBill;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DetailSheetHeader(data: data),
                  const SizedBox(height: 12),
                  if (item != null) ...[
                    _DetailInfoRow(
                      label: '预期时间',
                      value: DateFormatter.formatDateTime(item.dueTime),
                    ),
                    _DetailInfoRow(
                      label: '状态',
                      value: data.statusLabel ?? '待处理',
                    ),
                    if (linkedBill != null)
                      _DetailInfoRow(
                        label: '实际时间',
                        value: DateFormatter.formatDateTime(
                          linkedBill.billTime,
                        ),
                      ),
                    if (item.description?.trim().isNotEmpty == true)
                      _DetailInfoRow(
                        label: '说明',
                        value: item.description!.trim(),
                      ),
                    const SizedBox(height: 12),
                    if (item.status == 'pending' && linkedBill == null)
                      _DetailActionRow(
                        children: [
                          OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(sheetContext).pop();
                              context.push('/items/${item.id}/edit');
                            },
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('编辑'),
                          ),
                          if (item.amountType == 'income' ||
                              item.amountType == 'expense')
                            FilledButton.icon(
                              onPressed: () {
                                Navigator.of(sheetContext).pop();
                                _openBillForItem(context, item);
                              },
                              icon: Icon(
                                item.amountType == 'income'
                                    ? Icons.payments_outlined
                                    : Icons.outbox_outlined,
                              ),
                              label: Text(
                                item.amountType == 'income' ? '收款' : '付款',
                              ),
                            )
                          else
                            FilledButton.icon(
                              onPressed: () {
                                Navigator.of(sheetContext).pop();
                                _completeItem(context, ref, item);
                              },
                              icon: const Icon(Icons.check),
                              label: const Text('完成'),
                            ),
                        ],
                      )
                    else if (linkedBill != null)
                      _DetailActionRow(
                        children: [
                          FilledButton.icon(
                            onPressed: () {
                              Navigator.of(sheetContext).pop();
                              _confirmDeleteBill(context, ref, linkedBill);
                            },
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('删除账单'),
                          ),
                        ],
                      )
                    else
                      _DetailActionRow(
                        children: [
                          if (item.amountType == 'income' ||
                              item.amountType == 'expense')
                            OutlinedButton.icon(
                              onPressed: () {
                                Navigator.of(sheetContext).pop();
                                _openBillForItem(context, item);
                              },
                              icon: const Icon(Icons.receipt_long),
                              label: const Text('补账'),
                            ),
                          FilledButton.icon(
                            onPressed: () {
                              Navigator.of(sheetContext).pop();
                              _confirmDeleteItem(context, ref, item);
                            },
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('删除事项'),
                          ),
                        ],
                      ),
                  ] else if (bill != null) ...[
                    _DetailInfoRow(
                      label: '记账时间',
                      value: DateFormatter.formatDateTime(bill.billTime),
                    ),
                    _DetailInfoRow(
                      label: '类型',
                      value: bill.amountType == 'income' ? '收入' : '支出',
                    ),
                    if (bill.note?.trim().isNotEmpty == true)
                      _DetailInfoRow(label: '备注', value: bill.note!.trim()),
                    const SizedBox(height: 12),
                    _DetailActionRow(
                      children: [
                        FilledButton.icon(
                          onPressed: () {
                            Navigator.of(sheetContext).pop();
                            _confirmDeleteBill(context, ref, bill);
                          },
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('删除'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
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

class _DetailSheetHeader extends StatelessWidget {
  const _DetailSheetHeader({required this.data});

  final _FlowCardData data;

  @override
  Widget build(BuildContext context) {
    final title = data.entry.title;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CardEntryIcon(icon: data.visual.icon, color: data.visual.color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                data.entry.kind == ProjectFlowEntryKind.bill ? '账单' : '事项',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        if (data.trailingText != null)
          CardTrailingValue(
            text: data.trailingText!,
            color: data.trailingColor,
          ),
      ],
    );
  }
}

class _DetailInfoRow extends StatelessWidget {
  const _DetailInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailActionRow extends StatelessWidget {
  const _DetailActionRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 0; index < children.length; index++) ...[
          Expanded(child: children[index]),
          if (index != children.length - 1) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _DatePill extends StatelessWidget {
  const _DatePill({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
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
                  color: AppColors.textSecondary,
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

class _SectionCard extends StatelessWidget {
  const _SectionCard({this.title, required this.child});

  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(
                title!,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
            ],
            child,
          ],
        ),
      ),
    );
  }
}
