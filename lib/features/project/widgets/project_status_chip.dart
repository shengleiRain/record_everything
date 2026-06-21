import 'package:flutter/material.dart';
import 'package:record_everything/l10n/l10n.dart';
import '../../../domain/enums/project_status.dart';

class ProjectStatusChip extends StatelessWidget {
  const ProjectStatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final ps = ProjectStatus.fromString(status);
    final color = _colorFor(ps);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        context.l.projectStatus(ps),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _colorFor(ProjectStatus ps) => switch (ps) {
    ProjectStatus.active => Colors.green,
    ProjectStatus.completed => Colors.teal,
    ProjectStatus.cancelled => Colors.grey,
    ProjectStatus.archived => Colors.brown,
  };
}
