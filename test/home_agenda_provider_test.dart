import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record_everything/data/database/app_database.dart';
import 'package:record_everything/data/database/database_provider.dart';
import 'package:record_everything/data/repositories/bill_record_repository.dart';
import 'package:record_everything/data/repositories/life_item_repository.dart';
import 'package:record_everything/features/home/models/day_bucket_view_model.dart';
import 'package:record_everything/features/home/providers/home_providers.dart';

void main() {
  test('home calendar defaults to collapsed week mode', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(homeCalendarModeProvider), HomeCalendarMode.week);
  });

  test(
    'life item repository watches range inclusively at start and ordered asc',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      final repository = LifeItemRepository(db);
      final start = DateTime(2026, 6, 4);
      final end = DateTime(2026, 6, 5);

      await repository.create(
        title: 'before range',
        dueTime: start.subtract(const Duration(minutes: 1)),
      );
      await repository.create(
        title: 'later in range',
        dueTime: start.add(const Duration(hours: 18)),
      );
      await repository.create(title: 'range start', dueTime: start);
      await repository.create(title: 'next day excluded', dueTime: end);

      final items = await repository.watchBetween(start, end).first;

      expect(items.map((item) => item.title), [
        'range start',
        'later in range',
      ]);
    },
  );

  test(
    'bill record repository watches range before end and ordered desc',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      final repository = BillRecordRepository(db);
      final start = DateTime(2026, 6, 4);
      final end = DateTime(2026, 6, 5);

      await repository.create(
        title: 'before range',
        amount: 100,
        billTime: start.subtract(const Duration(minutes: 1)),
      );
      await repository.create(
        title: 'range start',
        amount: 200,
        billTime: start,
      );
      await repository.create(
        title: 'later in range',
        amount: 300,
        billTime: start.add(const Duration(hours: 18)),
      );
      await repository.create(
        title: 'next day excluded',
        amount: 400,
        billTime: end,
      );

      final records = await repository.watchBetween(start, end).first;

      expect(records.map((record) => record.title), [
        'later in range',
        'range start',
      ]);
    },
  );

  test('selected day agenda combines life items and bill records', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    addTearDown(db.close);

    container.read(homeSelectedDateProvider.notifier).state = DateTime(
      2026,
      6,
      4,
    );

    final lifeRepository = LifeItemRepository(db);
    final billRepository = BillRecordRepository(db);

    await lifeRepository.create(
      title: '信用卡还款',
      amount: 1000,
      amountType: 'expense',
      dueTime: DateTime(2026, 6, 4, 10),
      status: 'completed',
    );
    await lifeRepository.create(
      title: '明天事项',
      dueTime: DateTime(2026, 6, 5, 10),
    );
    await billRepository.create(
      title: '买菜记录',
      amount: 88,
      billTime: DateTime(2026, 6, 4, 12),
    );

    final rows = await _waitForAsyncRows(
      container,
      homeSelectedDayAgendaProvider,
      2,
    );

    expect(rows.map((row) => row.title), ['买菜记录', '信用卡还款']);
    expect(rows.map((row) => row.title), isNot(contains('明天事项')));
    expect(rows.map((row) => row.date), everyElement(DateTime(2026, 6, 4)));
  });

  test(
    'calendar buckets always return full month grid and mark selected day',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      addTearDown(db.close);

      container.read(homeSelectedDateProvider.notifier).state = DateTime(
        2026,
        6,
        4,
      );
      container.read(homeVisibleAnchorDateProvider.notifier).state = DateTime(
        2026,
        6,
        4,
      );

      // Provider always returns month grid regardless of mode
      final buckets = await _waitForAsyncRows(
        container,
        homeCalendarBucketsProvider,
        35,
      );

      // Month grid is Sunday-first (first row starts on Sunday)
      expect(buckets.first.date.weekday, 7);
      expect(
        buckets
            .singleWhere((bucket) => bucket.date == DateTime(2026, 6, 4))
            .isSelected,
        isTrue,
      );
    },
  );

  test('day bucket compact labels use yuan formatting and priority', () {
    final date = DateTime(2026, 6, 4);

    DayBucketViewModel bucket({
      int itemCount = 0,
      int overdueCount = 0,
      int income = 0,
      int expense = 0,
    }) {
      return DayBucketViewModel(
        date: date,
        isSelected: false,
        isInVisibleMonth: true,
        itemCount: itemCount,
        overdueCount: overdueCount,
        income: income,
        expense: expense,
      );
    }

    expect(
      bucket(
        overdueCount: 2,
        expense: 12000,
        income: 860000,
        itemCount: 3,
      ).compactLabel,
      '逾期',
    );
    expect(
      bucket(expense: 12000, income: 860000, itemCount: 3).compactLabel,
      '¥120',
    );
    expect(bucket(income: 860000, itemCount: 3).compactLabel, '+¥8600');
    expect(bucket(itemCount: 3).compactLabel, '3项');
    expect(bucket().compactLabel, '空');
  });
}

Future<List<T>> _waitForAsyncRows<T>(
  ProviderContainer container,
  ProviderListenable<AsyncValue<List<T>>> provider,
  int expectedLength,
) async {
  final end = DateTime.now().add(const Duration(seconds: 3));
  while (DateTime.now().isBefore(end)) {
    final rows = container.read(provider).valueOrNull;
    if (rows != null && rows.length == expectedLength) return rows;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }

  fail(
    'Expected provider to emit $expectedLength rows, got '
    '${container.read(provider)}',
  );
}
