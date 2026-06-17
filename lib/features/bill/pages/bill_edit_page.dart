import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/dialog_helper.dart';
import '../../../core/widgets/date_field.dart';
import '../../../core/widgets/section_card.dart';
import '../../../domain/enums/bill_amount_type.dart';
import '../../../shared/widgets/app_dropdown_field.dart';
import '../../project/widgets/project_picker_field.dart';
import '../providers/bill_providers.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/database_provider.dart';
import '../../life_item/providers/life_item_providers.dart';

class BillEditPage extends ConsumerStatefulWidget {
  const BillEditPage({super.key});

  @override
  ConsumerState<BillEditPage> createState() => _BillEditPageState();
}

class _BillEditPageState extends ConsumerState<BillEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  BillAmountType _amountType = BillAmountType.expense;
  DateTime _billTime = DateTime.now();
  int? _selectedCategoryId;
  int? _projectId;
  int? _lifeItemId;
  bool _isEdit = false;
  int? _editId;
  bool _loaded = false;
  List<Category> _categories = [];
  bool _isReadonly = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  void _loadCategories() {
    final type = _amountType == BillAmountType.income ? 'income' : 'expense';
    ref.read(databaseProvider).categoryDao.getByType(type).then((cats) {
      if (!mounted) return;
      setState(() => _categories = cats);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    final state = GoRouterState.of(context);
    final extra = state.extra;
    if (extra is Map) {
      _projectId = extra['projectId'] as int?;
      _lifeItemId = extra['lifeItemId'] as int?;
      final title = extra['title'];
      if (title is String && title.trim().isNotEmpty) {
        _titleController.text = title.trim();
      }
      final amount = extra['amount'];
      if (amount is int) {
        _amountController.text = (amount / 100).toStringAsFixed(2);
      }
      final amountType = extra['amountType'];
      if (amountType == 'income' || amountType == 'expense') {
        _amountType = BillAmountType.fromString(amountType as String);
      }
      final billTime = extra['billTime'];
      if (billTime is DateTime) {
        _billTime = billTime;
      }
    }
    final idStr = state.pathParameters['id'];
    if (idStr != null && idStr != 'new') {
      _isEdit = true;
      _editId = int.tryParse(idStr);
      _loadBill();
    }
    _loaded = true;
  }

  Future<void> _loadBill() async {
    if (_editId == null) return;
    final db = ref.read(databaseProvider);
    final bill = await db.billRecordDao.getById(_editId!);
    if (!mounted) return;
    setState(() {
      _titleController.text = bill.title;
      _amountController.text = (bill.amount / 100).toStringAsFixed(2);
      _amountType = BillAmountType.fromString(bill.amountType);
      _billTime = bill.billTime;
      _selectedCategoryId = bill.categoryId;
      _projectId = bill.projectId;
      _lifeItemId = bill.lifeItemId;
      _noteController.text = bill.note ?? '';
      _isReadonly = bill.deletedAt != null;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isReadonly) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('账单（只读）')),
        body: const _ReadonlyMessage(
          title: '账单已删除',
          message: '回收站中的账单不能编辑，恢复后再修改。',
        ),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEdit ? '编辑账单' : '新建账单'),
        actions: [
          IconButton(
            tooltip: '保存',
            icon: const Icon(Icons.check),
            onPressed: _save,
          ),
          if (_isEdit)
            IconButton(
              tooltip: '删除',
              icon: const Icon(Icons.delete),
              onPressed: () => _confirmDelete(context),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SectionCard(
              title: '账单内容',
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
                    controller: _noteController,
                    decoration: const InputDecoration(labelText: '备注'),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: '金额与分类',
              child: Column(
                children: [
                  AppDropdownField<BillAmountType>(
                    label: '类型',
                    value: _amountType,
                    options: BillAmountType.values
                        .map((t) => AppDropdownOption(value: t, label: t.label))
                        .toList(),
                    onSelected: (v) => setState(() {
                      _amountType = v ?? _amountType;
                      _selectedCategoryId = null;
                      _loadCategories();
                    }),
                  ),
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
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? '请输入金额' : null,
                  ),
                  const SizedBox(height: 16),
                  if (_categories.isNotEmpty)
                    AppDropdownField<int>(
                      label: '分类',
                      value: _categories.any((c) => c.id == _selectedCategoryId)
                          ? _selectedCategoryId
                          : null,
                      options: _categories
                          .map(
                            (c) =>
                                AppDropdownOption(value: c.id, label: c.name),
                          )
                          .toList(),
                      onSelected: (v) =>
                          setState(() => _selectedCategoryId = v),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: '账单时间',
              child: Column(
                children: [
                  ProjectPickerField(
                    value: _projectId,
                    onChanged: (v) => setState(() => _projectId = v),
                  ),
                  const SizedBox(height: 16),
                  DateField(
                    key: const ValueKey('bill-date-field'),
                    label: '日期',
                    value: DateFormatter.formatDate(_billTime),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _billTime,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null && mounted) {
                        setState(() => _billTime = picked);
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _save,
              child: Text(_isEdit ? '保存修改' : '创建账单'),
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    if (_isReadonly) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('账单已删除，不可编辑')));
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    final notifier = ref.read(billNotifierProvider.notifier);

    if (_isEdit && _editId != null) {
      ref
          .read(databaseProvider)
          .billRecordDao
          .getById(_editId!)
          .then((bill) {
            return ref
                .read(billRepoProvider)
                .updateRecord(
                  bill.copyWith(
                    title: _titleController.text.trim(),
                    amount: MoneyFormatter.parse(_amountController.text) ?? 0,
                    amountType: _amountType.value,
                    categoryId: Value(_selectedCategoryId),
                    projectId: Value(_projectId),
                    billTime: _billTime,
                    note: Value(_noteController.text.trim()),
                    updatedAt: DateTime.now(),
                  ),
                );
          })
          .then((_) {
            if (mounted) context.pop();
          });
    } else {
      notifier
          .create(
            title: _titleController.text.trim(),
            amount: MoneyFormatter.parse(_amountController.text) ?? 0,
            amountType: _amountType.value,
            categoryId: _selectedCategoryId,
            projectId: _projectId,
            lifeItemId: _lifeItemId,
            billTime: _billTime,
            note: _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
          )
          .then((_) async {
            final lifeItemId = _lifeItemId;
            if (lifeItemId == null) return;
            await ref
                .read(lifeItemNotifierProvider.notifier)
                .complete(lifeItemId);
          })
          .then((_) {
            if (mounted) context.pop();
          });
    }
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('删除后可在回收站恢复，确认要删除这条账单吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(billNotifierProvider.notifier).delete(_editId!);
              ctx.safePop();
              if (context.mounted) context.pop();
            },
            child: const Text('删除'),
          ),
        ],
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
              onPressed: () => context.go('/bills'),
              child: const Text('返回账单列表'),
            ),
          ],
        ),
      ),
    );
  }
}
