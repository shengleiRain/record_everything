import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/life_items_table.dart';

part 'life_item_dao.g.dart';

@DriftAccessor(tables: [LifeItems])
class LifeItemDao extends DatabaseAccessor<AppDatabase>
    with _$LifeItemDaoMixin {
  LifeItemDao(super.db);

  Future<List<LifeItem>> getAll() => select(lifeItems).get();

  Stream<List<LifeItem>> watchAll() => (select(
    lifeItems,
  )..orderBy([(t) => OrderingTerm.asc(t.dueTime)])).watch();

  Stream<List<LifeItem>> watchBetween(DateTime start, DateTime end) =>
      (select(lifeItems)
            ..where(
              (t) =>
                  t.dueTime.isBiggerOrEqualValue(start) &
                  t.dueTime.isSmallerThanValue(end),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.dueTime)]))
          .watch();

  Stream<List<LifeItem>> watchByStatus(String status) =>
      (select(lifeItems)
            ..where((t) => t.status.equals(status))
            ..orderBy([(t) => OrderingTerm.asc(t.dueTime)]))
          .watch();

  Future<LifeItem> getById(int id) =>
      (select(lifeItems)..where((t) => t.id.equals(id))).getSingle();

  Stream<LifeItem> watchById(int id) =>
      (select(lifeItems)..where((t) => t.id.equals(id))).watchSingle();

  Future<LifeItem> insertOne(LifeItemsCompanion entry) =>
      into(lifeItems).insertReturning(entry);

  Future updateOne(LifeItemsCompanion entry) =>
      update(lifeItems).replace(entry);

  Future deleteById(int id) =>
      (delete(lifeItems)..where((t) => t.id.equals(id))).go();

  Future<int> countByCategory(int categoryId) async {
    final countExpr = lifeItems.id.count();
    final query = selectOnly(lifeItems)
      ..addColumns([countExpr])
      ..where(lifeItems.categoryId.equals(categoryId));
    final row = await query.getSingle();
    return row.read(countExpr) ?? 0;
  }

  Stream<List<LifeItem>> watchTodayPending() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    return (select(lifeItems)
          ..where(
            (t) =>
                t.status.equals('pending') &
                t.dueTime.isBiggerOrEqualValue(start) &
                t.dueTime.isSmallerThanValue(end),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.dueTime)]))
        .watch();
  }

  Stream<List<LifeItem>> watchUpcoming(int days) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(Duration(days: days));
    return (select(lifeItems)
          ..where(
            (t) =>
                t.status.equals('pending') &
                t.dueTime.isBiggerOrEqualValue(start) &
                t.dueTime.isSmallerThanValue(end),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.dueTime)]))
        .watch();
  }

  Stream<List<LifeItem>> watchForecastExpenses(int days) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(Duration(days: days));
    return (select(lifeItems)
          ..where(
            (t) =>
                t.status.equals('pending') &
                t.amountType.equals('expense') &
                t.amount.isNotNull() &
                t.dueTime.isBiggerOrEqualValue(start) &
                t.dueTime.isSmallerThanValue(end),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.dueTime)]))
        .watch();
  }

  Stream<List<LifeItem>> watchOverdue() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return (select(lifeItems)
          ..where(
            (t) =>
                t.status.equals('pending') &
                t.dueTime.isSmallerThanValue(today),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.dueTime)]))
        .watch();
  }

  Future<int> countCompletedInMonth(DateTime month) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);
    final items =
        await (select(lifeItems)..where(
              (t) =>
                  t.status.equals('completed') &
                  t.updatedAt.isBiggerOrEqualValue(start) &
                  t.updatedAt.isSmallerThanValue(end),
            ))
            .get();
    return items.length;
  }

  Stream<int> watchCompletedCountInMonth(DateTime month) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);
    final countExpr = lifeItems.id.count();
    final query = selectOnly(lifeItems)
      ..addColumns([countExpr])
      ..where(
        lifeItems.status.equals('completed') &
            lifeItems.updatedAt.isBiggerOrEqualValue(start) &
            lifeItems.updatedAt.isSmallerThanValue(end),
      );
    return query.watchSingle().map((row) => row.read(countExpr) ?? 0);
  }
}
