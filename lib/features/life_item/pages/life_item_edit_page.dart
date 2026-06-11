import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' show Value;
import '../../../domain/enums/item_type.dart';
import '../../../domain/enums/amount_type.dart';
import '../../../domain/enums/repeat_period.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/utils/date_formatter.dart';
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

  ItemType _itemType = ItemType.todo;
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
    setState(() {
      _loadFromItem(item);
      _projectId = item.projectId;
    });
  }

  void _loadFromMap(Map<String, dynamic> data) {
    _titleController.text = data['title'] as String? ?? '';
    _descController.text = data['description'] as String? ?? '';
    _itemType = ItemType.fromString(data['itemType'] as String? ?? 'todo');
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
    _itemType = ItemType.fromString(item.itemType);
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
      _itemType = ItemType.fromString(template.itemType);
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

  _LifeItemQuickType? get _selectedQuickType => switch (_itemType) {
    ItemType.todo => _LifeItemQuickType.todo,
    ItemType.expiration => _LifeItemQuickType.expiration,
    ItemType.bill => _LifeItemQuickType.bill,
    ItemType.subscription => _LifeItemQuickType.subscription,
    _ => null,
  };

  void _applyQuickType(_LifeItemQuickType type) {
    setState(() {
      switch (type) {
        case _LifeItemQuickType.todo:
          _itemType = ItemType.todo;
          _amountType = AmountType.none;
        case _LifeItemQuickType.expiration:
          _itemType = ItemType.expiration;
          _amountType = AmountType.none;
        case _LifeItemQuickType.bill:
          _itemType = ItemType.bill;
          if (_amountType == AmountType.none) _amountType = AmountType.expense;
        case _LifeItemQuickType.subscription:
          _itemType = ItemType.subscription;
          if (_amountType == AmountType.none) _amountType = AmountType.expense;
          _hasRepeat = true;
          _repeatPeriod = RepeatPeriod.monthly;
      }
    });
  }

  void _save() {
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
                itemType: _itemType.value,
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
            'itemType': _itemType.value,
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(_isEdit ? '编辑事项' : '新建事项')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!_isEdit) ...[
              _ItemTemplateSelector(
                selectedTemplateId: _selectedTemplateId,
                onSelected: (template) {
                  if (template == null) {
                    setState(() => _selectedTemplateId = null);
                  } else {
                    _applyItemTemplate(template);
                  }
                },
              ),
              const SizedBox(height: 16),
            ],
            _SectionCard(
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
                  TextFormField(
                    controller: _descController,
                    decoration: const InputDecoration(labelText: '备注'),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: '类型与分类',
              child: Column(
                children: [
                  _QuickTypeSelector(
                    selected: _selectedQuickType,
                    onSelected: _applyQuickType,
                  ),
                  const SizedBox(height: 16),
                  AppDropdownField<ItemType>(
                    label: '事项类型',
                    value: _itemType,
                    options: ItemType.values
                        .map((t) => AppDropdownOption(value: t, label: t.label))
                        .toList(),
                    onSelected: (v) =>
                        setState(() => _itemType = v ?? _itemType),
                  ),
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
                              (c) =>
                                  AppDropdownOption(value: c.id, label: c.name),
                            )
                            .toList(),
                        onSelected: (v) =>
                            setState(() => _selectedCategoryId = v),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: '时间与金额',
              child: Column(
                children: [
                  ProjectPickerField(
                    value: _projectId,
                    onChanged: (v) => setState(() => _projectId = v),
                  ),
                  const SizedBox(height: 16),
                  _DateField(
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
                        .map((p) => AppDropdownOption(value: p, label: p.label))
                        .toList(),
                    onSelected: (v) =>
                        setState(() => _reminderPreset = v ?? _reminderPreset),
                  ),
                  if (_reminderPreset == ReminderPreset.custom) ...[
                    const SizedBox(height: 16),
                    _DateField(
                      label: '提醒日期',
                      value: DateFormatter.formatDate(
                        _customReminderTime ?? _dueDate,
                      ),
                      onTap: _pickCustomReminderDate,
                    ),
                    const SizedBox(height: 16),
                    _DateField(
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
                        .map((t) => AppDropdownOption(value: t, label: t.label))
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
            _SectionCard(
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
                            (p) => AppDropdownOption(value: p, label: p.label),
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
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _save,
              child: Text(_isEdit ? '保存修改' : '创建事项'),
            ),
          ],
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
}

class _DateField extends StatelessWidget {
  const _DateField({
    super.key,
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

class _ItemTemplateSelector extends ConsumerWidget {
  const _ItemTemplateSelector({
    required this.selectedTemplateId,
    required this.onSelected,
  });

  final int? selectedTemplateId;
  final ValueChanged<ItemTemplate?> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(itemTemplatesProvider);
    return templatesAsync.when(
      loading: () => const _ItemTemplateShell(
        title: '事项模板',
        subtitle: '正在加载模板...',
        child: LinearProgressIndicator(),
      ),
      error: (error, _) => _ItemTemplateShell(
        title: '事项模板',
        subtitle: '模板加载失败',
        child: Text('$error'),
      ),
      data: (templates) {
        final selected = templates
            .where((template) => template.id == selectedTemplateId)
            .firstOrNull;
        return _ItemTemplateShell(
          title: selected?.name ?? '不使用模板',
          subtitle: selected == null ? '手动设置类型、分类、日期和金额' : '已套用默认类型、分类、日期和提醒',
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => _openPicker(context, templates),
                icon: const Icon(Icons.auto_awesome_motion_outlined),
                label: Text(selected == null ? '选择模板' : '更换模板'),
              ),
              if (selected != null) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => onSelected(null),
                  child: const Text('清除'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _openPicker(BuildContext context, List<ItemTemplate> templates) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => _ItemTemplatePickerSheet(
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

class _ItemTemplateShell extends StatelessWidget {
  const _ItemTemplateShell({
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
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_motion_outlined,
                    size: 20,
                  ),
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
                    ItemType.fromString(template.itemType).label,
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

enum _LifeItemQuickType {
  todo('待办', Icons.check_circle_outline),
  expiration('到期', Icons.event_available_outlined),
  bill('账单', Icons.receipt_long_outlined),
  subscription('订阅', Icons.autorenew);

  const _LifeItemQuickType(this.label, this.icon);

  final String label;
  final IconData icon;
}

class _QuickTypeSelector extends StatelessWidget {
  const _QuickTypeSelector({required this.selected, required this.onSelected});

  final _LifeItemQuickType? selected;
  final ValueChanged<_LifeItemQuickType> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.start,
        children: _LifeItemQuickType.values
            .map(
              (type) => ChoiceChip(
                selected: selected == type,
                showCheckmark: false,
                avatar: Icon(type.icon, size: 18),
                label: Text(type.label),
                onSelected: (_) => onSelected(type),
              ),
            )
            .toList(),
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
    final theme = Theme.of(context);

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
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
