import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/database_provider.dart';
import '../../../data/repositories/project_repository.dart';
import '../../../domain/enums/amount_type.dart';
import '../../../domain/enums/item_type.dart';
import '../../../shared/widgets/app_dropdown_field.dart';
import '../providers/project_providers.dart';

class ProjectTemplateEditPage extends ConsumerStatefulWidget {
  const ProjectTemplateEditPage({super.key});

  @override
  ConsumerState<ProjectTemplateEditPage> createState() =>
      _ProjectTemplateEditPageState();
}

class _ProjectTemplateEditPageState
    extends ConsumerState<ProjectTemplateEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _noteController = TextEditingController();
  final List<_StepDraft> _steps = [];

  bool _loaded = false;
  bool _isEdit = false;
  int? _editId;
  ProjectTemplate? _template;
  int? _categoryId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    final idStr = GoRouterState.of(context).pathParameters['id'];
    if (idStr != null && idStr != 'new') {
      _isEdit = true;
      _editId = int.tryParse(idStr);
      _load();
    } else {
      _steps.add(_StepDraft(title: '下一步行动', offsetDays: 0));
    }
    _loaded = true;
  }

  Future<void> _load() async {
    final id = _editId;
    if (id == null) return;
    final repo = ref.read(projectRepoProvider);
    final template = await repo.getTemplateById(id);
    final steps = await repo.getTemplateSteps(id);
    if (!mounted) return;
    setState(() {
      _template = template;
      _nameController.text = template.name;
      _noteController.text = template.note ?? '';
      _categoryId = template.categoryId;
      _steps
        ..clear()
        ..addAll(steps.map(_StepDraft.fromStep));
      if (_steps.isEmpty) {
        _steps.add(_StepDraft(title: '下一步行动', offsetDays: 0));
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    for (final step in _steps) {
      step.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final steps = _steps
        .where((step) => step.titleController.text.trim().isNotEmpty)
        .map((step) => step.toInput())
        .toList(growable: false);
    if (steps.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('至少保留一个模板节点')));
      return;
    }

    final notifier = ref.read(projectNotifierProvider.notifier);
    if (_isEdit && _template != null) {
      await notifier.updateTemplate(
        template: _template!.copyWith(
          name: _nameController.text.trim(),
          categoryId: Value(_categoryId),
          note: Value(
            _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
          ),
          updatedAt: DateTime.now(),
        ),
        steps: steps,
      );
    } else {
      await notifier.createTemplate(
        name: _nameController.text.trim(),
        categoryId: _categoryId,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        steps: steps,
      );
    }

    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEdit ? '编辑项目模板' : '新建项目模板'),
        actions: [
          IconButton(
            tooltip: '保存',
            icon: const Icon(Icons.check),
            onPressed: _save,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          children: [
            _SectionCard(
              title: '模板信息',
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: '模板名称 *'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? '请输入模板名称'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder<List<Category>>(
                    future: ref
                        .read(databaseProvider)
                        .categoryDao
                        .getByType('project'),
                    builder: (context, snapshot) {
                      final categories = snapshot.data ?? const <Category>[];
                      if (categories.isEmpty) return const SizedBox.shrink();
                      return AppDropdownField<int>(
                        label: '默认项目类型',
                        value: categories.any((c) => c.id == _categoryId)
                            ? _categoryId
                            : null,
                        options: categories
                            .map(
                              (category) => AppDropdownOption(
                                value: category.id,
                                label: category.name,
                              ),
                            )
                            .toList(),
                        onSelected: (value) =>
                            setState(() => _categoryId = value),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _noteController,
                    decoration: const InputDecoration(labelText: '模板备注'),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: '默认节点',
              child: Column(
                children: [
                  for (var index = 0; index < _steps.length; index++) ...[
                    _StepDraftCard(
                      index: index,
                      draft: _steps[index],
                      onChanged: () => setState(() {}),
                      onDelete: _steps.length == 1
                          ? null
                          : () => setState(() {
                              final removed = _steps.removeAt(index);
                              removed.dispose();
                            }),
                    ),
                    if (index != _steps.length - 1) const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => setState(
                        () =>
                            _steps.add(_StepDraft(title: '新节点', offsetDays: 0)),
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('添加节点'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _save, child: const Text('保存模板')),
          ],
        ),
      ),
    );
  }
}

class _StepDraft {
  _StepDraft({
    required String title,
    this.itemType = ItemType.todo,
    this.amountType = AmountType.none,
    int? amount,
    int offsetDays = 0,
  }) : titleController = TextEditingController(text: title),
       amountController = TextEditingController(
         text: amount == null ? '' : (amount / 100).toStringAsFixed(2),
       ),
       offsetDaysController = TextEditingController(text: '$offsetDays');

  factory _StepDraft.fromStep(ProjectTemplateStep step) {
    return _StepDraft(
      title: step.title,
      itemType: ItemType.fromString(step.itemType),
      amountType: AmountType.fromString(step.amountType),
      amount: step.amount,
      offsetDays: step.offsetDays,
    );
  }

  final TextEditingController titleController;
  final TextEditingController amountController;
  final TextEditingController offsetDaysController;
  ItemType itemType;
  AmountType amountType;

  ProjectTemplateStepInput toInput() {
    return ProjectTemplateStepInput(
      title: titleController.text.trim(),
      itemType: itemType.value,
      amountType: amountType.value,
      offsetDays: int.tryParse(offsetDaysController.text.trim()) ?? 0,
      amount: amountType == AmountType.none
          ? null
          : MoneyFormatter.parse(amountController.text),
    );
  }

  void dispose() {
    titleController.dispose();
    amountController.dispose();
    offsetDaysController.dispose();
  }
}

class _StepDraftCard extends StatelessWidget {
  const _StepDraftCard({
    required this.index,
    required this.draft,
    required this.onChanged,
    required this.onDelete,
  });

  final int index;
  final _StepDraft draft;
  final VoidCallback onChanged;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  '节点 ${index + 1}',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(
                  tooltip: '删除节点',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            TextFormField(
              controller: draft.titleController,
              decoration: const InputDecoration(labelText: '节点标题 *'),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? '请输入节点标题' : null,
            ),
            const SizedBox(height: 12),
            AppDropdownField<ItemType>(
              label: '节点类型',
              value: draft.itemType,
              options: ItemType.values
                  .map(
                    (type) => AppDropdownOption(value: type, label: type.label),
                  )
                  .toList(),
              onSelected: (value) {
                draft.itemType = value ?? draft.itemType;
                onChanged();
              },
            ),
            const SizedBox(height: 12),
            AppDropdownField<AmountType>(
              label: '金额类型',
              value: draft.amountType,
              options: AmountType.values
                  .map(
                    (type) => AppDropdownOption(value: type, label: type.label),
                  )
                  .toList(),
              onSelected: (value) {
                draft.amountType = value ?? draft.amountType;
                onChanged();
              },
            ),
            if (draft.amountType != AmountType.none) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: draft.amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: '默认金额',
                  prefixText: '¥',
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: draft.offsetDaysController,
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              decoration: const InputDecoration(
                labelText: '相对关键日期偏移天数',
                helperText: '0 表示关键日期当天，-7 表示提前 7 天，14 表示之后 14 天',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
