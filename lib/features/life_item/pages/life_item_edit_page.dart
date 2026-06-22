import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record_everything/core/utils/category_display.dart';
import 'package:record_everything/l10n/l10n.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' show Value;
import '../../../domain/enums/item_status.dart';
import '../../../domain/enums/amount_type.dart';
import '../../../core/utils/toast.dart';
import '../../../domain/enums/repeat_period.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/form_draft_store.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/widgets/date_field.dart';
import '../../../core/widgets/section_card.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/database_provider.dart';
import '../models/reminder_preset.dart';
import '../../../shared/widgets/app_dropdown_field.dart';
import '../../../shared/widgets/dirty_guard_mixin.dart';
import '../../../shared/widgets/form_save_mixin.dart';
import '../../../shared/widgets/money_text_form_field.dart';
import '../../../shared/widgets/readonly_message.dart';
import '../../project/widgets/project_picker_field.dart';
import '../../settings/providers/settings_providers.dart';
import '../providers/life_item_providers.dart';

class LifeItemEditPage extends ConsumerStatefulWidget {
  const LifeItemEditPage({super.key});

  @override
  ConsumerState<LifeItemEditPage> createState() => _LifeItemEditPageState();
}

class _LifeItemEditPageState extends ConsumerState<LifeItemEditPage>
    with FormSaveMixin<LifeItemEditPage>, DirtyGuardMixin<LifeItemEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _amountController = TextEditingController();
  final FormDraftStore _draftStore = FormDraftStore();
  static const String _draftEntityType = 'life_item';

  AmountType _amountType = AmountType.none;
  RepeatPeriod _repeatPeriod = RepeatPeriod.daily;
  int _customRepeatDays = 30;
  bool _hasRepeat = false;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 1));
  int? _selectedCategoryId;
  int? _projectId;
  int? _selectedTemplateId;
  String _titleInput = '';
  String _recommendTitle = '';
  Timer? _recommendDebounce;
  ReminderPreset _reminderPreset = ReminderPreset.none;
  DateTime? _customReminderTime;
  bool _isEdit = false;
  int? _editId;
  bool _loaded = false;
  bool _isHydratingForm = false;

  /// 终态（已完成/已取消/已归档）或已软删除的事项，编辑页整页只读，
  /// 状态只能通过详情页的「重新打开」按钮变更。
  bool _isReadonly = false;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_onTitleChanged);
    _descController.addListener(_onDescChanged);
    _amountController.addListener(_onAmountChanged);
  }

  void _onDescChanged() {
    if (_isHydratingForm || _isReadonly) return;
    markDirtyAndPersist(_collectDraft);
  }

  void _onAmountChanged() {
    if (_isHydratingForm || _isReadonly) return;
    markDirtyAndPersist(_collectDraft);
  }

  void _onTitleChanged() {
    if (_isHydratingForm || _isReadonly) return;
    final next = _titleController.text;
    if (next == _titleInput) return;
    setState(() => _titleInput = next);
    markDirtyAndPersist(_collectDraft);
    // Debounce the template recommendation query so we don't hit the DB on
    // every keystroke.
    _recommendDebounce?.cancel();
    _recommendDebounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _recommendTitle = next);
    });
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
        _isHydratingForm = true;
        _loadFromMap(extra);
        _isHydratingForm = false;
      }
    }
    if (!_isEdit) {
      final idStr = state.pathParameters['id'];
      if (idStr != null && idStr != 'new') {
        _isEdit = true;
        _editId = int.tryParse(idStr);
      }
    }
    // Also check extra for projectId when navigating from project detail
    if (!_isEdit && extra is Map && extra['projectId'] != null) {
      _projectId = extra['projectId'] as int?;
    }
    final draftType = _isEdit && _editId != null
        ? FormDraftStore.editDraftKey(_draftEntityType, _editId!)
        : FormDraftStore.newDraftKey(_draftEntityType);
    attachDraft(_draftStore, draftType, collect: _collectDraft, noun: '事项');
    if (_isEdit) {
      if (extra == null ||
          extra is! Map<String, dynamic> ||
          !extra.containsKey('id')) {
        _loadFromDatabase(offerDraftAfterLoad: true);
      } else {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => maybeRestoreDraft(_applyLifeItemDraft, noun: '事项'),
        );
      }
    } else {
      // New item: offer to restore a recent unsaved draft (draft takes
      // precedence over pre-filled values, same as the bill page).
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => maybeRestoreDraft(_applyLifeItemDraft, noun: '事项'),
      );
    }
    _loaded = true;
  }

  Future<void> _loadFromDatabase({bool offerDraftAfterLoad = false}) async {
    final id = _editId;
    if (id == null) return;
    final item = await ref.read(databaseProvider).lifeItemDao.getById(id);
    if (!mounted) return;
    final status = ItemStatus.fromString(item.status);
    _isHydratingForm = true;
    setState(() {
      _loadFromItem(item);
      _projectId = item.projectId;
      _isReadonly = status.isFinal || item.deletedAt != null;
    });
    _isHydratingForm = false;
    if (offerDraftAfterLoad && !_isReadonly) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => maybeRestoreDraft(_applyLifeItemDraft, noun: '事项'),
      );
    }
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
    _recommendDebounce?.cancel();
    _titleController.removeListener(_onTitleChanged);
    _descController.removeListener(_onDescChanged);
    _amountController.removeListener(_onAmountChanged);
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

  Map<String, dynamic> _collectDraft() {
    return {
      'title': _titleController.text,
      'description': _descController.text,
      'amount': _amountController.text,
      'amountType': _amountType.value,
      'dueDate': _dueDate.toIso8601String(),
      'categoryId': _selectedCategoryId,
      'projectId': _projectId,
      'reminderPreset': _reminderPreset.name,
      'customReminderTime': _customReminderTime?.toIso8601String(),
      'hasRepeat': _hasRepeat,
      'repeatPeriod': _repeatPeriod.value,
      'customRepeatDays': _customRepeatDays,
    };
  }

  void _applyLifeItemDraft(Map<String, dynamic> draft) {
    _isHydratingForm = true;
    setState(() {
      _titleController.text = draft['title'] as String? ?? '';
      _descController.text = draft['description'] as String? ?? '';
      _amountController.text = draft['amount'] as String? ?? '';
      _amountType = AmountType.fromString(
        draft['amountType'] as String? ?? 'none',
      );
      _dueDate =
          DateTime.tryParse(draft['dueDate'] as String? ?? '') ??
          DateTime.now().add(const Duration(days: 1));
      _selectedCategoryId = draft['categoryId'] as int?;
      _projectId = draft['projectId'] as int?;
      final presetName = draft['reminderPreset'] as String?;
      if (presetName != null) {
        _reminderPreset = ReminderPreset.values.firstWhere(
          (p) => p.name == presetName,
          orElse: () => ReminderPreset.none,
        );
      }
      _customReminderTime = DateTime.tryParse(
        draft['customReminderTime'] as String? ?? '',
      );
      _hasRepeat = draft['hasRepeat'] as bool? ?? false;
      final periodValue = draft['repeatPeriod'] as String?;
      if (periodValue != null) {
        _repeatPeriod = RepeatPeriod.fromString(periodValue);
      }
      _customRepeatDays =
          draft['customRepeatDays'] as int? ?? _customRepeatDays;
    });
    _isHydratingForm = false;
  }

  Future<void> _save() async {
    // 守卫：终态/已删除事项整页只读，禁止任何写入（防绕过 UI）。
    if (_isReadonly) {
      Toast.error(context, context.l.toast_itemCompletedReadonly);
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    final notifier = ref.read(lifeItemNotifierProvider.notifier);

    if (_isEdit && _editId != null) {
      final item = await ref
          .read(databaseProvider)
          .lifeItemDao
          .getById(_editId!);
      await runSave(() async {
        await notifier.update(
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
        markClean();
        await clearDraft();
        if (mounted) context.pop();
      });
    } else {
      await runSave(() async {
        await notifier.create({
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
        });
        markClean();
        await clearDraft();
        if (mounted) context.pop();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isReadonly) {
      return Scaffold(
        backgroundColor: AppColors.background(context),
        appBar: AppBar(title: Text(context.l.page_itemReadonly)),
        body: ReadonlyMessage(
          title: '事项已完结',
          message: '只读状态的事项不能编辑，可在详情中重新打开后再修改。',
          backLabel: '返回事项列表',
          onBack: () => context.go('/items'),
        ),
      );
    }
    return PopScope(
      canPop: !isDirty,
      onPopInvokedWithResult: (didPop, _) => onPopInvoked(didPop),
      child: Scaffold(
        backgroundColor: AppColors.background(context),
        appBar: AppBar(
          title: Text(
            _isReadonly
                ? '${_isEdit ? context.l.page_itemEdit : context.l.page_itemNew}（只读）'
                : (_isEdit ? context.l.page_itemEdit : context.l.page_itemNew),
          ),
          actions: [
            if (!_isEdit)
              IconButton(
                tooltip: '选择模板',
                onPressed: isSaving ? null : _openTemplatePicker,
                icon: const Icon(Icons.auto_awesome_motion_outlined),
              ),
            IconButton(
              tooltip: _isEdit ? '保存修改' : '创建事项',
              onPressed: isSaving ? null : _save,
              icon: isSaving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_rounded),
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
                          title: _recommendTitle,
                          selectedTemplateId: _selectedTemplateId,
                          onApply: (template) =>
                              _applyItemTemplate(template, replaceTitle: false),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Builder(
                        builder: (context) {
                          final cats =
                              ref
                                  .watch(categoriesByTypeProvider('item'))
                                  .valueOrNull ??
                              const <Category>[];
                          if (cats.isEmpty) return const SizedBox.shrink();
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
                                    label: categoryDisplayName(context, c),
                                  ),
                                )
                                .toList(),
                            onSelected: (v) => setState(() {
                              _selectedCategoryId = v;
                              markDirtyAndPersist(_collectDraft);
                            }),
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
                        onChanged: (v) => setState(() {
                          _projectId = v;
                          markDirtyAndPersist(_collectDraft);
                        }),
                      ),
                      const SizedBox(height: 16),
                      DateField(
                        key: const ValueKey('life-item-date-field'),
                        label: '日期',
                        initialValue: _dueDate,
                        onPick: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _dueDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                          );
                          if (picked != null && mounted) {
                            setState(() => _dueDate = picked);
                            markDirtyAndPersist(_collectDraft);
                          }
                          return picked;
                        },
                      ),
                      const SizedBox(height: 16),
                      AppDropdownField<ReminderPreset>(
                        label: '提醒',
                        value: _reminderPreset,
                        options: ReminderPreset.values
                            .map(
                              (p) =>
                                  AppDropdownOption(value: p, label: context.l.reminderPreset(p)),
                            )
                            .toList(),
                        onSelected: (v) => setState(() {
                          _reminderPreset = v ?? _reminderPreset;
                          markDirtyAndPersist(_collectDraft);
                        }),
                      ),
                      if (_reminderPreset == ReminderPreset.custom) ...[
                        const SizedBox(height: 16),
                        DateField(
                          label: '提醒日期',
                          initialValue: _customReminderTime ?? _dueDate,
                          onPick: _pickCustomReminderDate,
                        ),
                        const SizedBox(height: 16),
                        DateField(
                          label: '提醒时间',
                          initialValue: _customReminderTime ?? _dueDate,
                          formatter: _formatTime,
                          suffixIcon: Icons.access_time,
                          onPick: _pickCustomReminderTime,
                        ),
                      ],
                      const SizedBox(height: 16),
                      AppDropdownField<AmountType>(
                        label: '金额类型',
                        value: _amountType,
                        options: AmountType.values
                            .map(
                              (t) =>
                                  AppDropdownOption(value: t, label: context.l.amountType(t)),
                            )
                            .toList(),
                        onSelected: (v) => setState(() {
                          _amountType = v ?? _amountType;
                          markDirtyAndPersist(_collectDraft);
                        }),
                      ),
                      if (_amountType != AmountType.none) ...[
                        const SizedBox(height: 16),
                        MoneyTextFormField(controller: _amountController),
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
                        onChanged: (v) => setState(() {
                          _hasRepeat = v;
                          markDirtyAndPersist(_collectDraft);
                        }),
                      ),
                      if (_hasRepeat) ...[
                        const SizedBox(height: 8),
                        AppDropdownField<RepeatPeriod>(
                          label: '重复频率',
                          value: _repeatPeriod,
                          options: RepeatPeriod.values
                              .map(
                                (p) =>
                                    AppDropdownOption(value: p, label: context.l.repeatPeriod(p)),
                              )
                              .toList(),
                          onSelected: (v) => setState(() {
                            _repeatPeriod = v ?? _repeatPeriod;
                            markDirtyAndPersist(_collectDraft);
                          }),
                        ),
                        if (_repeatPeriod == RepeatPeriod.custom) ...[
                          const SizedBox(height: 16),
                          TextFormField(
                            initialValue: _customRepeatDays.toString(),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: '每 N 天',
                            ),
                            onChanged: (v) {
                              _customRepeatDays = int.tryParse(v) ?? 30;
                              markDirtyAndPersist(_collectDraft);
                            },
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
      ),
    );
  }

  DateTime? _resolvedReminderTime() {
    return _reminderPreset.remindTimeFor(
      _dueDate,
      customTime: _customReminderTime ?? _dueDate,
    );
  }

  Future<DateTime?> _pickCustomReminderDate() async {
    final current = _customReminderTime ?? _dueDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null || !mounted) return null;
    final merged = DateTime(
      picked.year,
      picked.month,
      picked.day,
      current.hour,
      current.minute,
    );
    setState(() => _customReminderTime = merged);
    markDirtyAndPersist(_collectDraft);
    return merged;
  }

  Future<DateTime?> _pickCustomReminderTime() async {
    final current = _customReminderTime ?? _dueDate;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (picked == null || !mounted) return null;
    final merged = DateTime(
      current.year,
      current.month,
      current.day,
      picked.hour,
      picked.minute,
    );
    setState(() => _customReminderTime = merged);
    markDirtyAndPersist(_collectDraft);
    return merged;
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
    final categories =
        ref.watch(categoriesByTypeProvider('item')).valueOrNull ??
        const <Category>[];
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
                      ? AppColors.primary(context)
                      : AppColors.textSecondary(context),
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
            color: selected ? AppColors.primary(context) : AppColors.textSecondary(context),
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
                    color: AppColors.textSecondary(context),
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
          color: selected ? AppColors.primaryLight : AppColors.surface(context),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? AppColors.primary(context)
                : AppColors.border(context),
          ),
        ),
        child: Padding(padding: const EdgeInsets.all(12), child: child),
      ),
    );
  }
}
