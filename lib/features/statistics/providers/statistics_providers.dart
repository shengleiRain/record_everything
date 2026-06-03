import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../bill/providers/bill_providers.dart';
import '../../life_item/providers/life_item_providers.dart';

final statsMonthProvider = StateProvider<DateTime>((ref) => DateTime.now());

final statsIncomeProvider = FutureProvider<int>((ref) {
  final month = ref.watch(statsMonthProvider);
  return ref.watch(billRepoProvider).sumIncomeForMonth(month);
});

final statsExpenseProvider = FutureProvider<int>((ref) {
  final month = ref.watch(statsMonthProvider);
  return ref.watch(billRepoProvider).sumExpenseForMonth(month);
});

final statsCompletedCountProvider = FutureProvider<int>((ref) {
  final month = ref.watch(statsMonthProvider);
  return ref.watch(lifeItemRepoProvider).countCompletedInMonth(month);
});

final statsOverdueCountProvider = StreamProvider<int>((ref) {
  return ref.watch(overdueItemsProvider).maybeWhen(
    data: (items) => Stream.value(items.length),
    orElse: () => Stream.value(0),
  );
});

final statsForecastProvider = StreamProvider<int>((ref) {
  return ref.watch(forecastExpensesProvider).maybeWhen(
    data: (items) => Stream.value(items.fold<int>(0, (sum, item) => sum + (item.amount ?? 0))),
    orElse: () => Stream.value(0),
  );
});
