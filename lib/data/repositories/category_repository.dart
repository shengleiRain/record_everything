import 'package:drift/drift.dart';

import '../database/app_database.dart';

enum CategoryDeleteReason { defaultCategory, inUse }

class CategoryDeleteException implements Exception {
  const CategoryDeleteException(this.reason);

  final CategoryDeleteReason reason;

  @override
  String toString() => switch (reason) {
    CategoryDeleteReason.defaultCategory => '默认分类不能删除',
    CategoryDeleteReason.inUse => '分类已被事项或账单使用',
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
      ),
    );
    return updated;
  }

  Future<void> deleteCategory(int id) async {
    final category = await _db.categoryDao.getById(id);
    if (category.isDefault) {
      throw const CategoryDeleteException(CategoryDeleteReason.defaultCategory);
    }

    final lifeItemCount = await _db.lifeItemDao.countByCategory(id);
    final billRecordCount = await _db.billRecordDao.countByCategory(id);
    if (lifeItemCount + billRecordCount > 0) {
      throw const CategoryDeleteException(CategoryDeleteReason.inUse);
    }

    await _db.categoryDao.deleteById(id);
  }
}
