import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/swipe_action_reveal.dart';
import '../../../data/database/app_database.dart';
import '../providers/project_providers.dart';

class ProjectTemplateListPage extends ConsumerWidget {
  const ProjectTemplateListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(projectTemplatesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('项目模板')),
      body: templatesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('加载失败: $error')),
        data: (templates) {
          if (templates.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.view_timeline_outlined,
                      size: 56,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '还没有项目模板',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '模板用于自动生成项目里的待办、待收款和交付节点。',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          // 与项目/账单列表页一致：点击空白区域收起已展开的滑动按钮。
          return Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (event) =>
                SwipeRevealController.closeIfOutside(event.position),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              itemCount: templates.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) =>
                  _TemplateTile(template: templates[index]),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/projects/templates/new'),
        icon: const Icon(Icons.add),
        label: const Text('新模板'),
      ),
    );
  }
}

class _TemplateTile extends ConsumerWidget {
  const _TemplateTile({required this.template});

  final ProjectTemplate template;

  Future<bool?> _confirmDelete(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除模板'),
        content: Text('确定删除”${template.name}”？已创建的项目不会受影响。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmCopy(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('复制模板'),
        content: Text('复制“${template.name}”为新模板？复制后会打开新模板供你编辑。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('复制'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final steps = ref
        .watch(projectTemplateStepsProvider(template.id))
        .valueOrNull;

    final card = Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.view_timeline_outlined, size: 20),
        ),
        title: Text(
          template.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (template.isDefault) const _Badge(label: '预置'),
                _Badge(label: '${steps?.length ?? 0} 个默认节点'),
              ],
            ),
            if (template.note?.isNotEmpty == true) ...[
              const SizedBox(height: 4),
              Text(
                template.note!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        onTap: () => context.push('/projects/templates/${template.id}/edit'),
      ),
    );

    // 与项目/账单卡片一致的滑动操作：左滑露出「复制 / 删除」两个按钮。
    return SwipeActionReveal(
      actions: [
        SwipeAction(
          label: '复制',
          icon: Icons.content_copy,
          color: AppColors.primary,
          onTap: () async {
            final shouldCopy = await _confirmCopy(context);
            if (shouldCopy != true) return;
            if (!context.mounted) return;
            final copy = await ref
                .read(projectNotifierProvider.notifier)
                .duplicateTemplate(template.id);
            if (!context.mounted) return;
            context.push('/projects/templates/${copy.id}/edit');
          },
        ),
        SwipeAction(
          label: '删除',
          icon: Icons.delete_outline,
          color: AppColors.overdue,
          onTap: () async {
            final shouldDelete = await _confirmDelete(context);
            if (shouldDelete != true) return;
            await ref
                .read(projectNotifierProvider.notifier)
                .deleteTemplate(template.id);
          },
        ),
      ],
      child: card,
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
