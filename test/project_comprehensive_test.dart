import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record_everything/data/database/app_database.dart';
import 'package:record_everything/data/repositories/bill_record_repository.dart';
import 'package:record_everything/data/repositories/life_item_repository.dart';
import 'package:record_everything/data/repositories/project_repository.dart';
import 'package:record_everything/domain/enums/project_event_type.dart';
import 'package:record_everything/domain/enums/project_status.dart';
import 'package:record_everything/core/constants/project_template_keys.dart';

/// 项目管理全业务路径测试。
///
/// 覆盖：
/// - 项目 CRUD 完整生命周期
/// - 项目状态机所有合法/非法流转
/// - 项目模板 CRUD
/// - 从模板创建项目
/// - 复制项目模板
/// - 项目事件管理
/// - 项目与生活事项关联
/// - 项目与账单关联
/// - 项目财务统计
/// - 日期锚点系统（关键日期偏移、创建日期偏移）
/// - 关键日期变更重新计算步骤日期
/// - 软删除与恢复
void main() {
  group('Project CRUD 完整生命周期', () {
    late AppDatabase db;
    late ProjectRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = ProjectRepository(db);
    });

    tearDown(() => db.close());

    test('创建项目默认状态为 active', () async {
      final project = await repo.createProject(title: '测试项目');
      expect(project.projectStatus, 'active');
      expect(project.title, '测试项目');
      expect(project.deletedAt, isNull);
    });

    test('创建带完整参数的项目', () async {
      final project = await repo.createProject(
        title: '完整项目',
        participant: '张三',
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2026, 12, 31),
        totalAmount: 1000000,
        note: '项目备注',
      );
      expect(project.participant, '张三');
      expect(project.startDate, DateTime(2026, 7, 1));
      expect(project.endDate, DateTime(2026, 12, 31));
      expect(project.totalAmount, 1000000);
      expect(project.note, '项目备注');
    });

    test('更新项目内容', () async {
      final project = await repo.createProject(title: '原始标题');
      final updated = project.copyWith(
        title: '更新后标题',
        participant: const Value('李四'),
      );
      await repo.updateProject(updated);
      final fetched = await repo.getById(project.id);
      expect(fetched.title, '更新后标题');
      expect(fetched.participant, '李四');
    });

    test('按 ID 查看项目', () async {
      final project = await repo.createProject(title: '查看项目');
      final fetched = await repo.watchById(project.id).first;
      expect(fetched.id, project.id);
    });

    test('watchAll 返回所有项目', () async {
      await repo.createProject(title: '项目A');
      await repo.createProject(title: '项目B');
      final projects = await repo.watchAll().first;
      expect(projects.length, 2);
    });
  });

  group('Project 状态机全部流转', () {
    late AppDatabase db;
    late ProjectRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = ProjectRepository(db);
    });

    tearDown(() => db.close());

    test('active → completed（标记完成）', () async {
      final project = await repo.createProject(title: '完成项目');
      final updated = await repo.changeStatus(project, ProjectStatus.completed);
      expect(updated.projectStatus, 'completed');
    });

    test('active → cancelled（取消项目）', () async {
      final project = await repo.createProject(title: '取消项目');
      final updated = await repo.changeStatus(project, ProjectStatus.cancelled);
      expect(updated.projectStatus, 'cancelled');
    });

    test('completed → archived（归档）', () async {
      final project = await repo.createProject(title: '归档项目');
      await repo.changeStatus(project, ProjectStatus.completed);
      final archived = await repo.changeStatus(
        project.copyWith(projectStatus: 'completed'),
        ProjectStatus.archived,
      );
      expect(archived.projectStatus, 'archived');
    });

    test('completed → active（重新激活）', () async {
      final project = await repo.createProject(title: '重激活项目');
      await repo.changeStatus(project, ProjectStatus.completed);
      final reactivated = await repo.changeStatus(
        project.copyWith(projectStatus: 'completed'),
        ProjectStatus.active,
      );
      expect(reactivated.projectStatus, 'active');
    });

    test('cancelled → active（重新激活）', () async {
      final project = await repo.createProject(title: '取消后激活');
      await repo.changeStatus(project, ProjectStatus.cancelled);
      final reactivated = await repo.changeStatus(
        project.copyWith(projectStatus: 'cancelled'),
        ProjectStatus.active,
      );
      expect(reactivated.projectStatus, 'active');
    });

    test('archived → active（重新激活）', () async {
      final project = await repo.createProject(title: '归档后激活');
      await repo.changeStatus(project, ProjectStatus.completed);
      await repo.changeStatus(
        project.copyWith(projectStatus: 'completed'),
        ProjectStatus.archived,
      );
      final reactivated = await repo.changeStatus(
        project.copyWith(projectStatus: 'archived'),
        ProjectStatus.active,
      );
      expect(reactivated.projectStatus, 'active');
    });

    test('active 不能直接 archived', () async {
      final project = await repo.createProject(title: '非法流转');
      expect(
        () => repo.changeStatus(project, ProjectStatus.archived),
        throwsA(isA<StateError>()),
      );
    });

    test('cancelled 不能直接 archived', () async {
      final project = await repo.createProject(title: '非法流转');
      await repo.changeStatus(project, ProjectStatus.cancelled);
      expect(
        () => repo.changeStatus(
          project.copyWith(projectStatus: 'cancelled'),
          ProjectStatus.archived,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('状态变更自动记录事件', () async {
      final project = await repo.createProject(title: '事件项目');
      await repo.changeStatus(project, ProjectStatus.completed);

      final events = await repo.watchProjectEvents(project.id).first;
      expect(events, hasLength(1));
      expect(events.first.eventType, ProjectEventType.statusChange.value);
      expect(events.first.title, '状态变更: 进行中 -> 已完成');
      expect(events.first.isSystem, isTrue);
    });

    test('非法状态变更不产生事件', () async {
      final project = await repo.createProject(title: '无事件项目');
      try {
        await repo.changeStatus(project, ProjectStatus.archived);
      } catch (_) {}

      final events = await repo.watchProjectEvents(project.id).first;
      expect(events, isEmpty);
    });
  });

  group('Project 模板 CRUD', () {
    late AppDatabase db;
    late ProjectRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = ProjectRepository(db);
    });

    tearDown(() => db.close());

    test('创建自定义模板', () async {
      final template = await repo.createProjectTemplate(
        name: '自定义模板',
        note: '模板说明',
        steps: const [
          ProjectTemplateStepInput(
            title: '步骤一',
            amountType: 'none',
            offsetDays: 0,
          ),
          ProjectTemplateStepInput(
            title: '步骤二',
            amountType: 'income',
            amount: 100000,
            offsetDays: 7,
          ),
        ],
      );

      expect(template.name, '自定义模板');
      expect(template.note, '模板说明');
      expect(template.isDefault, isFalse);

      final steps = await repo.getTemplateSteps(template.id);
      expect(steps, hasLength(2));
      expect(steps.first.title, '步骤一');
      expect(steps.last.title, '步骤二');
      expect(steps.last.amount, 100000);
    });

    test('更新模板内容和步骤', () async {
      final template = await repo.createProjectTemplate(
        name: '原始模板',
        steps: const [
          ProjectTemplateStepInput(
            title: '原始步骤',
            amountType: 'none',
            offsetDays: 0,
          ),
        ],
      );

      await repo.updateProjectTemplate(
        template: template.copyWith(name: '更新后模板'),
        steps: const [
          ProjectTemplateStepInput(
            title: '新步骤一',
            amountType: 'none',
            offsetDays: 0,
          ),
          ProjectTemplateStepInput(
            title: '新步骤二',
            amountType: 'expense',
            amount: 50000,
            offsetDays: 3,
          ),
        ],
      );

      final updated = await repo.getTemplateById(template.id);
      expect(updated.name, '更新后模板');

      final steps = await repo.getTemplateSteps(template.id);
      expect(steps, hasLength(2));
      expect(steps.first.title, '新步骤一');
      expect(steps.last.title, '新步骤二');
    });

    test('删除模板', () async {
      final template = await repo.createProjectTemplate(
        name: '待删除模板',
        steps: const [
          ProjectTemplateStepInput(
            title: '步骤',
            amountType: 'none',
            offsetDays: 0,
          ),
        ],
      );

      await repo.deleteProjectTemplate(template.id);
      final templates = await repo.watchTemplates().first;
      expect(templates.any((t) => t.id == template.id), isFalse);
    });

    test('watchTemplates 返回所有模板', () async {
      await repo.createProjectTemplate(
        name: '模板A',
        steps: const [
          ProjectTemplateStepInput(
            title: '步骤',
            amountType: 'none',
            offsetDays: 0,
          ),
        ],
      );
      await repo.createProjectTemplate(
        name: '模板B',
        steps: const [
          ProjectTemplateStepInput(
            title: '步骤',
            amountType: 'none',
            offsetDays: 0,
          ),
        ],
      );

      final templates = await repo.watchTemplates().first;
      expect(templates.length, greaterThanOrEqualTo(2));
    });
  });

  group('Project 从模板创建', () {
    late AppDatabase db;
    late ProjectRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = ProjectRepository(db);
    });

    tearDown(() => db.close());

    test('从自定义模板创建项目并生成步骤事项', () async {
      final template = await repo.createProjectTemplate(
        name: '接单模板',
        steps: const [
          ProjectTemplateStepInput(
            title: '确认需求',
            amountType: 'none',
            offsetDays: 0,
          ),
          ProjectTemplateStepInput(
            title: '收定金',
            amountType: 'income',
            amount: 50000,
            offsetDays: 3,
          ),
          ProjectTemplateStepInput(
            title: '交付',
            amountType: 'none',
            offsetDays: 14,
          ),
          ProjectTemplateStepInput(
            title: '收尾款',
            amountType: 'income',
            amount: 50000,
            offsetDays: 15,
          ),
        ],
      );

      final steps = (await repo.getTemplateSteps(template.id))
          .map(ProjectTemplateStepInput.fromTemplateStep)
          .toList(growable: false);

      final project = await repo.createProjectFromTemplate(
        template: template,
        steps: steps,
        title: '客户A项目',
        participant: '客户A',
        startDate: DateTime(2026, 8, 1),
      );

      expect(project.templateKey, 'custom:${template.id}');

      final items = await db.lifeItemDao.watchByProjectId(project.id).first;
      expect(items, hasLength(4));
      expect(items.map((i) => i.title), [
        '确认需求',
        '收定金',
        '交付',
        '收尾款',
      ]);
      expect(items.where((i) => i.amountType == 'income'), hasLength(2));
    });

    test('从内置婚纱摄影模板创建项目', () async {
      final template = await repo.getTemplateByKey(
        ProjectTemplateKeys.weddingPhotography,
      );
      expect(template, isNotNull);

      final steps = (await repo.getTemplateSteps(template!.id))
          .map(ProjectTemplateStepInput.fromTemplateStep)
          .toList(growable: false);

      final project = await repo.createProjectFromTemplate(
        template: template,
        steps: steps,
        title: '王先生婚礼跟拍',
        participant: '王先生',
        startDate: DateTime(2026, 10, 1),
      );

      expect(project.templateKey, ProjectTemplateKeys.weddingPhotography);
      final items = await db.lifeItemDao.watchByProjectId(project.id).first;
      expect(items, hasLength(5));
    });

    test('从内置证件摄影模板创建项目', () async {
      final template = await repo.getTemplateByKey(
        ProjectTemplateKeys.certificatePhotography,
      );
      expect(template, isNotNull);

      final steps = (await repo.getTemplateSteps(template!.id))
          .map(ProjectTemplateStepInput.fromTemplateStep)
          .toList(growable: false);

      final project = await repo.createProjectFromTemplate(
        template: template,
        steps: steps,
        title: '证件照拍摄',
        startDate: DateTime(2026, 9, 1),
      );

      final items = await db.lifeItemDao.watchByProjectId(project.id).first;
      expect(items, hasLength(4));
    });
  });

  group('Project 复制模板', () {
    late AppDatabase db;
    late ProjectRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = ProjectRepository(db);
    });

    tearDown(() => db.close());

    test('复制内置模板', () async {
      final original = await repo.getTemplateByKey(
        ProjectTemplateKeys.weddingPhotography,
      );
      expect(original, isNotNull);

      final copy = await repo.duplicateProjectTemplate(original!.id);

      expect(copy.id, isNot(original.id));
      expect(copy.name, '${original.name} 副本');
      expect(copy.templateKey, isNull);
      expect(copy.isDefault, isFalse);
      expect(copy.categoryId, original.categoryId);

      final copySteps = await repo.getTemplateSteps(copy.id);
      final originalSteps = await repo.getTemplateSteps(original.id);
      expect(copySteps.length, originalSteps.length);
    });

    test('复制自定义模板', () async {
      final original = await repo.createProjectTemplate(
        name: '自定义模板',
        note: '说明',
        steps: const [
          ProjectTemplateStepInput(
            title: '步骤一',
            amountType: 'none',
            offsetDays: 0,
          ),
        ],
      );

      final copy = await repo.duplicateProjectTemplate(original.id);
      expect(copy.name, '自定义模板 副本');
      expect(copy.note, '说明');

      final copySteps = await repo.getTemplateSteps(copy.id);
      expect(copySteps.first.title, '步骤一');
    });
  });

  group('Project 事件管理', () {
    late AppDatabase db;
    late ProjectRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = ProjectRepository(db);
    });

    tearDown(() => db.close());

    test('添加项目事件', () async {
      final project = await repo.createProject(title: '事件项目');
      final event = await repo.addEvent(
        projectId: project.id,
        eventType: ProjectEventType.note.value,
        title: '客户反馈',
        description: '客户对初稿满意',
        eventTime: DateTime(2026, 7, 15),
      );

      expect(event.projectId, project.id);
      expect(event.title, '客户反馈');
      expect(event.isSystem, isFalse);
    });

    test('添加系统事件', () async {
      final project = await repo.createProject(title: '系统事件项目');
      final event = await repo.addEvent(
        projectId: project.id,
        eventType: ProjectEventType.statusChange.value,
        title: '状态变更',
        eventTime: DateTime(2026, 7, 15),
        isSystem: true,
      );

      expect(event.isSystem, isTrue);
    });

    test('watchProjectEvents 返回项目所有事件', () async {
      final project = await repo.createProject(title: '多事件项目');
      await repo.addEvent(
        projectId: project.id,
        eventType: ProjectEventType.note.value,
        title: '事件1',
        eventTime: DateTime(2026, 7, 1),
      );
      await repo.addEvent(
        projectId: project.id,
        eventType: ProjectEventType.milestone.value,
        title: '事件2',
        eventTime: DateTime(2026, 7, 15),
      );

      final events = await repo.watchProjectEvents(project.id).first;
      expect(events, hasLength(2));
    });
  });

  group('Project 与生活事项关联', () {
    late AppDatabase db;
    late ProjectRepository projectRepo;
    late LifeItemRepository itemRepo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      projectRepo = ProjectRepository(db);
      itemRepo = LifeItemRepository(db);
    });

    tearDown(() => db.close());

    test('watchProjectLifeItems 返回项目下的事项', () async {
      final project = await projectRepo.createProject(title: '关联项目');
      await itemRepo.create(
        title: '项目事项A',
        dueTime: DateTime(2026, 7, 1),
        projectId: project.id,
      );
      await itemRepo.create(
        title: '项目事项B',
        dueTime: DateTime(2026, 7, 15),
        projectId: project.id,
      );
      await itemRepo.create(
        title: '独立事项',
        dueTime: DateTime(2026, 7, 1),
      );

      final items = await projectRepo.watchProjectLifeItems(project.id).first;
      expect(items, hasLength(2));
      expect(items.any((i) => i.title == '独立事项'), isFalse);
    });
  });

  group('Project 与账单关联', () {
    late AppDatabase db;
    late ProjectRepository projectRepo;
    late BillRecordRepository billRepo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      projectRepo = ProjectRepository(db);
      billRepo = BillRecordRepository(db);
    });

    tearDown(() => db.close());

    test('watchProjectBills 返回项目下的账单', () async {
      final project = await projectRepo.createProject(title: '账单项目');
      await billRepo.create(
        title: '项目收入',
        amount: 100000,
        amountType: 'income',
        billTime: DateTime(2026, 7, 1),
        projectId: project.id,
      );
      await billRepo.create(
        title: '项目支出',
        amount: 30000,
        amountType: 'expense',
        billTime: DateTime(2026, 7, 10),
        projectId: project.id,
      );

      final bills = await projectRepo.watchProjectBills(project.id).first;
      expect(bills, hasLength(2));
    });

    test('watchProjectIncome 返回项目收入总额', () async {
      final project = await projectRepo.createProject(title: '收入项目');
      await billRepo.create(
        title: '收入1',
        amount: 100000,
        amountType: 'income',
        billTime: DateTime(2026, 7, 1),
        projectId: project.id,
      );
      await billRepo.create(
        title: '收入2',
        amount: 50000,
        amountType: 'income',
        billTime: DateTime(2026, 7, 15),
        projectId: project.id,
      );

      final income = await projectRepo.watchProjectIncome(project.id).first;
      expect(income, 150000);
    });

    test('watchProjectExpense 返回项目支出总额', () async {
      final project = await projectRepo.createProject(title: '支出项目');
      await billRepo.create(
        title: '支出1',
        amount: 20000,
        amountType: 'expense',
        billTime: DateTime(2026, 7, 1),
        projectId: project.id,
      );
      await billRepo.create(
        title: '支出2',
        amount: 10000,
        amountType: 'expense',
        billTime: DateTime(2026, 7, 15),
        projectId: project.id,
      );

      final expense = await projectRepo.watchProjectExpense(project.id).first;
      expect(expense, 30000);
    });
  });

  group('Project 日期锚点系统', () {
    late AppDatabase db;
    late ProjectRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = ProjectRepository(db);
    });

    tearDown(() => db.close());

    test('关键日期偏移步骤正确计算到期日', () async {
      final template = await repo.createProjectTemplate(
        name: '关键日期模板',
        steps: const [
          ProjectTemplateStepInput(
            title: '拍摄日前7天',
            amountType: 'none',
            keyDateOffsetDays: -7,
          ),
          ProjectTemplateStepInput(
            title: '拍摄日当天',
            amountType: 'none',
            keyDateOffsetDays: 0,
          ),
          ProjectTemplateStepInput(
            title: '拍摄日后15天',
            amountType: 'none',
            keyDateOffsetDays: 15,
          ),
        ],
      );

      final steps = (await repo.getTemplateSteps(template.id))
          .map(ProjectTemplateStepInput.fromTemplateStep)
          .toList(growable: false);

      final project = await repo.createProjectFromTemplate(
        template: template,
        steps: steps,
        title: '关键日期项目',
        startDate: DateTime(2026, 10, 1),
      );

      final items = await db.lifeItemDao.watchByProjectId(project.id).first;
      final item1 = items.singleWhere((i) => i.title == '拍摄日前7天');
      final item2 = items.singleWhere((i) => i.title == '拍摄日当天');
      final item3 = items.singleWhere((i) => i.title == '拍摄日后15天');

      expect(item1.dueTime, DateTime(2026, 9, 24));
      expect(item2.dueTime, DateTime(2026, 10, 1));
      expect(item3.dueTime, DateTime(2026, 10, 16));
      expect(item1.projectDateAnchor, 'keyDate');
      expect(item1.projectDateManuallyEdited, isFalse);
    });

    test('创建日期偏移步骤正确计算到期日', () async {
      final template = await repo.createProjectTemplate(
        name: '创建日期模板',
        steps: const [
          ProjectTemplateStepInput(
            title: '创建后3天',
            amountType: 'none',
            createdDateOffsetDays: 3,
          ),
          ProjectTemplateStepInput(
            title: '创建后7天',
            amountType: 'none',
            createdDateOffsetDays: 7,
          ),
        ],
      );

      final steps = (await repo.getTemplateSteps(template.id))
          .map(ProjectTemplateStepInput.fromTemplateStep)
          .toList(growable: false);

      final project = await repo.createProjectFromTemplate(
        template: template,
        steps: steps,
        title: '创建日期项目',
        startDate: DateTime(2026, 10, 1),
      );

      final items = await db.lifeItemDao.watchByProjectId(project.id).first;
      final createdDate = DateTime(
        project.createdAt.year,
        project.createdAt.month,
        project.createdAt.day,
      );

      final item1 = items.singleWhere((i) => i.title == '创建后3天');
      final item2 = items.singleWhere((i) => i.title == '创建后7天');

      expect(item1.dueTime, createdDate.add(const Duration(days: 3)));
      expect(item2.dueTime, createdDate.add(const Duration(days: 7)));
      expect(item1.projectDateAnchor, 'createdDate');
    });

    test('关键日期变更重新计算未手动编辑的步骤', () async {
      final template = await repo.createProjectTemplate(
        name: '联动模板',
        steps: const [
          ProjectTemplateStepInput(
            title: '关键日期前5天',
            amountType: 'none',
            keyDateOffsetDays: -5,
          ),
          ProjectTemplateStepInput(
            title: '关键日期后10天',
            amountType: 'none',
            keyDateOffsetDays: 10,
          ),
        ],
      );

      final steps = (await repo.getTemplateSteps(template.id))
          .map(ProjectTemplateStepInput.fromTemplateStep)
          .toList(growable: false);

      final project = await repo.createProjectFromTemplate(
        template: template,
        steps: steps,
        title: '联动项目',
        startDate: DateTime(2026, 8, 1),
      );

      // 修改关键日期
      await repo.updateProject(
        project.copyWith(startDate: Value(DateTime(2026, 8, 20))),
      );

      final items = await db.lifeItemDao.watchByProjectId(project.id).first;
      final item1 = items.singleWhere((i) => i.title == '关键日期前5天');
      final item2 = items.singleWhere((i) => i.title == '关键日期后10天');

      expect(item1.dueTime, DateTime(2026, 8, 15));
      expect(item2.dueTime, DateTime(2026, 8, 30));
    });

    test('手动编辑的步骤不受关键日期变更影响', () async {
      final itemRepo = LifeItemRepository(db);
      final template = await repo.createProjectTemplate(
        name: '手动编辑模板',
        steps: const [
          ProjectTemplateStepInput(
            title: '自动步骤',
            amountType: 'none',
            keyDateOffsetDays: 5,
          ),
        ],
      );

      final steps = (await repo.getTemplateSteps(template.id))
          .map(ProjectTemplateStepInput.fromTemplateStep)
          .toList(growable: false);

      final project = await repo.createProjectFromTemplate(
        template: template,
        steps: steps,
        title: '手动编辑项目',
        startDate: DateTime(2026, 8, 1),
      );

      // 手动编辑步骤日期
      final items = await db.lifeItemDao.watchByProjectId(project.id).first;
      final item = items.first;
      await itemRepo.updateItem(
        item.copyWith(dueTime: DateTime(2026, 12, 25)),
      );

      // 修改关键日期
      await repo.updateProject(
        project.copyWith(startDate: Value(DateTime(2026, 9, 1))),
      );

      final finalItem = await db.lifeItemDao.getById(item.id);
      expect(finalItem.dueTime, DateTime(2026, 12, 25));
      expect(finalItem.projectDateManuallyEdited, isTrue);
    });
  });

  group('Project 软删除与恢复', () {
    late AppDatabase db;
    late ProjectRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = ProjectRepository(db);
    });

    tearDown(() => db.close());

    test('软删除后不在活跃列表中', () async {
      final project = await repo.createProject(title: '删除项目');
      await repo.softDeleteProject(project.id);
      final all = await db.projectDao.getAll();
      expect(all.where((p) => p.id == project.id), isEmpty);
    });

    test('恢复软删除的项目', () async {
      final project = await repo.createProject(title: '恢复项目');
      await repo.softDeleteProject(project.id);
      await repo.restoreProject(project.id);
      final all = await db.projectDao.getAll();
      expect(all.where((p) => p.id == project.id), isNotEmpty);
    });

    test('永久删除后无法恢复', () async {
      final project = await repo.createProject(title: '永久删除');
      await repo.permanentDeleteProject(project.id);
      final all = await db.projectDao.getAll();
      expect(all, isEmpty);
    });
  });

  group('Project 筛选查询', () {
    late AppDatabase db;
    late ProjectRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = ProjectRepository(db);
    });

    tearDown(() => db.close());

    test('watchByStatus 按状态筛选', () async {
      await repo.createProject(title: '活跃项目');
      final completed = await repo.createProject(title: '完成项目');
      await repo.changeStatus(completed, ProjectStatus.completed);

      final active = await repo.watchByStatus('active').first;
      expect(active.any((p) => p.title == '活跃项目'), isTrue);
      expect(active.any((p) => p.title == '完成项目'), isFalse);
    });

    test('hasLinkedRecords 检查项目是否有关联记录', () async {
      final project = await repo.createProject(title: '有记录项目');
      final hasLinked = await repo.hasLinkedRecords(project.id);
      expect(hasLinked, isFalse);

      // 添加关联事项
      await db.lifeItemDao.insertOne(
        LifeItemsCompanion.insert(
          title: '关联事项',
          dueTime: DateTime(2026, 7, 1),
          projectId: Value(project.id),
        ),
      );

      final hasLinkedAfter = await repo.hasLinkedRecords(project.id);
      expect(hasLinkedAfter, isTrue);
    });
  });
}
