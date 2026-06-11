import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';

void showQuickCreateSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => QuickCreateSheet(
      onNavigate: (location, {extra}) {
        Navigator.of(sheetContext).pop();
        context.push(location, extra: extra);
      },
    ),
  );
}

class QuickCreateSheet extends StatelessWidget {
  const QuickCreateSheet({super.key, required this.onNavigate});

  final void Function(String location, {Object? extra}) onNavigate;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'quick_create_sheet',
      container: true,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '快速新增',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        Text(
                          '选择一种记录',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 2.8,
                      children: [
                        _QuickCreateAction(
                          key: const ValueKey('quick-create-bill'),
                          icon: Icons.payments_outlined,
                          title: '记一笔',
                          subtitle: '收入 / 支出流水',
                          onTap: () => onNavigate('/bills/new'),
                        ),
                        _QuickCreateAction(
                          key: const ValueKey('quick-create-item'),
                          icon: Icons.check_circle_outline,
                          title: '建事项',
                          subtitle: '待办 / 提醒',
                          onTap: () => onNavigate('/items/new'),
                        ),
                        _QuickCreateAction(
                          key: const ValueKey('quick-create-bill-item'),
                          icon: Icons.event_available_outlined,
                          title: '账单到期',
                          subtitle: '还款 / 缴费',
                          onTap: () => onNavigate('/items/new'),
                        ),
                        _QuickCreateAction(
                          key: const ValueKey('quick-create-template'),
                          icon: Icons.repeat,
                          title: '周期模板',
                          subtitle: '会员 / 耗材',
                          onTap: () => onNavigate('/items/new'),
                        ),
                        _QuickCreateAction(
                          key: const ValueKey('quick-create-project'),
                          icon: Icons.folder_outlined,
                          title: '建项目',
                          subtitle: '项目 / 订单',
                          onTap: () => onNavigate('/projects/new'),
                        ),
                        _QuickCreateAction(
                          key: const ValueKey('quick-create-photography'),
                          icon: Icons.photo_camera_outlined,
                          title: '摄影接单',
                          subtitle: '定金 / 尾款',
                          onTap: () => onNavigate(
                            '/projects/new',
                            extra: {'template': 'photography'},
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickCreateAction extends StatelessWidget {
  const _QuickCreateAction({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
