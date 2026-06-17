import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' show Value;
import '../../../core/constants/project_template_keys.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/date_field.dart';
import '../../../core/widgets/section_card.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/database_provider.dart';
import '../../../data/repositories/project_repository.dart';
import '../../../domain/enums/amount_type.dart';
import '../../../domain/enums/item_type.dart';
import '../../../domain/enums/project_status.dart';
import '../../../shared/widgets/app_dropdown_field.dart';
import '../providers/project_providers.dart';

const double _stepContentHorizontalInset = 16;
const double _stepPageTopInset = 16;
const double _stepPageBottomInset = 16;
const double _stepPageBottomDragExtent = 56;
const double _stepCardContentMinExtent = 430;
const double _stepTabAddButtonGap = 8;

class ProjectEditPage extends ConsumerStatefulWidget {
  const ProjectEditPage({super.key});

  @override
  ConsumerState<ProjectEditPage> createState() => _ProjectEditPageState();
}

class _ProjectEditPageState extends ConsumerState<ProjectEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _participantController = TextEditingController();
  final _noteController = TextEditingController();

  ProjectStatus _status = ProjectStatus.defaultStatus;
  int? _selectedCategoryId;
  DateTime? _startDate;
  DateTime? _endDate;
  int? _selectedTemplateId;
  String? _pendingTemplateKey;
  final List<_ProjectStepDraft> _stepDrafts = [];
  late final PageController _stepPageController;
  late final ScrollController _stepTabScrollController;
  int _selectedStepIndex = 0;
  bool _isEdit = false;
  int? _editId;
  bool _loaded = false;
  bool _isTitleManuallyEdited = false;
  Map<int, String> _categoryNames = {};
  /// 终态（已完成/已取消/已归档）或已软删除的项目，编辑页整页只读，
  /// 状态只能通过详情页的「推进/取消/重开/归档」按钮变更。
  bool _isReadonly = false;

  @override
  void initState() {
    super.initState();
    _stepPageController = PageController();
    _stepTabScrollController = ScrollController();
  }

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
    } else {
      // 新建项目时，关键日期默认为当天
      _startDate = DateTime.now();
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
      _tryAutoTitle();
      _loadTemplateDrafts(template);
    });
  }

  void _selectTemplate(ProjectTemplate? template) {
    setState(() {
      _selectedTemplateId = template?.id;
      _selectedCategoryId = template?.categoryId ?? _selectedCategoryId;
      _pendingTemplateKey = null;
    });
    _tryAutoTitle();
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
    final baseDate = _startDate ?? DateTime.now();
    _replaceStepDrafts(
      steps
          .map((step) => _ProjectStepDraft.fromStep(step, baseDate: baseDate))
          .toList(),
    );
  }

  void _replaceStepDrafts(List<_ProjectStepDraft> drafts) {
    for (final draft in _stepDrafts) {
      draft.dispose();
    }
    // Defer the setState to the next frame. This method is reached after an
    // async gap (_loadTemplateDrafts awaits getTemplateSteps), so by the time
    // it runs the widget tree may already be mid-build (e.g. a category
    // FutureBuilder rebuilding on the same frame). Calling setState
    // synchronously then throws "setState/markNeedsBuild called during build"
    // because the new draft's TextFormFields get marked dirty inside that
    // in-flight build. Scheduling after the frame keeps it safe.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _stepDrafts
          ..clear()
          ..addAll(drafts);
        _selectedStepIndex = 0;
      });
      _syncStepPage(animate: false);
    });
  }

  Future<void> _loadFromDatabase() async {
    final id = _editId;
    if (id == null) return;
    final project = await ref.read(databaseProvider).projectDao.getById(id);
    if (!mounted) return;
    final status = ProjectStatus.fromString(project.projectStatus);
    setState(() {
      _titleController.text = project.title;
      _participantController.text = project.participant ?? '';
      _status = status;
      _selectedCategoryId = project.categoryId;
      _startDate = project.startDate;
      _endDate = project.endDate;
      _noteController.text = project.note ?? '';
      _isReadonly = status.isFinal || project.deletedAt != null;
    });
  }

  @override
  void dispose() {
    _stepPageController.dispose();
    _stepTabScrollController.dispose();
    _titleController.dispose();
    _participantController.dispose();
    _noteController.dispose();
    for (final draft in _stepDrafts) {
      draft.dispose();
    }
    super.dispose();
  }

  List<ProjectTemplateStepInput> _enabledStepInputs() {
    return _stepDrafts
        .where((draft) => draft.titleController.text.trim().isNotEmpty)
        .map((draft) => draft.toInput())
        .toList(growable: false);
  }

  int get _currentStepIndex {
    if (_stepDrafts.isEmpty) return 0;
    return _selectedStepIndex.clamp(0, _stepDrafts.length - 1).toInt();
  }

  void _addStep() {
    setState(() {
      final baseDate = _startDate ?? DateTime.now();
      _stepDrafts.add(
        _ProjectStepDraft(title: '新节点', baseDate: baseDate, dueDate: baseDate),
      );
      _selectedStepIndex = _stepDrafts.length - 1;
    });
    _syncStepPage();
  }

  void _deleteCurrentStep() {
    if (_stepDrafts.isEmpty) return;
    setState(() {
      final removed = _stepDrafts.removeAt(_currentStepIndex);
      removed.dispose();
      _selectedStepIndex = _stepDrafts.isEmpty
          ? 0
          : _selectedStepIndex.clamp(0, _stepDrafts.length - 1).toInt();
    });
    _syncStepPage(animate: false);
  }

  void _selectStep(int index) {
    if (_stepDrafts.isEmpty) return;
    final next = index.clamp(0, _stepDrafts.length - 1).toInt();
    if (next == _selectedStepIndex) return;
    setState(() => _selectedStepIndex = next);
    _syncStepPage();
  }

  void _reorderStep(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;
    final selectedStep = _stepDrafts[_currentStepIndex];
    setState(() {
      if (oldIndex < newIndex) newIndex -= 1;
      final moved = _stepDrafts.removeAt(oldIndex);
      _stepDrafts.insert(newIndex, moved);
      _selectedStepIndex = _stepDrafts.indexOf(selectedStep);
    });
    _syncStepPage(animate: false);
  }

  void _syncStepPage({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _stepDrafts.isEmpty) return;
      final index = _currentStepIndex;
      if (_stepPageController.hasClients) {
        if (animate) {
          _stepPageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
          );
        } else {
          _stepPageController.jumpToPage(index);
        }
      }
      _syncStepTabScroll(index: index, animate: animate);
    });
  }

  void _syncStepTabScroll({required int index, required bool animate}) {
    if (!_stepTabScrollController.hasClients) return;
    final position = _stepTabScrollController.position;
    const itemExtent = _StepTabStrip.itemExtent;
    const leadingPadding = 0.0;
    final itemStart = leadingPadding + index * itemExtent;
    final itemEnd = itemStart + itemExtent;
    final visibleStart = position.pixels;
    final visibleEnd = visibleStart + position.viewportDimension;

    double? targetOffset;
    if (itemStart < visibleStart) {
      targetOffset = itemStart;
    } else if (itemEnd > visibleEnd) {
      targetOffset = itemEnd - position.viewportDimension;
    }
    if (targetOffset == null) return;

    final clampedOffset = targetOffset.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((clampedOffset - position.pixels).abs() < 0.5) return;

    if (animate) {
      _stepTabScrollController.animateTo(
        clampedOffset,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    } else {
      _stepTabScrollController.jumpTo(clampedOffset);
    }
  }

  void _handlePageChanged(int index) {
    if (index == _selectedStepIndex) return;
    setState(() => _selectedStepIndex = index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncStepTabScroll(index: _currentStepIndex, animate: true);
    });
  }

  void _updateStepDates() {
    final baseDate = _startDate ?? DateTime.now();
    for (final draft in _stepDrafts) {
      draft.updateDueDate(baseDate);
    }
  }

  String _generateAutoTitle() {
    final parts = <String>[];
    if (_selectedCategoryId != null &&
        _categoryNames.containsKey(_selectedCategoryId)) {
      parts.add(_categoryNames[_selectedCategoryId]!);
    }
    final participant = _participantController.text.trim();
    if (participant.isNotEmpty) parts.add(participant);
    if (_startDate != null) parts.add(DateFormatter.formatDate(_startDate!));
    return parts.join('-');
  }

  void _tryAutoTitle() {
    // 用户已手动编辑标题或处于编辑模式时，不再自动生成
    if (_isTitleManuallyEdited || _isEdit) return;
    final auto = _generateAutoTitle();
    if (auto.isNotEmpty) {
      _titleController.text = auto;
    }
  }

  Future<void> _save() async {
    // 守卫：终态/已删除项目整页只读，禁止任何写入（防绕过 UI）。
    if (_isReadonly) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('项目已完结，不可编辑')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择关键日期')),
      );
      return;
    }
    final notifier = ref.read(projectNotifierProvider.notifier);

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
          totalAmount: const Value(null),
          note: Value(
            _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
          ),
          updatedAt: DateTime.now(),
        ),
      );
    } else if (_selectedTemplateId != null) {
      await notifier.createFromTemplate(
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
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );
    } else {
      await notifier.create(
        title: _titleController.text.trim(),
        categoryId: _selectedCategoryId,
        participant: _participantController.text.trim().isEmpty
            ? null
            : _participantController.text.trim(),
        projectStatus: _status.value,
        startDate: _startDate,
        endDate: _endDate,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );
    }

    if (!mounted) return;
    context.pop();
  }

  void _openTemplatePicker() {
    final templates = ref.read(projectTemplatesProvider).valueOrNull ?? [];
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => _ProjectTemplatePickerSheet(
        templates: templates,
        selectedTemplateId: _selectedTemplateId,
        onSelected: (template) {
          Navigator.of(sheetContext).pop();
          _selectTemplate(template);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final templates = ref.watch(projectTemplatesProvider).valueOrNull;
    _applyPendingTemplateSelection(templates);

    final currentStepIndex = _currentStepIndex;
    final mediaQuery = MediaQuery.of(context);
    final bottomPadding = mediaQuery.viewPadding.bottom + _stepPageBottomInset;
    final keyboardInset = mediaQuery.viewInsets.bottom;

    final selectedTemplate = templates
        ?.where((t) => t.id == _selectedTemplateId)
        .firstOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          _isReadonly
              ? '${_isEdit ? '项目' : '新建项目'}（只读）'
              : (_isEdit ? '编辑项目' : '新建项目'),
        ),
        actions: [
          if (!_isEdit && !_isReadonly)
            TextButton(
              onPressed: _openTemplatePicker,
              child: Text(
                selectedTemplate?.name ?? '模板',
                style: TextStyle(
                  color: selectedTemplate != null
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
              ),
            ),
          if (!_isReadonly)
            IconButton(
              key: const ValueKey('project-edit-save'),
              tooltip: '保存',
              icon: const Icon(Icons.check),
              onPressed: _save,
            ),
        ],
      ),
      body: AbsorbPointer(
        // 终态/已删除时禁用整页交互，使所有字段只读。
        absorbing: _isReadonly,
        child: Form(
        key: _formKey,
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            // 基本信息
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              sliver: SliverToBoxAdapter(
                child: _BasicInfoSection(
                  titleController: _titleController,
                  participantController: _participantController,
                  noteController: _noteController,
                  status: _status,
                  selectedCategoryId: _selectedCategoryId,
                  startDate: _startDate,
                  endDate: _endDate,
                  isEdit: _isEdit,
                  onTitleManuallyEdited: () => _isTitleManuallyEdited = true,
                  onStatusChanged: (v) =>
                      setState(() => _status = v ?? _status),
                  onCategoryChanged: (v) {
                    setState(() => _selectedCategoryId = v);
                    _tryAutoTitle();
                  },
                  onStartDateChanged: (date) {
                    setState(() {
                      _startDate = date;
                      _updateStepDates();
                    });
                    _tryAutoTitle();
                  },
                  onEndDateChanged: (date) => setState(() => _endDate = date),
                  onParticipantChanged: () => _tryAutoTitle(),
                  onCategoriesLoaded: (names) {
                    _categoryNames = names;
                    _tryAutoTitle();
                  },
                ),
              ),
            ),
            // 节点部分（新建模式下始终显示）
            if (!_isEdit) ...[
              SliverPersistentHeader(
                pinned: true,
                delegate: _StepTabHeader(
                  scrollController: _stepTabScrollController,
                  steps: _stepDrafts,
                  selectedIndex: currentStepIndex,
                  onReorder: _reorderStep,
                  onSelected: _selectStep,
                  onAdd: _addStep,
                ),
              ),
              if (_stepDrafts.isNotEmpty)
                SliverLayoutBuilder(
                  builder: (context, constraints) {
                    final workspaceHeight =
                        constraints.viewportMainAxisExtent + keyboardInset;
                    final minHeight = workspaceHeight - _StepTabHeader.extent;
                    final contentHeight =
                        _stepPageTopInset +
                        _stepCardContentMinExtent +
                        _stepPageBottomDragExtent +
                        bottomPadding;
                    final pageHeight = minHeight < contentHeight
                        ? contentHeight
                        : minHeight;
                    return SliverToBoxAdapter(
                      child: SizedBox(
                        height: pageHeight < 0 ? 0 : pageHeight,
                        child: PageView.builder(
                          controller: _stepPageController,
                          itemCount: _stepDrafts.length,
                          onPageChanged: _handlePageChanged,
                          itemBuilder: (context, index) {
                            return ColoredBox(
                              color: Colors.transparent,
                              child: LayoutBuilder(
                                builder: (context, pageConstraints) {
                                  final cardMinHeight =
                                      pageConstraints.maxHeight -
                                      _stepPageTopInset -
                                      _stepPageBottomDragExtent -
                                      bottomPadding;
                                  return Padding(
                                    padding: EdgeInsets.fromLTRB(
                                      _stepContentHorizontalInset,
                                      _stepPageTopInset,
                                      _stepContentHorizontalInset,
                                      bottomPadding,
                                    ),
                                    child: Column(
                                      children: [
                                        Align(
                                          alignment: Alignment.topCenter,
                                          child: ConstrainedBox(
                                            constraints: BoxConstraints(
                                              maxWidth: 560,
                                              minHeight: cardMinHeight < 0
                                                  ? 0
                                                  : cardMinHeight,
                                            ),
                                            child: _ProjectStepDraftCard(
                                              draft: _stepDrafts[index],
                                              onChanged: () => setState(() {}),
                                              onDelete: _deleteCurrentStep,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(
                                          height: _stepPageBottomDragExtent,
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
            ],
          ],
        ),
        ),
      ),
    );
  }
}

// ==================== 基本信息部分 ====================

class _BasicInfoSection extends ConsumerStatefulWidget {
  const _BasicInfoSection({
    required this.titleController,
    required this.participantController,
    required this.noteController,
    required this.status,
    required this.selectedCategoryId,
    required this.startDate,
    required this.endDate,
    required this.isEdit,
    required this.onTitleManuallyEdited,
    required this.onStatusChanged,
    required this.onCategoryChanged,
    required this.onStartDateChanged,
    required this.onEndDateChanged,
    required this.onParticipantChanged,
    required this.onCategoriesLoaded,
  });

  final TextEditingController titleController;
  final TextEditingController participantController;
  final TextEditingController noteController;
  final ProjectStatus status;
  final int? selectedCategoryId;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isEdit;
  final VoidCallback onTitleManuallyEdited;
  final ValueChanged<ProjectStatus?> onStatusChanged;
  final ValueChanged<int?> onCategoryChanged;
  final ValueChanged<DateTime?> onStartDateChanged;
  final ValueChanged<DateTime?> onEndDateChanged;
  final VoidCallback onParticipantChanged;
  final ValueChanged<Map<int, String>> onCategoriesLoaded;

  @override
  ConsumerState<_BasicInfoSection> createState() => _BasicInfoSectionState();
}

class _BasicInfoSectionState extends ConsumerState<_BasicInfoSection> {
  String? _lastCategoriesSignature;

  void _publishCategoriesLoaded(List<Category> categories) {
    final signature = categories
        .map((category) => '${category.id}:${category.name}')
        .join('|');
    if (_lastCategoriesSignature == signature) return;
    _lastCategoriesSignature = signature;

    final names = {
      for (final category in categories) category.id: category.name,
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onCategoriesLoaded(names);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '基本信息',
      child: Column(
        children: [
          TextFormField(
            controller: widget.titleController,
            decoration: const InputDecoration(labelText: '项目标题 *'),
            validator: (v) => (v == null || v.trim().isEmpty) ? '请输入标题' : null,
            onChanged: (_) => widget.onTitleManuallyEdited(),
          ),
          const SizedBox(height: 16),
          FutureBuilder(
            future: ref.read(databaseProvider).categoryDao.getByType('project'),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              final cats = snapshot.data!;
              _publishCategoriesLoaded(cats);
              final validValue =
                  cats.any((c) => c.id == widget.selectedCategoryId)
                  ? widget.selectedCategoryId
                  : null;
              return AppDropdownField<int>(
                label: '项目类型',
                value: validValue,
                options: cats
                    .map((c) => AppDropdownOption(value: c.id, label: c.name))
                    .toList(),
                onSelected: widget.onCategoryChanged,
              );
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: widget.participantController,
            decoration: const InputDecoration(labelText: '客户/参与人'),
            onChanged: (_) => widget.onParticipantChanged(),
          ),
          const SizedBox(height: 16),
          DateField(
            label: '关键日期 *',
            value: widget.startDate != null
                ? DateFormatter.formatDate(widget.startDate!)
                : '未设置',
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: widget.startDate ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2035),
              );
              if (picked != null) {
                widget.onStartDateChanged(picked);
              }
            },
          ),
          const SizedBox(height: 16),
          AppDropdownField<ProjectStatus>(
            label: '项目状态',
            value: widget.status,
            options: ProjectStatus.values
                .map((s) => AppDropdownOption(value: s, label: s.label))
                .toList(),
            onSelected: widget.onStatusChanged,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: widget.noteController,
            decoration: const InputDecoration(labelText: '备注'),
            maxLines: 3,
          ),
        ],
      ),
    );
  }
}

// ==================== 模板选择弹窗 ====================

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
            Text(
              '项目模板',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            for (final template in templates) ...[
              _TemplateOptionTile(
                template: template,
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
    required this.selected,
    required this.onTap,
  });

  final ProjectTemplate template;
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
                Text(
                  template.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '${steps?.length ?? 0} 个节点${note != null && note.isNotEmpty ? ' · $note' : ''}',
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

// ==================== 节点部分 ====================

class _ProjectStepDraft {
  _ProjectStepDraft({
    required String title,
    this.itemType = ItemType.todo,
    this.amountType = AmountType.none,
    int? amount,
    required DateTime baseDate,
    required DateTime dueDate,
  }) : localId = _nextLocalId++,
       titleController = TextEditingController(text: title),
       amountController = TextEditingController(
         text: amount == null ? '' : (amount / 100).toStringAsFixed(2),
       ),
       _dueDate = dueDate;

  static int _nextLocalId = 0;

  final int localId;

  factory _ProjectStepDraft.fromStep(
    ProjectTemplateStep step, {
    required DateTime baseDate,
  }) {
    final dueDate = baseDate.add(Duration(days: step.offsetDays));
    return _ProjectStepDraft(
      title: step.title,
      itemType: ItemType.fromString(step.itemType),
      amountType: AmountType.fromString(step.amountType),
      amount: step.amount,
      baseDate: baseDate,
      dueDate: dueDate,
    );
  }

  final TextEditingController titleController;
  final TextEditingController amountController;
  ItemType itemType;
  AmountType amountType;
  DateTime _dueDate;

  DateTime get dueDate => _dueDate;

  void updateDueDate(DateTime baseDate) {
    // 保持原有的相对天数，更新到期日
    // 这里不需要改变，因为用户可以直接选择日期
  }

  void setDueDate(DateTime date) {
    _dueDate = date;
  }

  ProjectTemplateStepInput toInput() {
    return ProjectTemplateStepInput(
      title: titleController.text.trim(),
      itemType: itemType.value,
      amountType: amountType.value,
      offsetDays: 0, // 不再使用相对天数
      amount: amountType == AmountType.none
          ? null
          : MoneyFormatter.parse(amountController.text),
    );
  }

  void dispose() {
    titleController.dispose();
    amountController.dispose();
  }
}

class _StepTabHeader extends SliverPersistentHeaderDelegate {
  const _StepTabHeader({
    required this.scrollController,
    required this.steps,
    required this.selectedIndex,
    required this.onReorder,
    required this.onSelected,
    required this.onAdd,
  });

  final ScrollController scrollController;
  final List<_ProjectStepDraft> steps;
  final int selectedIndex;
  final ReorderCallback onReorder;
  final ValueChanged<int> onSelected;
  final VoidCallback onAdd;

  static const double extent = 60;

  @override
  double get maxExtent => extent;

  @override
  double get minExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      color: AppColors.background,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          _stepContentHorizontalInset,
          6,
          _stepContentHorizontalInset,
          6,
        ),
        child: SizedBox(
          height: 48,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final hasSteps = steps.isNotEmpty;
              final buttonWidth = hasSteps
                  ? _AnimatedAddButton.collapsedExtent
                  : _AnimatedAddButton.expandedWidth;
              final tabLimit =
                  constraints.maxWidth -
                  buttonWidth -
                  (hasSteps ? _stepTabAddButtonGap : 0);
              final tabWidth = hasSteps
                  ? _StepTabStrip.widthForCount(
                      steps.length,
                    ).clamp(0.0, tabLimit < 0 ? 0.0 : tabLimit).toDouble()
                  : 0.0;

              return Row(
                children: [
                  if (hasSteps)
                    AnimatedContainer(
                      key: const ValueKey('project-edit-tab-area'),
                      duration: _AnimatedAddButton.duration,
                      curve: _AnimatedAddButton.curve,
                      width: tabWidth,
                      child: _StepTabStrip(
                        scrollController: scrollController,
                        steps: steps,
                        selectedIndex: selectedIndex,
                        onReorder: onReorder,
                        onSelected: onSelected,
                      ),
                    ),
                  if (hasSteps) const SizedBox(width: _stepTabAddButtonGap),
                  _AnimatedAddButton(
                    key: const ValueKey('project-edit-add-step'),
                    isEmpty: !hasSteps,
                    onPressed: onAdd,
                  ),
                  const Spacer(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _StepTabHeader oldDelegate) => true;
}

class _AnimatedAddButton extends StatelessWidget {
  const _AnimatedAddButton({
    super.key,
    required this.isEmpty,
    required this.onPressed,
  });

  final bool isEmpty;
  final VoidCallback onPressed;

  static const double collapsedExtent = 44;
  static const double expandedWidth = 112;
  static const Duration duration = Duration(milliseconds: 260);
  static const Curve curve = Curves.easeOutCubic;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isEmpty ? AppColors.surface : AppColors.primary;
    final foregroundColor = isEmpty ? AppColors.primary : Colors.white;

    return Tooltip(
      message: '添加节点',
      child: AnimatedContainer(
        duration: duration,
        curve: curve,
        width: isEmpty ? expandedWidth : collapsedExtent,
        height: collapsedExtent,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(collapsedExtent / 2),
          border: Border.all(
            color: isEmpty
                ? AppColors.primary.withValues(alpha: 0.35)
                : AppColors.primary,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: isEmpty ? 0.08 : 0.16),
              blurRadius: isEmpty ? 8 : 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(collapsedExtent / 2),
            onTap: onPressed,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final showLabel = isEmpty && constraints.maxWidth >= 96;
                return AnimatedPadding(
                  duration: duration,
                  curve: curve,
                  padding: EdgeInsets.symmetric(horizontal: showLabel ? 10 : 0),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_rounded,
                          size: 20,
                          color: foregroundColor,
                        ),
                        if (showLabel) ...[
                          const SizedBox(width: 4),
                          Text(
                            '添加节点',
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                            textAlign: TextAlign.center,
                            strutStyle: const StrutStyle(
                              fontSize: 14,
                              height: 1,
                              forceStrutHeight: true,
                            ),
                            textHeightBehavior: const TextHeightBehavior(
                              applyHeightToFirstAscent: false,
                              applyHeightToLastDescent: false,
                            ),
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: foregroundColor,
                                  fontWeight: FontWeight.w700,
                                  height: 1,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _StepTabStrip extends StatelessWidget {
  const _StepTabStrip({
    required this.scrollController,
    required this.steps,
    required this.selectedIndex,
    required this.onReorder,
    required this.onSelected,
  });

  static const double itemExtent = 112;

  static double widthForCount(int count) {
    if (count <= 0) return 0;
    return itemExtent * count;
  }

  final ScrollController scrollController;
  final List<_ProjectStepDraft> steps;
  final int selectedIndex;
  final ReorderCallback onReorder;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) return const SizedBox.shrink();

    return ReorderableListView.builder(
      key: const ValueKey('project-edit-step-tabs'),
      scrollController: scrollController,
      scrollDirection: Axis.horizontal,
      buildDefaultDragHandles: false,
      itemExtent: itemExtent,
      padding: EdgeInsets.zero,
      proxyDecorator: (child, index, animation) {
        return Material(
          color: Colors.transparent,
          child: ScaleTransition(
            scale: Tween<double>(begin: 1, end: 1.04).animate(animation),
            child: child,
          ),
        );
      },
      itemCount: steps.length,
      onReorder: onReorder,
      itemBuilder: (context, index) {
        final trailingGap = index == steps.length - 1 ? 0.0 : 6.0;
        return Padding(
          key: ValueKey('project-edit-step-tab-${steps[index].localId}'),
          padding: EdgeInsets.only(right: trailingGap),
          child: ReorderableDelayedDragStartListener(
            key: ValueKey('project-edit-step-tab-drag-$index'),
            index: index,
            child: _StepTab(
              index: index,
              title: steps[index].titleController.text.trim(),
              selected: index == selectedIndex,
              onSelected: () => onSelected(index),
            ),
          ),
        );
      },
    );
  }
}

class _StepTab extends StatelessWidget {
  const _StepTab({
    required this.index,
    required this.title,
    required this.selected,
    required this.onSelected,
  });

  final int index;
  final String title;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = selected ? AppColors.primaryDark : AppColors.textPrimary;
    final badgeBg = selected ? AppColors.primary : AppColors.primaryLight;
    final badgeFg = selected ? Colors.white : AppColors.primary;
    final displayTitle = title.isNotEmpty ? title : '未命名节点';
    return InkWell(
      key: ValueKey('project-edit-step-tab-button-$index'),
      borderRadius: BorderRadius.circular(10),
      onTap: onSelected,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: selected ? AppColors.primaryLight : colorScheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected
                      ? AppColors.primary
                      : Colors.black.withValues(alpha: 0.08),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 6, 8, 6),
                child: Align(
                  alignment: Alignment.center,
                  child: Text(
                    displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(10),
                  bottomRight: Radius.circular(8),
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.18),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: SizedBox(
                width: 24,
                height: 18,
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: badgeFg,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectStepDraftCard extends StatelessWidget {
  const _ProjectStepDraftCard({
    required this.draft,
    required this.onChanged,
    required this.onDelete,
  });

  final _ProjectStepDraft draft;
  final VoidCallback onChanged;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 48),
              child: Column(
                children: [
                  TextFormField(
                    key: const ValueKey('project-edit-step-title-field'),
                    controller: draft.titleController,
                    decoration: const InputDecoration(labelText: '节点标题 *'),
                    onChanged: (_) => onChanged(),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? '请输入节点标题'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  AppDropdownField<ItemType>(
                    label: '节点类型',
                    value: draft.itemType,
                    options: ItemType.values
                        .map(
                          (type) =>
                              AppDropdownOption(value: type, label: type.label),
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
                          (type) =>
                              AppDropdownOption(value: type, label: type.label),
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
                        labelText: '金额',
                        prefixText: '¥',
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  DateField(
                    label: '到期日期',
                    value: DateFormatter.formatDate(draft.dueDate),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: draft.dueDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) {
                        draft.setDueDate(picked);
                        onChanged();
                      }
                    },
                  ),
                ],
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: SizedBox.square(
                dimension: 48,
                child: IconButton(
                  tooltip: '删除节点',
                  onPressed: onDelete,
                  icon: const Icon(Icons.close),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== 通用组件 ====================

