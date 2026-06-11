import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/enums/project_event_type.dart';
import '../../../shared/widgets/app_dropdown_field.dart';
import '../providers/project_providers.dart';

void showProjectEventSheet(BuildContext context, WidgetRef ref, int projectId) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ProjectEventSheet(projectId: projectId),
  );
}

class _ProjectEventSheet extends ConsumerStatefulWidget {
  const _ProjectEventSheet({required this.projectId});
  final int projectId;

  @override
  ConsumerState<_ProjectEventSheet> createState() => _ProjectEventSheetState();
}

class _ProjectEventSheetState extends ConsumerState<_ProjectEventSheet> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  ProjectEventType _eventType = ProjectEventType.note;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    await ref.read(projectNotifierProvider.notifier).addEvent(
      projectId: widget.projectId,
      eventType: _eventType.value,
      title: title,
      description: _descController.text.trim().isEmpty
          ? null
          : _descController.text.trim(),
      eventTime: DateTime.now(),
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '添加事件',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          AppDropdownField<ProjectEventType>(
            label: '事件类型',
            value: _eventType,
            options: ProjectEventType.values
                .map((t) => AppDropdownOption(value: t, label: t.label))
                .toList(),
            onSelected: (v) =>
                setState(() => _eventType = v ?? _eventType),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: '标题 *'),
            autofocus: true,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descController,
            decoration: const InputDecoration(labelText: '描述'),
            maxLines: 3,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: _save, child: const Text('添加')),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
