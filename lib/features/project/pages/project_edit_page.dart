import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' show Value;
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/database/database_provider.dart';
import '../../../domain/enums/project_status.dart';
import '../../../shared/widgets/app_dropdown_field.dart';
import '../providers/project_providers.dart';

class ProjectEditPage extends ConsumerStatefulWidget {
  const ProjectEditPage({super.key});

  @override
  ConsumerState<ProjectEditPage> createState() => _ProjectEditPageState();
}

class _ProjectEditPageState extends ConsumerState<ProjectEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _participantController = TextEditingController();
  final _totalAmountController = TextEditingController();
  final _noteController = TextEditingController();

  ProjectStatus _status = ProjectStatus.planned;
  int? _selectedCategoryId;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isEdit = false;
  int? _editId;
  bool _loaded = false;

  // Photography template fields
  bool _usePhotoTemplate = false;
  final _shootTypeController = TextEditingController();
  final _depositAmountController = TextEditingController();
  DateTime? _depositDueDate;
  final _finalPaymentAmountController = TextEditingController();
  DateTime? _finalPaymentDueDate;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    final state = GoRouterState.of(context);
    final idStr = state.pathParameters['id'];
    if (idStr != null && idStr != 'new') {
      _isEdit = true;
      _editId = int.tryParse(idStr);
      _loadFromDatabase();
    }
    // Check if template is requested via extra
    final extra = state.extra;
    if (extra is Map && extra['template'] == 'photography') {
      _usePhotoTemplate = true;
    }
    _loaded = true;
  }

  Future<void> _loadFromDatabase() async {
    final id = _editId;
    if (id == null) return;
    final project = await ref.read(databaseProvider).projectDao.getById(id);
    if (!mounted) return;
    setState(() {
      _titleController.text = project.title;
      _participantController.text = project.participant ?? '';
      _status = ProjectStatus.fromString(project.projectStatus);
      _selectedCategoryId = project.categoryId;
      _startDate = project.startDate;
      _endDate = project.endDate;
      if (project.totalAmount != null) {
        _totalAmountController.text = MoneyFormatter.formatInt(
          project.totalAmount!,
        );
      }
      _noteController.text = project.note ?? '';
      if (project.templateKey == 'photography_order') {
        _usePhotoTemplate = true;
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _participantController.dispose();
    _totalAmountController.dispose();
    _noteController.dispose();
    _shootTypeController.dispose();
    _depositAmountController.dispose();
    _finalPaymentAmountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final notifier = ref.read(projectNotifierProvider.notifier);

    final totalAmount = _totalAmountController.text.isNotEmpty
        ? MoneyFormatter.parse(_totalAmountController.text)
        : null;
    int? createdProjectId;

    if (_isEdit && _editId != null) {
      final project = await ref
          .read(databaseProvider)
          .projectDao
          .getById(_editId!);
      await notifier.update(
        project.copyWith(
          title: _titleController.text.trim(),
          categoryId: Value(_selectedCategoryId),
          participant: Value(
            _participantController.text.trim().isEmpty
                ? null
                : _participantController.text.trim(),
          ),
          projectStatus: _status.value,
          startDate: Value(_startDate),
          endDate: Value(_endDate),
          totalAmount: Value(totalAmount),
          note: Value(
            _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
          ),
          updatedAt: DateTime.now(),
        ),
      );
    } else if (_usePhotoTemplate) {
      final project = await notifier.createPhotography(
        title: _titleController.text.trim(),
        participant: _participantController.text.trim(),
        shootDate: _startDate ?? DateTime.now().add(const Duration(days: 7)),
        totalAmount: totalAmount ?? 0,
        shootType: _shootTypeController.text.trim().isEmpty
            ? null
            : _shootTypeController.text.trim(),
        depositAmount: _depositAmountController.text.isNotEmpty
            ? MoneyFormatter.parse(_depositAmountController.text)
            : null,
        depositDueDate: _depositDueDate,
        finalPaymentAmount: _finalPaymentAmountController.text.isNotEmpty
            ? MoneyFormatter.parse(_finalPaymentAmountController.text)
            : null,
        finalPaymentDueDate: _finalPaymentDueDate,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        projectCategoryId: _selectedCategoryId,
      );
      createdProjectId = project.id;
    } else {
      final project = await notifier.create(
        title: _titleController.text.trim(),
        categoryId: _selectedCategoryId,
        participant: _participantController.text.trim().isEmpty
            ? null
            : _participantController.text.trim(),
        projectStatus: _status.value,
        startDate: _startDate,
        endDate: _endDate,
        totalAmount: totalAmount,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );
      createdProjectId = project.id;
    }

    if (!mounted) return;
    if (_isEdit) {
      context.pop();
    } else if (createdProjectId != null) {
      context.go('/projects/$createdProjectId');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(_isEdit ? '编辑项目' : '新建项目')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SectionCard(
              title: '基本信息',
              child: Column(
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: '项目标题 *'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? '请输入标题' : null,
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder(
                    future: ref
                        .read(databaseProvider)
                        .categoryDao
                        .getByType('project'),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox.shrink();
                      final cats = snapshot.data!;
                      final validValue =
                          cats.any((c) => c.id == _selectedCategoryId)
                          ? _selectedCategoryId
                          : null;
                      return AppDropdownField<int>(
                        label: '项目类型',
                        value: validValue,
                        options: cats
                            .map(
                              (c) =>
                                  AppDropdownOption(value: c.id, label: c.name),
                            )
                            .toList(),
                        onSelected: (v) {
                          final selectedCategory = cats
                              .where((category) => category.id == v)
                              .firstOrNull;
                          setState(() {
                            _selectedCategoryId = v;
                            if (!_isEdit &&
                                (selectedCategory?.name.contains('摄影') ??
                                    false)) {
                              _usePhotoTemplate = true;
                            }
                          });
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  if (!_isEdit) ...[
                    SwitchListTile(
                      key: const ValueKey('project-photography-template'),
                      value: _usePhotoTemplate,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('摄影接单模板'),
                      subtitle: const Text('生成定金、尾款、拍摄日和交付节点'),
                      onChanged: (value) =>
                          setState(() => _usePhotoTemplate = value),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _participantController,
                    decoration: const InputDecoration(labelText: '客户/参与人'),
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
                    label: '关键日期',
                    value: _startDate != null
                        ? DateFormatter.formatDate(_startDate!)
                        : '未设置',
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _startDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null && mounted) {
                        setState(() => _startDate = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _DateField(
                    label: '结束/交付日期（可选）',
                    value: _endDate != null
                        ? DateFormatter.formatDate(_endDate!)
                        : '未设置',
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate:
                            _endDate ??
                            _startDate ??
                            DateTime.now().add(const Duration(days: 30)),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null && mounted) {
                        setState(() => _endDate = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _totalAmountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: '约定总额',
                      prefixText: '¥',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: '状态与备注',
              child: Column(
                children: [
                  AppDropdownField<ProjectStatus>(
                    label: '项目状态',
                    value: _status,
                    options: ProjectStatus.values
                        .map((s) => AppDropdownOption(value: s, label: s.label))
                        .toList(),
                    onSelected: (v) => setState(() => _status = v ?? _status),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _noteController,
                    decoration: const InputDecoration(labelText: '备注'),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            if (!_isEdit && _usePhotoTemplate) ...[
              const SizedBox(height: 16),
              _SectionCard(
                title: '摄影接单模板',
                child: Column(
                  children: [
                    TextFormField(
                      controller: _shootTypeController,
                      decoration: const InputDecoration(
                        labelText: '拍摄类型',
                        hintText: '如：婚礼/写真/商业',
                      ),
                    ),
                    const SizedBox(height: 16),
                    _DateField(
                      label: '拍摄日期',
                      value: _startDate != null
                          ? DateFormatter.formatDate(_startDate!)
                          : '请在上方设置关键日期',
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate:
                              _startDate ??
                              DateTime.now().add(const Duration(days: 7)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null && mounted) {
                          setState(() => _startDate = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _depositAmountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: '定金金额',
                        prefixText: '¥',
                      ),
                    ),
                    const SizedBox(height: 16),
                    _DateField(
                      label: '定金应收日期',
                      value: _depositDueDate != null
                          ? DateFormatter.formatDate(_depositDueDate!)
                          : '未设置（默认拍摄前7天）',
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate:
                              _depositDueDate ??
                              (_startDate != null
                                  ? _startDate!.subtract(
                                      const Duration(days: 7),
                                    )
                                  : DateTime.now()),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null && mounted) {
                          setState(() => _depositDueDate = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _finalPaymentAmountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: '尾款金额',
                        prefixText: '¥',
                      ),
                    ),
                    const SizedBox(height: 16),
                    _DateField(
                      label: '尾款应收日期',
                      value: _finalPaymentDueDate != null
                          ? DateFormatter.formatDate(_finalPaymentDueDate!)
                          : '未设置（默认拍摄后14天）',
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate:
                              _finalPaymentDueDate ??
                              (_startDate != null
                                  ? _startDate!.add(const Duration(days: 14))
                                  : DateTime.now().add(
                                      const Duration(days: 14),
                                    )),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null && mounted) {
                          setState(() => _finalPaymentDueDate = picked);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _save,
              child: Text(_isEdit ? '保存修改' : '创建项目'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
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
