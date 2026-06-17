import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' show Value;
import '../../../domain/enums/item_status.dart';
import '../../../domain/enums/amount_type.dart';
import '../../../domain/enums/repeat_period.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/date_field.dart';
import '../../../core/widgets/section_card.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/database_provider.dart';
import '../models/reminder_preset.dart';
import '../../../shared/widgets/app_dropdown_field.dart';
import '../../project/widgets/project_picker_field.dart';
import '../providers/life_item_providers.dart';

class LifeItemEditPage extends ConsumerStatefulWidget {
  const LifeItemEditPage({super.key});

  @override
  ConsumerState<LifeItemEditPage> createState() => _LifeItemEditPageState();
}

class _LifeItemEditPageState extends ConsumerState<LifeItemEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _amountController = TextEditingController();

  AmountType _amountType = AmountType.none;
  RepeatPeriod _repeatPeriod = RepeatPeriod.daily;
  int _customRepeatDays = 30;
  bool _hasRepeat = false;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 1));
  int? _selectedCategoryId;
  int? _projectId;
  int? _selectedTemplateId;
  String _titleInput = '';
  ReminderPreset _reminderPreset = ReminderPreset.none;
  DateTime? _customReminderTime;
  bool _isEdit = false;
  int? _editId;
  bool _loaded = false;

  /// 终态（已完成/已取消/已归档）或已软删除的事项，编辑页整页只读，
  /// 状态只能通过详情页的「重新打开」按钮变更。
  bool _isReadonly = false;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_onTitleChanged);
  }

  void _onTitleChanged() {
    if (_isEdit) return;
    final next = _titleController.text;
    if (next == _titleInput) return;
    setState(() => _titleInput = next);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    final state = GoRouterState.of(context);
    final extra = state.extra;
    if (extra != null && extra is Map<String, dynamic>) {
      if (extra.containsKey('projectId') && !_isEdit) {
        _projectId = extra['projectId'] as int?;
      }
      if (extra.containsKey('id')) {
        _isEdit = true;
        _editId = extra['id'] as int?;
        _loadFromMap(extra);
      }
    }
    if (!_isEdit) {
      final idStr = state.pathParameters['id'];
      if (idStr != null && idStr != 'new') {
        _isEdit = true;
        _editId = int.tryParse(idStr);
        _loadFromDatabase();
      }
    }
    // Also check extra for projectId when navigating from project detail
    if (!_isEdit && extra is Map && extra['projectId'] != null) {
      _projectId = extra['projectId'] as int?;
    }
    _loaded = true;
  }

  Future<void> _loadFromDatabase() async {
    final id = _editId;
    if (id == null) return;
    final item = await ref.read(databaseProvider).lifeItemDao.getById(id);
    if (!mounted) return;
    final status = ItemStatus.fromString(item.status);
    setState(() {
      _loadFromItem(item);
      _projectId = item.projectId;
      _isReadonly = status.isFinal || item.deletedAt != null;
    });
  }

  void _loadFromMap(Map<String, dynamic> data) {
    _titleController.text = data['title'] as String? ?? '';
    _descController.text = data['description'] as String? ?? '';
    _amountType = AmountType.fromString(
      data['amountType'] as String? ?? 'none',
    );
    if (data['amount'] != null) {
      _amountController.text = ((data['amount'] as int) / 100).toStringAsFixed(
        2,
      );
    }
    _dueDate =
        data['dueTime'] as DateTime? ??
        DateTime.now().add(const Duration(days: 1));
    _selectedCategoryId = data['categoryId'] as int?;
    _reminderPreset = ReminderPreset.fromRemindTime(
      data['remindTime'] as DateTime?,
      _dueDate,
    );
    if (_reminderPreset == ReminderPreset.custom) {
      _customReminderTime = data['remindTime'] as DateTime?;
    }
    _hasRepeat = data['repeatRule'] != null;
    if (_hasRepeat) {
      final ruleStr = data['repeatRule'] as String;
      if (ruleStr.startsWith('every:')) {
        _repeatPeriod = RepeatPeriod.custom;
        _customRepeatDays = int.tryParse(ruleStr.split(':')[1]) ?? 30;
      } else {
        _repeatPeriod = RepeatPeriod.fromString(ruleStr);
      }
    }
  }

  void _loadFromItem(LifeItem item) {
    _titleController.text = item.title;
    _descController.text = item.description ?? '';
    _amountType = AmountType.fromString(item.amountType);
    if (item.amount != null) {
      _amountController.text = (item.amount! / 100).toStringAsFixed(2);
    } else {
      _amountController.clear();
    }
    _dueDate = item.dueTime;
    _selectedCategoryId = item.categoryId;
    _reminderPreset = ReminderPreset.fromRemindTime(
      item.remindTime,
      item.dueTime,
    );
    if (_reminderPreset == ReminderPreset.custom) {
      _customReminderTime = item.remindTime;
    }
    _hasRepeat = item.repeatRule != null;
    if (_hasRepeat) {
      final ruleStr = item.repeatRule!;
      if (ruleStr.startsWith('every:')) {
        _repeatPeriod = RepeatPeriod.custom;
        _customRepeatDays = int.tryParse(ruleStr.split(':')[1]) ?? 30;
      } else {
        _repeatPeriod = RepeatPeriod.fromString(ruleStr);
      }
    }
  }

  void _applyItemTemplate(ItemTemplate template, {bool replaceTitle = true}) {
    final dueDate = DateTime.now().add(Duration(days: template.dueOffsetDays));
    setState(() {
      _selectedTemplateId = template.id;
      if (replaceTitle || _titleController.text.trim().isEmpty) {
        _titleController.text = template.name;
      }
      _amountType = AmountType.fromString(template.amountType);
      if (template.amount != null) {
        _amountController.text = (template.amount! / 100).toStringAsFixed(2);
      } else if (_amountType == AmountType.none) {
        _amountController.clear();
      }
      _dueDate = dueDate;
      _selectedCategoryId = template.categoryId ?? _selectedCategoryId;
      final reminderOffset = template.reminderOffsetDays;
      if (reminderOffset == null) {
        _reminderPreset = ReminderPreset.none;
        _customReminderTime = null;
      } else {
        _reminderPreset = ReminderPreset.custom;
        _customReminderTime = dueDate.add(Duration(days: reminderOffset));
      }
      final repeatRule = template.repeatRule;
      if (repeatRule != null) {
        _hasRepeat = true;
        if (repeatRule.startsWith('every:')) {
          _repeatPeriod = RepeatPeriod.custom;
          _customRepeatDays = int.tryParse(repeatRule.split(':')[1]) ?? 30;
        } else {
          _repeatPeriod = RepeatPeriod.fromString(repeatRule);
        }
      } else {
        _hasRepeat = false;
      }
    });
  }

  @override
  void dispose() {
    _titleController.removeListener(_onTitleChanged);
    _titleController.dispose();
    _descController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  String? _buildRepeatRule() {
    if (!_hasRepeat) return null;
    if (_repeatPeriod == RepeatPeriod.custom) {
      return 'every:$_customRepeatDays:days';
    }
    return _repeatPeriod.value;
  }

  void _save() {
    // 守卫：终态/已删除事项整页只读，禁止任何写入（防绕过 UI）。
    if (_isReadonly) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('事项已完结，不可编辑')));
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    final notifier = ref.read(lifeItemNotifierProvider.notifier);

    if (_isEdit && _editId != null) {
      ref
          .read(databaseProvider)
          .lifeItemDao
          .getById(_editId!)
          .then((item) {
            return notifier.update(
              item.copyWith(
                title: _titleController.text.trim(),
                description: Value(
                  _descController.text.trim().isEmpty
                      ? null
                      : _descController.text.trim(),
                ),
                categoryId: Value(_selectedCategoryId),
                projectId: Value(_projectId),
                amount: Value(
                  _amountType != AmountType.none
                      ? MoneyFormatter.parse(_amountController.text)
                      : null,
                ),
                amountType: _amountType.value,
                dueTime: _dueDate,
                remindTime: Value(_resolvedReminderTime()),
                repeatRule: Value(_buildRepeatRule()),
                updatedAt: DateTime.now(),
              ),
            );
          })
          .then((_) {
            if (mounted) context.pop();
          });
    } else {
      notifier
          .create({
            'title': _titleController.text.trim(),
            'description': _descController.text.trim().isEmpty
                ? null
                : _descController.text.trim(),
            'categoryId': _selectedCategoryId,
            'projectId': _projectId,
            'amount': _amountType != AmountType.none
                ? MoneyFormatter.parse(_amountController.text)
                : null,
            'amountType': _amountType.value,
            'dueTime': _dueDate,
            'remindTime': _resolvedReminderTime(),
            'repeatRule': _buildRepeatRule(),
          })
          .then((_) {
            if (mounted) context.pop();
          });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isReadonly) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('事项（只读）')),
        body: const _ReadonlyMessage(
          title: '事项已完结',
          message: '只读状态的事项不能编辑，可在详情中重新打开后再修改。',
        ),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          _isReadonly
              ? '${_isEdit ? '事项' : '新建事项'}（只读）'
              : (_isEdit ? '编辑事项' : '新建事项'),
        ),
        actions: [
          if (!_isEdit)
            IconButton(
              tooltip: '选择模板',
              onPressed: _openTemplatePicker,
              icon: const Icon(Icons.auto_awesome_motion_outlined),
            ),
          IconButton(
            tooltip: _isEdit ? '保存修改' : '创建事项',
            onPressed: _save,
            icon: const Icon(Icons.check_rounded),
          ),
        ],
      ),
      body: AbsorbPointer(
        // 终态/已删除时禁用整页交互，使所有字段只读。
        absorbing: _isReadonly,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SectionCard(
                title: '事项内容',
                child: Column(
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(labelText: '标题 *'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? '请输入标题' : null,
                    ),
                    if (!_isEdit) ...[
                      _ItemTemplateRecommendations(
                        title: _titleInput,
                        selectedTemplateId: _selectedTemplateId,
                        onApply: (template) =>
                            _applyItemTemplate(template, replaceTitle: false),
                      ),
                    ],
                    const SizedBox(height: 16),
                    FutureBuilder(
                      future: ref
                          .read(databaseProvider)
                          .categoryDao
                          .getByType('item'),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const SizedBox.shrink();
                        final cats = snapshot.data!;
                        final validValue =
                            cats.any((c) => c.id == _selectedCategoryId)
                            ? _selectedCategoryId
                            : null;
                        return AppDropdownField<int>(
                          label: '分类',
                          value: validValue,
                          options: cats
                              .map(
                                (c) => AppDropdownOption(
                                  value: c.id,
                                  label: c.name,
                                ),
                              )
                              .toList(),
                          onSelected: (v) =>
                              setState(() => _selectedCategoryId = v),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descController,
                      decoration: const InputDecoration(labelText: '备注'),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: '时间与金额',
                child: Column(
                  children: [
                    ProjectPickerField(
                      value: _projectId,
                      onChanged: (v) => setState(() => _projectId = v),
                    ),
                    const SizedBox(height: 16),
                    DateField(
                      key: const ValueKey('life-item-date-field'),
                      label: '日期',
                      value: DateFormatter.formatDate(_dueDate),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _dueDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null && mounted) {
                          setState(() => _dueDate = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    AppDropdownField<ReminderPreset>(
                      label: '提醒',
                      value: _reminderPreset,
                      options: ReminderPreset.values
                          .map(
                            (p) => AppDropdownOption(value: p, label: p.label),
                          )
                          .toList(),
                      onSelected: (v) => setState(
                        () => _reminderPreset = v ?? _reminderPreset,
                      ),
                    ),
                    if (_reminderPreset == ReminderPreset.custom) ...[
                      const SizedBox(height: 16),
                      DateField(
                        label: '提醒日期',
                        value: DateFormatter.formatDate(
                          _customReminderTime ?? _dueDate,
                        ),
                        onTap: _pickCustomReminderDate,
                      ),
                      const SizedBox(height: 16),
                      DateField(
                        label: '提醒时间',
                        value: _formatTime(_customReminderTime ?? _dueDate),
                        onTap: _pickCustomReminderTime,
                      ),
                    ],
                    const SizedBox(height: 16),
                    AppDropdownField<AmountType>(
                      label: '金额类型',
                      value: _amountType,
                      options: AmountType.values
                          .map(
                            (t) => AppDropdownOption(value: t, label: t.label),
                          )
                          .toList(),
                      onSelected: (v) =>
                          setState(() => _amountType = v ?? _amountType),
                    ),
                    if (_amountType != AmountType.none) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: '金额',
                          prefixText: '¥',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: '重复规则',
                child: Column(
                  children: [
                    SwitchListTile(
                      value: _hasRepeat,
                      title: const Text('重复'),
                      contentPadding: EdgeInsets.zero,
                      onChanged: (v) => setState(() => _hasRepeat = v),
                    ),
                    if (_hasRepeat) ...[
                      const SizedBox(height: 8),
                      AppDropdownField<RepeatPeriod>(
                        label: '重复频率',
                        value: _repeatPeriod,
                        options: RepeatPeriod.values
                            .map(
                              (p) =>
                                  AppDropdownOption(value: p, label: p.label),
                            )
                            .toList(),
                        onSelected: (v) =>
                            setState(() => _repeatPeriod = v ?? _repeatPeriod),
                      ),
                      if (_repeatPeriod == RepeatPeriod.custom) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          initialValue: _customRepeatDays.toString(),
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: '每 N 天'),
                          onChanged: (v) =>
                              _customRepeatDays = int.tryParse(v) ?? 30,
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  DateTime? _resolvedReminderTime() {
    return _reminderPreset.remindTimeFor(
      _dueDate,
      customTime: _customReminderTime ?? _dueDate,
    );
  }

  Future<void> _pickCustomReminderDate() async {
    final current = _customReminderTime ?? _dueDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _customReminderTime = DateTime(
        picked.year,
        picked.month,
        picked.day,
        current.hour,
        current.minute,
      );
    });
  }

  Future<void> _pickCustomReminderTime() async {
    final current = _customReminderTime ?? _dueDate;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _customReminderTime = DateTime(
        current.year,
        current.month,
        current.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  String _formatTime(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _openTemplatePicker() async {
    final templates = await ref.read(lifeItemRepoProvider).getTemplates();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => _ItemTemplatePickerSheet(
        templates: templates,
        selectedTemplateId: _selectedTemplateId,
        onSelected: (template) {
          Navigator.of(sheetContext).pop();
          if (template == null) {
            setState(() => _selectedTemplateId = null);
          } else {
            _applyItemTemplate(template);
          }
        },
      ),
    );
  }
}

class _ReadonlyMessage extends StatelessWidget {
  const _ReadonlyMessage({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 48, color: AppColors.textHint),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go('/items'),
              child: const Text('返回事项列表'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemTemplateRecommendations extends ConsumerWidget {
  const _ItemTemplateRecommendations({
    required this.title,
    required this.selectedTemplateId,
    required this.onApply,
  });

  final String title;
  final int? selectedTemplateId;
  final ValueChanged<ItemTemplate> onApply;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return const SizedBox.shrink();
    final recommendations = ref.watch(
      itemTemplateRecommendationsProvider(trimmed),
    );
    return recommendations.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (templates) {
        final rows = templates
            .where((template) => template.id != selectedTemplateId)
            .toList();
        if (rows.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final template in rows)
                  ActionChip(
                    avatar: const Icon(Icons.tips_and_updates_outlined),
                    label: Text('推荐：${template.name}'),
                    onPressed: () => onApply(template),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ItemTemplatePickerSheet extends ConsumerWidget {
  const _ItemTemplatePickerSheet({
    required this.templates,
    required this.selectedTemplateId,
    required this.onSelected,
  });

  final List<ItemTemplate> templates;
  final int? selectedTemplateId;
  final ValueChanged<ItemTemplate?> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(
      FutureProvider.autoDispose(
        (ref) => ref.read(databaseProvider).categoryDao.getByType('item'),
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
            '选择事项模板',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          _ItemTemplateOptionFrame(
            selected: selectedTemplateId == null,
            onTap: () => onSelected(null),
            child: Row(
              children: [
                Icon(
                  selectedTemplateId == null
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: selectedTemplateId == null
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '不使用模板',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: 2),
                      Text('手动设置事项字段'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          for (final template in templates) ...[
            _ItemTemplateTile(
              template: template,
              categoryName: categoryNames[template.categoryId],
              selected: selectedTemplateId == template.id,
              onTap: () => onSelected(template),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _ItemTemplateTile extends StatelessWidget {
  const _ItemTemplateTile({
    required this.template,
    required this.categoryName,
    required this.selected,
    required this.onTap,
  });

  final ItemTemplate template;
  final String? categoryName;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _ItemTemplateOptionFrame(
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
                  [
                    if (categoryName != null) categoryName!,
                    if (template.repeatRule != null) '重复',
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

class _ItemTemplateOptionFrame extends StatelessWidget {
  const _ItemTemplateOptionFrame({
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
