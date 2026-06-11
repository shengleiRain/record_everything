import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record_everything/data/database/app_database.dart';
import 'package:record_everything/data/repositories/bill_record_repository.dart';
import 'package:record_everything/data/repositories/life_item_repository.dart';
import 'package:record_everything/data/repositories/project_repository.dart';
import 'package:record_everything/domain/enums/item_type.dart';
import 'package:record_everything/domain/enums/project_event_type.dart';
import 'package:record_everything/features/settings/services/backup_service.dart';

void main() {
  group('Project module', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() => db.close());

    test(
      'photography template creates typed payment and timeline items',
      () async {
        final project = await ProjectRepository(db)
            .createPhotographyProjectFromTemplate(
              title: '婚礼跟拍',
              participant: '张三',
              shootDate: DateTime(2026, 7, 1),
              totalAmount: 680000,
              shootType: '婚礼',
              depositAmount: 200000,
              finalPaymentAmount: 480000,
            );

        final items = await db.lifeItemDao.watchByProjectId(project.id).first;
        final types = items.map((item) => item.itemType).toSet();

        expect(project.templateKey, 'photography_order');
        expect(types, containsAll(['payment_due', 'milestone', 'delivery']));
        expect(ItemType.fromString('payment_due'), ItemType.paymentDue);
        expect(ItemType.fromString('milestone'), ItemType.milestone);
        expect(ItemType.fromString('delivery'), ItemType.delivery);
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
          itemType: 'payment_due',
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
        expect(updatedItem.itemType, 'payment_due');
        expect(updatedBill.projectId, project.id);
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
  });
}
