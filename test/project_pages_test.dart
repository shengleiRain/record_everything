import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record_everything/data/database/app_database.dart';
import 'package:record_everything/data/repositories/bill_record_repository.dart';
import 'package:record_everything/data/repositories/life_item_repository.dart';
import 'package:record_everything/data/repositories/project_repository.dart';
import 'package:record_everything/features/project/pages/project_detail_page.dart';

void main() {
  group('project detail flow entries', () {
    late AppDatabase db;
    late ProjectRepository projectRepo;
    late LifeItemRepository itemRepo;
    late BillRecordRepository billRepo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      projectRepo = ProjectRepository(db);
      itemRepo = LifeItemRepository(db);
      billRepo = BillRecordRepository(db);
    });

    tearDown(() => db.close());

    test(
      'combines project items and independent bills in chronological order',
      () async {
        final data = await _seedProjectFlow(
          projectRepo: projectRepo,
          itemRepo: itemRepo,
          billRepo: billRepo,
        );

        final items = (await db.lifeItemDao.getAll())
            .where((item) => item.projectId == data.project.id)
            .toList(growable: false);
        final bills = (await db.billRecordDao.getAll())
            .where((bill) => bill.projectId == data.project.id)
            .toList(growable: false);

        final entries = buildProjectFlowEntries(items: items, bills: bills);

        expect(entries, hasLength(3));
        expect(entries.map((entry) => entry.title), ['收定金', '道具采购', '拍摄日提醒']);
        expect(entries.map((entry) => entry.kind), [
          ProjectFlowEntryKind.item,
          ProjectFlowEntryKind.bill,
          ProjectFlowEntryKind.item,
        ]);
      },
    );

    test(
      'keeps linked bills attached to their item instead of duplicating them',
      () async {
        final data = await _seedProjectFlow(
          projectRepo: projectRepo,
          itemRepo: itemRepo,
          billRepo: billRepo,
        );

        final entries = buildProjectFlowEntries(
          items: (await db.lifeItemDao.getAll())
              .where((item) => item.projectId == data.project.id)
              .toList(growable: false),
          bills: (await db.billRecordDao.getAll())
              .where((bill) => bill.projectId == data.project.id)
              .toList(growable: false),
        );

        final paymentEntry = entries.singleWhere(
          (entry) => entry.item?.id == data.paymentItem.id,
        );

        expect(paymentEntry.linkedBill?.id, data.linkedBill.id);
        expect(paymentEntry.sortTime, data.linkedBill.billTime);
        expect(
          entries.where((entry) => entry.bill?.id == data.linkedBill.id),
          isEmpty,
        );
        expect(
          entries.singleWhere(
            (entry) => entry.bill?.id == data.independentBill.id,
          ),
          isA<ProjectFlowEntry>(),
        );
      },
    );

    test(
      'preserves zero linked bill amount and empty no-amount items',
      () async {
        final project = await projectRepo.createProject(title: '零金额项目');
        final zeroItem = await itemRepo.create(
          title: '免费补拍',
          projectId: project.id,
          itemType: 'payment_due',
          amountType: 'income',
          dueTime: DateTime(2026, 8, 1),
        );
        final zeroBill = await billRepo.create(
          title: '免费补拍',
          projectId: project.id,
          lifeItemId: zeroItem.id,
          amount: 0,
          amountType: 'income',
          billTime: DateTime(2026, 8, 2, 10),
        );
        final noAmountItem = await itemRepo.create(
          title: '内部沟通',
          projectId: project.id,
          itemType: 'todo',
          dueTime: DateTime(2026, 8, 3),
        );

        final entries = buildProjectFlowEntries(
          items: (await db.lifeItemDao.getAll())
              .where((item) => item.projectId == project.id)
              .toList(growable: false),
          bills: (await db.billRecordDao.getAll())
              .where((bill) => bill.projectId == project.id)
              .toList(growable: false),
        );

        final zeroEntry = entries.singleWhere(
          (entry) => entry.item?.id == zeroItem.id,
        );
        final noAmountEntry = entries.singleWhere(
          (entry) => entry.item?.id == noAmountItem.id,
        );

        expect(zeroEntry.linkedBill?.id, zeroBill.id);
        expect(zeroEntry.displayAmount, 0);
        expect(zeroEntry.displayAmountType, 'income');
        expect(noAmountEntry.displayAmount, isNull);
        expect(noAmountEntry.displayAmountType, 'none');
      },
    );

    test(
      'keeps completed financial item amount without a linked bill',
      () async {
        final project = await projectRepo.createProject(title: '补账项目');
        final completedIncome = await itemRepo.create(
          title: '收定金',
          projectId: project.id,
          itemType: 'payment_due',
          amountType: 'income',
          amount: 300000,
          dueTime: DateTime(2026, 8, 4),
          status: 'completed',
        );

        final entries = buildProjectFlowEntries(
          items: (await db.lifeItemDao.getAll())
              .where((item) => item.projectId == project.id)
              .toList(growable: false),
          bills: const [],
        );
        final entry = entries.singleWhere(
          (entry) => entry.item?.id == completedIncome.id,
        );

        expect(entry.displayAmount, 300000);
        expect(entry.displayAmountType, 'income');
        expect(
          buildProjectFlowMetaText(
            item: entry.item,
            bill: entry.bill,
            linkedBill: entry.linkedBill,
            isBill: entry.kind == ProjectFlowEntryKind.bill,
          ),
          '已收款',
        );
      },
    );

    test('calculates pending receivable from unsettled income items', () async {
      final project = await projectRepo.createProject(
        title: '金额自动计算项目',
        totalAmount: 99999999,
      );
      final pendingIncome = await itemRepo.create(
        title: '收尾款',
        projectId: project.id,
        itemType: 'payment_due',
        amountType: 'income',
        amount: 12880000,
        dueTime: DateTime(2026, 8, 10),
      );
      final settledIncome = await itemRepo.create(
        title: '收定金',
        projectId: project.id,
        itemType: 'payment_due',
        amountType: 'income',
        amount: 2000000,
        dueTime: DateTime(2026, 8),
      );
      await billRepo.create(
        title: '收定金',
        projectId: project.id,
        lifeItemId: settledIncome.id,
        amount: 2000000,
        amountType: 'income',
        billTime: DateTime(2026, 8, 2),
      );
      await itemRepo.create(
        title: '采购道具',
        projectId: project.id,
        itemType: 'bill',
        amountType: 'expense',
        amount: 68000,
        dueTime: DateTime(2026, 8, 3),
      );

      final items = (await db.lifeItemDao.getAll())
          .where((item) => item.projectId == project.id)
          .toList(growable: false);
      final bills = (await db.billRecordDao.getAll())
          .where((bill) => bill.projectId == project.id)
          .toList(growable: false);

      expect(pendingIncome.amount, 12880000);
      expect(
        calculateProjectPendingReceivable(items: items, bills: bills),
        12880000,
      );
    });
  });
}

