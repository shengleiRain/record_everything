import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record_everything/data/database/app_database.dart';
import 'package:record_everything/data/repositories/bill_record_repository.dart';

void main() {
  late AppDatabase db;
  late BillRecordRepository repo;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.categoryDao.getAll(); // 触发播种
    repo = BillRecordRepository(db);
  });
  tearDown(() async => db.close());

  test('suggestCategoryByTitle 匹配历史分类', () async {
    final cats = await db.categoryDao.getByType('expense');
    expect(cats, isNotEmpty);
    final cat = cats.first;

    await repo.create(
      title: '午餐',
      amount: 2500,
      amountType: 'expense',
      categoryId: cat.id,
      accountId: 1,
      billTime: DateTime.now(),
    );
    await repo.create(
      title: '午餐外卖',
      amount: 3000,
      amountType: 'expense',
      categoryId: cat.id,
      accountId: 1,
      billTime: DateTime.now(),
    );

    final suggested = await db.billRecordDao.suggestCategoryByTitle(
      '午餐',
      'expense',
    );
    expect(suggested, cat.id);
  });

  test('suggestCategoryByTitle 短关键词返回 null', () async {
    final suggested = await db.billRecordDao.suggestCategoryByTitle(
      'a',
      'expense',
    );
    expect(suggested, isNull);
  });

  test('suggestCategoryByTitle 无匹配返回 null', () async {
    final suggested = await db.billRecordDao.suggestCategoryByTitle(
      '完全不存在的标题XYZ',
      'expense',
    );
    expect(suggested, isNull);
  });

  test('watchDailySumsForMonth 返回按日聚合数据', () async {
    await repo.create(
      title: '早餐',
      amount: 1000,
      amountType: 'expense',
      accountId: 1,
      billTime: DateTime(2026, 6, 10),
    );
    await repo.create(
      title: '午餐',
      amount: 2500,
      amountType: 'expense',
      accountId: 1,
      billTime: DateTime(2026, 6, 10),
    );
    await repo.create(
      title: '晚餐',
      amount: 3000,
      amountType: 'expense',
      accountId: 1,
      billTime: DateTime(2026, 6, 15),
    );

    final rows = await db.billRecordDao
        .watchDailySumsForMonth(DateTime(2026, 6), 'expense')
        .first;
    expect(rows, hasLength(2));
    final day10 = rows.firstWhere((r) => r.date.day == 10);
    expect(day10.total, 3500);
    final day15 = rows.firstWhere((r) => r.date.day == 15);
    expect(day15.total, 3000);
  });

  test('watchCategoryMonthlySums 返回按月+分类聚合', () async {
    final cats = await db.categoryDao.getByType('expense');
    final cat1 = cats[0];
    final cat2 = cats.length > 1 ? cats[1] : cats[0];

    await repo.create(
      title: '午餐',
      amount: 2500,
      amountType: 'expense',
      categoryId: cat1.id,
      accountId: 1,
      billTime: DateTime(2026, 5, 10),
    );
    await repo.create(
      title: '打车',
      amount: 1500,
      amountType: 'expense',
      categoryId: cat2.id,
      accountId: 1,
      billTime: DateTime(2026, 6, 10),
    );

    final rows = await db.billRecordDao
        .watchCategoryMonthlySums(
          DateTime(2026, 5, 1),
          DateTime(2026, 7, 1),
          'expense',
        )
        .first;
    expect(rows.length, greaterThanOrEqualTo(2));
    final may = rows.firstWhere(
      (r) => r.year == 2026 && r.month == 5 && r.categoryId == cat1.id,
    );
    expect(may.total, 2500);
  });
}
