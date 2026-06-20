import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record_everything/data/database/app_database.dart';
import 'package:record_everything/data/repositories/life_item_repository.dart';
import 'package:record_everything/data/repositories/bill_record_repository.dart';
import 'package:record_everything/domain/enums/item_status.dart';
import 'package:record_everything/domain/models/repeat_rule.dart';

/// 生活事项全业务路径测试。
///
/// 覆盖：
/// - CRUD 完整生命周期
/// - 状态机所有合法/非法流转
/// - 完成并生成账单
/// - 完成并生成账单 + 自动生成下期
/// - 延期操作
/// - 取消与重新打开
/// - 软删除与恢复
/// - 永久删除
/// - 重复规则（每日/每周/每月/每年/自定义天数）
/// - 逾期判定
/// - 事项模板推荐
/// - 分类关联与标记使用
void main() {
  group('LifeItem CRUD 完整生命周期', () {
    late AppDatabase db;
    late LifeItemRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = LifeItemRepository(db);
    });

    tearDown(() => db.close());

    test('创建事项默认状态为 pending', () async {
      final item = await repo.create(
        title: '测试事项',
        dueTime: DateTime(2026, 7, 1),
      );
      expect(item.status, 'pending');
      expect(item.title, '测试事项');
      expect(item.deletedAt, isNull);
    });

    test('创建带完整参数的事项', () async {
      final item = await repo.create(
        title: '完整事项',
        description: '描述内容',
        amount: 5000,
        amountType: 'expense',
        dueTime: DateTime(2026, 7, 1),
        remindTime: DateTime(2026, 6, 30),
        repeatRule: 'monthly',
      );
      expect(item.description, '描述内容');
      expect(item.amount, 5000);
      expect(item.amountType, 'expense');
      expect(item.remindTime, DateTime(2026, 6, 30));
      expect(item.repeatRule, 'monthly');
    });

    test('更新事项内容', () async {
      final item = await repo.create(
        title: '原始标题',
        dueTime: DateTime(2026, 7, 1),
      );
      final updated = item.copyWith(title: '更新后标题', amount: const Value(8000));
      await repo.updateItem(updated);
      final fetched = await db.lifeItemDao.getById(item.id);
      expect(fetched.title, '更新后标题');
      expect(fetched.amount, 8000);
    });

    test('按 ID 查看事项', () async {
      final item = await repo.create(
        title: '查看事项',
        dueTime: DateTime(2026, 7, 1),
      );
      final stream = repo.watchById(item.id);
      final fetched = await stream.first;
      expect(fetched.id, item.id);
      expect(fetched.title, '查看事项');
    });
  });

  group('LifeItem 状态机全部流转', () {
    late AppDatabase db;
    late LifeItemRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = LifeItemRepository(db);
    });

    tearDown(() => db.close());

    Future<LifeItem> seed({String title = '测试事项'}) {
      return repo.create(
        title: title,
        dueTime: DateTime.now().add(const Duration(days: 1)),
      );
    }

    test('pending → completed（完成）', () async {
      final item = await seed();
      final completed = await repo.complete(item.id);
      expect(completed.status, 'completed');
    });

    test('pending → cancelled（取消）', () async {
      final item = await seed();
      final cancelled = await repo.cancel(item.id);
      expect(cancelled.status, 'cancelled');
    });

    test('completed → pending（重新打开）', () async {
      final item = await seed();
      await repo.complete(item.id);
      final reopened = await repo.reopen(item.id);
      expect(reopened.status, 'pending');
    });

    test('cancelled → pending（重新打开）', () async {
      final item = await seed();
      await repo.cancel(item.id);
      final reopened = await repo.reopen(item.id);
      expect(reopened.status, 'pending');
    });

    test('completed 不能再次 complete', () async {
      final item = await seed();
      await repo.complete(item.id);
      expect(() => repo.complete(item.id), throwsA(isA<StateError>()));
    });

    test('completed 不能 cancel', () async {
      final item = await seed();
      await repo.complete(item.id);
      expect(() => repo.cancel(item.id), throwsA(isA<StateError>()));
    });

    test('cancelled 不能再次 cancel', () async {
      final item = await seed();
      await repo.cancel(item.id);
      expect(() => repo.cancel(item.id), throwsA(isA<StateError>()));
    });

    test('cancelled 不能 complete', () async {
      final item = await seed();
      await repo.cancel(item.id);
      expect(() => repo.complete(item.id), throwsA(isA<StateError>()));
    });

    test('pending 不能 reopen', () async {
      final item = await seed();
      expect(() => repo.reopen(item.id), throwsA(isA<StateError>()));
    });

    test('完整流转：pending → completed → pending → cancelled → pending', () async {
      final item = await seed(title: '流转测试');

      final completed = await repo.complete(item.id);
      expect(completed.status, 'completed');

      final reopened1 = await repo.reopen(item.id);
      expect(reopened1.status, 'pending');

      final cancelled = await repo.cancel(item.id);
      expect(cancelled.status, 'cancelled');

      final reopened2 = await repo.reopen(item.id);
      expect(reopened2.status, 'pending');
    });
  });

  group('LifeItem 完成并生成账单', () {
    late AppDatabase db;
    late LifeItemRepository itemRepo;
    late BillRecordRepository billRepo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      itemRepo = LifeItemRepository(db);
      billRepo = BillRecordRepository(db);
    });

    tearDown(() => db.close());

    test('完成带金额的事项后可手动创建关联账单', () async {
      final item = await itemRepo.create(
        title: '会员续费',
        amount: 29900,
        amountType: 'expense',
        dueTime: DateTime(2026, 7, 1),
      );
      await itemRepo.complete(item.id);

      final bill = await billRepo.create(
        title: '会员续费',
        amount: 29900,
        amountType: 'expense',
        billTime: DateTime.now(),
        lifeItemId: item.id,
      );

      expect(bill.lifeItemId, item.id);
      expect(bill.amount, 29900);
      expect(bill.amountType, 'expense');

      final completedItem = await db.lifeItemDao.getById(item.id);
      expect(completedItem.status, 'completed');
    });

    test('完成并生成下期事项（重复规则 monthly）', () async {
      final item = await itemRepo.create(
        title: '月度订阅',
        amount: 9900,
        amountType: 'expense',
        dueTime: DateTime(2026, 7, 15),
        repeatRule: 'monthly',
      );

      final nextItem = await itemRepo.completeAndGenerateNext(item.id);

      expect(nextItem.status, 'pending');
      expect(nextItem.title, '月度订阅');
      expect(nextItem.amount, 9900);
      expect(nextItem.repeatRule, 'monthly');
      expect(nextItem.dueTime, DateTime(2026, 8, 15));
      expect(nextItem.id, isNot(item.id));

      final originalItem = await db.lifeItemDao.getById(item.id);
      expect(originalItem.status, 'completed');
    });

    test('完成并生成下期事项（重复规则 weekly）', () async {
      final item = await itemRepo.create(
        title: '每周会议',
        dueTime: DateTime(2026, 7, 1),
        repeatRule: 'weekly',
      );

      final nextItem = await itemRepo.completeAndGenerateNext(item.id);
      expect(nextItem.dueTime, DateTime(2026, 7, 8));
    });

    test('完成并生成下期事项（重复规则 daily）', () async {
      final item = await itemRepo.create(
        title: '每日打卡',
        dueTime: DateTime(2026, 7, 1),
        repeatRule: 'daily',
      );

      final nextItem = await itemRepo.completeAndGenerateNext(item.id);
      expect(nextItem.dueTime, DateTime(2026, 7, 2));
    });

    test('完成并生成下期事项（自定义天数 every:14:days）', () async {
      final item = await itemRepo.create(
        title: '双周报',
        dueTime: DateTime(2026, 7, 1),
        repeatRule: 'every:14:days',
      );

      final nextItem = await itemRepo.completeAndGenerateNext(item.id);
      expect(nextItem.dueTime, DateTime(2026, 7, 15));
    });

    test('完成并生成下期事项（重复规则 yearly）', () async {
      final item = await itemRepo.create(
        title: '年度体检',
        dueTime: DateTime(2026, 7, 1),
        repeatRule: 'yearly',
      );

      final nextItem = await itemRepo.completeAndGenerateNext(item.id);
      expect(nextItem.dueTime, DateTime(2026 + 1, 7, 1));
    });
  });

  group('LifeItem 延期操作', () {
    late AppDatabase db;
    late LifeItemRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = LifeItemRepository(db);
    });

    tearDown(() => db.close());

    test('延期更新到期日期', () async {
      final item = await repo.create(
        title: '延期事项',
        dueTime: DateTime(2026, 7, 1),
      );
      final deferred = await repo.defer(item.id, DateTime(2026, 7, 15));
      expect(deferred.dueTime, DateTime(2026, 7, 15));
      expect(deferred.status, 'pending');
    });

    test('延期不改变状态', () async {
      final item = await repo.create(
        title: '延期事项',
        dueTime: DateTime(2026, 7, 1),
      );
      final deferred = await repo.defer(item.id, DateTime(2026, 8, 1));
      expect(deferred.status, 'pending');
    });

    test('延期事项后到期日期被更新', () async {
      final item = await repo.create(
        title: '项目事项',
        dueTime: DateTime(2026, 7, 1),
        projectDateAnchor: 'keyDate',
        projectDateOffsetDays: 5,
      );
      final deferred = await repo.defer(item.id, DateTime(2026, 7, 20));
      expect(deferred.dueTime, DateTime(2026, 7, 20));
      // 验证数据库中的到期日期已更新
      final fromDb = await db.lifeItemDao.getById(item.id);
      expect(fromDb.dueTime, DateTime(2026, 7, 20));
    });
  });

  group('LifeItem 软删除与恢复', () {
    late AppDatabase db;
    late LifeItemRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = LifeItemRepository(db);
    });

    tearDown(() => db.close());

    test('软删除后不在活跃列表中', () async {
      final item = await repo.create(
        title: '删除事项',
        dueTime: DateTime(2026, 7, 1),
      );
      await repo.deleteItem(item.id);
      final all = await db.lifeItemDao.getAll();
      expect(all.where((i) => i.id == item.id), isEmpty);
    });

    test('软删除后可在已删除列表中找到', () async {
      final item = await repo.create(
        title: '删除事项',
        dueTime: DateTime(2026, 7, 1),
      );
      await repo.deleteItem(item.id);
      final deleted = await db.lifeItemDao.getDeleted();
      expect(deleted.where((i) => i.id == item.id), isNotEmpty);
    });

    test('恢复软删除的事项', () async {
      final item = await repo.create(
        title: '恢复事项',
        dueTime: DateTime(2026, 7, 1),
      );
      await repo.deleteItem(item.id);
      await repo.restoreItem(item.id);
      final all = await db.lifeItemDao.getAll();
      expect(all.where((i) => i.id == item.id), isNotEmpty);
    });

    test('永久删除后无法恢复', () async {
      final item = await repo.create(
        title: '永久删除',
        dueTime: DateTime(2026, 7, 1),
      );
      await repo.permanentDeleteItem(item.id);
      final all = await db.lifeItemDao.getAll();
      expect(all, isEmpty);
      final deleted = await db.lifeItemDao.getDeleted();
      expect(deleted, isEmpty);
    });
  });

  group('LifeItem 查询流', () {
    late AppDatabase db;
    late LifeItemRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = LifeItemRepository(db);
    });

    tearDown(() => db.close());

    test('watchTodayPending 返回今日待处理事项', () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 23, 59);
      final tomorrow = today.add(const Duration(days: 1));

      await repo.create(title: '今日事项', dueTime: today);
      await repo.create(title: '明日事项', dueTime: tomorrow);

      final items = await repo.watchTodayPending().first;
      expect(items.any((i) => i.title == '今日事项'), isTrue);
      expect(items.any((i) => i.title == '明日事项'), isFalse);
    });

    test('watchOverdue 返回逾期事项', () async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final tomorrow = DateTime.now().add(const Duration(days: 1));

      await repo.create(title: '逾期事项', dueTime: yesterday);
      await repo.create(title: '未逾期事项', dueTime: tomorrow);

      final items = await repo.watchOverdue().first;
      expect(items.any((i) => i.title == '逾期事项'), isTrue);
      expect(items.any((i) => i.title == '未逾期事项'), isFalse);
    });

    test('watchUpcoming 返回未来 N 天的事项', () async {
      final now = DateTime.now();
      await repo.create(
        title: '3天后',
        dueTime: now.add(const Duration(days: 3)),
      );
      await repo.create(
        title: '10天后',
        dueTime: now.add(const Duration(days: 10)),
      );

      final items = await repo.watchUpcoming(7).first;
      expect(items.any((i) => i.title == '3天后'), isTrue);
      expect(items.any((i) => i.title == '10天后'), isFalse);
    });

    test('watchBetween 返回日期范围内的事项', () async {
      await repo.create(title: '范围内', dueTime: DateTime(2026, 7, 15));
      await repo.create(title: '范围外', dueTime: DateTime(2026, 8, 15));

      final items = await repo
          .watchBetween(DateTime(2026, 7, 1), DateTime(2026, 7, 31))
          .first;
      expect(items.any((i) => i.title == '范围内'), isTrue);
      expect(items.any((i) => i.title == '范围外'), isFalse);
    });

    test('watchForecastExpenses 返回未来支出预测', () async {
      await repo.create(
        title: '即将支出',
        amount: 5000,
        amountType: 'expense',
        dueTime: DateTime.now().add(const Duration(days: 5)),
      );
      await repo.create(
        title: '远期支出',
        amount: 3000,
        amountType: 'expense',
        dueTime: DateTime.now().add(const Duration(days: 60)),
      );
      await repo.create(
        title: '收入项',
        amount: 10000,
        amountType: 'income',
        dueTime: DateTime.now().add(const Duration(days: 5)),
      );

      final items = await repo.watchForecastExpenses(30).first;
      expect(items.any((i) => i.title == '即将支出'), isTrue);
      expect(items.any((i) => i.title == '远期支出'), isFalse);
      expect(items.any((i) => i.title == '收入项'), isFalse);
    });
  });

  group('LifeItem 事项模板推荐', () {
    late AppDatabase db;
    late LifeItemRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = LifeItemRepository(db);
    });

    tearDown(() => db.close());

    test('空标题不推荐模板', () async {
      final templates = await repo.recommendTemplates('');
      expect(templates, isEmpty);
    });

    test('空白标题不推荐模板', () async {
      final templates = await repo.recommendTemplates('   ');
      expect(templates, isEmpty);
    });

    test('匹配关键词推荐会员续费模板', () async {
      final templates = await repo.recommendTemplates('Netflix 会员续费');
      expect(templates, isNotEmpty);
      expect(
        templates.any((t) => t.templateKey == 'membership_renewal'),
        isTrue,
      );
    });

    test('匹配关键词推荐证件过期模板', () async {
      final templates = await repo.recommendTemplates('护照快到期了');
      expect(templates, isNotEmpty);
      expect(
        templates.any((t) => t.templateKey == 'document_expiry'),
        isTrue,
      );
    });

    test('匹配关键词推荐药品补货模板', () async {
      final templates = await repo.recommendTemplates('感冒药吃完了要补货');
      expect(templates, isNotEmpty);
      expect(
        templates.any((t) => t.templateKey == 'medicine_restock'),
        isTrue,
      );
    });

    test('匹配关键词推荐家庭账单模板', () async {
      final templates = await repo.recommendTemplates('电费账单到期');
      expect(templates, isNotEmpty);
      expect(
        templates.any((t) => t.templateKey == 'household_bill'),
        isTrue,
      );
    });

    test('无匹配关键词不推荐', () async {
      final templates = await repo.recommendTemplates('完全无关的内容xyz');
      expect(templates, isEmpty);
    });

    test('最多推荐 3 个模板', () async {
      // 使用一个可能匹配多个模板的通用词
      final templates = await repo.recommendTemplates('续费');
      expect(templates.length, lessThanOrEqualTo(3));
    });

    test('模板包含 6 个内置模板', () async {
      final templates = await repo.getTemplates();
      expect(templates.length, 6);
      expect(templates.where((t) => t.isDefault).length, 6);
    });
  });

  group('LifeItem 分类关联', () {
    late AppDatabase db;
    late LifeItemRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = LifeItemRepository(db);
    });

    tearDown(() => db.close());

    test('创建带分类的事项后标记分类已使用', () async {
      final categories = await db.categoryDao.getByType('item');
      final category = categories.first;

      await repo.create(
        title: '分类事项',
        categoryId: category.id,
        dueTime: DateTime(2026, 7, 1),
      );

      final updated = await db.categoryDao.getById(category.id);
      expect(updated.lastUsedAt, isNotNull);
    });
  });
}
