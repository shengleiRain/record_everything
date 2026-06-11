import 'package:flutter/material.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/database/app_database.dart';
import 'project_status_chip.dart';
import 'project_financial_bar.dart';

class ProjectCard extends StatelessWidget {
  const ProjectCard({
    super.key,
    required this.project,
    this.incomeReceived = 0,
    this.onTap,
  });

  final Project project;
  final int incomeReceived;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
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
              if (project.totalAmount != null && project.totalAmount! > 0) ...[
                const SizedBox(height: 10),
                ProjectFinancialBar(
                  totalAmount: project.totalAmount,
                  incomeReceived: incomeReceived,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
