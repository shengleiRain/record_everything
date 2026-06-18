import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/project_providers.dart';

/// A small tappable chip that shows a bound project's name.
///
/// Renders nothing when [projectId] is null. Otherwise it resolves the project
/// title via [projectByIdProvider] (mirroring the detail-page `_ProjectLink`)
/// and navigates to `/projects/$projectId` on tap. Designed to sit inside a
/// card's subtitle line.
///
/// The chip always sizes to its content (icon + padding + title) — it never
/// stretches to fill a row. [expanded] only loosens the title's max width so
/// longer names render in full where there's room (e.g. inside a bottom-sheet
/// "归属项目" row); pass `expanded: false` (the default) to keep the title tight
/// for compact card rows. [maxExpandedWidth] caps the title width in expanded
/// mode so an unusually long name still wraps with an ellipsis.
class ProjectNameChip extends ConsumerWidget {
  const ProjectNameChip({
    super.key,
    required this.projectId,
    this.expanded = false,
    this.maxExpandedWidth = 220,
    this.maxCompactTitleWidth = 80,
    this.minCompactTitleWidth = compactMinimumTitleWidth,
    this.trailingGap = 0,
  });

  const ProjectNameChip.compactCard({
    super.key,
    required this.projectId,
    this.trailingGap = 0,
  }) : expanded = false,
       maxExpandedWidth = 220,
       maxCompactTitleWidth = compactMinimumTitleWidth,
       minCompactTitleWidth = compactMinimumTitleWidth;

  /// Approximate width of three Chinese characters in the chip's label style.
  static const double compactMinimumTitleWidth = 42;

  final int? projectId;
  final bool expanded;

  /// Upper bound on the title width in [expanded] mode, so very long project
  /// names don't stretch the chip out. Ignored when [expanded] is false.
  final double maxExpandedWidth;

  /// Upper bound on the title width in compact mode.
  final double maxCompactTitleWidth;

  /// Lower bound on the title width in compact mode when layout has room.
  final double minCompactTitleWidth;

  /// Spacing after the chip. Kept inside the chip so missing projects render
  /// without leaving a leading gap before subtitle text.
  final double trailingGap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = projectId;
    if (id == null) return const SizedBox.shrink();

    final project = ref.watch(projectByIdProvider(id)).valueOrNull;
    // Project not found or is in the recycle bin — hide the chip entirely.
    if (project == null || project.deletedAt != null) {
      return const SizedBox.shrink();
    }

    final title = Text(
      project.title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: Colors.blue,
        fontWeight: FontWeight.w700,
      ),
    );

    final titleMaxWidth = expanded ? maxExpandedWidth : maxCompactTitleWidth;
    final titleMinWidth = expanded
        ? 0.0
        : minCompactTitleWidth.clamp(0.0, titleMaxWidth);

    return Padding(
      padding: EdgeInsets.only(right: trailingGap),
      child: InkWell(
        onTap: () => context.push('/projects/$id'),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          constraints: BoxConstraints(maxWidth: titleMaxWidth + 27),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.blue.withValues(alpha: 0.30)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.folder_outlined, size: 12, color: Colors.blue),
              const SizedBox(width: 3),
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: titleMinWidth,
                    maxWidth: titleMaxWidth,
                  ),
                  child: title,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
