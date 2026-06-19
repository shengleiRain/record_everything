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

  Stream<BillRecord> watchById(int id) =>
      (select(billRecords)..where((t) => t.id.equals(id))).watchSingle();

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

  /// Streams the set of life-item ids that already have a (non-deleted) bill.
  ///
  /// Used by the home agenda to hide life items whose completion has been
  /// recorded as a bill (mirroring the project detail page): those items are
  /// represented by their bill row instead, dated by billTime.
  Stream<Set<int>> watchLifeItemIdsWithBills() {
    final expr = billRecords.lifeItemId;
    final query = selectOnly(billRecords)
      ..addColumns([expr])
      ..where(
        billRecords.lifeItemId.isNotNull() & billRecords.deletedAt.isNull(),
      );
    return query.watch().map(
      (rows) => {
        for (final row in rows)
          if (row.read(expr) case final int id) id,
      },
    );
  }

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

  /// 当月按日聚合支出/收入。在 Dart 层分组，避免 Drift SQL 表达式兼容问题。
  Stream<List<DailySumRow>> watchDailySumsForMonth(
    DateTime month,
    String amountType,
  ) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);
    return watchBetween(start, end)
        .map(
          (bills) => bills
              .where((b) => b.amountType == amountType && b.deletedAt == null)
              .fold<Map<int, int>>({}, (map, b) {
                final day = b.billTime.day;
                map[day] = (map[day] ?? 0) + b.amount;
                return map;
              })
              .entries
              .map(
                (e) => DailySumRow(
                  date: DateTime(month.year, month.month, e.key),
                  total: e.value,
                ),
              )
              .toList()
            ..sort((a, b) => a.date.day.compareTo(b.date.day)),
        );
  }

  /// 按月+分类聚合（用于分类趋势图）。在 Dart 层分组。
  Stream<List<CategoryMonthlySumRow>> watchCategoryMonthlySums(
    DateTime start,
    DateTime end,
    String amountType,
  ) {
    return watchBetween(start, end)
        .map(
          (bills) => bills
              .where(
                (b) =>
                    b.amountType == amountType &&
                    b.deletedAt == null &&
                    b.categoryId != null,
              )
              .fold<Map<String, CategoryMonthlySumRow>>({}, (map, b) {
                final key =
                    '${b.billTime.year}-${b.billTime.month}-${b.categoryId}';
                final existing = map[key];
                if (existing != null) {
                  map[key] = CategoryMonthlySumRow(
                    year: existing.year,
                    month: existing.month,
                    categoryId: existing.categoryId,
                    total: existing.total + b.amount,
                  );
                } else {
                  map[key] = CategoryMonthlySumRow(
                    year: b.billTime.year,
                    month: b.billTime.month,
                    categoryId: b.categoryId!,
                    total: b.amount,
                  );
                }
                return map;
              })
              .values
              .toList()
            ..sort(
              (a, b) =>
                  a.year != b.year
                      ? a.year.compareTo(b.year)
                      : a.month.compareTo(b.month),
            ),
        );
  }

  /// 根据标题关键词推荐分类 id（历史账单中最常用的分类）。
  /// keyword 长度 < 2 时返回 null。
  Future<int?> suggestCategoryByTitle(
    String keyword,
    String amountType,
  ) async {
    if (keyword.trim().length < 2) return null;
    final catIdExpr = billRecords.categoryId;
    final countExpr = catIdExpr.count();
    final query = selectOnly(billRecords)
      ..addColumns([catIdExpr, countExpr])
      ..where(
        billRecords.title.like('%$keyword%') &
            billRecords.amountType.equals(amountType) &
            billRecords.deletedAt.isNull() &
            billRecords.categoryId.isNotNull(),
      )
      ..groupBy([catIdExpr])
      ..orderBy([OrderingTerm.desc(countExpr)])
      ..limit(1);
    final result = await query.getSingleOrNull();
    return result?.read(catIdExpr);
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

class DailySumRow {
  final DateTime date;
  final int total;
  const DailySumRow({required this.date, required this.total});
}

class CategoryMonthlySumRow {
  final int year;
  final int month;
  final int categoryId;
  final int total;
  const CategoryMonthlySumRow({
    required this.year,
    required this.month,
    required this.categoryId,
    required this.total,
  });
}
