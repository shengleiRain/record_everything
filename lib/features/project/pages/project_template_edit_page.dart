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

const double _stepContentHorizontalInset = 16;
const double _stepPageTopInset = 16;
const double _stepPageBottomInset = 16;
const double _stepPageBottomDragExtent = 56;
const double _stepCardContentMinExtent = 430;

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
  late final PageController _stepPageController;
  late final ScrollController _stepTabScrollController;

  Future<List<Category>>? _categoriesFuture;
  int _selectedStepIndex = 0;
  bool _loaded = false;
  bool _isEdit = false;
  int? _editId;
  ProjectTemplate? _template;
  int? _categoryId;

  @override
  void initState() {
    super.initState();
    _stepPageController = PageController();
    _stepTabScrollController = ScrollController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _categoriesFuture ??= ref
        .read(databaseProvider)
        .categoryDao
        .getByType('project');
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
      _selectedStepIndex = 0;
    });
    _syncStepPage(animate: false);
  }

  @override
  void dispose() {
    _stepPageController.dispose();
    _stepTabScrollController.dispose();
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

  int get _currentStepIndex {
    if (_steps.isEmpty) return 0;
    return _selectedStepIndex.clamp(0, _steps.length - 1).toInt();
  }

  bool get _canSave => !_isEdit || _template != null;

  void _addStep() {
    setState(() {
      _steps.add(_StepDraft(title: '新节点', offsetDays: 0));
      _selectedStepIndex = _steps.length - 1;
    });
    _syncStepPage();
  }

  void _deleteCurrentStep() {
    if (_steps.length <= 1) return;
    setState(() {
      final removed = _steps.removeAt(_currentStepIndex);
      removed.dispose();
      _selectedStepIndex = _selectedStepIndex
          .clamp(0, _steps.length - 1)
          .toInt();
    });
    _syncStepPage(animate: false);
  }

  void _reorderStep(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;
    final selectedStep = _steps[_currentStepIndex];
    setState(() {
      if (oldIndex < newIndex) newIndex -= 1;
      final moved = _steps.removeAt(oldIndex);
      _steps.insert(newIndex, moved);
      _selectedStepIndex = _steps.indexOf(selectedStep);
    });
    _syncStepPage(animate: false);
  }

  void _selectStep(int index) {
    final next = index.clamp(0, _steps.length - 1).toInt();
    if (next == _selectedStepIndex) return;
    setState(() => _selectedStepIndex = next);
    _syncStepPage();
  }

  void _syncStepPage({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _steps.isEmpty) return;
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

  @override
  Widget build(BuildContext context) {
    final currentStepIndex = _currentStepIndex;
    final mediaQuery = MediaQuery.of(context);
    final bottomPadding = mediaQuery.viewPadding.bottom + _stepPageBottomInset;
    final keyboardInset = mediaQuery.viewInsets.bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEdit ? '编辑项目模板' : '新建项目模板'),
        actions: [
          IconButton(
            key: const ValueKey('project-template-add-step'),
            tooltip: '添加节点',
            icon: const Icon(Icons.add),
            onPressed: _addStep,
          ),
          IconButton(
            tooltip: '保存',
            icon: const Icon(Icons.check),
            onPressed: _canSave ? _save : null,
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
                  categoriesFuture:
                      _categoriesFuture ?? Future.value(const <Category>[]),
                  categoryId: _categoryId,
                  nameController: _nameController,
                  noteController: _noteController,
                  onCategorySelected: (value) =>
                      setState(() => _categoryId = value),
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _StepTabHeader(
                scrollController: _stepTabScrollController,
                steps: _steps,
                selectedIndex: currentStepIndex,
                onReorder: _reorderStep,
                onSelected: _selectStep,
              ),
            ),
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
                    child: _steps.isEmpty
                        ? const SizedBox.shrink()
                        : PageView.builder(
                            key: const ValueKey(
                              'project-template-step-page-view',
                            ),
                            controller: _stepPageController,
                            itemCount: _steps.length,
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
                                              key: ValueKey(
                                                'project-template-step-card-frame-$index',
                                              ),
                                              constraints: BoxConstraints(
                                                maxWidth: 560,
                                                minHeight: cardMinHeight < 0
                                                    ? 0
                                                    : cardMinHeight,
                                              ),
                                              child: _StepDraftCard(
                                                key: ValueKey(
                                                  'project-template-step-card-${_steps[index].localId}',
                                                ),
                                                draft: _steps[index],
                                                onChanged: () =>
                                                    setState(() {}),
                                                onDelete: _steps.length == 1
                                                    ? null
                                                    : _deleteCurrentStep,
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
    );
  }
}

class _TemplateInfoSection extends StatelessWidget {
  const _TemplateInfoSection({
    required this.categoriesFuture,
    required this.categoryId,
    required this.nameController,
    required this.noteController,
    required this.onCategorySelected,
  });

  final Future<List<Category>> categoriesFuture;
  final int? categoryId;
  final TextEditingController nameController;
  final TextEditingController noteController;
  final ValueChanged<int?> onCategorySelected;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
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
          FutureBuilder<List<Category>>(
            future: categoriesFuture,
            builder: (context, snapshot) {
              final categories = snapshot.data ?? const <Category>[];
              if (categories.isEmpty) {
                return const SizedBox.shrink();
              }
              return Column(
                children: [
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
                            label: category.name,
                          ),
                        )
                        .toList(),
                    onSelected: onCategorySelected,
                  ),
                ],
              );
            },
          ),
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

