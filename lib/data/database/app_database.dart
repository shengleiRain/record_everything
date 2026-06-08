import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import '../../core/constants/default_categories.dart';
import 'tables/categories_table.dart';
import 'tables/life_items_table.dart';
import 'tables/bill_records_table.dart';
import 'tables/accounts_table.dart';
import 'tables/monthly_budgets_table.dart';
import 'daos/life_item_dao.dart';
import 'daos/bill_record_dao.dart';
import 'daos/category_dao.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [Categories, LifeItems, BillRecords, Accounts, MonthlyBudgets],
  daos: [LifeItemDao, BillRecordDao, CategoryDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

  static QueryExecutor openConnection() {
    return driftDatabase(name: 'life_items.db');
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      await _insertDefaultCategories();
      await _insertDefaultAccount();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        await m.createTable(accounts);
        await m.createTable(monthlyBudgets);
        await m.addColumn(lifeItems, lifeItems.deletedAt);
        await m.addColumn(billRecords, billRecords.accountId);
        await m.addColumn(billRecords, billRecords.deletedAt);
        await _insertDefaultAccount();
      }
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

  Future<void> _insertDefaultAccount() async {
    final existing = await (select(
      accounts,
    )..where((t) => t.isDefault.equals(true))).get();
    if (existing.isNotEmpty) return;
    await into(accounts).insert(
      AccountsCompanion.insert(name: '默认账户', isDefault: const Value(true)),
    );
  }
}
