import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/dialog_helper.dart';
import '../../../domain/enums/bill_amount_type.dart';
import '../../../shared/widgets/app_dropdown_field.dart';
import '../providers/bill_providers.dart';
import '../../../data/database/database_provider.dart';

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
      _noteController.text = bill.note ?? '';
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
            _SectionCard(
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
            _SectionCard(
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
                  FutureBuilder(
                    future: ref
                        .read(databaseProvider)
                        .categoryDao
                        .getByType(
                          _amountType == BillAmountType.income
                              ? 'income'
                              : 'expense',
                        ),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox.shrink();
                      final cats = snapshot.data!;
                      return AppDropdownField<int>(
                        label: '分类',
                        value: cats.any((c) => c.id == _selectedCategoryId)
                            ? _selectedCategoryId
                            : null,
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
              title: '账单时间',
              child: _DateField(
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
            billTime: _billTime,
            note: _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
          )
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
        content: const Text('删除后无法恢复，确认要删除这条账单吗？'),
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
