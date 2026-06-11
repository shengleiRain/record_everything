import 'package:drift/drift.dart';

import '../database/app_database.dart';

enum CategoryDeleteReason { inUse }

enum CategoryMergeReason { sameCategory, typeMismatch }

class CategoryMergeException implements Exception {
  const CategoryMergeException(this.reason);

  final CategoryMergeReason reason;

  @override
  String toString() => switch (reason) {
    CategoryMergeReason.sameCategory => '不能合并到自身',
    CategoryMergeReason.typeMismatch => '只能合并同类型分类',
  };
}

class CategoryDeleteException implements Exception {
  const CategoryDeleteException(this.reason);

  final CategoryDeleteReason reason;

  @override
  String toString() => switch (reason) {
    CategoryDeleteReason.inUse => '分类已被事项、账单或项目使用',
  };
}

class CategoryRepository {
  final AppDatabase _db;
  CategoryRepository(this._db);

  Stream<List<Category>> watchAll() => _db.categoryDao.watchAll();
  Stream<List<Category>> watchByType(String type) =>
      _db.categoryDao.watchByType(type);
  Future<List<Category>> getAll() => _db.categoryDao.getAll();
  Future<List<Category>> getByType(String type) =>
      _db.categoryDao.getByType(type);
  Future<Map<int, int>> usageCountsByType(String type) =>
      _db.categoryDao.usageCountsByType(type);

  Future<Category> create({
    required String name,
    required String type,
    String icon = 'category',
  }) {
    return _db.categoryDao.insertOne(
      CategoriesCompanion.insert(
        name: name.trim(),
        type: type,
        icon: Value(icon.trim().isEmpty ? 'category' : icon.trim()),
      ),
    );
  }

  Future<Category> updateCategory(Category category) async {
    final updated = category.copyWith(
      name: category.name.trim(),
      icon: category.icon.trim().isEmpty ? 'category' : category.icon.trim(),
    );
    await _db.categoryDao.updateOne(
      CategoriesCompanion(
        id: Value(updated.id),
        name: Value(updated.name),
        type: Value(updated.type),
        icon: Value(updated.icon),
        isDefault: Value(updated.isDefault),
        isHidden: Value(updated.isHidden),
        isPinned: Value(updated.isPinned),
        lastUsedAt: Value(updated.lastUsedAt),
      ),
    );
    return updated;
  }

  Future<void> deleteCategory(int id) async {
    final category = await _db.categoryDao.getById(id);
    if (category.isDefault) {
      await _db.categoryDao.setHidden(id, true);
      return;
    }

    final lifeItemCount = await _db.lifeItemDao.countByCategory(id);
    final billRecordCount = await _db.billRecordDao.countByCategory(id);
    final projectCount = await _projectCountByCategory(id);
    if (lifeItemCount + billRecordCount + projectCount > 0) {
      throw const CategoryDeleteException(CategoryDeleteReason.inUse);
    }

    await _db.categoryDao.deleteById(id);
  }

  Future<void> setHidden(int id, bool hidden) async {
    await _db.categoryDao.setHidden(id, hidden);
  }

  Future<void> setPinned(int id, bool pinned) async {
    await _db.categoryDao.setPinned(id, pinned);
  }

  Future<void> mergeCategory({
    required int sourceId,
    required int targetId,
  }) async {
    if (sourceId == targetId) {
      throw const CategoryMergeException(CategoryMergeReason.sameCategory);
    }

    final source = await _db.categoryDao.getById(sourceId);
    final target = await _db.categoryDao.getById(targetId);
    if (source.type != target.type) {
      throw const CategoryMergeException(CategoryMergeReason.typeMismatch);
    }

    await _db.transaction(() async {
      await _db.customUpdate(
        'UPDATE life_items SET category_id = ?, updated_at = ? WHERE category_id = ?',
        variables: [
          Variable.withInt(targetId),
          Variable.withDateTime(DateTime.now()),
          Variable.withInt(sourceId),
        ],
        updates: {_db.lifeItems},
      );
      await _db.customUpdate(
        'UPDATE bill_records SET category_id = ?, updated_at = ? WHERE category_id = ?',
        variables: [
          Variable.withInt(targetId),
          Variable.withDateTime(DateTime.now()),
          Variable.withInt(sourceId),
        ],
        updates: {_db.billRecords},
      );
      await _db.customUpdate(
        'UPDATE projects SET category_id = ?, updated_at = ? WHERE category_id = ?',
        variables: [
          Variable.withInt(targetId),
          Variable.withDateTime(DateTime.now()),
          Variable.withInt(sourceId),
        ],
        updates: {_db.projects},
      );
      await _db.categoryDao.setHidden(sourceId, true);
      await _db.categoryDao.markUsed(targetId);
    });
  }

  Future<int> usageCount(int categoryId) =>
      _db.categoryDao.usageCountByCategory(categoryId);

  Future<int> _projectCountByCategory(int categoryId) async {
    final row = await _db
        .customSelect(
          'SELECT COUNT(*) AS cnt FROM projects WHERE category_id = ? AND deleted_at IS NULL',
          variables: [Variable.withInt(categoryId)],
        )
        .getSingle();
    return row.data['cnt'] as int? ?? 0;
  }
}
