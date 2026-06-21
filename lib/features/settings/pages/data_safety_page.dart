import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record_everything/l10n/l10n.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/toast.dart';
import '../providers/settings_providers.dart';

class DataSafetyPage extends ConsumerWidget {
  const DataSafetyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l.page_dataSafety)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _ActionGroup(
            rows: [
              _ActionRowData(
                icon: Icons.file_upload_outlined,
                title: '导出备份',
                subtitle: '保存到本地文件',
                onTap: () => _exportLocal(context, ref),
              ),
              _ActionRowData(
                icon: Icons.cloud_upload_outlined,
                title: '上传到 WebDAV',
                subtitle: '备份到云端服务器',
                onTap: () => _exportWebDav(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ActionGroup(
            rows: [
              _ActionRowData(
                icon: Icons.file_download_outlined,
                title: '导入备份',
                subtitle: '从本地文件恢复数据',
                onTap: () => _importLocal(context, ref),
              ),
              _ActionRowData(
                icon: Icons.cloud_download_outlined,
                title: '从 WebDAV 导入',
                subtitle: '从云端服务器恢复',
                onTap: () => _importWebDav(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border(context)),
            ),
            child: Text(
              '导入会追加有效记录，并自动复用同名同类型分类。导入前会校验备份版本、字段结构、日期和金额格式。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary(context),
                    height: 1.5,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportLocal(BuildContext context, WidgetRef ref) async {
    try {
      final path = await ref
          .read(settingsNotifierProvider.notifier)
          .exportWithFilePicker();
      if (context.mounted) {
        Toast.info(context, path == null ? '已取消导出' : '备份已导出: $path');
      }
    } catch (error) {
      if (context.mounted) Toast.error(context, '导出失败: $error');
    }
  }

  Future<void> _exportWebDav(BuildContext context, WidgetRef ref) async {
    final config = await ref.read(webdavConfigProvider.future);
    if (config == null) {
      if (context.mounted) {
        Toast.info(context, '请先配置 WebDAV');
        context.push('/settings/webdav');
      }
      return;
    }
    try {
      await ref.read(settingsNotifierProvider.notifier).exportToWebDav();
      if (context.mounted) Toast.success(context, '备份已上传到 WebDAV');
    } catch (error) {
      if (context.mounted) Toast.error(context, '上传失败: $error');
    }
  }

  Future<void> _importLocal(BuildContext context, WidgetRef ref) async {
    try {
      final summary = await ref
          .read(settingsNotifierProvider.notifier)
          .importWithFilePicker();
      if (context.mounted) {
        final message = summary == null
            ? '已取消导入'
            : '导入成功: 分类 ${summary.categoriesImported}，'
                '模板 ${summary.projectTemplatesImported}，'
                '项目 ${summary.projectsImported}，'
                '事项 ${summary.lifeItemsImported}，'
                '账单 ${summary.billRecordsImported}';
        Toast.success(context, message);
      }
    } catch (error) {
      if (context.mounted) Toast.error(context, '导入失败: $error');
    }
  }

  Future<void> _importWebDav(BuildContext context, WidgetRef ref) async {
    final config = await ref.read(webdavConfigProvider.future);
    if (config == null) {
      if (context.mounted) {
        Toast.info(context, '请先配置 WebDAV');
        context.push('/settings/webdav');
      }
      return;
    }

    if (!context.mounted) return;

    // Show file list BottomSheet
    try {
      final files =
          await ref.read(settingsNotifierProvider.notifier).listWebDavBackups();
      if (!context.mounted) return;

      if (files.isEmpty) {
        Toast.info(context, '暂无备份文件');
        return;
      }

      final selected = await showModalBottomSheet<String>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  '选择备份文件',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: files.length,
                  itemBuilder: (ctx, index) {
                    final file = files[index];
                    return ListTile(
                      title: Text(file.fileName),
                      subtitle: Text(
                        '${file.displaySize}  ·  '
                        '${file.modifiedAt.month}/${file.modifiedAt.day} '
                        '${file.modifiedAt.hour}:${file.modifiedAt.minute.toString().padLeft(2, '0')}',
                      ),
                      onTap: () => Navigator.of(ctx).pop(file.fileName),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );

      if (selected == null || !context.mounted) return;

      final summary = await ref
          .read(settingsNotifierProvider.notifier)
          .importFromWebDav(selected);
      if (context.mounted) {
        if (summary == null) {
          Toast.info(context, '已取消导入');
        } else {
          Toast.success(
            context,
            '导入成功: 分类 ${summary.categoriesImported}，'
                '项目 ${summary.projectsImported}，'
                '事项 ${summary.lifeItemsImported}，'
                '账单 ${summary.billRecordsImported}',
          );
        }
      }
    } catch (error) {
      if (context.mounted) Toast.error(context, '导入失败: $error');
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
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        children: [
          for (var index = 0; index < rows.length; index++) ...[
            _ActionRow(data: rows[index]),
            if (index != rows.length - 1)
              Divider(
                height: 1,
                indent: 56,
                color: AppColors.borderLight(context),
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
      trailing: Icon(Icons.chevron_right, color: AppColors.textHint(context)),
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
