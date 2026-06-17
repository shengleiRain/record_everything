import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record_everything/data/database/app_database.dart';
import 'package:record_everything/data/repositories/bill_record_repository.dart';
import 'package:record_everything/data/repositories/life_item_repository.dart';
import 'package:record_everything/data/repositories/project_repository.dart';
import 'package:record_everything/domain/enums/project_event_type.dart';
import 'package:record_everything/core/constants/project_template_keys.dart';
import 'package:record_everything/features/settings/services/backup_service.dart';

void main() {
  group('Project module', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() => db.close());

    test('photography template creates payment and timeline items', () async {
      final repo = ProjectRepository(db);
      final template = await repo.getTemplateByKey(
        ProjectTemplateKeys.photographyOrder,
      );

      final steps = (await repo.getTemplateSteps(template!.id))
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
        template: template,
        steps: steps,
        title: '婚礼跟拍',
        startDate: DateTime(2026, 7, 1),
        participant: '张三',
      );

      final items = await db.lifeItemDao.watchByProjectId(project.id).first;

      expect(template.isDefault, isTrue);
      expect(project.templateKey, ProjectTemplateKeys.photographyOrder);
      expect(items.map((item) => item.title), [
        '收定金',
        '拍摄日提醒',
        '选片/确认交付内容',
        '修图交付',
        '收尾款',
      ]);
      expect(items.where((item) => item.amountType == 'income'), hasLength(2));
    });

    test('photography template edits affect generated project items', () async {
      final repo = ProjectRepository(db);
      final template = await repo.getTemplateByKey(
        ProjectTemplateKeys.photographyOrder,
      );
      expect(template == null, isFalse);

      await repo.updateProjectTemplate(
        template: template!.copyWith(name: '我的摄影流程'),
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

      expect(project.templateKey, ProjectTemplateKeys.photographyOrder);
      expect(items.map((item) => item.title), ['确认档期', '收预约款']);
      expect(items.first.dueTime, DateTime(2026, 9, 10));
      expect(items.last.amount, 100000);
    });

    test(
      'preset project templates can be deleted like custom templates',
      () async {
        final repo = ProjectRepository(db);
        final template = await repo.getTemplateByKey(
          ProjectTemplateKeys.photographyOrder,
        );
        expect(template != null, isTrue);

        await repo.deleteProjectTemplate(template!.id);

        final byKey = await repo.getTemplateByKey(
          ProjectTemplateKeys.photographyOrder,
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
        expect(project.note, '可编辑默认节点');
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
  });
}
