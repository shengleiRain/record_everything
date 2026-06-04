import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import '../../core/constants/default_categories.dart';
import 'tables/categories_table.dart';
import 'tables/life_items_table.dart';
import 'tables/bill_records_table.dart';
import 'daos/life_item_dao.dart';
import 'daos/bill_record_dao.dart';
import 'daos/category_dao.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [Categories, LifeItems, BillRecords],
  daos: [LifeItemDao, BillRecordDao, CategoryDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  static QueryExecutor openConnection() {
    return driftDatabase(name: 'life_items.db');
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      await _insertDefaultCategories();
    },
  );

  Future<void> _insertDefaultCategories() async {
    for (final c in DefaultCategories.income) {
      await into(categories).insert(
        CategoriesCompanion.insert(
          name: c['name']!,
          type: 'income',
          icon: Value(c['icon']!),
          isDefault: const Value(true),
        ),
      );
    }
    for (final c in DefaultCategories.expense) {
      await into(categories).insert(
        CategoriesCompanion.insert(
          name: c['name']!,
          type: 'expense',
          icon: Value(c['icon']!),
          isDefault: const Value(true),
        ),
      );
    }
    for (final c in DefaultCategories.item) {
      await into(categories).insert(
        CategoriesCompanion.insert(
          name: c['name']!,
          type: 'item',
          icon: Value(c['icon']!),
          isDefault: const Value(true),
        ),
      );
    }
  }
}
