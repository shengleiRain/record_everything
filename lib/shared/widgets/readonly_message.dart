import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// A centered "this entity can't be edited" placeholder shown when an edit
/// page is opened on a finalized or soft-deleted entity.
///
/// Used by the project / life item / bill edit pages, which previously each
/// reimplemented this layout three times. The only variation between them is
/// the title/message copy and the back button's destination/label, both
/// exposed as constructor params.
class ReadonlyMessage extends StatelessWidget {
  const ReadonlyMessage({
    super.key,
    required this.title,
    required this.message,
    this.onBack,
    this.backLabel = '返回',
  });

  final String title;
  final String message;

  /// Called when the back button is tapped. When null, the button is omitted.
  final VoidCallback? onBack;

  /// Label for the back button. Defaults to '返回'.
  final String backLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 48, color: AppColors.textHint),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            if (onBack != null) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onBack,
                child: Text(backLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
