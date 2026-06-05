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
import '../../../shared/widgets/app_dropdown_field.dart';
import '../providers/life_item_providers.dart';
import '../widgets/quick_template_sheet.dart';

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
  bool _isEdit = false;
  int? _editId;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    final state = GoRouterState.of(context);
    final extra = state.extra;
    if (extra != null && extra is Map<String, dynamic>) {
      _isEdit = true;
      _editId = extra['id'] as int?;
      _loadFromMap(extra);
    } else {
      final idStr = state.pathParameters['id'];
      if (idStr != null && idStr != 'new') {
        _isEdit = true;
        _editId = int.tryParse(idStr);
        _loadFromDatabase();
      }
    }
    _loaded = true;
  }

  Future<void> _loadFromDatabase() async {
    final id = _editId;
    if (id == null) return;
    final item = await ref.read(databaseProvider).lifeItemDao.getById(id);
    if (!mounted) return;
    setState(() => _loadFromItem(item));
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

  void _applyTemplate(TemplateData t) {
    setState(() {
      _titleController.text = t.title;
      _itemType = ItemType.fromString(t.itemType);
      _amountType = AmountType.fromString(t.amountType);
      if (t.repeatRule != null) {
        _hasRepeat = true;
        if (t.repeatRule!.startsWith('every:')) {
          _repeatPeriod = RepeatPeriod.custom;
          _customRepeatDays = int.tryParse(t.repeatRule!.split(':')[1]) ?? 30;
        } else {
          _repeatPeriod = RepeatPeriod.fromString(t.repeatRule!);
        }
      }
    });
    _findCategoryByName(t.categoryName);
  }

  Future<void> _findCategoryByName(String? name) async {
    if (name == null) return;
    final db = ref.read(databaseProvider);
    final cats = await db.categoryDao.getAll();
    final match = cats.where((c) => c.name == name).firstOrNull;
    if (match != null && mounted) {
      setState(() => _selectedCategoryId = match.id);
    }
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
                amount: Value(
                  _amountType != AmountType.none
                      ? MoneyFormatter.parse(_amountController.text)
                      : null,
                ),
                amountType: _amountType.value,
                dueTime: _dueDate,
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
            'amount': _amountType != AmountType.none
                ? MoneyFormatter.parse(_amountController.text)
                : null,
            'amountType': _amountType.value,
            'dueTime': _dueDate,
            'remindTime': null,
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
      appBar: AppBar(
        title: Text(_isEdit ? '编辑事项' : '新建事项'),
        actions: [
          if (!_isEdit)
            TextButton(
              onPressed: () => showQuickTemplateSheet(context, _applyTemplate),
              child: const Text('模板'),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
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
                      if (picked != null) setState(() => _dueDate = picked);
                    },
                  ),
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
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _LifeItemQuickType.values
          .map(
            (type) => ChoiceChip(
              selected: selected == type,
              avatar: Icon(type.icon, size: 18),
              label: Text(type.label),
              onSelected: (_) => onSelected(type),
            ),
          )
          .toList(),
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
