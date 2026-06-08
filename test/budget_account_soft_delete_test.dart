import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record_everything/data/database/app_database.dart';
import 'package:record_everything/data/repositories/account_repository.dart';
import 'package:record_everything/data/repositories/bill_record_repository.dart';
import 'package:record_everything/data/repositories/budget_repository.dart';
import 'package:record_everything/data/repositories/life_item_repository.dart';

void main() {
  group('budget, account, and soft delete', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() => db.close());

    test('creates default account and stores monthly budget', () async {
      final accountRepo = AccountRepository(db);
      final budgetRepo = BudgetRepository(db);

      final account = await accountRepo.ensureDefaultAccount();
      await budgetRepo.setMonthlyBudget(DateTime(2026, 6, 6), 300000);

      expect(account.name, '默认账户');
      expect(await budgetRepo.getMonthlyBudget(DateTime(2026, 6, 1)), 300000);
    });

    test('soft deleted items and bills are hidden from active lists', () async {
      final itemRepo = LifeItemRepository(db);
      final billRepo = BillRecordRepository(db);
      final item = await itemRepo.create(
        title: '临时事项',
        dueTime: DateTime(2026, 6, 6),
      );
      final bill = await billRepo.create(
        title: '临时账单',
        amount: 1000,
        billTime: DateTime(2026, 6, 6),
      );

      await itemRepo.deleteItem(item.id);
      await billRepo.deleteRecord(bill.id);

      expect(await db.lifeItemDao.getAll(), isEmpty);
      expect(await db.billRecordDao.getAll(), isEmpty);
      expect((await db.lifeItemDao.getDeleted()).single.title, '临时事项');
      expect((await db.billRecordDao.getDeleted()).single.title, '临时账单');

      await itemRepo.restoreItem(item.id);
      await billRepo.restoreRecord(bill.id);

      expect((await db.lifeItemDao.getAll()).single.title, '临时事项');
      expect((await db.billRecordDao.getAll()).single.title, '临时账单');
    });
  });
}
