import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/dialog_helper.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/widgets/deleted_entity_banner.dart';
import '../../project/providers/project_providers.dart';
import '../providers/bill_providers.dart';

class BillDetailPage extends ConsumerWidget {
  const BillDetailPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id =
        int.tryParse(GoRouterState.of(context).pathParameters['id'] ?? '') ?? 0;
    final billAsync = ref.watch(billByIdProvider(id));

    return billAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(body: Center(child: Text('加载失败: $error'))),
      data: (bill) {
        final isDeleted = bill.deletedAt != null;
        final isIncome = bill.amountType == 'income';
        final amountColor = isIncome ? AppColors.income : AppColors.expense;
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('账单详情'),
            actions: [
              if (!isDeleted) ...[
                IconButton(
                  tooltip: '编辑',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => context.push('/bills/${bill.id}/edit'),
                ),
                IconButton(
                  tooltip: '删除',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _confirmDelete(context, ref, bill.id),
                ),
              ],
            ],
          ),
          body: Column(
            children: [
              if (isDeleted)
                DeletedEntityBanner(
                  entityLabel: '账单',
                  onRestore: () =>
                      ref.read(billRepoProvider).restoreRecord(bill.id),
                ),
              Expanded(
                child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                elevation: 0,
                color: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppColors.cardRadiusLarge),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: amountColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(AppColors.cardRadiusLarge),
                            ),
                            child: Icon(
                              isIncome
                                  ? Icons.payments_outlined
                                  : Icons.receipt_long_outlined,
                              color: amountColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              bill.title,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        isIncome
                            ? MoneyFormatter.formatIncome(bill.amount)
                            : MoneyFormatter.formatExpense(bill.amount),
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: amountColor,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        DateFormatter.formatDateTime(bill.billTime),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _InfoCard(
                rows: [
                  _InfoRow(
                    label: '类型',
                    value: isIncome ? '收入' : '支出',
                    valueColor: amountColor,
                  ),
                  _InfoRow(
                    label: '备注',
                    value: bill.note?.trim().isNotEmpty == true
                        ? bill.note!.trim()
                        : '无备注',
                  ),
                ],
              ),
              if (bill.projectId != null) ...[
                const SizedBox(height: 12),
                _ProjectLink(projectId: bill.projectId!),
              ],
            ],
          ),
          ),
        ],
      ),
      );
      },
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, int id) {
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
              ref.read(billNotifierProvider.notifier).delete(id);
              dialogContext.safePop();
              if (context.mounted) context.pop();
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

class _ProjectLink extends ConsumerWidget {
  const _ProjectLink({required this.projectId});

  final int projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(projectByIdProvider(projectId)).valueOrNull;
    // Project not found or is in the recycle bin.
    if (project == null || project.deletedAt != null) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppColors.cardRadiusLarge),
      ),
      child: ListTile(
        leading: const Icon(Icons.folder_outlined),
        title: const Text('归属项目'),
        subtitle: Text(project.title),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/projects/$projectId'),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.rows});

  final List<_InfoRow> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (var index = 0; index < rows.length; index++) ...[
              rows[index],
              if (index != rows.length - 1)
                Divider(
                  height: 20,
                  color: Colors.black.withValues(alpha: 0.06),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: valueColor ?? AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
