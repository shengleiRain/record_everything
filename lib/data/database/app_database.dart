import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import '../../core/constants/default_categories.dart';
import 'tables/categories_table.dart';
import 'tables/life_items_table.dart';
import 'tables/bill_records_table.dart';
import 'tables/accounts_table.dart';
import 'tables/monthly_budgets_table.dart';
import 'tables/projects_table.dart';
import 'tables/project_events_table.dart';
import 'daos/life_item_dao.dart';
import 'daos/bill_record_dao.dart';
import 'daos/category_dao.dart';
import 'daos/project_dao.dart';
import 'daos/project_event_dao.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Categories,
    LifeItems,
    BillRecords,
    Accounts,
    MonthlyBudgets,
    Projects,
    ProjectEvents,
  ],
  daos: [LifeItemDao, BillRecordDao, CategoryDao, ProjectDao, ProjectEventDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 3;

  static QueryExecutor openConnection() {
    return driftDatabase(name: 'life_items.db');
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      await _insertDefaultCategories();
      await _insertDefaultAccount();
      await _insertDefaultProjectCategories();
      await _createProjectIndexes();
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
      if (from < 3) {
        await m.createTable(projects);
        await m.createTable(projectEvents);
        await m.addColumn(lifeItems, lifeItems.projectId);
        await m.addColumn(billRecords, billRecords.projectId);
        await _insertDefaultProjectCategories();
        await _createProjectIndexes();
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

  Future<void> _insertDefaultProjectCategories() async {
    for (final c in DefaultCategories.project) {
      await into(categories).insert(
        CategoriesCompanion.insert(
          name: c['name']!,
          type: 'project',
          icon: Value(c['icon']!),
          isDefault: const Value(true),
        ),
      );
    }
  }

  Future<void> _createProjectIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_projects_category_deleted ON projects(category_id, deleted_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_projects_start_deleted ON projects(start_date, deleted_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_projects_status_deleted ON projects(project_status, deleted_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_life_items_project_due ON life_items(project_id, due_time, deleted_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_bill_records_project_time ON bill_records(project_id, bill_time, deleted_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_project_events_project_time ON project_events(project_id, event_time)',
    );
  }
}
