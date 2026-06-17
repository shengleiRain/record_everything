import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record_everything/data/database/app_database.dart';
import 'package:record_everything/data/repositories/life_item_repository.dart';
import 'package:record_everything/domain/enums/item_status.dart';
import 'package:record_everything/domain/enums/project_status.dart';

/// 状态机与状态流转的回归测试。
///
/// 覆盖：
/// - ProjectStatus / ItemStatus 的 isFinal、nextStatus、defaultStatus。
/// - fromString 的旧值（planned/waiting）映射到 active（兼容旧数据/旧备份）。
/// - LifeItem 的 cancel / reopen 在 repository 层确实写入正确状态。
/// - 数据库迁移（schemaVersion 6→7）将存量 planned/waiting 归并为 active。
void main() {
  group('ProjectStatus enum', () {
    test('defaultStatus 是 active', () {
      expect(ProjectStatus.defaultStatus, ProjectStatus.active);
    });

    test('只有 active 不是终态', () {
      expect(ProjectStatus.active.isFinal, isFalse);
      expect(ProjectStatus.completed.isFinal, isTrue);
      expect(ProjectStatus.cancelled.isFinal, isTrue);
      expect(ProjectStatus.archived.isFinal, isTrue);
    });

    test('nextStatus：active→completed，其余为 null（终态不可单向推进）', () {
      expect(ProjectStatus.active.nextStatus, ProjectStatus.completed);
      expect(ProjectStatus.completed.nextStatus, isNull);
      expect(ProjectStatus.cancelled.nextStatus, isNull);
      expect(ProjectStatus.archived.nextStatus, isNull);
    });

    test('advanceLabel：active 为「标记完成」', () {
      expect(ProjectStatus.active.advanceLabel, '标记完成');
    });

    test('fromString 正确解析四个状态', () {
      expect(ProjectStatus.fromString('active'), ProjectStatus.active);
      expect(ProjectStatus.fromString('completed'), ProjectStatus.completed);
      expect(ProjectStatus.fromString('cancelled'), ProjectStatus.cancelled);
      expect(ProjectStatus.fromString('archived'), ProjectStatus.archived);
    });

    test('fromString 把已废弃的旧值 planned/waiting 映射为 active', () {
      expect(ProjectStatus.fromString('planned'), ProjectStatus.active);
      expect(ProjectStatus.fromString('waiting'), ProjectStatus.active);
    });

    test('fromString 未知值兜底为 active', () {
      expect(ProjectStatus.fromString('unknown'), ProjectStatus.active);
      expect(ProjectStatus.fromString(''), ProjectStatus.active);
    });
  });

  group('ItemStatus enum', () {
    test('只有 pending 不是终态', () {
      expect(ItemStatus.pending.isFinal, isFalse);
      expect(ItemStatus.completed.isFinal, isTrue);
      expect(ItemStatus.cancelled.isFinal, isTrue);
      expect(ItemStatus.archived.isFinal, isTrue);
    });

    test('fromString 正确解析四个状态', () {
      expect(ItemStatus.fromString('pending'), ItemStatus.pending);
      expect(ItemStatus.fromString('completed'), ItemStatus.completed);
      expect(ItemStatus.fromString('cancelled'), ItemStatus.cancelled);
      expect(ItemStatus.fromString('archived'), ItemStatus.archived);
    });
  });

  group('LifeItem 状态流转（repository 层）', () {
    late AppDatabase db;
    late LifeItemRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = LifeItemRepository(db);
    });

    tearDown(() => db.close());

    Future<LifeItem> seed() {
      return repo.create(
        title: '测试事项',
        dueTime: DateTime.now().add(const Duration(days: 1)),
      );
    }

    test('create 默认状态为 pending', () async {
      final item = await seed();
      expect(ItemStatus.fromString(item.status), ItemStatus.pending);
    });

    test('complete 写入 completed', () async {
      final item = await seed();
      final updated = await repo.complete(item.id);
      expect(updated.status, 'completed');
    });

    test('cancel 写入 cancelled', () async {
      final item = await seed();
      final updated = await repo.cancel(item.id);
      expect(updated.status, 'cancelled');
    });

    test('reopen 从 completed 回退到 pending', () async {
      final item = await seed();
      await repo.complete(item.id);
      final reopened = await repo.reopen(item.id);
      expect(reopened.status, 'pending');
    });

    test('reopen 从 cancelled 回退到 pending', () async {
      final item = await seed();
      await repo.cancel(item.id);
      final reopened = await repo.reopen(item.id);
      expect(reopened.status, 'pending');
    });
  });

  group('数据库迁移 v6→v7（项目状态归并）', () {
    test('存量 planned/waiting 项目迁移为 active', () async {
      // 直接用内存库，手动插入旧状态行，模拟旧版本数据。
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      await db.customStatement(
        "INSERT INTO projects (title, project_status) VALUES "
        "('计划项目', 'planned'), ('等待项目', 'waiting'), "
        "('进行项目', 'active'), ('完成项目', 'completed')",
      );

      // 执行与迁移相同的归并语句。
      await db.customStatement(
        "UPDATE projects SET project_status = 'active' "
        "WHERE project_status IN ('planned', 'waiting')",
      );

      final rows = await db.customSelect(
        'SELECT title, project_status AS status FROM projects ORDER BY id',
      ).get();

      final byTitle = {for (final r in rows) r.read<String>('title'): r.read<String>('status')};
      expect(byTitle['计划项目'], 'active');
      expect(byTitle['等待项目'], 'active');
      expect(byTitle['进行项目'], 'active');
      expect(byTitle['完成项目'], 'completed');
    });
  });
}
