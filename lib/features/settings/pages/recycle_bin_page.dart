import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/toast.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/database_provider.dart';
import '../../bill/providers/bill_providers.dart';
import '../../life_item/providers/life_item_providers.dart';
import '../../project/providers/project_providers.dart';
import '../../project/widgets/project_name_chip.dart';

class RecycleBinPage extends ConsumerStatefulWidget {
  const RecycleBinPage({super.key});

  @override
  ConsumerState<RecycleBinPage> createState() => _RecycleBinPageState();
}

class _RecycleBinPageState extends ConsumerState<RecycleBinPage> {
  _RecycleBinData _data = const _RecycleBinData.empty();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final projects = await (db.select(
      db.projects,
    )..where((t) => t.deletedAt.isNotNull())).get();
    final items = await db.lifeItemDao.getDeleted();
    final bills = await db.billRecordDao.getDeleted();
    if (!mounted) return;
    setState(() {
      _data = _RecycleBinData(items: items, bills: bills, projects: projects);
      _loading = false;
    });
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('回收站')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _data.isEmpty
          ? const Center(child: Text('回收站为空'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                if (_data.projects.isNotEmpty) ...[
                  _SectionHeader(title: '项目', count: _data.projects.length),
                  for (final project in _data.projects)
                    _RecycleBinTile(
                      icon: Icons.folder_outlined,
                      title: project.title,
                      subtitle: '项目',
                      onRestore: () => _restoreProject(project),
                      onDelete: () => _permanentDeleteProject(project),
                    ),
                ],
                if (_data.items.isNotEmpty) ...[
                  _SectionHeader(title: '事项', count: _data.items.length),
                  for (final item in _data.items)
                    _RecycleBinTile(
                      icon: Icons.event_note,
                      title: item.title,
                      subtitle: '事项',
                      projectId: item.projectId,
                      onRestore: () => _restoreItem(item),
                      onDelete: () => _permanentDeleteItem(item),
                    ),
                ],
                if (_data.bills.isNotEmpty) ...[
                  _SectionHeader(title: '账单', count: _data.bills.length),
                  for (final bill in _data.bills)
                    _RecycleBinTile(
                      icon: Icons.receipt_long,
                      title: bill.title,
                      subtitle: '账单',
                      projectId: bill.projectId,
                      onRestore: () => _restoreBill(bill),
                      onDelete: () => _permanentDeleteBill(bill),
                    ),
                ],
              ],
            ),
    );
  }

  // --- Restore ---

  Future<void> _restoreProject(Project project) async {
    await ref.read(projectNotifierProvider.notifier).restore(project.id);
    if (!mounted) return;
    Toast.success(context, '项目已恢复');
    _refresh();
  }

  Future<void> _restoreItem(LifeItem item) async {
    await ref.read(lifeItemRepoProvider).restoreItem(item.id);
    if (!mounted) return;
    Toast.success(context, '事项已恢复');
    _refresh();
  }

  Future<void> _restoreBill(BillRecord bill) async {
    await ref.read(billRepoProvider).restoreRecord(bill.id);
    if (!mounted) return;
    Toast.success(context, '账单已恢复');
    _refresh();
  }

  // --- Permanent delete ---

  void _permanentDeleteProject(Project project) {
    _confirmPermanentDelete(
      label: '项目"${project.title}"',
      onConfirm: () async {
        await ref
            .read(projectNotifierProvider.notifier)
            .permanentDelete(project.id);
        if (!mounted) return;
        Toast.success(context, '项目已永久删除');
        _refresh();
      },
    );
  }

  void _permanentDeleteItem(LifeItem item) {
    _confirmPermanentDelete(
      label: '事项"${item.title}"',
      onConfirm: () async {
        await ref.read(lifeItemRepoProvider).permanentDeleteItem(item.id);
        if (!mounted) return;
        Toast.success(context, '事项已永久删除');
        _refresh();
      },
    );
  }

  void _permanentDeleteBill(BillRecord bill) {
    _confirmPermanentDelete(
      label: '账单"${bill.title}"',
      onConfirm: () async {
        await ref.read(billRepoProvider).permanentDeleteRecord(bill.id);
        if (!mounted) return;
        Toast.success(context, '账单已永久删除');
        _refresh();
      },
    );
  }

  void _confirmPermanentDelete({
    required String label,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('永久删除'),
        content: Text('确定永久删除$label？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.overdue),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              onConfirm();
            },
            child: const Text('永久删除'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 4),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.textHint.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecycleBinTile extends StatelessWidget {
  const _RecycleBinTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.projectId,
    required this.onRestore,
    required this.onDelete,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final int? projectId;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppColors.cardRadiusLarge),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 22, color: AppColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  ProjectNameLine(
                    projectId: projectId,
                    padding: const EdgeInsets.only(top: 3),
                  ),
                  Text(
                    subtitle,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.textHint),
                  ),
                ],
              ),
            ),
            TextButton(onPressed: onRestore, child: const Text('恢复')),
            IconButton(
              tooltip: '永久删除',
              icon: Icon(
                Icons.delete_forever_outlined,
                color: AppColors.overdue,
                size: 20,
              ),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _RecycleBinData {
  const _RecycleBinData({
    required this.items,
    required this.bills,
    required this.projects,
  });

  const _RecycleBinData.empty()
    : items = const [],
      bills = const [],
      projects = const [];

  final List<LifeItem> items;
  final List<BillRecord> bills;
  final List<Project> projects;

  bool get isEmpty => items.isEmpty && bills.isEmpty && projects.isEmpty;
}
