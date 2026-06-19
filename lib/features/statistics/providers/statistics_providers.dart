import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/daos/bill_record_dao.dart';
import '../../../data/database/database_provider.dart';
import '../../bill/providers/bill_providers.dart';
import '../../life_item/providers/life_item_providers.dart';
import '../../project/providers/project_providers.dart';

final statsMonthProvider = StateProvider<DateTime>((ref) => DateTime.now());

final statsIncomeProvider = StreamProvider<int>((ref) {
  final month = ref.watch(statsMonthProvider);
  return ref.watch(billRepoProvider).watchIncomeForMonth(month);
});

final statsExpenseProvider = StreamProvider<int>((ref) {
  final month = ref.watch(statsMonthProvider);
  return ref.watch(billRepoProvider).watchExpenseForMonth(month);
});

final statsBudgetProvider = StreamProvider<int>((ref) {
  final month = ref.watch(statsMonthProvider);
  return ref.watch(budgetRepoProvider).watchMonthlyBudget(month);
});

final statsCompletedCountProvider = StreamProvider<int>((ref) {
  final month = ref.watch(statsMonthProvider);
  return ref.watch(lifeItemRepoProvider).watchCompletedCountInMonth(month);
});

final statsOverdueCountProvider = StreamProvider<int>((ref) {
  return ref
      .watch(overdueItemsProvider)
      .maybeWhen(
        data: (items) => Stream.value(items.length),
        orElse: () => Stream.value(0),
      );
});

final statsForecastProvider = StreamProvider<int>((ref) {
  return ref
      .watch(forecastExpensesProvider)
      .maybeWhen(
        data: (items) => Stream.value(
          items.fold<int>(0, (sum, item) => sum + (item.amount ?? 0)),
        ),
        orElse: () => Stream.value(0),
      );
});

// --- Enhanced statistics providers ---

final statsMonthlyTrendIncomeProvider = StreamProvider<List<MonthlySumRow>>((
  ref,
) {
  final month = ref.watch(statsMonthProvider);
  final start = DateTime(month.year, month.month - 5, 1);
  final end = DateTime(month.year, month.month + 1, 1);
  return ref.watch(projectRepoProvider).watchMonthlySums(start, end, 'income');
});

final statsMonthlyTrendExpenseProvider = StreamProvider<List<MonthlySumRow>>((
  ref,
) {
  final month = ref.watch(statsMonthProvider);
  final start = DateTime(month.year, month.month - 5, 1);
  final end = DateTime(month.year, month.month + 1, 1);
  return ref.watch(projectRepoProvider).watchMonthlySums(start, end, 'expense');
});

final statsCategoryBreakdownIncomeProvider =
    StreamProvider<List<CategoryBreakdownRow>>((ref) {
      final month = ref.watch(statsMonthProvider);
      return ref
          .watch(projectRepoProvider)
          .watchCategoryBreakdown(month, 'income');
    });

final statsCategoryBreakdownExpenseProvider =
    StreamProvider<List<CategoryBreakdownRow>>((ref) {
      final month = ref.watch(statsMonthProvider);
      return ref
          .watch(projectRepoProvider)
          .watchCategoryBreakdown(month, 'expense');
    });

// Project stats
final statsActiveProjectsProvider = StreamProvider<List<Project>>((ref) {
  return ref.watch(projectRepoProvider).watchByStatus('active');
});

final statsCompletedProjectsProvider = StreamProvider<List<Project>>((ref) {
  return ref.watch(projectRepoProvider).watchByStatus('completed');
});

final statsProjectIncomeProvider = StreamProvider<int>((ref) {
  final month = ref.watch(statsMonthProvider);
  return ref.watch(projectRepoProvider).watchAllProjectIncomeForMonth(month);
});

// ===== 趋势分析（phase 3） =====

/// 当月每日支出总额。
final statsDailyTrendProvider = StreamProvider<List<DailySumRow>>((ref) {
  final month = ref.watch(statsMonthProvider);
  final db = ref.watch(databaseProvider);
  return db.billRecordDao.watchDailySumsForMonth(month, 'expense');
});

/// 最近 6 个月 Top 分类月度支出。
final statsCategoryTrendProvider =
    StreamProvider<List<CategoryMonthlySumRow>>((ref) {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month - 5, 1);
  final end = DateTime(now.year, now.month + 1, 1);
  final db = ref.watch(databaseProvider);
  return db.billRecordDao.watchCategoryMonthlySums(start, end, 'expense');
});

/// 分类 id → 名称映射（供图表图例使用）。
final categoryNamesProvider = FutureProvider<Map<int, String>>((ref) async {
  final db = ref.watch(databaseProvider);
  final cats = await db.categoryDao.getAll();
  return {for (final c in cats) c.id: c.name};
});
