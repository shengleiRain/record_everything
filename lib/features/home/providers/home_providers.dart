import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../bill/providers/bill_providers.dart';
import '../../life_item/providers/life_item_providers.dart';

final homeMonthlyIncomeProvider = StreamProvider<int>((ref) {
  final now = DateTime.now();
  return ref.watch(billRepoProvider).watchIncomeForMonth(now);
});

final homeMonthlyExpenseProvider = StreamProvider<int>((ref) {
  final now = DateTime.now();
  return ref.watch(billRepoProvider).watchExpenseForMonth(now);
});

final homeBalanceProvider = StreamProvider<int>((ref) {
  final income = ref.watch(homeMonthlyIncomeProvider).valueOrNull ?? 0;
  final expense = ref.watch(homeMonthlyExpenseProvider).valueOrNull ?? 0;
  return Stream.value(income - expense);
});

final homeForecastExpenseProvider = StreamProvider<int>((ref) {
  return ref
      .watch(forecastExpensesProvider)
      .maybeWhen(
        data: (items) => Stream.value(
          items.fold<int>(0, (sum, item) => sum + (item.amount ?? 0)),
        ),
        orElse: () => Stream.value(0),
      );
});
