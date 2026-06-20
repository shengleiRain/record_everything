import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record_everything/data/database/app_database.dart';
import 'package:record_everything/data/repositories/bill_record_repository.dart';
import 'package:record_everything/data/repositories/life_item_repository.dart';
import 'package:record_everything/data/repositories/project_repository.dart';

/// 账单记录全业务路径测试。
///
/// 覆盖：
/// - CRUD 完整生命周期
/// - 收入/支出分类
/// - 按月查询与汇总
/// - 关联生活事项
/// - 关联项目
/// - 软删除与恢复
/// - 永久删除
/// - 分类关联标记
void main() {
  group('BillRecord CRUD 完整生命周期', () {
    late AppDatabase db;
    late BillRecordRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = BillRecordRepository(db);
    });

    tearDown(() => db.close());

    test('创建支出账单', () async {
      final bill = await repo.create(
        title: '早餐',
        amount: 1200,
        amountType: 'expense',
        billTime: DateTime(2026, 7, 1),
      );
      expect(bill.title, '早餐');
      expect(bill.amount, 1200);
      expect(bill.amountType, 'expense');
      expect(bill.deletedAt, isNull);
    });

    test('创建收入账单', () async {
      final bill = await repo.create(
        title: '工资',
        amount: 800000,
        amountType: 'income',
        billTime: DateTime(2026, 7, 1),
      );
      expect(bill.amountType, 'income');
      expect(bill.amount, 800000);
    });

    test('创建带备注的账单', () async {
      final bill = await repo.create(
        title: '午餐',
        amount: 2500,
        amountType: 'expense',
        billTime: DateTime(2026, 7, 1),
        note: '和同事聚餐',
      );
      expect(bill.note, '和同事聚餐');
    });

    test('更新账单内容', () async {
      final bill = await repo.create(
        title: '原始标题',
        amount: 1000,
        amountType: 'expense',
        billTime: DateTime(2026, 7, 1),
      );
      final updated = bill.copyWith(title: '更新后标题', amount: 2000);
      await repo.updateRecord(updated);
      final fetched = await db.billRecordDao.getById(bill.id);
      expect(fetched.title, '更新后标题');
      expect(fetched.amount, 2000);
    });

    test('按 ID 查看账单', () async {
      final bill = await repo.create(
        title: '查看账单',
        amount: 1000,
        billTime: DateTime(2026, 7, 1),
      );
      final fetched = await repo.watchById(bill.id).first;
      expect(fetched.id, bill.id);
    });
  });

  group('BillRecord 按月查询与汇总', () {
    late AppDatabase db;
    late BillRecordRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = BillRecordRepository(db);
    });

    tearDown(() => db.close());

    test('watchByMonth 返回指定月份的账单', () async {
      await repo.create(
        title: '7月支出',
        amount: 1000,
        amountType: 'expense',
        billTime: DateTime(2026, 7, 15),
      );
      await repo.create(
        title: '8月支出',
        amount: 2000,
        amountType: 'expense',
        billTime: DateTime(2026, 8, 15),
      );

      final july = await repo.watchByMonth(DateTime(2026, 7, 1)).first;
      expect(july.any((b) => b.title == '7月支出'), isTrue);
      expect(july.any((b) => b.title == '8月支出'), isFalse);
    });

    test('sumIncomeForMonth 正确汇总月收入', () async {
      await repo.create(
        title: '工资',
        amount: 800000,
        amountType: 'income',
        billTime: DateTime(2026, 7, 1),
      );
      await repo.create(
        title: '奖金',
        amount: 200000,
        amountType: 'income',
        billTime: DateTime(2026, 7, 15),
      );
      await repo.create(
        title: '支出',
        amount: 50000,
        amountType: 'expense',
        billTime: DateTime(2026, 7, 10),
      );

      final income = await repo.sumIncomeForMonth(DateTime(2026, 7, 1));
      expect(income, 1000000);
    });

    test('sumExpenseForMonth 正确汇总月支出', () async {
      await repo.create(
        title: '早餐',
        amount: 1200,
        amountType: 'expense',
        billTime: DateTime(2026, 7, 1),
      );
      await repo.create(
        title: '午餐',
        amount: 2500,
        amountType: 'expense',
        billTime: DateTime(2026, 7, 15),
      );

      final expense = await repo.sumExpenseForMonth(DateTime(2026, 7, 1));
      expect(expense, 3700);
    });

    test('无数据月份汇总为 0', () async {
      final income = await repo.sumIncomeForMonth(DateTime(2026, 12, 1));
      final expense = await repo.sumExpenseForMonth(DateTime(2026, 12, 1));
      expect(income, 0);
      expect(expense, 0);
    });

    test('watchBetween 返回日期范围内的账单', () async {
      await repo.create(
        title: '范围内',
        amount: 1000,
        billTime: DateTime(2026, 7, 15),
      );
      await repo.create(
        title: '范围外',
        amount: 2000,
        billTime: DateTime(2026, 8, 15),
      );

      final bills = await repo
          .watchBetween(DateTime(2026, 7, 1), DateTime(2026, 7, 31))
          .first;
      expect(bills.any((b) => b.title == '范围内'), isTrue);
      expect(bills.any((b) => b.title == '范围外'), isFalse);
    });
  });

  group('BillRecord 关联生活事项', () {
    late AppDatabase db;
    late BillRecordRepository billRepo;
    late LifeItemRepository itemRepo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      billRepo = BillRecordRepository(db);
      itemRepo = LifeItemRepository(db);
    });

    tearDown(() => db.close());

    test('创建关联生活事项的账单', () async {
      final item = await itemRepo.create(
        title: '会员续费',
        amount: 29900,
        amountType: 'expense',
        dueTime: DateTime(2026, 7, 1),
      );
      final bill = await billRepo.create(
        title: '会员续费',
        amount: 29900,
        amountType: 'expense',
        billTime: DateTime(2026, 7, 1),
        lifeItemId: item.id,
      );

      expect(bill.lifeItemId, item.id);
    });

    test('watchLifeItemIdsWithBills 返回已关联账单的事项 ID', () async {
      final item = await itemRepo.create(
        title: '有账单事项',
        dueTime: DateTime(2026, 7, 1),
      );
      await itemRepo.create(
        title: '无账单事项',
        dueTime: DateTime(2026, 7, 1),
      );
      await billRepo.create(
        title: '关联账单',
        amount: 1000,
        billTime: DateTime(2026, 7, 1),
        lifeItemId: item.id,
      );

      final ids = await billRepo.watchLifeItemIdsWithBills().first;
      expect(ids, contains(item.id));
    });
  });

  group('BillRecord 关联项目', () {
    late AppDatabase db;
    late BillRecordRepository billRepo;
    late ProjectRepository projectRepo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      billRepo = BillRecordRepository(db);
      projectRepo = ProjectRepository(db);
    });

    tearDown(() => db.close());

    test('创建关联项目的账单', () async {
      final project = await projectRepo.createProject(title: '测试项目');
      final bill = await billRepo.create(
        title: '项目支出',
        amount: 50000,
        amountType: 'expense',
        billTime: DateTime(2026, 7, 1),
        projectId: project.id,
      );

      expect(bill.projectId, project.id);
    });

    test('项目下账单可通过 ProjectRepository 查询', () async {
      final project = await projectRepo.createProject(title: '项目A');
      await billRepo.create(
        title: '项目A支出',
        amount: 10000,
        billTime: DateTime(2026, 7, 1),
        projectId: project.id,
      );
      await billRepo.create(
        title: '其他支出',
        amount: 5000,
        billTime: DateTime(2026, 7, 1),
      );

      final bills = await projectRepo.watchProjectBills(project.id).first;
      expect(bills, hasLength(1));
      expect(bills.first.title, '项目A支出');
    });

    test('项目收支汇总可通过 ProjectRepository 查询', () async {
      final project = await projectRepo.createProject(title: '项目B');
      await billRepo.create(
        title: '项目收入1',
        amount: 100000,
        amountType: 'income',
        billTime: DateTime(2026, 7, 1),
        projectId: project.id,
      );
      await billRepo.create(
        title: '项目收入2',
        amount: 50000,
        amountType: 'income',
        billTime: DateTime(2026, 7, 15),
        projectId: project.id,
      );
      await billRepo.create(
        title: '项目支出',
        amount: 30000,
        amountType: 'expense',
        billTime: DateTime(2026, 7, 10),
        projectId: project.id,
      );

      final income = await projectRepo.watchProjectIncome(project.id).first;
      final expense = await projectRepo.watchProjectExpense(project.id).first;
      expect(income, 150000);
      expect(expense, 30000);
    });
  });

  group('BillRecord 软删除与恢复', () {
    late AppDatabase db;
    late BillRecordRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = BillRecordRepository(db);
    });

    tearDown(() => db.close());

    test('软删除后不在活跃列表中', () async {
      final bill = await repo.create(
        title: '删除账单',
        amount: 1000,
        billTime: DateTime(2026, 7, 1),
      );
      await repo.deleteRecord(bill.id);
      final all = await db.billRecordDao.getAll();
      expect(all.where((b) => b.id == bill.id), isEmpty);
    });

    test('软删除后可在已删除列表中找到', () async {
      final bill = await repo.create(
        title: '删除账单',
        amount: 1000,
        billTime: DateTime(2026, 7, 1),
      );
      await repo.deleteRecord(bill.id);
      final deleted = await db.billRecordDao.getDeleted();
      expect(deleted.where((b) => b.id == bill.id), isNotEmpty);
    });

    test('恢复软删除的账单', () async {
      final bill = await repo.create(
        title: '恢复账单',
        amount: 1000,
        billTime: DateTime(2026, 7, 1),
      );
      await repo.deleteRecord(bill.id);
      await repo.restoreRecord(bill.id);
      final all = await db.billRecordDao.getAll();
      expect(all.where((b) => b.id == bill.id), isNotEmpty);
    });

    test('永久删除后无法恢复', () async {
      final bill = await repo.create(
        title: '永久删除',
        amount: 1000,
        billTime: DateTime(2026, 7, 1),
      );
      await repo.permanentDeleteRecord(bill.id);
      final all = await db.billRecordDao.getAll();
      expect(all, isEmpty);
      final deleted = await db.billRecordDao.getDeleted();
      expect(deleted, isEmpty);
    });
  });

  group('BillRecord 分类关联', () {
    late AppDatabase db;
    late BillRecordRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = BillRecordRepository(db);
    });

    tearDown(() => db.close());

    test('创建带分类的账单后标记分类已使用', () async {
      final categories = await db.categoryDao.getByType('expense');
      final category = categories.first;

      await repo.create(
        title: '分类账单',
        amount: 1000,
        categoryId: category.id,
        billTime: DateTime(2026, 7, 1),
      );

      final updated = await db.categoryDao.getById(category.id);
      expect(updated.lastUsedAt, isNotNull);
    });
  });
}
