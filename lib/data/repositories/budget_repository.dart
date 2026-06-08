import 'package:drift/drift.dart';

import '../database/app_database.dart';

class BudgetRepository {
  const BudgetRepository(this._db);

  final AppDatabase _db;

  Future<int> getMonthlyBudget(DateTime month) async {
    final monthStart = DateTime(month.year, month.month, 1);
    final row = await (_db.select(
      _db.monthlyBudgets,
    )..where((t) => t.monthStart.equals(monthStart))).getSingleOrNull();
    return row?.amount ?? 0;
  }

  Stream<int> watchMonthlyBudget(DateTime month) {
    final monthStart = DateTime(month.year, month.month, 1);
    return (_db.select(_db.monthlyBudgets)
          ..where((t) => t.monthStart.equals(monthStart)))
        .watchSingleOrNull()
        .map((row) => row?.amount ?? 0);
  }

  Future<void> setMonthlyBudget(DateTime month, int amount) async {
    final monthStart = DateTime(month.year, month.month, 1);
    await _db
        .into(_db.monthlyBudgets)
        .insertOnConflictUpdate(
          MonthlyBudgetsCompanion.insert(
            monthStart: monthStart,
            amount: amount,
            updatedAt: Value(DateTime.now()),
          ),
        );
  }
}