Future<_ProjectFlowSeed> _seedProjectFlow({
  required ProjectRepository projectRepo,
  required LifeItemRepository itemRepo,
  required BillRecordRepository billRepo,
}) async {
  final project = await projectRepo.createProject(
    title: '婚礼跟拍',
    participant: '张三',
    projectStatus: 'active',
    startDate: DateTime(2026, 7),
    note: '外景+仪式全程拍摄',
  );
  final paymentItem = await itemRepo.create(
    title: '收定金',
    projectId: project.id,
    itemType: 'payment_due',
    amountType: 'income',
    amount: 2000000,
    dueTime: DateTime(2026, 6, 17),
    status: 'completed',
  );
  final linkedBill = await billRepo.create(
    title: '收定金',
    projectId: project.id,
    lifeItemId: paymentItem.id,
    amount: 2000000,
    amountType: 'income',
    billTime: DateTime(2026, 6, 18, 14, 20),
  );
  await itemRepo.create(
    title: '拍摄日提醒',
    projectId: project.id,
    itemType: 'milestone',
    dueTime: DateTime(2026, 7),
  );
  final independentBill = await billRepo.create(
    title: '道具采购',
    projectId: project.id,
    amount: 1268000,
    amountType: 'expense',
    billTime: DateTime(2026, 6, 20, 9, 35),
  );

  return _ProjectFlowSeed(
    project: project,
    paymentItem: paymentItem,
    linkedBill: linkedBill,
    independentBill: independentBill,
  );
}

class _ProjectFlowSeed {
  const _ProjectFlowSeed({
    required this.project,
    required this.paymentItem,
    required this.linkedBill,
    required this.independentBill,
  });

  final Project project;
  final LifeItem paymentItem;
  final BillRecord linkedBill;
  final BillRecord independentBill;
}
