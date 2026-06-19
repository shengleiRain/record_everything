import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:record_everything/data/database/app_database.dart';
import 'package:record_everything/data/database/database_provider.dart';
import 'package:record_everything/features/smart_entry/models/draft_item.dart';
import 'package:record_everything/features/smart_entry/providers/smart_entry_providers.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    // 触发 onCreate 播种默认分类/账户。
    await db.categoryDao.getAll();
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('persist 账单后落库可见', () async {
    final bill = DraftItem(
      kind: DraftKind.bill,
      title: '午餐',
      amountCents: 2500,
      amountType: DraftAmountType.expense,
      time: DateTime(2026, 6, 19, 12),
      source: DraftSource.nl,
      confidence: 0.9,
      categoryGuess: '餐饮',
    );

    final result = await container
        .read(smartEntryPersistProvider)
        .persist([bill]);

    expect(result.failed, isEmpty);
    expect(result.saved, hasLength(1));
    expect(result.saved.first.categoryId, isNotNull); // 餐饮 匹配到 id

    // 验证账单真的写进了库。
    final records = await db.billRecordDao.getAll();
    expect(records, hasLength(1));
    expect(records.first.title, '午餐');
    expect(records.first.amount, 2500);
  });

  test('persist 事项后落库可见', () async {
    final item = DraftItem(
      kind: DraftKind.lifeItem,
      title: '开会',
      amountCents: null,
      amountType: DraftAmountType.none,
      time: DateTime(2026, 6, 20, 15),
      source: DraftSource.nl,
      confidence: 0.9,
    );

    final result = await container
        .read(smartEntryPersistProvider)
        .persist([item]);

    expect(result.failed, isEmpty);
    final items = await db.lifeItemDao.getAll();
    expect(items, hasLength(1));
    expect(items.first.title, '开会');
  });
}
