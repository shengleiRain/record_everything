import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/database/app_database.dart';
import '../../../shared/widgets/app_dropdown_field.dart';
import '../providers/settings_providers.dart';

class CategoryManagementPage extends ConsumerStatefulWidget {
  const CategoryManagementPage({super.key});

  @override
  ConsumerState<CategoryManagementPage> createState() =>
      _CategoryManagementPageState();
}

class _CategoryManagementPageState
    extends ConsumerState<CategoryManagementPage> {
  String _selectedType = 'expense';

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('分类管理')),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('add-category'),
        onPressed: () => _showCategoryDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('新增分类'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'expense', label: Text('支出')),
              ButtonSegment(value: 'income', label: Text('收入')),
              ButtonSegment(value: 'item', label: Text('事项')),
              ButtonSegment(value: 'project', label: Text('项目')),
            ],
            selected: {_selectedType},
            onSelectionChanged: (values) {
              setState(() => _selectedType = values.single);
            },
          ),
          const SizedBox(height: 12),
          categoriesAsync.when(
            data: (categories) {
              final rows = categories
                  .where((category) => category.type == _selectedType)
                  .toList();
              rows.sort(_compareCategories);
              if (rows.isEmpty) {
                return const _EmptyState();
              }
              return _CategoryGroup(
                rows: rows,
                onEdit: (category) =>
                    _showCategoryDialog(context, category: category),
                onDelete: _deleteCategory,
                onToggleHidden: _toggleHidden,
                onTogglePinned: _togglePinned,
                onMerge: (category) =>
                    _showMergeDialog(context, category, rows),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Text('分类加载失败: $error'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCategoryDialog(
    BuildContext context, {
    Category? category,
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => _CategoryEditDialog(
        category: category,
        type: _selectedType,
      ),
    );
  }

  int _compareCategories(Category a, Category b) {
    if (a.isHidden != b.isHidden) return a.isHidden ? 1 : -1;
    if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
    if (a.isDefault != b.isDefault) return a.isDefault ? -1 : 1;
    return a.name.compareTo(b.name);
  }

  Future<void> _toggleHidden(Category category) async {
    await ref
        .read(categoryNotifierProvider.notifier)
        .setHidden(category.id, !category.isHidden);
  }

  Future<void> _togglePinned(Category category) async {
    await ref
        .read(categoryNotifierProvider.notifier)
        .setPinned(category.id, !category.isPinned);
  }

  Future<void> _showMergeDialog(
    BuildContext context,
    Category category,
    List<Category> rows,
  ) async {
    int? targetId = rows
        .where((row) => row.id != category.id && !row.isHidden)
        .map((row) => row.id)
        .firstOrNull;
    final targets = rows
        .where((row) => row.id != category.id && !row.isHidden)
        .toList();
    if (targets.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('没有可合并的目标分类')));
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('合并“${category.name}”'),
          content: AppDropdownField<int>(
            label: '合并到',
            value: targetId,
            options: targets
                .map(
                  (target) =>
                      AppDropdownOption(value: target.id, label: target.name),
                )
                .toList(),
            onSelected: (value) => setDialogState(() => targetId = value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: targetId == null
                  ? null
                  : () async {
                      await ref
                          .read(categoryNotifierProvider.notifier)
                          .merge(sourceId: category.id, targetId: targetId!);
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                      }
                    },
              child: const Text('合并'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteCategory(Category category) async {
    try {
      await ref.read(categoryNotifierProvider.notifier).delete(category.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('已处理 ${category.name}')));
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }
}

class _CategoryGroup extends StatelessWidget {
  const _CategoryGroup({
    required this.rows,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleHidden,
    required this.onTogglePinned,
    required this.onMerge,
  });

  final List<Category> rows;
  final ValueChanged<Category> onEdit;
  final ValueChanged<Category> onDelete;
  final ValueChanged<Category> onToggleHidden;
  final ValueChanged<Category> onTogglePinned;
  final ValueChanged<Category> onMerge;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black.withValues(alpha: 0.07)),
      ),
      child: Column(
        children: [
          for (var index = 0; index < rows.length; index++) ...[
            _CategoryRow(
              category: rows[index],
              onEdit: () => onEdit(rows[index]),
              onDelete: () => onDelete(rows[index]),
              onToggleHidden: () => onToggleHidden(rows[index]),
              onTogglePinned: () => onTogglePinned(rows[index]),
              onMerge: rows[index].isDefault
                  ? null
                  : () => onMerge(rows[index]),
            ),
            if (index != rows.length - 1)
              Divider(
                height: 1,
                indent: 56,
                color: Colors.black.withValues(alpha: 0.06),
              ),
          ],
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleHidden,
    required this.onTogglePinned,
    required this.onMerge,
  });

  final Category category;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleHidden;
  final VoidCallback onTogglePinned;
  final VoidCallback? onMerge;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: category.isHidden ? 0.58 : 1,
      child: ListTile(
        minLeadingWidth: 28,
        leading: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primaryLight.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            category.name.characters.first,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                category.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (category.isPinned) const Icon(Icons.push_pin, size: 16),
          ],
        ),
        subtitle: _CategoryUsageLabel(category: category),
        onTap: category.isDefault ? null : onEdit,
        trailing: PopupMenuButton<String>(
          onSelected: (action) {
            switch (action) {
              case 'edit':
                onEdit();
                break;
              case 'pin':
                onTogglePinned();
                break;
              case 'hidden':
                onToggleHidden();
                break;
              case 'merge':
                onMerge?.call();
                break;
              case 'delete':
                onDelete();
                break;
            }
          },
          itemBuilder: (_) => [
            if (!category.isDefault)
              const PopupMenuItem(value: 'edit', child: Text('重命名')),
            PopupMenuItem(
              value: 'pin',
              child: Text(category.isPinned ? '取消常用置顶' : '常用置顶'),
            ),
            PopupMenuItem(
              value: 'hidden',
              child: Text(category.isHidden ? '恢复显示' : '隐藏'),
            ),
            if (!category.isDefault)
              const PopupMenuItem(value: 'merge', child: Text('合并到...')),
            if (!category.isDefault)
              const PopupMenuItem(value: 'delete', child: Text('删除')),
          ],
        ),
      ),
    );
  }
}

