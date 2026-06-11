import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_dropdown_field.dart';
import '../providers/project_providers.dart';

class ProjectPickerField extends ConsumerWidget {
  const ProjectPickerField({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = '归属项目',
  });

  static const int noProjectValue = 0;

  final int? value;
  final ValueChanged<int?> onChanged;
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(projectsProvider);

    return projectsAsync.when(
      loading: () => InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: const LinearProgressIndicator(minHeight: 2),
      ),
      error: (error, _) => InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text('项目加载失败: $error'),
      ),
      data: (projects) {
        final validValue = projects.any((project) => project.id == value)
            ? value
            : noProjectValue;
        return AppDropdownField<int>(
          label: label,
          value: validValue,
          options: [
            const AppDropdownOption(value: noProjectValue, label: '不归属项目'),
            ...projects.map(
              (project) =>
                  AppDropdownOption(value: project.id, label: project.title),
            ),
          ],
          onSelected: (selected) => onChanged(
            selected == null || selected == noProjectValue ? null : selected,
          ),
        );
      },
    );
  }
}
