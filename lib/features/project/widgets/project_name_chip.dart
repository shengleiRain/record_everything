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
class ProjectNameChip extends ConsumerWidget {
  const ProjectNameChip({super.key, required this.projectId});

  final int? projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = projectId;
    if (id == null) return const SizedBox.shrink();

    final project = ref.watch(projectByIdProvider(id)).valueOrNull;
    final label = project?.title;

    return InkWell(
      onTap: () => context.push('/projects/$id'),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Text(
                label ?? '加载中',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.blue,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
