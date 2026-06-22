import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record_everything/l10n/l10n.dart';
import 'package:record_everything/core/utils/category_display.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/form_draft_store.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/utils/toast.dart';
import '../../../core/widgets/section_card.dart';
import '../../../data/database/app_database.dart';
import '../../../data/repositories/project_repository.dart';
import '../../../domain/enums/amount_type.dart';
import '../../../shared/widgets/app_dropdown_field.dart';
import '../../../shared/widgets/dirty_guard_mixin.dart';
import '../../../shared/widgets/form_save_mixin.dart';
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

enum _StepDateAnchor { keyDate, createdDate }

class ProjectTemplateEditPage extends ConsumerStatefulWidget {
  const ProjectTemplateEditPage({super.key});

  @override
  ConsumerState<ProjectTemplateEditPage> createState() =>
      _ProjectTemplateEditPageState();
}

class _ProjectTemplateEditPageState
    extends ConsumerState<ProjectTemplateEditPage>
    with
        FormSaveMixin<ProjectTemplateEditPage>,
        DirtyGuardMixin<ProjectTemplateEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _noteController = TextEditingController();
  final FormDraftStore _draftStore = FormDraftStore();
  static const String _draftType = 'project_template';
  final StepEditorController<_StepDraft> _stepEditor = StepEditorController();

  bool _loaded = false;
  bool _isEdit = false;
  int? _editId;
  ProjectTemplate? _template;
  int? _categoryId;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onFieldChanged);
    _noteController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (_isEdit) return;
    markDirtyAndPersist(_collectTemplateDraft);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    attachDraft(_draftStore, _draftType);
    final idStr = GoRouterState.of(context).pathParameters['id'];
    if (idStr != null && idStr != 'new') {
      _isEdit = true;
      _editId = int.tryParse(idStr);
      _load();
    } else {
      _stepEditor.steps.add(_StepDraft(title: '下一步行动', offsetDays: 0));
      // Offer to restore a recent unsaved draft (draft takes precedence over
      // the default step, same as the bill page).
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => maybeRestoreDraft(_applyTemplateDraft, noun: '项目模板'),
      );
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
      _stepEditor.steps
        ..clear()
        ..addAll(steps.map(_StepDraft.fromStep));
      if (_stepEditor.steps.isEmpty) {
        _stepEditor.steps.add(_StepDraft(title: '下一步行动', offsetDays: 0));
      }
      _stepEditor.selectedIndex = 0;
    });
    _stepEditor.syncStepPage(
      notifyListeners: () => setState(() {}),
      animate: false,
    );
  }

  bool get _canSave => !_isEdit || _template != null;

  Map<String, dynamic> _collectTemplateDraft() {
    return {
      'name': _nameController.text,
      'note': _noteController.text,
      'categoryId': _categoryId,
      'steps': _stepEditor.steps
          .map(
            (draft) => {
              'title': draft.titleController.text,
              'amount': draft.amountController.text,
              'amountType': draft.amountType.value,
              'dateAnchor': draft.dateAnchor.name,
              'offsetDays': draft.offsetDays,
            },
          )
          .toList(growable: false),
    };
  }

  void _applyTemplateDraft(Map<String, dynamic> draft) {
    setState(() {
      _nameController.text = draft['name'] as String? ?? '';
      _noteController.text = draft['note'] as String? ?? '';
      _categoryId = draft['categoryId'] as int?;
      for (final old in _stepEditor.steps) {
        old.dispose();
      }
      final stepList = draft['steps'] as List? ?? const [];
      final drafts = stepList
          .map<Object>((raw) {
            final step = raw as Map<String, dynamic>;
            return _StepDraft(
              title: step['title'] as String? ?? '',
              amountType: AmountType.fromString(
                step['amountType'] as String? ?? 'none',
              ),
              amount: _parseAmountCents(step['amount'] as String?),
              dateAnchor: _StepDateAnchor.values.firstWhere(
                (anchor) => anchor.name == step['dateAnchor'],
                orElse: () => _StepDateAnchor.keyDate,
              ),
              offsetDays: step['offsetDays'] as int? ?? 0,
            );
          })
          .cast<_StepDraft>()
          .toList();
      _stepEditor.steps
        ..clear()
        ..addAll(drafts);
      if (_stepEditor.steps.isEmpty) {
        _stepEditor.steps.add(_StepDraft(title: '下一步行动', offsetDays: 0));
      }
      _stepEditor.selectedIndex = 0;
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

  @override
  void dispose() {
    _stepEditor.dispose();
    _nameController.removeListener(_onFieldChanged);
    _nameController.dispose();
    _noteController.removeListener(_onFieldChanged);
    _noteController.dispose();
    for (final step in _stepEditor.steps) {
      step.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final steps = _stepEditor.steps
        .where((step) => step.titleController.text.trim().isNotEmpty)
        .map((step) => step.toInput())
        .toList(growable: false);
    if (steps.isEmpty) {
      Toast.info(context, context.l.toast_keepOneTemplateNode);
      return;
    }

    final notifier = ref.read(projectNotifierProvider.notifier);
    await runSave(() async {
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
      if (mounted) {
        markClean();
        await clearDraft();
        if (!mounted) return;
        context.pop();
      }
    });
  }

  void _addStep() {
    _stepEditor.addStep(
      _StepDraft(title: '新节点', offsetDays: 0),
      notifyListeners: () => setState(() {}),
    );
    markDirtyAndPersist(_collectTemplateDraft);
  }

  void _deleteCurrentStep() {
    _stepEditor.deleteCurrent(
      notifyListeners: () => setState(() {}),
      disposeRemoved: (removed) => removed.dispose(),
    );
    markDirtyAndPersist(_collectTemplateDraft);
  }

  @override
  Widget build(BuildContext context) {
    final currentStepIndex = _stepEditor.currentIndex;
    final mediaQuery = MediaQuery.of(context);
    final bottomPadding = mediaQuery.viewPadding.bottom + _stepPageBottomInset;
    final keyboardInset = mediaQuery.viewInsets.bottom;

    return PopScope(
      canPop: !isDirty,
      onPopInvokedWithResult: (didPop, _) => onPopInvoked(didPop),
      child: Scaffold(
        backgroundColor: AppColors.background(context),
        appBar: AppBar(
          title: Text(_isEdit ? '编辑项目模板' : '新建项目模板'),
          actions: [
            IconButton(
              tooltip: '保存',
              icon: isSaving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              onPressed: (_canSave && !isSaving) ? _save : null,
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: CustomScrollView(
            key: const ValueKey('project-template-scroll-view'),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                sliver: SliverToBoxAdapter(
                  child: _TemplateInfoSection(
                    categoryId: _categoryId,
                    nameController: _nameController,
                    noteController: _noteController,
                    onCategorySelected: (value) => setState(() {
                      _categoryId = value;
                      markDirtyAndPersist(_collectTemplateDraft);
                    }),
                  ),
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: StepTabHeader<_StepDraft>(
                  scrollController: _stepEditor.tabScrollController,
                  steps: _stepEditor.steps,
                  selectedIndex: currentStepIndex,
                  onReorder: (oldIndex, newIndex) {
                    _stepEditor.reorderStep(
                      oldIndex,
                      newIndex,
                      notifyListeners: () => setState(() {}),
                    );
                    markDirtyAndPersist(_collectTemplateDraft);
                  },
                  onSelected: (index) => _stepEditor.selectStep(
                    index,
                    notifyListeners: () => setState(() {}),
                  ),
                  onAdd: _addStep,
                  keyPrefix: 'project-template',
                ),
              ),
              SliverLayoutBuilder(
                builder: (context, constraints) {
                  final workspaceHeight =
                      constraints.viewportMainAxisExtent + keyboardInset;
                  final minHeight = workspaceHeight - StepTabHeader.extent;
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
                      child: _stepEditor.steps.isEmpty
                          ? const SizedBox.shrink()
                          : PageView.builder(
                              key: const ValueKey(
                                'project-template-step-page-view',
                              ),
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
                                                  'project-template-step-card-frame-$index',
                                                ),
                                                constraints: BoxConstraints(
                                                  maxWidth: 560,
                                                  minHeight: cardMinHeight < 0
                                                      ? 0
                                                      : cardMinHeight,
                                                ),
                                                child: StepDraftCard<_StepDraft>(
                                                  key: ValueKey(
                                                    'project-template-step-card-${_stepEditor.steps[index].localId}',
                                                  ),
                                                  draft:
                                                      _stepEditor.steps[index],
                                                  amountLabel: '默认金额',
                                                  titleFieldKey: const ValueKey(
                                                    'project-template-step-title-field',
                                                  ),
                                                  amountFieldKey: const ValueKey(
                                                    'project-template-step-amount-field',
                                                  ),
                                                  deleteButtonKey: const ValueKey(
                                                    'project-template-delete-step',
                                                  ),
                                                  onChanged: () {
                                                    setState(() {});
                                                    markDirtyAndPersist(
                                                      _collectTemplateDraft,
                                                    );
                                                  },
                                                  onDelete: _deleteCurrentStep,
                                                  extraSlot: (draft) =>
                                                      _TemplateStepDateRuleField(
                                                        draft: draft,
                                                        onChanged: () {
                                                          setState(() {});
                                                          markDirtyAndPersist(
                                                            _collectTemplateDraft,
                                                          );
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
          ),
        ),
      ),
    );
  }
}

class _TemplateInfoSection extends ConsumerWidget {
  const _TemplateInfoSection({
    required this.categoryId,
    required this.nameController,
    required this.noteController,
    required this.onCategorySelected,
  });

  final int? categoryId;
  final TextEditingController nameController;
  final TextEditingController noteController;
  final ValueChanged<int?> onCategorySelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories =
        ref.watch(categoriesByTypeProvider('project')).valueOrNull ??
        const <Category>[];
    return SectionCard(
      title: '模板信息',
      child: Column(
        children: [
          TextFormField(
            key: const ValueKey('project-template-name-field'),
            controller: nameController,
            decoration: const InputDecoration(labelText: '模板名称 *'),
            validator: (value) =>
                value == null || value.trim().isEmpty ? '请输入模板名称' : null,
          ),
          if (categories.isNotEmpty) ...[
            const SizedBox(height: 16),
            AppDropdownField<int>(
              label: '默认项目类型',
              value: categories.any((c) => c.id == categoryId)
                  ? categoryId
                  : null,
              options: categories
                  .map(
                    (category) => AppDropdownOption(
                      value: category.id,
                      label: categoryDisplayName(context, category),
                    ),
                  )
                  .toList(),
              onSelected: onCategorySelected,
            ),
          ],
          const SizedBox(height: 16),
          TextFormField(
            key: const ValueKey('project-template-note-field'),
            controller: noteController,
            decoration: const InputDecoration(labelText: '模板备注'),
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}

class _TemplateStepDateRuleField extends StatelessWidget {
  const _TemplateStepDateRuleField({
    required this.draft,
    required this.onChanged,
  });

  final _StepDraft draft;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final isKeyDate = draft.dateAnchor == _StepDateAnchor.keyDate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: SegmentedButton<_StepDateAnchor>(
            segments: const [
              ButtonSegment(
                value: _StepDateAnchor.keyDate,
                label: Text(
                  '相对关键日期',
                  key: ValueKey('project-template-date-anchor-key'),
                ),
                icon: Icon(Icons.event_available_outlined),
              ),
              ButtonSegment(
                value: _StepDateAnchor.createdDate,
                label: Text(
                  '相对创建日期',
                  key: ValueKey('project-template-date-anchor-created'),
                ),
                icon: Icon(Icons.today_outlined),
              ),
            ],
            selected: {draft.dateAnchor},
            onSelectionChanged: (selection) {
              draft.dateAnchor = selection.single;
              onChanged();
            },
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: const ValueKey('project-template-step-offset-field'),
          controller: draft.offsetDaysController,
          keyboardType: const TextInputType.numberWithOptions(signed: true),
          decoration: InputDecoration(
            labelText: isKeyDate ? '关键日期偏移天数' : '创建日期偏移天数',
            helperText: isKeyDate
                ? '0 表示关键日期当天，-7 表示提前 7 天，14 表示之后 14 天'
                : '0 表示创建当天，7 表示创建后 7 天，-1 表示创建前 1 天',
            helperMaxLines: 3,
          ),
          validator: (value) {
            final text = value?.trim() ?? '';
            if (text.isEmpty) return '请输入偏移天数';
            return int.tryParse(text) == null ? '请输入整数天数' : null;
          },
          onChanged: (_) => onChanged(),
        ),
      ],
    );
  }
}

/// Template-page-specific draft: adds a relative date rule controller.
base class _StepDraft extends StepDraft {
  _StepDraft({
    required String title,
    AmountType amountType = AmountType.none,
    int? amount,
    this.dateAnchor = _StepDateAnchor.keyDate,
    int offsetDays = 0,
  }) : localId = StepDraftIdGenerator.nextId(),
       _amountType = amountType,
       offsetDaysController = TextEditingController(text: '$offsetDays'),
       super.internal(
         titleController: TextEditingController(text: title),
         amountController: TextEditingController(
           text: amount == null ? '' : (amount / 100).toStringAsFixed(2),
         ),
       );

  factory _StepDraft.fromStep(ProjectTemplateStep step) {
    return _StepDraft(
      title: step.title,
      amountType: AmountType.fromString(step.amountType),
      amount: step.amount,
      dateAnchor: step.createdDateOffsetDays == null
          ? _StepDateAnchor.keyDate
          : _StepDateAnchor.createdDate,
      offsetDays:
          step.createdDateOffsetDays ??
          step.keyDateOffsetDays ??
          step.offsetDays,
    );
  }

  @override
  final int localId;

  final TextEditingController offsetDaysController;
  AmountType _amountType;
  _StepDateAnchor dateAnchor;

  @override
  AmountType get amountType => _amountType;

  @override
  set amountType(AmountType value) => _amountType = value;

  int get offsetDays => int.tryParse(offsetDaysController.text.trim()) ?? 0;

  @override
  int? get amount => amountType == AmountType.none
      ? null
      : MoneyFormatter.parse(amountController.text);

  ProjectTemplateStepInput toInput() {
    return ProjectTemplateStepInput(
      title: titleController.text.trim(),
      amountType: amountType.value,
      keyDateOffsetDays: dateAnchor == _StepDateAnchor.keyDate
          ? offsetDays
          : null,
      createdDateOffsetDays: dateAnchor == _StepDateAnchor.createdDate
          ? offsetDays
          : null,
      amount: amount,
    );
  }

  @override
  void dispose() {
    titleController.dispose();
    amountController.dispose();
    offsetDaysController.dispose();
  }
}
