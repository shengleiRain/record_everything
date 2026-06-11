import 'package:drift/drift.dart';
import '../database/app_database.dart';

class BillRecordRepository {
  final AppDatabase _db;
  BillRecordRepository(this._db);

  Stream<List<BillRecord>> watchAll() => _db.billRecordDao.watchAll();
  Stream<List<BillRecord>> watchBetween(DateTime start, DateTime end) =>
      _db.billRecordDao.watchBetween(start, end);
  Stream<List<BillRecord>> watchByMonth(DateTime month) =>
      _db.billRecordDao.watchByMonth(month);

  Future<BillRecord> create({
    int? lifeItemId,
    int? accountId,
    int? projectId,
    required String title,
    int? categoryId,
    required int amount,
    String amountType = 'expense',
    required DateTime billTime,
    String? note,
  }) {
    return _db.billRecordDao.insertOne(
      BillRecordsCompanion.insert(
        lifeItemId: Value(lifeItemId),
        accountId: Value(accountId),
        projectId: Value(projectId),
        title: title,
        categoryId: Value(categoryId),
        amount: amount,
        amountType: Value(amountType),
        billTime: billTime,
        note: Value(note),
      ),
    );
  }

  Future<void> updateRecord(BillRecord record) {
    return _db.billRecordDao.updateOne(
      BillRecordsCompanion(
        id: Value(record.id),
        lifeItemId: Value(record.lifeItemId),
        accountId: Value(record.accountId),
        projectId: Value(record.projectId),
        title: Value(record.title),
        categoryId: Value(record.categoryId),
        amount: Value(record.amount),
        amountType: Value(record.amountType),
        billTime: Value(record.billTime),
        note: Value(record.note),
        createdAt: Value(record.createdAt),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deleteRecord(int id) => _db.billRecordDao.softDeleteById(id);

  Future<void> restoreRecord(int id) => _db.billRecordDao.restoreById(id);

  Future<int> sumIncomeForMonth(DateTime month) =>
      _db.billRecordDao.sumForMonth(month, 'income');
  Future<int> sumExpenseForMonth(DateTime month) =>
      _db.billRecordDao.sumForMonth(month, 'expense');
  Stream<int> watchIncomeForMonth(DateTime month) =>
      _db.billRecordDao.watchSumForMonth(month, 'income');
  Stream<int> watchExpenseForMonth(DateTime month) =>
      _db.billRecordDao.watchSumForMonth(month, 'expense');
}