class _CategoryUsageLabel extends StatelessWidget {
  const _CategoryUsageLabel({required this.category});

  final Category category;

  @override
  Widget build(BuildContext context) {
    final parts = [
      if (category.isDefault) '默认分类' else '自定义分类',
      if (category.isHidden) '已隐藏',
      if (category.isPinned) '常用置顶',
    ];
    return Text(parts.join(' · '));
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black.withValues(alpha: 0.07)),
      ),
      child: Text(
        '暂无分类',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}

/// 分类新增/编辑弹窗。
///
/// 控制器由 [State] 管理，生命周期与弹窗 widget 一致：只在弹窗关闭动画结束、
/// widget 真正被移除时才 dispose，避免退出动画期间 TextField 访问已 dispose
/// 的控制器（"A TextEditingController was used after being disposed"），
/// 同时修复了原先本地控制器从不被 dispose 的内存泄漏。
class _CategoryEditDialog extends ConsumerStatefulWidget {
  const _CategoryEditDialog({this.category, required this.type});

  final Category? category;
  final String type;

  @override
  ConsumerState<_CategoryEditDialog> createState() => _CategoryEditDialogState();
}

class _CategoryEditDialogState extends ConsumerState<_CategoryEditDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _iconController;
  late final bool _isEditing;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.category != null;
    _nameController = TextEditingController(text: widget.category?.name ?? '');
    _iconController = TextEditingController(
      text: widget.category?.icon ?? 'category',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _iconController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    final notifier = ref.read(categoryNotifierProvider.notifier);
    final category = widget.category;
    try {
      if (category == null) {
        await notifier.create(
          name: name,
          type: widget.type,
          icon: _iconController.text,
        );
      } else {
        await notifier.update(
          category.copyWith(
            name: name,
            icon: _iconController.text.trim().isEmpty
                ? 'category'
                : _iconController.text.trim(),
          ),
        );
      }
      if (mounted) Navigator.of(context).maybePop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? '编辑分类' : '新增分类'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '名称',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _iconController,
            decoration: const InputDecoration(
              labelText: '图标标识',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).maybePop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_isEditing ? '保存' : '新增'),
        ),
      ],
    );
  }
}
