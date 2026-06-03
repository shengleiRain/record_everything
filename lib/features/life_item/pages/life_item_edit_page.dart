import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../domain/enums/item_type.dart';
import '../../../domain/enums/amount_type.dart';
import '../../../domain/enums/repeat_period.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/database/database_provider.dart';
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
    }
    _loaded = true;
  }

  void _loadFromMap(Map<String, dynamic> data) {
    _titleController.text = data['title'] as String? ?? '';
    _descController.text = data['description'] as String? ?? '';
    _itemType = ItemType.fromString(data['itemType'] as String? ?? 'todo');
    _amountType = AmountType.fromString(data['amountType'] as String? ?? 'none');
    if (data['amount'] != null) {
      _amountController.text = ((data['amount'] as int) / 100).toStringAsFixed(2);
    }
    _dueDate = data['dueTime'] as DateTime? ?? DateTime.now().add(const Duration(days: 1));
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

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final notifier = ref.read(lifeItemNotifierProvider.notifier);

    notifier.create({
      'title': _titleController.text.trim(),
      'description': _descController.text.trim().isEmpty ? null : _descController.text.trim(),
      'itemType': _itemType.value,
      'categoryId': _selectedCategoryId,
      'amount': _amountType != AmountType.none ? MoneyFormatter.parse(_amountController.text) : null,
      'amountType': _amountType.value,
      'dueTime': _dueDate,
      'remindTime': null,
      'repeatRule': _buildRepeatRule(),
    }).then((_) {
      if (mounted) context.pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: '标题 *'),
              validator: (v) => (v == null || v.trim().isEmpty) ? '请输入标题' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<ItemType>(
              value: _itemType,
              decoration: const InputDecoration(labelText: '事项类型'),
              items: ItemType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.label))).toList(),
              onChanged: (v) => setState(() => _itemType = v!),
            ),
            const SizedBox(height: 16),
            FutureBuilder(
              future: ref.read(databaseProvider).categoryDao.getByType('item'),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                final cats = snapshot.data!;
                return DropdownButtonFormField<int>(
                  value: _selectedCategoryId,
                  decoration: const InputDecoration(labelText: '分类'),
                  items: cats.map((c) => DropdownMenuItem<int>(value: c.id, child: Text(c.name))).toList(),
                  onChanged: (v) => setState(() => _selectedCategoryId = v),
                );
              },
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('日期'),
              subtitle: Text(DateFormatter.formatDate(_dueDate)),
              trailing: const Icon(Icons.calendar_today),
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
            const SizedBox(height: 8),
            DropdownButtonFormField<AmountType>(
              value: _amountType,
              decoration: const InputDecoration(labelText: '金额类型'),
              items: AmountType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.label))).toList(),
              onChanged: (v) => setState(() => _amountType = v!),
            ),
            if (_amountType != AmountType.none) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: '金额', prefixText: '¥'),
              ),
            ],
            const SizedBox(height: 16),
            SwitchListTile(
              value: _hasRepeat,
              title: const Text('重复'),
              contentPadding: EdgeInsets.zero,
              onChanged: (v) => setState(() => _hasRepeat = v),
            ),
            if (_hasRepeat) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<RepeatPeriod>(
                value: _repeatPeriod,
                decoration: const InputDecoration(labelText: '重复频率'),
                items: RepeatPeriod.values.map((p) => DropdownMenuItem(value: p, child: Text(p.label))).toList(),
                onChanged: (v) => setState(() => _repeatPeriod = v!),
              ),
              if (_repeatPeriod == RepeatPeriod.custom) ...[
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: _customRepeatDays.toString(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '每 N 天'),
                  onChanged: (v) => _customRepeatDays = int.tryParse(v) ?? 30,
                ),
              ],
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: _descController,
              decoration: const InputDecoration(labelText: '备注'),
              maxLines: 3,
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
