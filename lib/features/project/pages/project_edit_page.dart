import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' show Value;
import '../../../core/constants/project_template_keys.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/database_provider.dart';
import '../../../data/repositories/project_repository.dart';
import '../../../domain/enums/amount_type.dart';
import '../../../domain/enums/item_type.dart';
import '../../../domain/enums/project_status.dart';
import '../../../shared/widgets/app_dropdown_field.dart';
import '../providers/project_providers.dart';

class ProjectEditPage extends ConsumerStatefulWidget {
  const ProjectEditPage({super.key});

  @override
  ConsumerState<ProjectEditPage> createState() => _ProjectEditPageState();
}

class _ProjectEditPageState extends ConsumerState<ProjectEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _participantController = TextEditingController();
  final _totalAmountController = TextEditingController();
  final _noteController = TextEditingController();

  ProjectStatus _status = ProjectStatus.planned;
  int? _selectedCategoryId;
  DateTime? _startDate;
  DateTime? _endDate;
  int? _selectedTemplateId;
  String? _pendingTemplateKey;
  final List<_ProjectStepDraft> _stepDrafts = [];
  bool _isEdit = false;
  int? _editId;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    final state = GoRouterState.of(context);
    final idStr = state.pathParameters['id'];
    if (idStr != null && idStr != 'new') {
      _isEdit = true;
      _editId = int.tryParse(idStr);
      _loadFromDatabase();
    }
    // Check if template is requested via extra
    final extra = state.extra;
    if (extra is Map && extra['template'] == 'photography') {
      _pendingTemplateKey = ProjectTemplateKeys.photographyOrder;
    }
    _loaded = true;
  }

  void _applyPendingTemplateSelection(List<ProjectTemplate>? templates) {
    final pendingKey = _pendingTemplateKey;
    if (_isEdit || pendingKey == null || templates == null) return;
    final template = templates
        .where((entry) => entry.templateKey == pendingKey)
        .firstOrNull;
    if (template == null || _selectedTemplateId == template.id) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _pendingTemplateKey != pendingKey) return;
      setState(() {
        _selectedTemplateId = template.id;
        _selectedCategoryId = template.categoryId ?? _selectedCategoryId;
        _pendingTemplateKey = null;
      });
      _loadTemplateDrafts(template);
    });
  }

  void _selectTemplate(ProjectTemplate? template) {
    setState(() {
      _selectedTemplateId = template?.id;
      _selectedCategoryId = template?.categoryId ?? _selectedCategoryId;
      _pendingTemplateKey = null;
    });
    _loadTemplateDrafts(template);
  }

  Future<void> _loadTemplateDrafts(ProjectTemplate? template) async {
    if (template == null) {
      _replaceStepDrafts(const []);
      return;
    }
    final steps = await ref
        .read(projectRepoProvider)
        .getTemplateSteps(template.id);
    if (!mounted || _selectedTemplateId != template.id) return;
    _replaceStepDrafts(steps.map(_ProjectStepDraft.fromStep).toList());
  }

  void _replaceStepDrafts(List<_ProjectStepDraft> drafts) {
    for (final draft in _stepDrafts) {
      draft.dispose();
    }
    setState(() {
      _stepDrafts
        ..clear()
        ..addAll(drafts);
    });
  }

  Future<void> _loadFromDatabase() async {
    final id = _editId;
    if (id == null) return;
    final project = await ref.read(databaseProvider).projectDao.getById(id);
    if (!mounted) return;
    setState(() {
      _titleController.text = project.title;
      _participantController.text = project.participant ?? '';
      _status = ProjectStatus.fromString(project.projectStatus);
      _selectedCategoryId = project.categoryId;
      _startDate = project.startDate;
      _endDate = project.endDate;
      if (project.totalAmount != null) {
        _totalAmountController.text = MoneyFormatter.formatInt(
          project.totalAmount!,
        );
      }
      _noteController.text = project.note ?? '';
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _participantController.dispose();
    _totalAmountController.dispose();
    _noteController.dispose();
    for (final draft in _stepDrafts) {
      draft.dispose();
    }
    super.dispose();
  }

  List<ProjectTemplateStepInput> _enabledStepInputs() {
    return _stepDrafts
        .where((draft) => draft.enabled)
        .where((draft) => draft.titleController.text.trim().isNotEmpty)
        .map((draft) => draft.toInput())
        .toList(growable: false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final notifier = ref.read(projectNotifierProvider.notifier);

    final totalAmount = _totalAmountController.text.isNotEmpty
        ? MoneyFormatter.parse(_totalAmountController.text)
        : null;
    int? createdProjectId;

    if (_isEdit && _editId != null) {
      final project = await ref
          .read(databaseProvider)
          .projectDao
          .getById(_editId!);
      await notifier.update(
        project.copyWith(
          title: _titleController.text.trim(),
          categoryId: Value(_selectedCategoryId),
          participant: Value(
            _participantController.text.trim().isEmpty
                ? null
                : _participantController.text.trim(),
          ),
          projectStatus: _status.value,
          startDate: Value(_startDate),
          endDate: Value(_endDate),
          totalAmount: Value(totalAmount),
          note: Value(
            _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
          ),
          updatedAt: DateTime.now(),
        ),
      );
    } else if (_selectedTemplateId != null) {
      final project = await notifier.createFromTemplate(
        templateId: _selectedTemplateId!,
        title: _titleController.text.trim(),
        steps: _enabledStepInputs(),
        categoryId: _selectedCategoryId,
        participant: _participantController.text.trim().isEmpty
            ? null
            : _participantController.text.trim(),
        projectStatus: _status.value,
        startDate: _startDate,
        endDate: _endDate,
        totalAmount: totalAmount,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );
      createdProjectId = project.id;
    } else {
      final project = await notifier.create(
        title: _titleController.text.trim(),
        categoryId: _selectedCategoryId,
        participant: _participantController.text.trim().isEmpty
            ? null
            : _participantController.text.trim(),
        projectStatus: _status.value,
        startDate: _startDate,
        endDate: _endDate,
        totalAmount: totalAmount,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );
      createdProjectId = project.id;
    }

    if (!mounted) return;
    if (_isEdit) {
      context.pop();
    } else if (createdProjectId != null) {
      context.go('/projects/$createdProjectId');
    }
  }

  @override
  Widget build(BuildContext context) {
    final templates = ref.watch(projectTemplatesProvider).valueOrNull;
    _applyPendingTemplateSelection(templates);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(_isEdit ? '编辑项目' : '新建项目')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SectionCard(
              title: '基本信息',
              child: Column(
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: '项目标题 *'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? '请输入标题' : null,
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder(
                    future: ref
                        .read(databaseProvider)
                        .categoryDao
                        .getByType('project'),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox.shrink();
                      final cats = snapshot.data!;
                      final validValue =
                          cats.any((c) => c.id == _selectedCategoryId)
                          ? _selectedCategoryId
                          : null;
                      return AppDropdownField<int>(
                        label: '项目类型',
                        value: validValue,
                        options: cats
                            .map(
                              (c) =>
                                  AppDropdownOption(value: c.id, label: c.name),
                            )
                            .toList(),
                        onSelected: (v) {
                          setState(() {
                            _selectedCategoryId = v;
                          });
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  if (!_isEdit) ...[
                    _ProjectTemplateSelector(
                      selectedTemplateId: _selectedTemplateId,
                      onSelected: _selectTemplate,
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _participantController,
                    decoration: const InputDecoration(labelText: '客户/参与人'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (!_isEdit && _selectedTemplateId != null) ...[
              _SectionCard(
                title: '模板节点',
                child: _ProjectStepDraftList(
                  baseDate: _startDate ?? DateTime.now(),
                  drafts: _stepDrafts,
                  onChanged: () => setState(() {}),
                ),
              ),
              const SizedBox(height: 16),
            ],
            _SectionCard(
              title: '时间与金额',
              child: Column(
                children: [
                  _DateField(
                    label: '关键日期',
                    value: _startDate != null
                        ? DateFormatter.formatDate(_startDate!)
                        : '未设置',
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _startDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null && mounted) {
                        setState(() => _startDate = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _DateField(
                    label: '结束/交付日期（可选）',
                    value: _endDate != null
                        ? DateFormatter.formatDate(_endDate!)
                        : '未设置',
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate:
                            _endDate ??
                            _startDate ??
                            DateTime.now().add(const Duration(days: 30)),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null && mounted) {
                        setState(() => _endDate = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _totalAmountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: '约定总额',
                      prefixText: '¥',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: '状态与备注',
              child: Column(
                children: [
                  AppDropdownField<ProjectStatus>(
                    label: '项目状态',
                    value: _status,
                    options: ProjectStatus.values
                        .map((s) => AppDropdownOption(value: s, label: s.label))
                        .toList(),
                    onSelected: (v) => setState(() => _status = v ?? _status),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _noteController,
                    decoration: const InputDecoration(labelText: '备注'),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _save,
              child: Text(_isEdit ? '保存修改' : '创建项目'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectTemplateSelector extends ConsumerWidget {
  const _ProjectTemplateSelector({
    required this.selectedTemplateId,
    required this.onSelected,
  });

  final int? selectedTemplateId;
  final ValueChanged<ProjectTemplate?> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(projectTemplatesProvider);
    return templatesAsync.when(
      loading: () => const _TemplateSelectorShell(
        title: '项目模板',
        subtitle: '正在加载模板...',
        child: LinearProgressIndicator(),
      ),
      error: (error, _) => _TemplateSelectorShell(
        title: '项目模板',
        subtitle: '模板加载失败',
        child: Text('$error'),
      ),
      data: (templates) {
        final selected = templates
            .where((template) => template.id == selectedTemplateId)
            .firstOrNull;
        return _TemplateSelectorShell(
          title: selected?.name ?? '不使用模板',
          subtitle: selected == null ? '只创建空项目，后续手动添加事项和账单' : '会在下方生成可调整的项目节点',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (selected != null) ...[
                _SelectedTemplateMeta(template: selected),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () =>
                        _openPicker(context: context, templates: templates),
                    icon: const Icon(Icons.view_timeline_outlined),
                    label: Text(selected == null ? '选择模板' : '更换模板'),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => context.push('/projects/templates'),
                    icon: const Icon(Icons.tune, size: 18),
                    label: const Text('管理'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _openPicker({
    required BuildContext context,
    required List<ProjectTemplate> templates,
  }) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => _ProjectTemplatePickerSheet(
        templates: templates,
        selectedTemplateId: selectedTemplateId,
        onSelected: (template) {
          Navigator.of(sheetContext).pop();
          onSelected(template);
        },
      ),
    );
  }
}

class _TemplateSelectorShell extends StatelessWidget {
  const _TemplateSelectorShell({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        color: Theme.of(context).colorScheme.surface,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.view_timeline_outlined, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _SelectedTemplateMeta extends ConsumerWidget {
  const _SelectedTemplateMeta({required this.template});

  final ProjectTemplate template;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final steps = ref
        .watch(projectTemplateStepsProvider(template.id))
        .valueOrNull;
    final note = template.note?.trim();
    return Text(
      '${steps?.length ?? 0} 个默认节点${note == null || note.isEmpty ? '' : ' · $note'}',
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
    );
  }
}

class _ProjectTemplatePickerSheet extends ConsumerWidget {
  const _ProjectTemplatePickerSheet({
    required this.templates,
    required this.selectedTemplateId,
    required this.onSelected,
  });

  final List<ProjectTemplate> templates;
  final int? selectedTemplateId;
  final ValueChanged<ProjectTemplate?> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(
      FutureProvider.autoDispose(
        (ref) => ref.read(databaseProvider).categoryDao.getByType('project'),
      ),
    );
    final categories = categoriesAsync.valueOrNull ?? const <Category>[];
    final categoryNames = {
      for (final category in categories) category.id: category.name,
    };
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Text(
            '选择项目模板',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          _NoTemplateTile(
            selected: selectedTemplateId == null,
            onTap: () => onSelected(null),
          ),
          if (templates.isNotEmpty) ...[
            const SizedBox(height: 16),
            _TemplatePickerSectionLabel(label: '项目模板'),
            const SizedBox(height: 8),
            for (final template in templates) ...[
              _TemplateOptionTile(
                template: template,
                categoryName: categoryNames[template.categoryId],
                selected: selectedTemplateId == template.id,
                onTap: () => onSelected(template),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }
}

class _TemplatePickerSectionLabel extends StatelessWidget {
  const _TemplatePickerSectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _NoTemplateTile extends StatelessWidget {
  const _NoTemplateTile({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _TemplateOptionFrame(
      selected: selected,
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            selected ? Icons.check_circle : Icons.radio_button_unchecked,
            color: selected ? AppColors.primary : AppColors.textSecondary,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('不使用模板', style: TextStyle(fontWeight: FontWeight.w700)),
                SizedBox(height: 2),
                Text('创建空项目，之后手动添加事项和账单'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TemplateOptionTile extends ConsumerWidget {
  const _TemplateOptionTile({
    required this.template,
    required this.categoryName,
    required this.selected,
    required this.onTap,
  });

  final ProjectTemplate template;
  final String? categoryName;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final steps = ref
        .watch(projectTemplateStepsProvider(template.id))
        .valueOrNull;
    final note = template.note?.trim();
    return _TemplateOptionFrame(
      selected: selected,
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            selected ? Icons.check_circle : Icons.radio_button_unchecked,
            color: selected ? AppColors.primary : AppColors.textSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        template.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (categoryName != null) categoryName!,
                    '${steps?.length ?? 0} 个节点',
                    if (note != null && note.isNotEmpty) note,
                  ].join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TemplateOptionFrame extends StatelessWidget {
  const _TemplateOptionFrame({
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryLight : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : Colors.black.withValues(alpha: 0.08),
          ),
        ),
        child: Padding(padding: const EdgeInsets.all(12), child: child),
      ),
    );
  }
}

class _ProjectStepDraft {
  _ProjectStepDraft({
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

  factory _ProjectStepDraft.fromStep(ProjectTemplateStep step) {
    return _ProjectStepDraft(
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
  bool enabled = true;

  int get offsetDays => int.tryParse(offsetDaysController.text.trim()) ?? 0;

  ProjectTemplateStepInput toInput() {
    return ProjectTemplateStepInput(
      title: titleController.text.trim(),
      itemType: itemType.value,
      amountType: amountType.value,
      offsetDays: offsetDays,
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

class _ProjectStepDraftList extends StatelessWidget {
  const _ProjectStepDraftList({
    required this.baseDate,
    required this.drafts,
    required this.onChanged,
  });

  final DateTime baseDate;
  final List<_ProjectStepDraft> drafts;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    if (drafts.isEmpty) {
      return Text(
        '这个模板还没有节点，会只创建项目。',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
      );
    }
    return Column(
      children: [
        for (var index = 0; index < drafts.length; index++) ...[
          _ProjectStepDraftCard(
            index: index,
            draft: drafts[index],
            baseDate: baseDate,
            onChanged: onChanged,
          ),
          if (index != drafts.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _ProjectStepDraftCard extends StatelessWidget {
  const _ProjectStepDraftCard({
    required this.index,
    required this.draft,
    required this.baseDate,
    required this.onChanged,
  });

  final int index;
  final _ProjectStepDraft draft;
  final DateTime baseDate;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final dueDate = baseDate.add(Duration(days: draft.offsetDays));
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        color: draft.enabled
            ? Theme.of(context).colorScheme.surface
            : AppColors.background,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '节点 ${index + 1} · ${DateFormatter.formatDate(dueDate)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Switch(
                  value: draft.enabled,
                  onChanged: (value) {
                    draft.enabled = value;
                    onChanged();
                  },
                ),
              ],
            ),
            TextFormField(
              controller: draft.titleController,
              enabled: draft.enabled,
              decoration: const InputDecoration(labelText: '节点标题'),
              onChanged: (_) => onChanged(),
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
                if (!draft.enabled) return;
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
                if (!draft.enabled) return;
                draft.amountType = value ?? draft.amountType;
                onChanged();
              },
            ),
            if (draft.amountType != AmountType.none) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: draft.amountController,
                enabled: draft.enabled,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: '金额',
                  prefixText: '¥',
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: draft.offsetDaysController,
              enabled: draft.enabled,
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              decoration: const InputDecoration(labelText: '相对关键日期天数'),
              onChanged: (_) => onChanged(),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today),
        ),
        child: Text(value, style: Theme.of(context).textTheme.bodyLarge),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
