import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../domain/enums/bill_amount_type.dart';
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
      appBar: AppBar(
        title: Text(_isEdit ? '编辑账单' : '新建账单'),
        actions: [
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
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: '标题 *'),
              validator: (v) => (v == null || v.trim().isEmpty) ? '请输入标题' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<BillAmountType>(
              value: _amountType,
              decoration: const InputDecoration(labelText: '类型'),
              items: BillAmountType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.label))).toList(),
              onChanged: (v) => setState(() {
                _amountType = v!;
                _selectedCategoryId = null;
              }),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: '金额', prefixText: '¥'),
              validator: (v) => (v == null || v.trim().isEmpty) ? '请输入金额' : null,
            ),
            const SizedBox(height: 16),
            FutureBuilder(
              future: ref.read(databaseProvider).categoryDao.getByType(
                    _amountType == BillAmountType.income ? 'income' : 'expense',
                  ),
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
              subtitle: Text(DateFormatter.formatDate(_billTime)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _billTime,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (picked != null) setState(() => _billTime = picked);
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(labelText: '备注'),
              maxLines: 2,
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
      ref.read(databaseProvider).billRecordDao.getById(_editId!).then((bill) {
        return ref.read(billRepoProvider).updateRecord(bill.copyWith(
              title: _titleController.text.trim(),
              amount: MoneyFormatter.parse(_amountController.text) ?? 0,
              amountType: _amountType.value,
              categoryId: Value(_selectedCategoryId),
              billTime: _billTime,
              note: Value(_noteController.text.trim()),
              updatedAt: DateTime.now(),
            ));
      }).then((_) {
        if (mounted) context.pop();
      });
    } else {
      notifier.create(
        title: _titleController.text.trim(),
        amount: MoneyFormatter.parse(_amountController.text) ?? 0,
        amountType: _amountType.value,
        categoryId: _selectedCategoryId,
        billTime: _billTime,
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      ).then((_) {
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              ref.read(billNotifierProvider.notifier).delete(_editId!);
              Navigator.pop(ctx);
              context.pop();
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
