import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record_everything/data/database/app_database.dart';
import 'package:record_everything/data/repositories/bill_record_repository.dart';
import 'package:record_everything/data/repositories/category_repository.dart';
import 'package:record_everything/data/repositories/life_item_repository.dart';
import 'package:record_everything/data/repositories/project_repository.dart';

/// 分类管理全业务路径测试。
///
/// 覆盖：
/// - 分类 CRUD
/// - 分类隐藏/显示
/// - 分类置顶/取消置顶
/// - 默认分类保护（不可删除，只能隐藏）
/// - 使用中分类保护（不可删除正在使用的分类）
/// - 分类合并（同类型、不同类型）
/// - 分类合并异常处理
/// - 按类型查询分类
/// - 分类使用计数
void main() {
  group('Category CRUD', () {
    late AppDatabase db;
    late CategoryRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = CategoryRepository(db);
    });

    tearDown(() => db.close());

    test('创建自定义分类', () async {
      final category = await repo.create(
        name: '自定义分类',
        type: 'expense',
        icon: 'coffee',
      );
      expect(category.name, '自定义分类');
      expect(category.type, 'expense');
      expect(category.icon, 'coffee');
      expect(category.isDefault, isFalse);
      expect(category.isHidden, isFalse);
    });

    test('创建空图标分类使用默认图标', () async {
      final category = await repo.create(
        name: '无图标分类',
        type: 'income',
        icon: '',
      );
      expect(category.icon, 'category');
    });

    test('更新分类名称', () async {
      final category = await repo.create(
        name: '原始名称',
        type: 'expense',
      );
      final updated = category.copyWith(name: '更新后名称');
      await repo.updateCategory(updated);
      final fetched = await db.categoryDao.getById(category.id);
      expect(fetched.name, '更新后名称');
    });

    test('按类型查询分类', () async {
      await repo.create(name: '收入分类', type: 'income');
      await repo.create(name: '支出分类', type: 'expense');
      await repo.create(name: '事项分类', type: 'item');

      final income = await repo.getByType('income');
      final expense = await repo.getByType('expense');
      final item = await repo.getByType('item');

      expect(income.any((c) => c.name == '收入分类'), isTrue);
      expect(expense.any((c) => c.name == '支出分类'), isTrue);
      expect(item.any((c) => c.name == '事项分类'), isTrue);
    });
  });

  group('Category 隐藏与置顶', () {
    late AppDatabase db;
    late CategoryRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = CategoryRepository(db);
    });

    tearDown(() => db.close());

    test('隐藏分类', () async {
      final category = await repo.create(name: '待隐藏', type: 'expense');
      await repo.setHidden(category.id, true);
      final updated = await db.categoryDao.getById(category.id);
      expect(updated.isHidden, isTrue);
    });

    test('显示已隐藏的分类', () async {
      final category = await repo.create(name: '待显示', type: 'expense');
      await repo.setHidden(category.id, true);
      await repo.setHidden(category.id, false);
      final updated = await db.categoryDao.getById(category.id);
      expect(updated.isHidden, isFalse);
    });

    test('置顶分类', () async {
      final category = await repo.create(name: '待置顶', type: 'expense');
      await repo.setPinned(category.id, true);
      final updated = await db.categoryDao.getById(category.id);
      expect(updated.isPinned, isTrue);
    });

    test('取消置顶', () async {
      final category = await repo.create(name: '待取消置顶', type: 'expense');
      await repo.setPinned(category.id, true);
      await repo.setPinned(category.id, false);
      final updated = await db.categoryDao.getById(category.id);
      expect(updated.isPinned, isFalse);
    });
  });

  group('Category 默认分类保护', () {
    late AppDatabase db;
    late CategoryRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = CategoryRepository(db);
    });

    tearDown(() => db.close());

    test('删除默认分类变为隐藏', () async {
      final categories = await repo.getByType('expense');
      final defaultCategory = categories.firstWhere((c) => c.isDefault);

      await repo.deleteCategory(defaultCategory.id);

      final updated = await db.categoryDao.getById(defaultCategory.id);
      expect(updated.isHidden, isTrue);
    });
  });

  group('Category 使用中分类保护', () {
    late AppDatabase db;
    late CategoryRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = CategoryRepository(db);
    });

    tearDown(() => db.close());

    test('删除被生活事项使用的分类抛出异常', () async {
      final category = await repo.create(name: '使用中', type: 'item');
      await LifeItemRepository(db).create(
        title: '使用分类的事项',
        categoryId: category.id,
        dueTime: DateTime(2026, 7, 1),
      );

      expect(
        () => repo.deleteCategory(category.id),
        throwsA(isA<CategoryDeleteException>()),
      );
    });

    test('删除被账单使用的分类抛出异常', () async {
      final category = await repo.create(name: '账单使用', type: 'expense');
      await BillRecordRepository(db).create(
        title: '使用分类的账单',
        categoryId: category.id,
        amount: 1000,
        billTime: DateTime(2026, 7, 1),
      );

      expect(
        () => repo.deleteCategory(category.id),
        throwsA(isA<CategoryDeleteException>()),
      );
    });

    test('删除被项目使用的分类抛出异常', () async {
      final category = await repo.create(name: '项目使用', type: 'project');
      await ProjectRepository(db).createProject(
        title: '使用分类的项目',
        categoryId: category.id,
      );

      expect(
        () => repo.deleteCategory(category.id),
        throwsA(isA<CategoryDeleteException>()),
      );
    });

    test('删除未使用的自定义分类成功', () async {
      final category = await repo.create(name: '未使用', type: 'expense');
      await repo.deleteCategory(category.id);

      final all = await repo.getAll();
      expect(all.any((c) => c.id == category.id), isFalse);
    });
  });

  group('Category 合并', () {
    late AppDatabase db;
    late CategoryRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = CategoryRepository(db);
    });

    tearDown(() => db.close());

    test('合并同类型分类重新分配引用', () async {
      final source = await repo.create(name: '源分类', type: 'expense');
      final target = await repo.create(name: '目标分类', type: 'expense');

      await LifeItemRepository(db).create(
        title: '源分类事项',
        categoryId: source.id,
        dueTime: DateTime(2026, 7, 1),
      );
      await BillRecordRepository(db).create(
        title: '源分类账单',
        categoryId: source.id,
        amount: 1000,
        billTime: DateTime(2026, 7, 1),
      );

      await repo.mergeCategory(sourceId: source.id, targetId: target.id);

      // 源分类被隐藏
      final sourceCategory = await db.categoryDao.getById(source.id);
      expect(sourceCategory.isHidden, isTrue);

      // 引用被重新分配
      final items = await db.lifeItemDao.getAll();
      expect(items.first.categoryId, target.id);

      final bills = await db.billRecordDao.getAll();
      expect(bills.first.categoryId, target.id);
    });

    test('合并到自身抛出异常', () async {
      final category = await repo.create(name: '自身', type: 'expense');
      expect(
        () => repo.mergeCategory(
          sourceId: category.id,
          targetId: category.id,
        ),
        throwsA(isA<CategoryMergeException>()),
      );
    });

    test('合并不同类型分类抛出异常', () async {
      final expense = await repo.create(name: '支出', type: 'expense');
      final income = await repo.create(name: '收入', type: 'income');
      expect(
        () => repo.mergeCategory(
          sourceId: expense.id,
          targetId: income.id,
        ),
        throwsA(isA<CategoryMergeException>()),
      );
    });
  });

  group('Category 使用计数', () {
    late AppDatabase db;
    late CategoryRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = CategoryRepository(db);
    });

    tearDown(() => db.close());

    test('usageCount 返回分类使用次数', () async {
      final category = await repo.create(name: '计数分类', type: 'expense');
      expect(await repo.usageCount(category.id), 0);

      await LifeItemRepository(db).create(
        title: '事项1',
        categoryId: category.id,
        dueTime: DateTime(2026, 7, 1),
      );
      expect(await repo.usageCount(category.id), 1);

      await BillRecordRepository(db).create(
        title: '账单1',
        categoryId: category.id,
        amount: 1000,
        billTime: DateTime(2026, 7, 1),
      );
      expect(await repo.usageCount(category.id), 2);
    });
  });

  group('Category 默认数据播种', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() => db.close());

    test('数据库播种包含收入、支出、事项、项目四类默认分类', () async {
      final income = await db.categoryDao.getByType('income');
      final expense = await db.categoryDao.getByType('expense');
      final item = await db.categoryDao.getByType('item');
      final project = await db.categoryDao.getByType('project');

      expect(income, isNotEmpty);
      expect(expense, isNotEmpty);
      expect(item, isNotEmpty);
      expect(project, isNotEmpty);

      // 所有默认分类标记为 isDefault
      expect(income.every((c) => c.isDefault), isTrue);
      expect(expense.every((c) => c.isDefault), isTrue);
      expect(item.every((c) => c.isDefault), isTrue);
      expect(project.every((c) => c.isDefault), isTrue);
    });

    test('默认分类包含跟拍类别', () async {
      final project = await db.categoryDao.getByType('project');
      expect(project.any((c) => c.name == '跟拍'), isTrue);
    });
  });
}
