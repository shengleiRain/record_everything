import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../providers/settings_providers.dart';

class DataSafetyPage extends ConsumerWidget {
  const DataSafetyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('数据安全')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _ActionGroup(
            rows: [
              _ActionRowData(
                icon: Icons.file_upload_outlined,
                title: '导出备份',
                subtitle: '保存为 JSON 文件',
                onTap: () => _export(context, ref),
              ),
              _ActionRowData(
                icon: Icons.file_download_outlined,
                title: '导入备份',
                subtitle: '从 JSON 文件恢复数据',
                onTap: () => _import(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.black.withValues(alpha: 0.07)),
            ),
            child: Text(
              '导入会追加有效记录，并自动复用同名同类型分类。导入前会校验备份版本、字段结构、日期和金额格式。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    try {
      final path = await ref
          .read(settingsNotifierProvider.notifier)
          .exportWithFilePicker();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(path == null ? '已取消导出' : '备份已导出: $path')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('导出失败: $error')));
      }
    }
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    try {
      final summary = await ref
          .read(settingsNotifierProvider.notifier)
          .importWithFilePicker();
      if (context.mounted) {
        final message = summary == null
            ? '已取消导入'
            : '导入成功: 分类 ${summary.categoriesImported}，模板 ${summary.projectTemplatesImported}，项目 ${summary.projectsImported}，事项 ${summary.lifeItemsImported}，账单 ${summary.billRecordsImported}';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('导入失败: $error')));
      }
    }
  }
}

class _ActionGroup extends StatelessWidget {
  const _ActionGroup({required this.rows});

  final List<_ActionRowData> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black.withValues(alpha: 0.07)),
      ),
      child: Column(
        children: [
          for (var index = 0; index < rows.length; index++) ...[
            _ActionRow(data: rows[index]),
            if (index != rows.length - 1)
              Divider(
                height: 1,
                indent: 56,
                color: Colors.black.withValues(alpha: 0.06),
              ),
          ],
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.data});

  final _ActionRowData data;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minLeadingWidth: 28,
      leading: Icon(data.icon, color: AppColors.primaryDark),
      title: Text(data.title),
      subtitle: Text(data.subtitle),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textHint),
      onTap: data.onTap,
    );
  }
}

class _ActionRowData {
  const _ActionRowData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}
