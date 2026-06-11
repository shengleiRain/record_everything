import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/database/app_database.dart';
import '../../../domain/enums/project_event_type.dart';
import '../../../domain/enums/project_status.dart';
import '../providers/project_providers.dart';
import '../widgets/project_status_chip.dart';
import '../widgets/project_financial_bar.dart';
import '../widgets/project_timeline.dart';
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
    final paymentDuesAsync = ref.watch(projectPaymentDuesProvider(project.id));
    final billsAsync = ref.watch(projectBillsProvider(project.id));

    final income = incomeAsync.valueOrNull ?? 0;
    final expense = expenseAsync.valueOrNull ?? 0;
    final paymentDueTotal =
        paymentDuesAsync.valueOrNull?.fold<int>(
          0,
          (sum, item) => sum + (item.amount ?? 0),
        ) ??
        0;
    final receivable =
        project.totalAmount ?? (paymentDueTotal > 0 ? paymentDueTotal : null);
    final remainingReceivable = _remainingAmount(receivable, income);
    final net = income - expense;
    final openItems =
        itemsAsync.valueOrNull?.where((i) => i.status == 'pending').length ?? 0;
    final completedItems =
        itemsAsync.valueOrNull?.where((i) => i.status == 'completed').length ??
        0;

    return Scaffold(
      appBar: AppBar(
        title: Text(project.title),
        actions: [
          IconButton(
            tooltip: '编辑项目',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push('/projects/${project.id}/edit'),
          ),
          PopupMenuButton<String>(
            tooltip: '更多项目操作',
            onSelected: (v) => _handleMenu(context, ref, v),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'delete', child: Text('删除项目')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 80),
        children: [
          // Overview
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        project.title,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    ProjectStatusChip(status: project.projectStatus),
                  ],
                ),
                if (project.participant != null &&
                    project.participant!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 16,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        project.participant!,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ],
                if (project.startDate != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.event_outlined,
                        size: 16,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        DateFormatter.formatDate(project.startDate!),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ],
                if (project.note != null && project.note!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    project.note!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Financial summary
          _SectionCard(
            title: '财务概览',
            child: Column(
              children: [
                _FinancialRow(label: '应收总额', value: receivable, color: null),
                if (paymentDueTotal > 0)
                  _FinancialRow(
                    label: '收款节点',
                    value: paymentDueTotal,
                    color: Colors.orange,
                  ),
                _FinancialRow(label: '已收', value: income, color: Colors.green),
                _FinancialRow(
                  label: '待收',
                  value: remainingReceivable,
                  color: Colors.orange,
                ),
                _FinancialRow(label: '项目支出', value: expense, color: Colors.red),
                _FinancialRow(
                  label: '净额',
                  value: net,
                  color: net >= 0 ? Colors.green : Colors.red,
                ),
                if (receivable != null && receivable > 0) ...[
                  const SizedBox(height: 12),
                  ProjectFinancialBar(
                    totalAmount: receivable,
                    incomeReceived: income,
                  ),
                ],
              ],
            ),
          ),

          // Quick actions
          _SectionCard(
            title: '快捷操作',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ActionChip(
                  icon: Icons.add_task,
                  label: '添加事项',
                  onTap: () => context.push(
                    '/items/new',
                    extra: {'projectId': project.id},
                  ),
                ),
                _ActionChip(
                  icon: Icons.receipt_long,
                  label: '记一笔',
                  onTap: () => context.push(
                    '/bills/new',
                    extra: {'projectId': project.id},
                  ),
                ),
                _ActionChip(
                  icon: Icons.note_add_outlined,
                  label: '添加事件',
                  onTap: () => showProjectEventSheet(context, ref, project.id),
                ),
                _ActionChip(
                  icon: _statusAdvanceIcon(project.projectStatus),
                  label: _statusAdvanceLabel(project.projectStatus),
                  onTap: () => _advanceStatus(ref),
                ),
              ],
            ),
          ),

          // Items section
          _SectionCard(
            title: '事项 ($openItems 待办 / $completedItems 已完成)',
            child: itemsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('加载失败: $e'),
              data: (items) {
                if (items.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: Text(
                        '暂无事项',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ),
                  );
                }
                return Column(
                  children: items
                      .map(
                        (item) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            item.status == 'completed'
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            color: item.status == 'completed'
                                ? Colors.green
                                : Theme.of(context).colorScheme.outline,
                            size: 20,
                          ),
                          title: Text(
                            item.title,
                            style: TextStyle(
                              decoration: item.status == 'completed'
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          subtitle: item.amount != null
                              ? Text(
                                  '${item.amountType == 'income' ? '+' : '-'}${MoneyFormatter.formatInt(item.amount!)}',
                                  style: TextStyle(
                                    color: item.amountType == 'income'
                                        ? Colors.green
                                        : Colors.red,
                                    fontSize: 12,
                                  ),
                                )
                              : null,
                          onTap: () => context.push('/items/${item.id}'),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ),

          // Bills section
          _SectionCard(
            title: '账单',
            child: billsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('加载失败: $e'),
              data: (bills) {
                if (bills.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: Text(
                        '暂无账单',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ),
                  );
                }
                return Column(
                  children: bills
                      .map(
                        (bill) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            bill.amountType == 'income'
                                ? Icons.arrow_downward
                                : Icons.arrow_upward,
                            color: bill.amountType == 'income'
                                ? Colors.green
                                : Colors.red,
                            size: 20,
                          ),
                          title: Text(bill.title),
                          subtitle: Text(
                            DateFormatter.formatDate(bill.billTime),
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: Text(
                            '${bill.amountType == 'income' ? '+' : '-'}${MoneyFormatter.formatInt(bill.amount)}',
                            style: TextStyle(
                              color: bill.amountType == 'income'
                                  ? Colors.green
                                  : Colors.red,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onTap: () => context.push('/bills/${bill.id}/edit'),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ),

          // Timeline
          _SectionCard(
            title: '时间线',
            child: ProjectTimeline(projectId: project.id),
          ),
        ],
      ),
    );
  }

  void _handleMenu(BuildContext context, WidgetRef ref, String action) {
    if (action == 'delete') {
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

  int? _remainingAmount(int? total, int received) {
    if (total == null) return null;
    final remaining = total - received;
    return remaining > 0 ? remaining : 0;
  }
}

class _FinancialRow extends StatelessWidget {
  const _FinancialRow({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int? value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(
            value != null ? MoneyFormatter.formatInt(value!) : '—',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(
                title!,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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
