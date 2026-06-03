import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/categories_table.dart';

part 'category_dao.g.dart';

@DriftAccessor(tables: [Categories])
class CategoryDao extends DatabaseAccessor<AppDatabase> with _$CategoryDaoMixin {
  CategoryDao(super.db);

  Future<List<Category>> getAll() => select(categories).get();

  Future<List<Category>> getByType(String type) =>
      (select(categories)..where((t) => t.type.equals(type))).get();

  Future<Category> insertOne(CategoriesCompanion entry) =>
      into(categories).insertReturning(entry);

  Stream<List<Category>> watchByType(String type) =>
      (select(categories)..where((t) => t.type.equals(type))).watch();
}
