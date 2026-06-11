import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/app_database.dart';
import '../../../data/database/database_provider.dart';
import '../../bill/providers/bill_providers.dart';
import '../../life_item/providers/life_item_providers.dart';
import '../../project/providers/project_providers.dart';

class RecycleBinPage extends ConsumerWidget {
  const RecycleBinPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('回收站')),
      body: FutureBuilder(
        future: _load(ref),
        builder: (context, snapshot) {
          final data = snapshot.data;
          if (data == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (data.items.isEmpty &&
              data.bills.isEmpty &&
              data.projects.isEmpty) {
            return const Center(child: Text('回收站为空'));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              for (final project in data.projects)
                ListTile(
                  leading: const Icon(Icons.folder_outlined),
                  title: Text(project.title),
                  subtitle: const Text('项目'),
                  trailing: TextButton(
                    onPressed: () async {
                      await ref
                          .read(projectNotifierProvider.notifier)
                          .restore(project.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('项目已恢复')),
                        );
                      }
                    },
                    child: const Text('恢复'),
                  ),
                ),
              for (final item in data.items)
                ListTile(
                  leading: const Icon(Icons.event_note),
                  title: Text(item.title),
                  subtitle: const Text('事项'),
                  trailing: TextButton(
                    onPressed: () async {
                      await ref.read(lifeItemRepoProvider).restoreItem(item.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('事项已恢复')),
                        );
                      }
                    },
                    child: const Text('恢复'),
                  ),
                ),
              for (final bill in data.bills)
                ListTile(
                  leading: const Icon(Icons.receipt_long),
                  title: Text(bill.title),
                  subtitle: const Text('账单'),
                  trailing: TextButton(
                    onPressed: () async {
                      await ref.read(billRepoProvider).restoreRecord(bill.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('账单已恢复')),
                        );
                      }
                    },
                    child: const Text('恢复'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<_RecycleBinData> _load(WidgetRef ref) async {
    final db = ref.read(databaseProvider);
    final allProjects =
        await (db.select(db.projects)
              ..where((t) => t.deletedAt.isNotNull()))
            .get();
    return _RecycleBinData(
      items: await db.lifeItemDao.getDeleted(),
      bills: await db.billRecordDao.getDeleted(),
      projects: allProjects,
    );
  }
}

class _RecycleBinData {
  const _RecycleBinData({
    required this.items,
    required this.bills,
    required this.projects,
  });

  final List<LifeItem> items;
  final List<BillRecord> bills;
  final List<Project> projects;
}
