import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../bill/providers/bill_providers.dart';
import '../../life_item/providers/life_item_providers.dart';

final homeMonthlyIncomeProvider = FutureProvider<int>((ref) {
  final now = DateTime.now();
  return ref.watch(billRepoProvider).sumIncomeForMonth(now);
});

final homeMonthlyExpenseProvider = FutureProvider<int>((ref) {
  final now = DateTime.now();
  return ref.watch(billRepoProvider).sumExpenseForMonth(now);
});

final homeBalanceProvider = FutureProvider<int>((ref) async {
  final income = await ref.watch(homeMonthlyIncomeProvider.future);
  final expense = await ref.watch(homeMonthlyExpenseProvider.future);
  return income - expense;
});

final homeForecastExpenseProvider = StreamProvider<int>((ref) {
  return ref.watch(forecastExpensesProvider).maybeWhen(
    data: (items) => Stream.value(items.fold<int>(0, (sum, item) => sum + (item.amount ?? 0))),
    orElse: () => Stream.value(0),
  );
});
