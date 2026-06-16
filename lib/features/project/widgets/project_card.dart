import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/swipe_action_reveal.dart';
import '../../../data/database/app_database.dart';
import '../../../domain/enums/project_status.dart';
import 'project_status_chip.dart';

class ProjectCard extends StatelessWidget {
  const ProjectCard({
    super.key,
    required this.project,
    this.onTap,
    this.onEdit,
    this.onArchive,
    this.onDelete,
  });

  final Project project;
  final VoidCallback? onTap;

  /// Swipe-revealed actions. When all are null the card renders as a plain
  /// tappable card (its historical behaviour).
  final VoidCallback? onEdit;
  final VoidCallback? onArchive;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ps = ProjectStatus.fromString(project.projectStatus);
    final stripeColor = _colorFor(ps);
    // Archived projects are read-only: editing is not allowed.
    final isArchived = ps == ProjectStatus.archived;

    final card = Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(color: stripeColor),
                child: const SizedBox(width: 4),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              project.title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ProjectStatusChip(status: project.projectStatus),
                        ],
                      ),
                      if (project.participant != null &&
                          project.participant!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          project.participant!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (project.startDate != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.event_outlined,
                              size: 14,
                              color: theme.colorScheme.outline,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              DateFormatter.formatDate(project.startDate!),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final actions = <SwipeAction>[
      // Edit is a modification; archived projects are read-only.
      if (onEdit != null && !isArchived)
        SwipeAction(
          label: '编辑',
          icon: Icons.edit_outlined,
          color: AppColors.primary,
          onTap: onEdit!,
        ),
      if (onArchive != null && ps != ProjectStatus.archived)
        SwipeAction(
          label: '归档',
          icon: Icons.inventory_2_outlined,
          color: Colors.brown,
          onTap: onArchive!,
        ),
      if (onDelete != null)
        SwipeAction(
          label: '删除',
          icon: Icons.delete_outline,
          color: AppColors.overdue,
          onTap: onDelete!,
        ),
    ];

    // Keep the horizontal margin OUTSIDE the SwipeActionReveal so the reveal's
    // action layer aligns with the card's width (otherwise the 148px-wide
    // actions peek out past the card's right edge before any swipe).
    const outerPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 4);
    if (actions.isEmpty) {
      return Padding(padding: outerPadding, child: card);
    }
    return Padding(
      padding: outerPadding,
      child: SwipeActionReveal(actions: actions, child: card),
    );
  }

  Color _colorFor(ProjectStatus ps) => switch (ps) {
    ProjectStatus.planned => Colors.blue,
    ProjectStatus.active => Colors.green,
    ProjectStatus.waiting => Colors.orange,
    ProjectStatus.completed => Colors.teal,
    ProjectStatus.cancelled => Colors.grey,
    ProjectStatus.archived => Colors.brown,
  };
}
