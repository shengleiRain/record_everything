import '../database/app_database.dart';

class CategoryRepository {
  final AppDatabase _db;
  CategoryRepository(this._db);

  Stream<List<Category>> watchByType(String type) =>
      _db.categoryDao.watchByType(type);
  Future<List<Category>> getAll() => _db.categoryDao.getAll();
  Future<List<Category>> getByType(String type) =>
      _db.categoryDao.getByType(type);
}
