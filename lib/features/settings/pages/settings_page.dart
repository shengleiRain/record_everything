import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/notification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/settings_providers.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _SettingsGroup(
            rows: [
              _SettingsRowData(
                icon: '账',
                title: '默认账本',
                subtitle: '生活账本 · 默认记录入口',
                onTap: () => _showComingSoon(context, '默认账本'),
              ),
              _SettingsRowData(
                icon: '类',
                title: '分类管理',
                subtitle: '支出、收入、事项类型',
                onTap: () => _showComingSoon(context, '分类管理'),
              ),
              _SettingsRowData(
                icon: '铃',
                title: '提醒设置',
                subtitle: '到期提醒通知权限',
                onTap: () => NotificationService.requestPermission(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SettingsGroup(
            rows: [
              _SettingsRowData(
                icon: '入',
                title: '导入数据',
                subtitle: '从 JSON 备份恢复',
                onTap: () => _showImportDialog(context, ref),
              ),
              _SettingsRowData(
                icon: '出',
                title: '导出备份',
                subtitle: '导出为本地 JSON 文件',
                onTap: () => _export(context, ref),
              ),
              _SettingsRowData(
                icon: '安',
                title: '数据安全',
                subtitle: '本地存储 · 可导出恢复',
                onTap: () => _showComingSoon(context, '数据安全'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _PreferenceCard(),
          const SizedBox(height: 12),
          _AboutRow(),
        ],
      ),
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    try {
      final path = await ref
          .read(settingsNotifierProvider.notifier)
          .exportToJson();
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('数据已导出至: $path')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('导出失败: $e')));
      }
    }
  }

  void _showImportDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('导入数据'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: '粘贴 JSON 数据',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await ref
                    .read(settingsNotifierProvider.notifier)
                    .importFromJson(controller.text);
                if (context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('数据导入成功')));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('导入失败: $e')));
                }
              }
            },
            child: const Text('导入'),
          ),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context, String title) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$title 后续开放')));
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.rows});

  final List<_SettingsRowData> rows;

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
            _SettingsRow(data: rows[index]),
            if (index != rows.length - 1)
              Divider(
                height: 1,
                indent: 56,
                endIndent: 12,
                color: Colors.black.withValues(alpha: 0.06),
              ),
          ],
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.data});

  final _SettingsRowData data;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: data.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                data.icon,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    data.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }
}

class _SettingsRowData {
  const _SettingsRowData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}

class _PreferenceCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '应用偏好',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Text(
                '移动端优先',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '首页默认使用收缩周视图，也可展开为整月日历；下方列表跟随选中日期切换，只显示当天事项和账单。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text(
      '生活事项 v0.1.0',
      textAlign: TextAlign.center,
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: AppColors.textHint),
    );
  }
}
