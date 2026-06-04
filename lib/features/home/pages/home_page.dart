import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/date_formatter.dart';
import '../../life_item/providers/life_item_providers.dart';
import '../providers/home_providers.dart';
import '../widgets/overview_card.dart';
import '../widgets/today_todos_card.dart';
import '../widgets/upcoming_card.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayAsync = ref.watch(todayPendingProvider);
    final upcomingAsync = ref.watch(upcomingItemsProvider);
    final incomeAsync = ref.watch(homeMonthlyIncomeProvider);
    final expenseAsync = ref.watch(homeMonthlyExpenseProvider);
    final balanceAsync = ref.watch(homeBalanceProvider);
    final forecastAsync = ref.watch(homeForecastExpenseProvider);

    return Semantics(
      label: 'home_dashboard_screen',
      container: true,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('今天有什么要处理？', style: TextStyle(fontSize: 18)),
              Text(
                DateFormatter.formatDate(DateTime.now()),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            OverviewCard(
              income: incomeAsync.valueOrNull ?? 0,
              expense: expenseAsync.valueOrNull ?? 0,
              balance: balanceAsync.valueOrNull ?? 0,
              forecast: forecastAsync.valueOrNull ?? 0,
            ),
            todayAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (items) => TodayTodosCard(items: items),
            ),
            upcomingAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (items) => UpcomingCard(items: items),
            ),
          ],
        ),
      ),
    );
  }
}
