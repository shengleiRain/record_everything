import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A banner shown at the top of a detail/edit page when the entity has been
/// soft-deleted (is in the recycle bin).
///
/// Provides a visual indicator and a restore callback.
class DeletedEntityBanner extends StatelessWidget {
  const DeletedEntityBanner({
    super.key,
    required this.entityLabel,
    this.onRestore,
  });

  /// Human-readable entity type, e.g. '项目', '事项', '账单'.
  final String entityLabel;

  /// Called when the user taps "恢复". If null, the button is hidden.
  final VoidCallback? onRestore;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.upcoming.withValues(alpha: 0.12),
        border: Border(
          bottom: BorderSide(color: AppColors.upcoming.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.delete_outline, size: 18, color: AppColors.upcoming),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '此$entityLabel已在回收站中',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (onRestore != null)
            TextButton(
              onPressed: onRestore,
              child: const Text('恢复'),
            ),
        ],
      ),
    );
  }
}

/// Wraps a detail page body with a recycle-bin banner when [isDeleted] is true.
///
/// When deleted, the [child] is still rendered (so the user can see the
/// content) but the [deletedChild] replaces it if provided — useful for
/// showing a stripped-down view with only the restore action.
class DeletedEntityWrapper extends StatelessWidget {
  const DeletedEntityWrapper({
    super.key,
    required this.isDeleted,
    required this.entityLabel,
    this.onRestore,
    required this.child,
  });

  final bool isDeleted;
  final String entityLabel;
  final VoidCallback? onRestore;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!isDeleted) return child;
    return Column(
      children: [
        DeletedEntityBanner(
          entityLabel: entityLabel,
          onRestore: onRestore,
        ),
        Expanded(child: child),
      ],
    );
  }
}
