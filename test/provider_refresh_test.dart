import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record_everything/data/database/app_database.dart';
import 'package:record_everything/data/database/database_provider.dart';
import 'package:record_everything/features/bill/providers/bill_providers.dart';
import 'package:record_everything/features/home/providers/home_providers.dart';
import 'package:record_everything/features/life_item/providers/life_item_providers.dart';
import 'package:record_everything/features/statistics/providers/statistics_providers.dart';

void main() {
  test('bill and home amount providers refresh after bill mutations', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    addTearDown(db.close);

    final billExpenses = <int>[];
    final homeExpenses = <int>[];
    final homeBalances = <int>[];
    final statsExpenses = <int>[];
    final billSub = container.listen(
      monthlyExpenseProvider,
      (_, next) => billExpenses.add(next.valueOrNull ?? 0),
      fireImmediately: true,
    );
    final homeSub = container.listen(
      homeMonthlyExpenseProvider,
      (_, next) => homeExpenses.add(next.valueOrNull ?? 0),
      fireImmediately: true,
    );
    final homeBalanceSub = container.listen(
      homeBalanceProvider,
      (_, next) => homeBalances.add(next.valueOrNull ?? 0),
      fireImmediately: true,
    );
    final statsExpenseSub = container.listen(
      statsExpenseProvider,
      (_, next) => statsExpenses.add(next.valueOrNull ?? 0),
      fireImmediately: true,
    );
    addTearDown(billSub.close);
    addTearDown(homeSub.close);
    addTearDown(homeBalanceSub.close);
    addTearDown(statsExpenseSub.close);

    await _waitForValue(billExpenses, 0);
    await _waitForValue(homeExpenses, 0);
    await _waitForValue(homeBalances, 0);
    await _waitForValue(statsExpenses, 0);

    await container
        .read(billNotifierProvider.notifier)
        .create(
          title: 'provider refresh bill',
          amount: 1234,
          billTime: DateTime.now(),
        );

    await _waitForValue(billExpenses, 1234);
    await _waitForValue(homeExpenses, 1234);
    await _waitForValue(homeBalances, -1234);
    await _waitForValue(statsExpenses, 1234);

    final bill = (await db.billRecordDao.getAll()).firstWhere(
      (record) => record.title == 'provider refresh bill',
    );
    await container
        .read(billRepoProvider)
        .updateRecord(bill.copyWith(amount: 2345, updatedAt: DateTime.now()));

    await _waitForValue(billExpenses, 2345);
    await _waitForValue(homeExpenses, 2345);
    await _waitForValue(homeBalances, -2345);
    await _waitForValue(statsExpenses, 2345);

    await container.read(billNotifierProvider.notifier).delete(bill.id);

    await _waitForValue(billExpenses, 0);
    await _waitForValue(homeExpenses, 0);
    await _waitForValue(homeBalances, 0);
    await _waitForValue(statsExpenses, 0);
  });

  test('statistics completed count refreshes after item mutations', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    addTearDown(db.close);

    final completedCounts = <int>[];
    final completedSub = container.listen(
      statsCompletedCountProvider,
      (_, next) => completedCounts.add(next.valueOrNull ?? 0),
      fireImmediately: true,
    );
    addTearDown(completedSub.close);

    await _waitForValue(completedCounts, 0);

    final item = await container.read(lifeItemNotifierProvider.notifier).create(
      {'title': 'provider refresh item', 'dueTime': DateTime.now()},
    );

    await container.read(lifeItemNotifierProvider.notifier).complete(item.id);

    await _waitForValue(completedCounts, 1);
  });
}

Future<void> _waitForValue(List<int> values, int expected) async {
  final end = DateTime.now().add(const Duration(seconds: 3));
  while (DateTime.now().isBefore(end)) {
    if (values.contains(expected)) return;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  fail('Expected provider values to contain $expected, got $values');
}
