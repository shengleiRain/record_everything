import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' show Value;
import '../../../core/constants/project_template_keys.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/form_draft_store.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/date_field.dart';
import '../../../core/widgets/section_card.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/database_provider.dart';
import '../../../data/repositories/project_repository.dart';
import '../../../domain/enums/amount_type.dart';
import '../../../domain/enums/project_status.dart';
import '../../../shared/widgets/app_dropdown_field.dart';
import '../../../shared/widgets/dirty_guard_mixin.dart';
import '../../../shared/widgets/form_save_mixin.dart';
import '../../../shared/widgets/readonly_message.dart';
import '../../settings/providers/settings_providers.dart';
import '../providers/project_providers.dart';
import '../widgets/step_editor/step_draft.dart';
import '../widgets/step_editor/step_draft_card.dart';
import '../widgets/step_editor/step_editor_controller.dart';
import '../widgets/step_editor/step_tab_strip.dart';

const double _stepPageTopInset = 16;
const double _stepPageBottomInset = 16;
const double _stepPageBottomDragExtent = 56;
const double _stepCardContentMinExtent = 430;

class ProjectEditPage extends ConsumerStatefulWidget {
  const ProjectEditPage({super.key});

  @override
  ConsumerState<ProjectEditPage> createState() => _ProjectEditPageState();
}

