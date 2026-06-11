import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/bill_records_table.dart';

part 'bill_record_dao.g.dart';

@DriftAccessor(tables: [BillRecords])
class BillRecordDao extends DatabaseAccessor<AppDatabase>
    with _$BillRecordDaoMixin {
  BillRecordDao(super.db);

  Future<List<BillRecord>> getAll() =>
      (select(billRecords)
            ..where((t) => t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm.desc(t.billTime)]))
          .get();

  Future<List<BillRecord>> getDeleted() =>
      (select(billRecords)..where((t) => t.deletedAt.isNotNull())).get();

  Stream<List<BillRecord>> watchAll() =>
      (select(billRecords)
            ..where((t) => t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm.desc(t.billTime)]))
          .watch();

  Stream<List<BillRecord>> watchBetween(DateTime start, DateTime end) =>
      (select(billRecords)
            ..where(
              (t) =>
                  t.billTime.isBiggerOrEqualValue(start) &
                  t.billTime.isSmallerThanValue(end) &
                  t.deletedAt.isNull(),
            )
            ..orderBy([(t) => OrderingTerm.desc(t.billTime)]))
          .watch();

  Future<BillRecord> getById(int id) =>
      (select(billRecords)..where((t) => t.id.equals(id))).getSingle();

  Future<BillRecord> insertOne(BillRecordsCompanion entry) =>
      into(billRecords).insertReturning(entry);

  Future updateOne(BillRecordsCompanion entry) =>
      update(billRecords).replace(entry);

  Future deleteById(int id) =>
      (delete(billRecords)..where((t) => t.id.equals(id))).go();

  Future<int> softDeleteById(int id) =>
      (update(billRecords)..where((t) => t.id.equals(id))).write(
        BillRecordsCompanion(deletedAt: Value(DateTime.now())),
      );

  Future<int> restoreById(int id) =>
      (update(billRecords)..where((t) => t.id.equals(id))).write(
        const BillRecordsCompanion(deletedAt: Value(null)),
      );

  Future<int> countByCategory(int categoryId) async {
    final countExpr = billRecords.id.count();
    final query = selectOnly(billRecords)
      ..addColumns([countExpr])
      ..where(billRecords.categoryId.equals(categoryId));
    final row = await query.getSingle();
    return row.read(countExpr) ?? 0;
  }

  Stream<List<BillRecord>> watchByMonth(DateTime month) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);
    return (select(billRecords)
          ..where(
            (t) =>
                t.billTime.isBiggerOrEqualValue(start) &
                t.billTime.isSmallerThanValue(end) &
                t.deletedAt.isNull(),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.billTime)]))
        .watch();
  }

  Stream<List<BillRecord>> watchByMonthAndType(
    DateTime month,
    String amountType,
  ) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);
    return (select(billRecords)
          ..where(
            (t) =>
                t.billTime.isBiggerOrEqualValue(start) &
                t.billTime.isSmallerThanValue(end) &
                t.deletedAt.isNull() &
                t.amountType.equals(amountType),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.billTime)]))
        .watch();
  }

  Future<int> sumForMonth(DateTime month, String amountType) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);
    final sumExpr = billRecords.amount.sum();
    final query = selectOnly(billRecords)
      ..addColumns([sumExpr])
      ..where(
        billRecords.billTime.isBiggerOrEqualValue(start) &
            billRecords.billTime.isSmallerThanValue(end) &
            billRecords.deletedAt.isNull() &
            billRecords.amountType.equals(amountType),
      );
    final row = await query.getSingle();
    return row.read(sumExpr) ?? 0;
  }

  Stream<int> watchSumForMonth(DateTime month, String amountType) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);
    final sumExpr = billRecords.amount.sum();
    final query = selectOnly(billRecords)
      ..addColumns([sumExpr])
      ..where(
        billRecords.billTime.isBiggerOrEqualValue(start) &
            billRecords.billTime.isSmallerThanValue(end) &
            billRecords.deletedAt.isNull() &
            billRecords.amountType.equals(amountType),
      );
    return query.watchSingle().map((row) => row.read(sumExpr) ?? 0);
  }

  Stream<List<BillRecord>> watchByProjectId(int projectId) =>
      (select(billRecords)
            ..where((t) => t.projectId.equals(projectId) & t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm.desc(t.billTime)]))
          .watch();

  Stream<int> watchSumByProjectId(int projectId, String amountType) {
    final sumExpr = billRecords.amount.sum();
    final query = selectOnly(billRecords)
      ..addColumns([sumExpr])
      ..where(
        billRecords.projectId.equals(projectId) &
            billRecords.deletedAt.isNull() &
            billRecords.amountType.equals(amountType),
      );
    return query.watchSingle().map((row) => row.read(sumExpr) ?? 0);
  }

  Stream<List<MonthlySumRow>> watchMonthlySumsForRange(
    DateTime start,
    DateTime end,
    String amountType,
  ) {
    final yearExpr = billRecords.billTime.year;
    final monthExpr = billRecords.billTime.month;
    final sumExpr = billRecords.amount.sum();
    final query = selectOnly(billRecords)
      ..addColumns([yearExpr, monthExpr, sumExpr])
      ..where(
        billRecords.billTime.isBiggerOrEqualValue(start) &
            billRecords.billTime.isSmallerThanValue(end) &
            billRecords.deletedAt.isNull() &
            billRecords.amountType.equals(amountType),
      )
      ..groupBy([yearExpr, monthExpr])
      ..orderBy([OrderingTerm.asc(yearExpr), OrderingTerm.asc(monthExpr)]);
    return query.watch().map(
      (rows) => rows
          .map(
            (r) => MonthlySumRow(
              yearMonth:
                  (r.read(yearExpr) ?? 0) * 100 + (r.read(monthExpr) ?? 0),
              sum: r.read(sumExpr) ?? 0,
            ),
          )
          .toList(),
    );
  }

  Stream<List<CategoryBreakdownRow>> watchCategoryBreakdown(
    DateTime month,
    String amountType,
  ) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);
    final catIdExpr = billRecords.categoryId;
    final sumExpr = billRecords.amount.sum();
    final query = selectOnly(billRecords)
      ..addColumns([catIdExpr, sumExpr])
      ..where(
        billRecords.billTime.isBiggerOrEqualValue(start) &
            billRecords.billTime.isSmallerThanValue(end) &
            billRecords.deletedAt.isNull() &
            billRecords.amountType.equals(amountType),
      )
      ..groupBy([catIdExpr])
      ..orderBy([OrderingTerm.desc(sumExpr)]);
    return query.watch().map(
      (rows) => rows
          .map(
            (r) => CategoryBreakdownRow(
              categoryId: r.read(catIdExpr),
              sum: r.read(sumExpr) ?? 0,
            ),
          )
          .toList(),
    );
  }

  Stream<int> watchProjectIncomeForMonth(int projectId, DateTime month) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);
    final sumExpr = billRecords.amount.sum();
    final query = selectOnly(billRecords)
      ..addColumns([sumExpr])
      ..where(
        billRecords.projectId.equals(projectId) &
            billRecords.billTime.isBiggerOrEqualValue(start) &
            billRecords.billTime.isSmallerThanValue(end) &
            billRecords.deletedAt.isNull() &
            billRecords.amountType.equals('income'),
      );
    return query.watchSingle().map((row) => row.read(sumExpr) ?? 0);
  }

  Stream<int> watchAllProjectIncomeForMonth(DateTime month) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);
    final sumExpr = billRecords.amount.sum();
    final query = selectOnly(billRecords)
      ..addColumns([sumExpr])
      ..where(
        billRecords.projectId.isNotNull() &
            billRecords.billTime.isBiggerOrEqualValue(start) &
            billRecords.billTime.isSmallerThanValue(end) &
            billRecords.deletedAt.isNull() &
            billRecords.amountType.equals('income'),
      );
    return query.watchSingle().map((row) => row.read(sumExpr) ?? 0);
  }
}

class MonthlySumRow {
  final int yearMonth;
  final int sum;
  const MonthlySumRow({required this.yearMonth, required this.sum});
}

class CategoryBreakdownRow {
  final int? categoryId;
  final int sum;
  const CategoryBreakdownRow({this.categoryId, required this.sum});
}
