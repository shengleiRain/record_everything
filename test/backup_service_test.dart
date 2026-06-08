import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record_everything/data/database/app_database.dart';
import 'package:record_everything/data/repositories/bill_record_repository.dart';
import 'package:record_everything/data/repositories/category_repository.dart';
import 'package:record_everything/data/repositories/life_item_repository.dart';
import 'package:record_everything/features/settings/services/backup_service.dart';

void main() {
  group('BackupService', () {
    late AppDatabase db;
    late BackupService service;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      service = BackupService(db);
    });

    tearDown(() => db.close());

    test('exports and imports categories, life items, and bills', () async {
      final category = await CategoryRepository(
        db,
      ).create(name: '咖啡', type: 'expense', icon: 'coffee');
      final item = await LifeItemRepository(db).create(
        title: '咖啡豆补货',
        categoryId: category.id,
        amount: 6800,
        amountType: 'expense',
        dueTime: DateTime(2026, 6, 6, 9),
      );
      await BillRecordRepository(db).create(
        title: '买咖啡豆',
        amount: 6800,
        categoryId: category.id,
        billTime: DateTime(2026, 6, 6, 10),
        lifeItemId: item.id,
      );

      final jsonText = await service.exportToJson();

      await db.close();
      db = AppDatabase.forTesting(NativeDatabase.memory());
      service = BackupService(db);
      final summary = await service.importFromJson(jsonText);

      expect(summary.lifeItemsImported, 1);
      expect(summary.billRecordsImported, 1);
      expect(summary.categoriesImported, greaterThanOrEqualTo(1));
      expect(
        (await db.lifeItemDao.getAll()).map((row) => row.title),
        contains('咖啡豆补货'),
      );
      expect(
        (await db.billRecordDao.getAll()).map((row) => row.title),
        contains('买咖啡豆'),
      );
      expect(
        (await db.categoryDao.getByType('expense')).map((row) => row.name),
        contains('咖啡'),
      );
    });

    test('rejects invalid backup schema before mutating data', () async {
      final before = await db.lifeItemDao.getAll();

      expect(
        () => service.importFromJson(jsonEncode({'version': 1})),
        throwsA(isA<BackupFormatException>()),
      );

      expect(await db.lifeItemDao.getAll(), before);
    });

    test('skips duplicate life items and bills when importing twice', () async {
      final jsonText = jsonEncode({
        'version': 1,
        'categories': [],
        'lifeItems': [
          {
            'title': '重复事项',
            'dueTime': '2026-06-06T10:00:00.000',
            'status': 'pending',
          },
        ],
        'billRecords': [
          {
            'title': '重复账单',
            'amount': 1200,
            'billTime': '2026-06-06T12:00:00.000',
          },
        ],
      });

      await service.importFromJson(jsonText);
      final summary = await service.importFromJson(jsonText);

      expect(summary.lifeItemsImported, 0);
      expect(summary.billRecordsImported, 0);
      expect((await db.lifeItemDao.getAll()).length, 1);
      expect((await db.billRecordDao.getAll()).length, 1);
    });
  });
}