class _ProjectEditPageState extends ConsumerState<ProjectEditPage>
    with FormSaveMixin<ProjectEditPage>, DirtyGuardMixin<ProjectEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _participantController = TextEditingController();
  final _noteController = TextEditingController();
  final FormDraftStore _draftStore = FormDraftStore();
  static const String _draftType = 'project';
  final StepEditorController<_ProjectStepDraft> _stepEditor =
      StepEditorController();

  ProjectStatus _status = ProjectStatus.defaultStatus;
  int? _selectedCategoryId;
  DateTime? _startDate;
  DateTime? _endDate;
  int? _selectedTemplateId;
  String? _pendingTemplateKey;
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
    _noteController.addListener(_onNoteChanged);
  }

  void _onNoteChanged() {
    if (_isEdit) return;
    markDirtyAndPersist(_collectProjectDraft);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    attachDraft(_draftStore, _draftType);
    final state = GoRouterState.of(context);
    final idStr = state.pathParameters['id'];
    if (idStr != null && idStr != 'new') {
      _isEdit = true;
      _editId = int.tryParse(idStr);
      _loadFromDatabase();
    } else {
      // 新建项目时，关键日期默认为当天
      _startDate = DateTime.now();
      // Offer to restore a recent unsaved draft (draft takes precedence over
      // template pre-fill, same as the bill page).
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => maybeRestoreDraft(_applyProjectDraft, noun: '项目'),
      );
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
    for (final draft in _stepEditor.steps) {
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
        _stepEditor.steps
          ..clear()
          ..addAll(drafts);
        _stepEditor.selectedIndex = 0;
      });
      _stepEditor.syncStepPage(
        notifyListeners: () => setState(() {}),
        animate: false,
      );
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
    _stepEditor.dispose();
    _titleController.dispose();
    _participantController.dispose();
    _noteController.removeListener(_onNoteChanged);
    _noteController.dispose();
    for (final draft in _stepEditor.steps) {
      draft.dispose();
    }
    super.dispose();
  }

  List<ProjectTemplateStepInput> _enabledStepInputs() {
    return _stepEditor.steps
        .where((draft) => draft.titleController.text.trim().isNotEmpty)
        .map((draft) => draft.toInput())
        .toList(growable: false);
  }

  void _updateStepDates() {
    final baseDate = _startDate ?? DateTime.now();
    for (final draft in _stepEditor.steps) {
      draft.updateDueDate(baseDate);
    }
  }

  Map<String, dynamic> _collectProjectDraft() {
    return {
      'title': _titleController.text,
      'participant': _participantController.text,
      'note': _noteController.text,
      'status': _status.value,
      'categoryId': _selectedCategoryId,
      'startDate': _startDate?.toIso8601String(),
      'endDate': _endDate?.toIso8601String(),
      'selectedTemplateId': _selectedTemplateId,
      'steps': _stepEditor.steps
          .map((draft) => {
                'title': draft.titleController.text,
                'amount': draft.amountController.text,
                'amountType': draft.amountType.value,
                'dueDate': draft.dueDate.toIso8601String(),
              })
          .toList(growable: false),
    };
  }

  void _applyProjectDraft(Map<String, dynamic> draft) {
    setState(() {
      _titleController.text = draft['title'] as String? ?? '';
      _participantController.text = draft['participant'] as String? ?? '';
      _noteController.text = draft['note'] as String? ?? '';
      _status = ProjectStatus.fromString(
        draft['status'] as String? ?? _status.value,
      );
      _selectedCategoryId = draft['categoryId'] as int?;
      _startDate = DateTime.tryParse(draft['startDate'] as String? ?? '');
      _endDate = DateTime.tryParse(draft['endDate'] as String? ?? '');
      _selectedTemplateId = draft['selectedTemplateId'] as int?;
      // Rebuild the step drafts from the persisted snapshot.
      for (final old in _stepEditor.steps) {
        old.dispose();
      }
      final stepList = draft['steps'] as List? ?? const [];
      final baseDate = _startDate ?? DateTime.now();
      final drafts = stepList.map<Object>((raw) {
        final step = raw as Map<String, dynamic>;
        return _ProjectStepDraft(
          title: step['title'] as String? ?? '',
          amountType: AmountType.fromString(
            step['amountType'] as String? ?? 'none',
          ),
          amount: _parseAmountCents(step['amount'] as String?),
          baseDate: baseDate,
          dueDate: DateTime.tryParse(step['dueDate'] as String? ?? '') ??
              baseDate,
        );
      }).cast<_ProjectStepDraft>().toList();
      _stepEditor.steps
        ..clear()
        ..addAll(drafts);
      _stepEditor.selectedIndex = 0;
      _isTitleManuallyEdited = true; // 草稿标题优先于自动生成
    });
    _stepEditor.syncStepPage(
      notifyListeners: () => setState(() {}),
      animate: false,
    );
  }

  int? _parseAmountCents(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    return MoneyFormatter.parse(text);
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('项目已完结，不可编辑')));
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    final notifier = ref.read(projectNotifierProvider.notifier);

    await runSave(() async {
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
      markClean();
      await clearDraft();
      if (!mounted) return;
      context.pop();
    });
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

  void _addStep() {
    final baseDate = _startDate ?? DateTime.now();
    _stepEditor.addStep(
      _ProjectStepDraft(title: '新节点', baseDate: baseDate, dueDate: baseDate),
      notifyListeners: () => setState(() {}),
    );
    markDirtyAndPersist(_collectProjectDraft);
  }

  void _deleteCurrentStep() {
    _stepEditor.deleteCurrent(
      notifyListeners: () => setState(() {}),
      disposeRemoved: (removed) => removed.dispose(),
    );
    markDirtyAndPersist(_collectProjectDraft);
  }

  @override
  Widget build(BuildContext context) {
    if (_isReadonly) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('项目（只读）')),
        body: ReadonlyMessage(
          title: '项目已完结',
          message: '只读状态的项目不能编辑，可在项目详情中重新激活后再修改。',
          backLabel: '返回项目',
          onBack: () {
            final id = _editId;
            if (id == null) {
              context.go('/projects');
            } else {
              context.go('/projects/$id');
            }
          },
        ),
      );
    }
    final templates = ref.watch(projectTemplatesProvider).valueOrNull;
    _applyPendingTemplateSelection(templates);

    final currentStepIndex = _stepEditor.currentIndex;
    final mediaQuery = MediaQuery.of(context);
    final bottomPadding = mediaQuery.viewPadding.bottom + _stepPageBottomInset;
    final keyboardInset = mediaQuery.viewInsets.bottom;

    final selectedTemplate = templates
        ?.where((t) => t.id == _selectedTemplateId)
        .firstOrNull;

    return PopScope(
      canPop: !isDirty,
      onPopInvokedWithResult: (didPop, _) => onPopInvoked(didPop),
      child: Scaffold(
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
                onPressed: isSaving ? null : _openTemplatePicker,
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
                icon: isSaving
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                onPressed: isSaving ? null : _save,
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
                    selectedCategoryId: _selectedCategoryId,
                    startDate: _startDate,
                    endDate: _endDate,
                    isEdit: _isEdit,
                    onTitleManuallyEdited: () {
                      _isTitleManuallyEdited = true;
                      markDirtyAndPersist(_collectProjectDraft);
                    },
                    onCategoryChanged: (v) {
                      setState(() => _selectedCategoryId = v);
                      _tryAutoTitle();
                      markDirtyAndPersist(_collectProjectDraft);
                    },
                    onStartDateChanged: (date) {
                      setState(() {
                        _startDate = date;
                        _updateStepDates();
                      });
                      _tryAutoTitle();
                      markDirtyAndPersist(_collectProjectDraft);
                    },
                    onEndDateChanged: (date) {
                      setState(() => _endDate = date);
                      markDirtyAndPersist(_collectProjectDraft);
                    },
                    onParticipantChanged: () {
                      _tryAutoTitle();
                      markDirtyAndPersist(_collectProjectDraft);
                    },
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
                  delegate: StepTabHeader<_ProjectStepDraft>(
                    scrollController: _stepEditor.tabScrollController,
                    steps: _stepEditor.steps,
                    selectedIndex: currentStepIndex,
                    onReorder: (oldIndex, newIndex) {
                      _stepEditor.reorderStep(
                        oldIndex,
                        newIndex,
                        notifyListeners: () => setState(() {}),
                      );
                      markDirtyAndPersist(_collectProjectDraft);
                    },
                    onSelected: (index) => _stepEditor.selectStep(
                      index,
                      notifyListeners: () => setState(() {}),
                    ),
                    onAdd: _addStep,
                    keyPrefix: 'project-edit',
                  ),
                ),
                if (_stepEditor.steps.isNotEmpty)
                  SliverLayoutBuilder(
                    builder: (context, constraints) {
                      final workspaceHeight =
                          constraints.viewportMainAxisExtent + keyboardInset;
                      final minHeight =
                          workspaceHeight - StepTabHeader.extent;
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
                            key: const ValueKey('project-edit-step-page-view'),
                            controller: _stepEditor.pageController,
                            itemCount: _stepEditor.steps.length,
                            onPageChanged: (index) =>
                                _stepEditor.handlePageChanged(
                                  index,
                                  notifyListeners: () => setState(() {}),
                                ),
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
                                        16,
                                        _stepPageTopInset,
                                        16,
                                        bottomPadding,
                                      ),
                                      child: Column(
                                        children: [
                                          Align(
                                            alignment: Alignment.topCenter,
                                            child: ConstrainedBox(
                                              key: ValueKey(
                                                'project-edit-step-card-frame-$index',
                                              ),
                                              constraints: BoxConstraints(
                                                maxWidth: 560,
                                                minHeight: cardMinHeight < 0
                                                    ? 0
                                                    : cardMinHeight,
                                              ),
                                              child: StepDraftCard<
                                                _ProjectStepDraft
                                              >(
                                                key: ValueKey(
                                                  'project-edit-step-card-${_stepEditor.steps[index].localId}',
                                                ),
                                                draft: _stepEditor.steps[index],
                                                amountLabel: '金额',
                                                titleFieldKey: const ValueKey(
                                                  'project-edit-step-title-field',
                                                ),
                                                amountFieldKey: const ValueKey(
                                                  'project-edit-step-amount-field',
                                                ),
                                                onChanged: () {
                                                  setState(() {});
                                                  markDirtyAndPersist(
                                                    _collectProjectDraft,
                                                  );
                                                },
                                                onDelete: _deleteCurrentStep,
                                                extraSlot: (draft) => DateField(
                                                  label: '到期日期',
                                                  initialValue: draft.dueDate,
                                                  onPick: () async {
                                                    final picked =
                                                        await showDatePicker(
                                                          context: context,
                                                          initialDate:
                                                              draft.dueDate,
                                                          firstDate:
                                                              DateTime(2020),
                                                          lastDate:
                                                              DateTime(2035),
                                                        );
                                                    if (picked != null) {
                                                      draft.setDueDate(picked);
                                                      setState(() {});
                                                      markDirtyAndPersist(
                                                        _collectProjectDraft,
                                                      );
                                                    }
                                                    return picked;
                                                  },
                                                ),
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
    required this.selectedCategoryId,
    required this.startDate,
    required this.endDate,
    required this.isEdit,
    required this.onTitleManuallyEdited,
    required this.onCategoryChanged,
    required this.onStartDateChanged,
    required this.onEndDateChanged,
    required this.onParticipantChanged,
    required this.onCategoriesLoaded,
  });

  final TextEditingController titleController;
  final TextEditingController participantController;
  final TextEditingController noteController;
  final int? selectedCategoryId;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isEdit;
  final VoidCallback onTitleManuallyEdited;
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
          Builder(
            builder: (context) {
              final cats =
                  ref.watch(categoriesByTypeProvider('project')).valueOrNull ??
                  const <Category>[];
              _publishCategoriesLoaded(cats);
              if (cats.isEmpty) return const SizedBox.shrink();
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
            key: const ValueKey('project-key-date-field'),
            label: '关键日期 *',
            initialValue: widget.startDate,
            validator: (value) =>
                value == null ? '请选择关键日期' : null,
            onPick: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: widget.startDate ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2035),
              );
              if (picked != null) {
                widget.onStartDateChanged(picked);
              }
              return picked;
            },
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

/// Project-page-specific draft: adds an absolute due date instead of a
/// relative offset.
base class _ProjectStepDraft extends StepDraft {
  _ProjectStepDraft({
    required String title,
    AmountType amountType = AmountType.none,
    int? amount,
    required DateTime baseDate,
    required DateTime dueDate,
  })  : localId = StepDraftIdGenerator.nextId(),
        _amountType = amountType,
        _dueDate = dueDate,
        super.internal(
          titleController: TextEditingController(text: title),
          amountController: TextEditingController(
            text: amount == null ? '' : (amount / 100).toStringAsFixed(2),
          ),
        );

  factory _ProjectStepDraft.fromStep(
    ProjectTemplateStep step, {
    required DateTime baseDate,
  }) {
    final dueDate = baseDate.add(Duration(days: step.offsetDays));
    return _ProjectStepDraft(
      title: step.title,
      amountType: AmountType.fromString(step.amountType),
      amount: step.amount,
      baseDate: baseDate,
      dueDate: dueDate,
    );
  }

  @override
  final int localId;

  AmountType _amountType;

  @override
  AmountType get amountType => _amountType;

  @override
  set amountType(AmountType value) => _amountType = value;

  DateTime _dueDate;

  DateTime get dueDate => _dueDate;

  void updateDueDate(DateTime baseDate) {
    // 保持原有的相对天数，更新到期日
    // 这里不需要改变，因为用户可以直接选择日期
  }

  void setDueDate(DateTime date) {
    _dueDate = date;
  }

  @override
  int? get amount => amountType == AmountType.none
      ? null
      : MoneyFormatter.parse(amountController.text);

  ProjectTemplateStepInput toInput() {
    return ProjectTemplateStepInput(
      title: titleController.text.trim(),
      amountType: amountType.value,
      offsetDays: 0, // 不再使用相对天数
      amount: amount,
    );
  }

  @override
  void dispose() {
    titleController.dispose();
    amountController.dispose();
  }
}
