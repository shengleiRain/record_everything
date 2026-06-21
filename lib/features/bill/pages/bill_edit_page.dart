import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/utils/dialog_helper.dart';
import '../../../core/utils/form_draft_store.dart';
import '../../../core/utils/toast.dart';
import '../../../core/widgets/date_field.dart';
import '../../../core/widgets/section_card.dart';
import '../../../domain/enums/bill_amount_type.dart';
import '../../../shared/widgets/app_dropdown_field.dart';
import '../../../shared/widgets/dirty_guard_mixin.dart';
import '../../../shared/widgets/form_save_mixin.dart';
import '../../../shared/widgets/money_text_form_field.dart';
import '../../../shared/widgets/readonly_message.dart';
import '../../project/widgets/project_picker_field.dart';
import '../providers/bill_providers.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/database_provider.dart';
import '../../life_item/providers/life_item_providers.dart';
import '../../settings/providers/settings_providers.dart';

class BillEditPage extends ConsumerStatefulWidget {
  const BillEditPage({super.key});

  @override
  ConsumerState<BillEditPage> createState() => _BillEditPageState();
}

class _BillEditPageState extends ConsumerState<BillEditPage>
    with FormSaveMixin<BillEditPage>, DirtyGuardMixin<BillEditPage> {
  static const String _draftEntityType = 'bill';
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final FormDraftStore _draftStore = FormDraftStore();

  BillAmountType _amountType = BillAmountType.expense;
  DateTime _billTime = DateTime.now();
  int? _selectedCategoryId;
  int? _projectId;
  int? _lifeItemId;
  bool _isEdit = false;
  int? _editId;
  bool _loaded = false;

  // 自动分类建议（phase 3）
  int? _suggestedCategoryId;
  Timer? _suggestionDebounce;
  bool _isReadonly = false;
  bool _isHydratingForm = false;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_onAmountChanged);
  }

  void _onAmountChanged() {
    if (_isHydratingForm || _isReadonly) return;
    _markDirtyAndPersist();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    final state = GoRouterState.of(context);
    final extra = state.extra;
    if (extra is Map) {
      _isHydratingForm = true;
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
      _isHydratingForm = false;
    }
    final idStr = state.pathParameters['id'];
    if (idStr != null && idStr != 'new') {
      _isEdit = true;
      _editId = int.tryParse(idStr);
    }
    final draftType = _isEdit && _editId != null
        ? FormDraftStore.editDraftKey(_draftEntityType, _editId!)
        : FormDraftStore.newDraftKey(_draftEntityType);
    attachDraft(_draftStore, draftType, collect: _collectDraft, noun: '账单');
    if (_isEdit) {
      _loadBill(offerDraftAfterLoad: true);
    } else {
      // New bill: offer to restore a recent unsaved draft.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => maybeRestoreDraft(_applyDraft, noun: '账单'),
      );
    }
    _loaded = true;
  }

  void _applyDraft(Map<String, dynamic> draft) {
    _isHydratingForm = true;
    setState(() {
      _titleController.text = (draft['title'] as String?) ?? '';
      _amountController.text = (draft['amount'] as String?) ?? '';
      _noteController.text = (draft['note'] as String?) ?? '';
      _amountType = BillAmountType.fromString(
        (draft['amountType'] as String?) ?? 'expense',
      );
      _billTime =
          DateTime.tryParse((draft['billTime'] as String?) ?? '') ??
          DateTime.now();
      _selectedCategoryId = draft['categoryId'] as int?;
      _projectId = draft['projectId'] as int?;
    });
    _isHydratingForm = false;
  }

  void _markDirtyAndPersist() {
    markDirtyAndPersist(_collectDraft);
  }

  Map<String, dynamic> _collectDraft() {
    return {
      'title': _titleController.text,
      'amount': _amountController.text,
      'note': _noteController.text,
      'amountType': _amountType.value,
      'billTime': _billTime.toIso8601String(),
      'categoryId': _selectedCategoryId,
      'projectId': _projectId,
    };
  }

  Future<void> _loadBill({bool offerDraftAfterLoad = false}) async {
    if (_editId == null) return;
    final db = ref.read(databaseProvider);
    final bill = await db.billRecordDao.getById(_editId!);
    if (!mounted) return;
    _isHydratingForm = true;
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
    _isHydratingForm = false;
    if (offerDraftAfterLoad && !_isReadonly) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => maybeRestoreDraft(_applyDraft, noun: '账单'),
      );
    }
  }

  @override
  void dispose() {
    _suggestionDebounce?.cancel();
    _amountController.removeListener(_onAmountChanged);
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _onTitleChanged(String title) {
    _suggestionDebounce?.cancel();
    if (title.trim().length < 2 || _selectedCategoryId != null) {
      setState(() => _suggestedCategoryId = null);
      return;
    }
    _suggestionDebounce = Timer(const Duration(milliseconds: 500), () async {
      final db = ref.read(databaseProvider);
      final id = await db.billRecordDao.suggestCategoryByTitle(
        title.trim(),
        _amountType.value,
      );
      if (mounted && id != null && _selectedCategoryId == null) {
        setState(() => _suggestedCategoryId = id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isReadonly) {
      return Scaffold(
        backgroundColor: AppColors.background(context),
        appBar: AppBar(title: const Text('账单（只读）')),
        body: ReadonlyMessage(
          title: '账单已删除',
          message: '回收站中的账单不能编辑，恢复后再修改。',
          backLabel: '返回账单列表',
          onBack: () => context.go('/bills'),
        ),
      );
    }
    final categoryType = _amountType == BillAmountType.income
        ? 'income'
        : 'expense';
    final categories =
        ref.watch(categoriesByTypeProvider(categoryType)).valueOrNull ??
        const <Category>[];
    return PopScope(
      canPop: !isDirty,
      onPopInvokedWithResult: (didPop, _) => onPopInvoked(didPop),
      child: Scaffold(
        backgroundColor: AppColors.background(context),
        appBar: AppBar(
          title: Text(_isEdit ? '编辑账单' : '新建账单'),
          actions: [
            IconButton(
              tooltip: '保存',
              icon: isSaving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              onPressed: isSaving ? null : _save,
            ),
            if (_isEdit)
              IconButton(
                tooltip: '删除',
                icon: const Icon(Icons.delete),
                onPressed: isSaving ? null : () => _confirmDelete(context),
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
    onChanged: (v) {
      _markDirtyAndPersist();
      _onTitleChanged(v);
    },
  ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _noteController,
                      decoration: const InputDecoration(labelText: '备注'),
                      maxLines: 2,
                      onChanged: (_) => _markDirtyAndPersist(),
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
                          .map(
                            (t) => AppDropdownOption(value: t, label: t.label),
                          )
                          .toList(),
                      onSelected: (v) => setState(() {
                        _amountType = v ?? _amountType;
                        _selectedCategoryId = null;
                        _markDirtyAndPersist();
                      }),
                    ),
                    const SizedBox(height: 16),
                    MoneyTextFormField(
                      controller: _amountController,
                      isRequired: true,
                    ),
                    const SizedBox(height: 16),
                    if (categories.isNotEmpty)
                      AppDropdownField<int>(
                        label: '分类',
                        value:
                            categories.any((c) => c.id == _selectedCategoryId)
                            ? _selectedCategoryId
                            : null,
                        options: categories
                            .map(
                              (c) =>
                                  AppDropdownOption(value: c.id, label: c.name),
                            )
                            .toList(),
                        onSelected: (v) => setState(() {
                          _selectedCategoryId = v;
                          _suggestedCategoryId = null;
                          _markDirtyAndPersist();
                        }),
                      ),
                    // 自动分类推荐（phase 3）
                    if (_suggestedCategoryId != null &&
                        _selectedCategoryId == null &&
                        categories.any((c) => c.id == _suggestedCategoryId))
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: ActionChip(
                          avatar: Icon(Icons.lightbulb_outline,
                              size: 16, color: AppColors.primary(context)),
                          label: Text(
                            '推荐：${categories.firstWhere((c) => c.id == _suggestedCategoryId).name}',
                          ),
                          onPressed: () => setState(() {
                            _selectedCategoryId = _suggestedCategoryId;
                            _suggestedCategoryId = null;
                            _markDirtyAndPersist();
                          }),
                        ),
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
                      onChanged: (v) => setState(() {
                        _projectId = v;
                        _markDirtyAndPersist();
                      }),
                    ),
                    const SizedBox(height: 16),
                    DateField(
                      key: const ValueKey('bill-date-field'),
                      label: '日期',
                      initialValue: _billTime,
                      onPick: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _billTime,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null && mounted) {
                          setState(() => _billTime = picked);
                          _markDirtyAndPersist();
                        }
                        return picked;
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_isReadonly) {
      Toast.error(context, '账单已删除，不可编辑');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    final notifier = ref.read(billNotifierProvider.notifier);

    if (_isEdit && _editId != null) {
      final bill = await ref
          .read(databaseProvider)
          .billRecordDao
          .getById(_editId!);
      await runSave(() async {
        await ref
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
        markClean();
        await clearDraft();
        if (mounted) context.pop();
      });
    } else {
      final ok = await runSave(() async {
        await notifier.create(
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
        );
        final lifeItemId = _lifeItemId;
        if (lifeItemId != null) {
          await ref
              .read(lifeItemNotifierProvider.notifier)
              .complete(lifeItemId);
        }
        markClean();
        await clearDraft();
        if (mounted) context.pop();
      });
      // runSave surfaced any error via SnackBar; nothing more to do.
      if (!ok) return;
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
