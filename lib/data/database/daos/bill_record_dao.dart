import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/bill_records_table.dart';

part 'bill_record_dao.g.dart';

@DriftAccessor(tables: [BillRecords])
class BillRecordDao extends DatabaseAccessor<AppDatabase>
    with _$BillRecordDaoMixin {
  BillRecordDao(super.db);

  Future<List<BillRecord>> getAll() => (select(
    billRecords,
  )..orderBy([(t) => OrderingTerm.desc(t.billTime)])).get();

  Stream<List<BillRecord>> watchAll() => (select(
    billRecords,
  )..orderBy([(t) => OrderingTerm.desc(t.billTime)])).watch();

  Future<BillRecord> getById(int id) =>
      (select(billRecords)..where((t) => t.id.equals(id))).getSingle();

  Future<BillRecord> insertOne(BillRecordsCompanion entry) =>
      into(billRecords).insertReturning(entry);

  Future updateOne(BillRecordsCompanion entry) =>
      update(billRecords).replace(entry);

  Future deleteById(int id) =>
      (delete(billRecords)..where((t) => t.id.equals(id))).go();

  Stream<List<BillRecord>> watchByMonth(DateTime month) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);
    return (select(billRecords)
          ..where(
            (t) =>
                t.billTime.isBiggerOrEqualValue(start) &
                t.billTime.isSmallerThanValue(end),
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
            billRecords.amountType.equals(amountType),
      );
    return query.watchSingle().map((row) => row.read(sumExpr) ?? 0);
  }
}