class _StepTabHeader extends SliverPersistentHeaderDelegate {
  const _StepTabHeader({
    required this.scrollController,
    required this.steps,
    required this.selectedIndex,
    required this.onReorder,
    required this.onSelected,
  });

  final ScrollController scrollController;
  final List<_StepDraft> steps;
  final int selectedIndex;
  final ReorderCallback onReorder;
  final ValueChanged<int> onSelected;

  static const double extent = 50;

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
      key: const ValueKey('project-template-step-tab-header'),
      color: AppColors.background,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: SizedBox(
          height: 42,
          child: _StepTabStrip(
            scrollController: scrollController,
            steps: steps,
            selectedIndex: selectedIndex,
            onReorder: onReorder,
            onSelected: onSelected,
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _StepTabHeader oldDelegate) => true;
}

class _StepTabStrip extends StatelessWidget {
  const _StepTabStrip({
    required this.scrollController,
    required this.steps,
    required this.selectedIndex,
    required this.onReorder,
    required this.onSelected,
  });

  static const double itemExtent = 88;
  static const double horizontalInset = _stepContentHorizontalInset;

  final ScrollController scrollController;
  final List<_StepDraft> steps;
  final int selectedIndex;
  final ReorderCallback onReorder;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: horizontalInset),
      child: ReorderableListView.builder(
        key: const ValueKey('project-template-step-tabs'),
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
            key: ValueKey('project-template-step-tab-${steps[index].localId}'),
            padding: EdgeInsets.only(right: trailingGap),
            child: ReorderableDelayedDragStartListener(
              key: ValueKey('project-template-step-tab-drag-$index'),
              index: index,
              child: _StepTab(
                index: index,
                selected: index == selectedIndex,
                onSelected: () => onSelected(index),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StepTab extends StatelessWidget {
  const _StepTab({
    required this.index,
    required this.selected,
    required this.onSelected,
  });

  final int index;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = selected ? AppColors.primaryDark : AppColors.textPrimary;
    return InkWell(
      key: ValueKey('project-template-step-tab-button-$index'),
      borderRadius: BorderRadius.circular(8),
      onTap: onSelected,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryLight : colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : Colors.black.withValues(alpha: 0.08),
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '节点 ${index + 1}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
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
  }) : localId = _nextLocalId++,
       titleController = TextEditingController(text: title),
       amountController = TextEditingController(
         text: amount == null ? '' : (amount / 100).toStringAsFixed(2),
       ),
       offsetDaysController = TextEditingController(text: '$offsetDays');

  static int _nextLocalId = 0;

  factory _StepDraft.fromStep(ProjectTemplateStep step) {
    return _StepDraft(
      title: step.title,
      itemType: ItemType.fromString(step.itemType),
      amountType: AmountType.fromString(step.amountType),
      amount: step.amount,
      offsetDays: step.offsetDays,
    );
  }

  final int localId;
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
    super.key,
    required this.draft,
    required this.onChanged,
    required this.onDelete,
  });

  final _StepDraft draft;
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
                    key: const ValueKey('project-template-step-title-field'),
                    controller: draft.titleController,
                    decoration: const InputDecoration(labelText: '节点标题 *'),
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
                      key: const ValueKey('project-template-step-amount-field'),
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
                    key: const ValueKey('project-template-step-offset-field'),
                    controller: draft.offsetDaysController,
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: '相对关键日期偏移天数',
                      helperText: '0 表示关键日期当天，-7 表示提前 7 天，14 表示之后 14 天',
                      helperMaxLines: 3,
                    ),
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
                  key: const ValueKey('project-template-delete-step'),
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
