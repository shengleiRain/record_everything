import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record_everything/data/database/app_database.dart';
import 'package:record_everything/data/database/database_provider.dart';
import 'package:record_everything/data/repositories/bill_record_repository.dart';
import 'package:record_everything/data/repositories/life_item_repository.dart';
import 'package:record_everything/data/repositories/project_repository.dart';
import 'package:record_everything/domain/enums/project_event_type.dart';
import 'package:record_everything/core/constants/project_template_keys.dart';
import 'package:record_everything/features/project/providers/project_providers.dart';
import 'package:record_everything/features/settings/services/backup_service.dart';

void main() {
  group('Project module', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() => db.close());

    test('wedding template creates payment and timeline items', () async {
      final repo = ProjectRepository(db);
      final template = await repo.getTemplateByKey(
        ProjectTemplateKeys.weddingPhotography,
      );

      final steps = (await repo.getTemplateSteps(template!.id))
          .map(ProjectTemplateStepInput.fromTemplateStep)
          .toList(growable: false);

      final project = await repo.createProjectFromTemplate(
        template: template,
        steps: steps,
        title: '婚礼跟拍',
        startDate: DateTime(2026, 7, 1),
        participant: '张三',
      );

      final items = await db.lifeItemDao.watchByProjectId(project.id).first;

      expect(template.isDefault, isTrue);
      expect(project.templateKey, ProjectTemplateKeys.weddingPhotography);
      // 节点按到期时间排序，断言集合而非严格顺序（顺序取决于「今天」与
      // 关键日期的相对位置，会随日历变化）。
      expect(items.map((item) => item.title).toSet(), {
        '定金',
        '拍摄',
        '交付预告片',
        '交付剩余照片',
        '尾款',
      });
      expect(items, hasLength(5));
      expect(items.where((item) => item.amountType == 'income'), hasLength(2));
    });

    test(
      'manual project steps are saved when no template is selected',
      () async {
        final container = ProviderContainer(
          overrides: [databaseProvider.overrideWithValue(db)],
        );
        addTearDown(container.dispose);

        final project = await container
            .read(projectNotifierProvider.notifier)
            .create(
              title: '无模板项目',
              startDate: DateTime(2026, 7, 1),
              steps: [
                ProjectTemplateStepInput(
                  title: '确认需求',
                  amountType: 'none',
                  absoluteDueTime: DateTime(2026, 7, 1),
                ),
                ProjectTemplateStepInput(
                  title: '收首款',
                  amountType: 'income',
                  amount: 120000,
                  absoluteDueTime: DateTime(2026, 7, 3),
                ),
              ],
            );

        final items = await db.lifeItemDao.watchByProjectId(project.id).first;

        expect(items.map((item) => item.title), ['确认需求', '收首款']);
        expect(items.first.dueTime, DateTime(2026, 7, 1));
        expect(items.last.dueTime, DateTime(2026, 7, 3));
        expect(items.last.amountType, 'income');
        expect(items.last.amount, 120000);
        expect(items.first.projectDateAnchor, null);
        expect(items.last.projectDateAnchor, null);
      },
    );

    test('template steps support key-date and creation-date offsets', () async {
      final repo = ProjectRepository(db);
      final template = await repo.createProjectTemplate(
        name: '双基准模板',
        steps: const [
          ProjectTemplateStepInput(
            title: '关键日期后',
            amountType: 'none',
            keyDateOffsetDays: 2,
          ),
          ProjectTemplateStepInput(
            title: '创建日期后',
            amountType: 'none',
            createdDateOffsetDays: 5,
          ),
        ],
      );

      final savedSteps = await repo.getTemplateSteps(template.id);
      expect(savedSteps.first.keyDateOffsetDays, 2);
      expect(savedSteps.first.createdDateOffsetDays, null);
      expect(savedSteps.last.keyDateOffsetDays, null);
      expect(savedSteps.last.createdDateOffsetDays, 5);

      final project = await repo.createProjectFromTemplate(
        template: template,
        steps: savedSteps
            .map(ProjectTemplateStepInput.fromTemplateStep)
            .toList(growable: false),
        title: '使用双基准模板',
        startDate: DateTime(2026, 8, 1),
      );
      final items = await db.lifeItemDao.watchByProjectId(project.id).first;
      final createdDate = DateTime(
        project.createdAt.year,
        project.createdAt.month,
        project.createdAt.day,
      );

      expect(items.map((item) => item.title), ['创建日期后', '关键日期后']);
      final createdItem = items.firstWhere((item) => item.title == '创建日期后');
      final keyItem = items.firstWhere((item) => item.title == '关键日期后');
      expect(keyItem.dueTime, DateTime(2026, 8, 3));
      expect(createdItem.dueTime, createdDate.add(const Duration(days: 5)));
      expect(keyItem.projectDateAnchor, 'keyDate');
      expect(keyItem.projectDateOffsetDays, 2);
      expect(keyItem.projectDateManuallyEdited, isFalse);
      expect(createdItem.projectDateAnchor, 'createdDate');
      expect(createdItem.projectDateOffsetDays, 5);
    });

    test(
      'project key date changes recalculate template items until manually edited',
      () async {
        final repo = ProjectRepository(db);
        final itemRepo = LifeItemRepository(db);
        final template = await repo.createProjectTemplate(
          name: '关键日期联动模板',
          steps: const [
            ProjectTemplateStepInput(
              title: '拍摄日后确认',
              amountType: 'none',
              keyDateOffsetDays: 2,
            ),
            ProjectTemplateStepInput(
              title: '建档后回访',
              amountType: 'none',
              createdDateOffsetDays: 3,
            ),
          ],
        );

        final savedSteps = await repo.getTemplateSteps(template.id);
        final project = await repo.createProjectFromTemplate(
          template: template,
          steps: savedSteps
              .map(ProjectTemplateStepInput.fromTemplateStep)
              .toList(growable: false),
          title: '联动项目',
          startDate: DateTime(2026, 8, 1),
        );

        await repo.updateProject(
          project.copyWith(startDate: Value(DateTime(2026, 8, 10))),
        );
        final movedItems = await db.lifeItemDao
            .watchByProjectId(project.id)
            .first;
        final keyItem = movedItems.singleWhere(
          (item) => item.title == '拍摄日后确认',
        );
        final createdItem = movedItems.singleWhere(
          (item) => item.title == '建档后回访',
        );

        expect(keyItem.dueTime, DateTime(2026, 8, 12));
        expect(createdItem.dueTime, isNot(DateTime(2026, 8, 13)));

        await itemRepo.updateItem(
          keyItem.copyWith(dueTime: DateTime(2026, 9, 1)),
        );
        final manuallyMoved = await db.lifeItemDao.getById(keyItem.id);
        expect(manuallyMoved.projectDateManuallyEdited, isTrue);

        await repo.updateProject(
          project.copyWith(startDate: Value(DateTime(2026, 8, 20))),
        );
        final finalKeyItem = await db.lifeItemDao.getById(keyItem.id);

        expect(finalKeyItem.dueTime, DateTime(2026, 9, 1));
      },
    );

    test('template edits affect generated project items', () async {
      final repo = ProjectRepository(db);
      final template = await repo.getTemplateByKey(
        ProjectTemplateKeys.weddingPhotography,
      );
      expect(template == null, isFalse);

      await repo.updateProjectTemplate(
        template: template!.copyWith(name: '我的跟拍流程'),
        steps: const [
          ProjectTemplateStepInput(
            title: '确认档期',
            amountType: 'none',
            offsetDays: -10,
          ),
          ProjectTemplateStepInput(
            title: '收预约款',
            amountType: 'income',
            amount: 100000,
            offsetDays: -7,
          ),
        ],
      );

      final updatedTemplate = await repo.getTemplateById(template.id);
      final steps = (await repo.getTemplateSteps(template.id))
          .map(
            (step) => ProjectTemplateStepInput(
              title: step.title,
              amountType: step.amountType,
              amount: step.amount,
              offsetDays: step.offsetDays,
            ),
          )
          .toList(growable: false);

      final project = await repo.createProjectFromTemplate(
        template: updatedTemplate,
        steps: steps,
        title: '写真拍摄',
        participant: '李四',
        startDate: DateTime(2026, 9, 20),
      );
      final items = await db.lifeItemDao.watchByProjectId(project.id).first;

      expect(project.templateKey, ProjectTemplateKeys.weddingPhotography);
      expect(items.map((item) => item.title), ['确认档期', '收预约款']);
      expect(items.first.dueTime, DateTime(2026, 9, 10));
      expect(items.last.amount, 100000);
    });

    test(
      'preset project templates can be deleted like custom templates',
      () async {
        final repo = ProjectRepository(db);
        final template = await repo.getTemplateByKey(
          ProjectTemplateKeys.weddingPhotography,
        );
        expect(template != null, isTrue);

        await repo.deleteProjectTemplate(template!.id);

        final byKey = await repo.getTemplateByKey(
          ProjectTemplateKeys.weddingPhotography,
        );
        final templates = await db.projectTemplateDao.getAll();

        expect(byKey == null, isTrue);
        expect(templates.any((row) => row.id == template.id), isFalse);
      },
    );

    test(
      'life item and bill updates preserve editable project relation',
      () async {
        final project = await ProjectRepository(
          db,
        ).createProject(title: '客户项目');
        final itemRepo = LifeItemRepository(db);
        final billRepo = BillRecordRepository(db);

        final item = await itemRepo.create(
          title: '收定金',
          amountType: 'income',
          amount: 120000,
          dueTime: DateTime(2026, 7, 1),
        );
        await itemRepo.updateItem(item.copyWith(projectId: Value(project.id)));
        final updatedItem = await db.lifeItemDao.getById(item.id);

        final bill = await billRepo.create(
          title: '定金到账',
          amount: 120000,
          amountType: 'income',
          billTime: DateTime(2026, 7, 2),
        );
        await billRepo.updateRecord(
          bill.copyWith(projectId: Value(project.id)),
        );
        final updatedBill = await db.billRecordDao.getById(bill.id);

        expect(updatedItem.projectId, project.id);
        expect(updatedItem.amountType, 'income');
        expect(updatedBill.projectId, project.id);
      },
    );

    test(
      'custom project template can be edited and used to create project items',
      () async {
        final repo = ProjectRepository(db);

        final template = await repo.createProjectTemplate(
          name: '轻量接单',
          note: '默认流程',
          steps: const [
            ProjectTemplateStepInput(
              title: '确认需求',
              amountType: 'none',
              offsetDays: 0,
            ),
            ProjectTemplateStepInput(
              title: '收预付款',
              amountType: 'income',
              amount: 100000,
              offsetDays: 1,
            ),
          ],
        );

        await repo.updateProjectTemplate(
          template: template.copyWith(
            name: '轻量项目模板',
            note: const Value('可编辑默认节点'),
          ),
          steps: const [
            ProjectTemplateStepInput(
              title: '签约确认',
              amountType: 'none',
              offsetDays: 0,
            ),
            ProjectTemplateStepInput(
              title: '收尾款',
              amountType: 'income',
              amount: 200000,
              offsetDays: 14,
            ),
          ],
        );

        final updatedTemplate = await repo.getTemplateById(template.id);
        final steps = (await repo.getTemplateSteps(template.id))
            .map(
              (step) => ProjectTemplateStepInput(
                title: step.title,
                amountType: step.amountType,
                amount: step.amount,
                offsetDays: step.offsetDays,
              ),
            )
            .toList(growable: false);
        final project = await repo.createProjectFromTemplate(
          template: updatedTemplate,
          steps: steps,
          title: '活动拍摄',
          participant: '客户 A',
          startDate: DateTime(2026, 8, 1),
        );

        final generatedItems = await db.lifeItemDao
            .watchByProjectId(project.id)
            .first;

        expect(updatedTemplate.name, '轻量项目模板');
        expect(steps.map((step) => step.title), ['签约确认', '收尾款']);
        expect(project.templateKey, 'custom:${template.id}');
        // 未填项目备注时不继承模板备注，保持为空。
        expect(project.note, null);
        expect(generatedItems, hasLength(2));
        expect(generatedItems.first.title, '签约确认');
        expect(generatedItems.first.amountType, 'none');
        expect(generatedItems.last.title, '收尾款');
        expect(generatedItems.last.amountType, 'income');
        expect(generatedItems.last.amount, 200000);
        expect(generatedItems.last.dueTime, DateTime(2026, 8, 15));
      },
    );

    test(
      'project backup import is idempotent for projects and events',
      () async {
        final repo = ProjectRepository(db);
        final project = await repo.createProject(title: '备份项目');
        await repo.addEvent(
          projectId: project.id,
          eventType: ProjectEventType.statusChange.value,
          title: '状态变更',
          eventTime: DateTime(2026, 7, 3),
          isSystem: true,
        );

        final jsonText = await BackupService(db).exportToJson();

        await db.close();
        db = AppDatabase.forTesting(NativeDatabase.memory());
        final service = BackupService(db);

        await service.importFromJson(jsonText);
        final second = await service.importFromJson(jsonText);

        final projects = await db.projectDao.getAll();
        final events = await db.projectEventDao.getByProject(
          projects.single.id,
        );

        expect(second.projectsImported, 0);
        expect(second.projectEventsImported, 0);
        expect(projects, hasLength(1));
        expect(events, hasLength(1));
      },
    );

    test(
      'project template backup import is idempotent for templates and steps',
      () async {
        final repo = ProjectRepository(db);
        await repo.createProjectTemplate(
          name: '客户项目',
          note: '模板说明',
          steps: const [
            ProjectTemplateStepInput(
              title: '建立沟通',
              amountType: 'none',
              offsetDays: 0,
            ),
            ProjectTemplateStepInput(
              title: '回款',
              amountType: 'income',
              amount: 60000,
              offsetDays: 7,
            ),
          ],
        );

        final jsonText = await BackupService(db).exportToJson();

        await db.close();
        db = AppDatabase.forTesting(NativeDatabase.memory());
        final service = BackupService(db);

        final first = await service.importFromJson(jsonText);
        final second = await service.importFromJson(jsonText);
        final templates = await db.projectTemplateDao.getAll();
        final customTemplate = templates.singleWhere(
          (template) => template.name == '客户项目',
        );
        final steps = await db.projectTemplateDao.getSteps(customTemplate.id);

        expect(first.projectTemplatesImported, 1);
        expect(first.projectTemplateStepsImported, 2);
        expect(second.projectTemplatesImported, 0);
        expect(second.projectTemplateStepsImported, 0);
        expect(customTemplate.name, '客户项目');
        expect(steps.map((step) => step.title), ['建立沟通', '回款']);
      },
    );

    test('default project type includes 跟拍 category', () async {
      final categories = await db.categoryDao.getByType('project');
      expect(
        categories.any((category) => category.name == '跟拍'),
        isTrue,
      );
    });

    test('wedding photography template ships with preset nodes', () async {
      final repo = ProjectRepository(db);
      final template = await repo.getTemplateByKey(
        ProjectTemplateKeys.weddingPhotography,
      );
      expect(template, isNot(null));
      expect(template!.isDefault, isTrue);
      expect(template.note, '婚礼跟拍预设模板，可根据自己的情况修改。');

      final steps = await repo.getTemplateSteps(template.id);
      expect(steps.map((step) => step.title), [
        '定金',
        '拍摄',
        '交付预告片',
        '交付剩余照片',
        '尾款',
      ]);
      // 收入项：定金（创建日期当天）与尾款（关键日期当天）。
      final incomeSteps = steps.where((step) => step.amountType == 'income');
      expect(incomeSteps.map((step) => step.title), ['定金', '尾款']);

      final deposit = steps.firstWhere((step) => step.title == '定金');
      expect(deposit.createdDateOffsetDays, 0);
      expect(deposit.keyDateOffsetDays, null);

      final shooting = steps.firstWhere((step) => step.title == '拍摄');
      expect(shooting.keyDateOffsetDays, 0);
      expect(shooting.createdDateOffsetDays, null);

      final remainPhotos = steps.firstWhere(
        (step) => step.title == '交付剩余照片',
      );
      expect(remainPhotos.keyDateOffsetDays, 15);
    });

    test('certificate photography template ships with preset nodes', () async {
      final repo = ProjectRepository(db);
      final template = await repo.getTemplateByKey(
        ProjectTemplateKeys.certificatePhotography,
      );
      expect(template, isNot(null));
      expect(template!.isDefault, isTrue);
      expect(template.note, '领证跟拍预设模板，可根据自己的情况修改。');

      final steps = await repo.getTemplateSteps(template.id);
      expect(steps.map((step) => step.title), [
        '定金',
        '拍摄',
        '交付照片',
        '尾款',
      ]);
      final incomeSteps = steps.where((step) => step.amountType == 'income');
      expect(incomeSteps.map((step) => step.title), ['定金', '尾款']);

      final deposit = steps.firstWhere((step) => step.title == '定金');
      expect(deposit.createdDateOffsetDays, 0);
      expect(deposit.keyDateOffsetDays, null);

      final shooting = steps.firstWhere((step) => step.title == '拍摄');
      expect(shooting.keyDateOffsetDays, 0);
      expect(shooting.createdDateOffsetDays, null);
    });

    test('duplicateProjectTemplate copies steps and detaches preset binding',
        () async {
      final repo = ProjectRepository(db);
      final original = await repo.getTemplateByKey(
        ProjectTemplateKeys.weddingPhotography,
      );
      expect(original, isNot(null));
      final originalSteps = await repo.getTemplateSteps(original!.id);

      final copy = await repo.duplicateProjectTemplate(original.id);

      expect(copy.id, isNot(original.id));
      expect(copy.name, '婚礼跟拍模板 副本');
      // 副本脱离内置绑定：没有 templateKey，也不是预置模板。
      expect(copy.templateKey, null);
      expect(copy.isDefault, isFalse);
      expect(copy.categoryId, original.categoryId);
      expect(copy.note, original.note);

      final copySteps = await repo.getTemplateSteps(copy.id);
      expect(
        copySteps.map((step) => step.title),
        originalSteps.map((step) => step.title),
      );
      // 节点的金额类型与两种日期锚点偏移都被完整复制。
      for (var i = 0; i < copySteps.length; i++) {
        expect(copySteps[i].amountType, originalSteps[i].amountType);
        expect(
          copySteps[i].keyDateOffsetDays,
          originalSteps[i].keyDateOffsetDays,
        );
        expect(
          copySteps[i].createdDateOffsetDays,
          originalSteps[i].createdDateOffsetDays,
        );
      }

      // 原模板与原节点保持不变。
      final stillOriginal = await repo.getTemplateByKey(
        ProjectTemplateKeys.weddingPhotography,
      );
      expect(stillOriginal, isNot(null));
      expect(await repo.getTemplateSteps(original.id), hasLength(5));
    });
  });
}
