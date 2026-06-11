import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/categories_table.dart';

part 'category_dao.g.dart';

@DriftAccessor(tables: [Categories])
class CategoryDao extends DatabaseAccessor<AppDatabase>
    with _$CategoryDaoMixin {
  CategoryDao(super.db);

  Future<List<Category>> getAll() => select(categories).get();

  Future<List<Category>> getByType(String type) async {
    final rows = await (select(
      categories,
    )..where((t) => t.type.equals(type) & t.isHidden.equals(false))).get();
    return _sortByUse(rows);
  }

  Future<Category> getById(int id) =>
      (select(categories)..where((t) => t.id.equals(id))).getSingle();

  Future<Category> insertOne(CategoriesCompanion entry) =>
      into(categories).insertReturning(entry);

  Future<void> updateOne(CategoriesCompanion entry) =>
      update(categories).replace(entry);

  Future<int> deleteById(int id) =>
      (delete(categories)..where((t) => t.id.equals(id))).go();

  Future<int> setHidden(int id, bool isHidden) =>
      (update(categories)..where((t) => t.id.equals(id))).write(
        CategoriesCompanion(isHidden: Value(isHidden)),
      );

  Future<int> setPinned(int id, bool isPinned) =>
      (update(categories)..where((t) => t.id.equals(id))).write(
        CategoriesCompanion(isPinned: Value(isPinned)),
      );

  Future<int> markUsed(int id) =>
      (update(categories)..where((t) => t.id.equals(id))).write(
        CategoriesCompanion(lastUsedAt: Value(DateTime.now())),
      );

  Stream<List<Category>> watchAll() => select(categories).watch();

  Stream<List<Category>> watchByType(String type) =>
      (select(categories)
            ..where((t) => t.type.equals(type) & t.isHidden.equals(false)))
          .watch()
          .asyncMap(_sortByUse);

  Future<int> usageCountByCategory(int categoryId) async {
    final row = await customSelect(
      '''
          SELECT
            (SELECT COUNT(*) FROM life_items
              WHERE category_id = ? AND deleted_at IS NULL) +
            (SELECT COUNT(*) FROM bill_records
              WHERE category_id = ? AND deleted_at IS NULL) +
            (SELECT COUNT(*) FROM projects
              WHERE category_id = ? AND deleted_at IS NULL) AS cnt
          ''',
      variables: [
        Variable.withInt(categoryId),
        Variable.withInt(categoryId),
        Variable.withInt(categoryId),
      ],
    ).getSingle();
    return row.data['cnt'] as int? ?? 0;
  }

  Future<Map<int, int>> usageCountsByType(String type) async {
    final rows = await customSelect(
      '''
          SELECT c.id AS id,
            (SELECT COUNT(*) FROM life_items
              WHERE category_id = c.id AND deleted_at IS NULL) +
            (SELECT COUNT(*) FROM bill_records
              WHERE category_id = c.id AND deleted_at IS NULL) +
            (SELECT COUNT(*) FROM projects
              WHERE category_id = c.id AND deleted_at IS NULL) AS cnt
          FROM categories c
          WHERE c.type = ?
          ''',
      variables: [Variable.withString(type)],
    ).get();
    return {
      for (final row in rows)
        row.data['id'] as int: row.data['cnt'] as int? ?? 0,
    };
  }

  Future<List<Category>> _sortByUse(List<Category> rows) async {
    final usage = {
      for (final category in rows)
        category.id: await usageCountByCategory(category.id),
    };
    final sorted = [...rows];
    sorted.sort((a, b) {
      final pinned = _compareBoolDesc(a.isPinned, b.isPinned);
      if (pinned != 0) return pinned;

      final aLast = a.lastUsedAt;
      final bLast = b.lastUsedAt;
      if (aLast != null || bLast != null) {
        if (aLast == null) return 1;
        if (bLast == null) return -1;
        final recent = bLast.compareTo(aLast);
        if (recent != 0) return recent;
      }

      final byUsage = (usage[b.id] ?? 0).compareTo(usage[a.id] ?? 0);
      if (byUsage != 0) return byUsage;

      final defaults = _compareBoolDesc(a.isDefault, b.isDefault);
      if (defaults != 0) return defaults;

      return a.name.compareTo(b.name);
    });
    return sorted;
  }

  int _compareBoolDesc(bool a, bool b) {
    if (a == b) return 0;
    return a ? -1 : 1;
  }
}
