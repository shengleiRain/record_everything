import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/database/app_database.dart';
import '../../../data/repositories/category_repository.dart';
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
              if (rows.isEmpty) {
                return const _EmptyState();
              }
              return _CategoryGroup(
                rows: rows,
                onEdit: (category) =>
                    _showCategoryDialog(context, category: category),
                onDelete: _deleteCategory,
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
  }) async {
    final nameController = TextEditingController(text: category?.name ?? '');
    final iconController = TextEditingController(
      text: category?.icon ?? 'category',
    );
    final isEditing = category != null;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isEditing ? '编辑分类' : '新增分类'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '名称',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: iconController,
              decoration: const InputDecoration(
                labelText: '图标标识',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              final notifier = ref.read(categoryNotifierProvider.notifier);
              if (category == null) {
                await notifier.create(
                  name: name,
                  type: _selectedType,
                  icon: iconController.text,
                );
              } else {
                await notifier.update(
                  category.copyWith(
                    name: name,
                    icon: iconController.text.trim().isEmpty
                        ? 'category'
                        : iconController.text.trim(),
                  ),
                );
              }
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: Text(isEditing ? '保存' : '新增'),
          ),
        ],
      ),
    );

    nameController.dispose();
    iconController.dispose();
  }

  Future<void> _deleteCategory(Category category) async {
    try {
      await ref.read(categoryNotifierProvider.notifier).delete(category.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('已删除 ${category.name}')));
      }
    } on CategoryDeleteException catch (error) {
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
  });

  final List<Category> rows;
  final ValueChanged<Category> onEdit;
  final ValueChanged<Category> onDelete;

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
              onDelete: rows[index].isDefault
                  ? null
                  : () => onDelete(rows[index]),
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
  });

  final Category category;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
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
      title: Text(category.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(category.isDefault ? '默认分类' : category.icon),
      onTap: onEdit,
      trailing: IconButton(
        tooltip: category.isDefault ? '默认分类不能删除' : '删除',
        icon: Icon(
          category.isDefault ? Icons.lock_outline : Icons.delete_outline,
          color: category.isDefault ? AppColors.textHint : AppColors.overdue,
        ),
        onPressed: onDelete,
      ),
    );
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
