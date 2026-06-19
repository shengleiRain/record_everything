import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../data/database/daos/bill_record_dao.dart';
import '../../../data/database/database_provider.dart';
import '../providers/statistics_providers.dart';
import '../widgets/category_trend_chart.dart';
import '../widgets/daily_trend_chart.dart';

class StatisticsPage extends ConsumerWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(statsMonthProvider);
    final income = ref.watch(statsIncomeProvider).valueOrNull ?? 0;
    final expense = ref.watch(statsExpenseProvider).valueOrNull ?? 0;
    final budget = ref.watch(statsBudgetProvider).valueOrNull ?? 0;
    final completed = ref.watch(statsCompletedCountProvider).valueOrNull ?? 0;
    final overdue = ref.watch(statsOverdueCountProvider).valueOrNull ?? 0;
    final forecast = ref.watch(statsForecastProvider).valueOrNull ?? 0;
    final balance = income - expense;
    final totalTasks = completed + overdue;
    final completionRate = totalTasks == 0
        ? 0
        : ((completed / totalTasks) * 100).round().clamp(0, 100);

    // Trend data
    final trendIncome =
        ref.watch(statsMonthlyTrendIncomeProvider).valueOrNull ?? const [];
    final trendExpense =
        ref.watch(statsMonthlyTrendExpenseProvider).valueOrNull ?? const [];

    // Category breakdown
    final catIncome =
        ref.watch(statsCategoryBreakdownIncomeProvider).valueOrNull ?? const [];
    final catExpense =
        ref.watch(statsCategoryBreakdownExpenseProvider).valueOrNull ??
        const [];

    // Project stats
    final activeProjects =
        ref.watch(statsActiveProjectsProvider).valueOrNull ?? const [];
    final completedProjects =
        ref.watch(statsCompletedProjectsProvider).valueOrNull ?? const [];
    final projectIncome =
        ref.watch(statsProjectIncomeProvider).valueOrNull ?? 0;

    // 趋势分析（phase 3）
    final dailyTrend =
        ref.watch(statsDailyTrendProvider).valueOrNull ?? const [];
    final categoryTrend =
        ref.watch(statsCategoryTrendProvider).valueOrNull ?? const [];
    final categoryNames =
        ref.watch(categoryNamesProvider).valueOrNull ?? const {};

    return Scaffold(
      appBar: AppBar(title: const Text('统计')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _MonthHeader(
            month: month,
            onPrevious: () => _changeMonth(ref, month, -1),
            onNext: () => _changeMonth(ref, month, 1),
          ),
          const SizedBox(height: 10),
          _SummaryGrid(
            cells: [
              _SummaryCellData(
                label: '结余',
                value: MoneyFormatter.format(balance),
                color: balance >= 0 ? AppColors.income : AppColors.expense,
              ),
              _SummaryCellData(
                label: '预算',
                value: budget == 0
                    ? '未设置'
                    : '${((expense / budget) * 100).round().clamp(0, 999)}%',
                color: AppColors.upcoming,
              ),
              _SummaryCellData(
                label: '完成率',
                value: '$completionRate%',
                color: AppColors.textPrimary,
              ),
              _SummaryCellData(
                label: '逾期',
                value: '$overdue',
                color: overdue > 0 ? AppColors.overdue : AppColors.textHint,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 6-month trend
          _ChartCard(
            title: '近6个月趋势',
            trailing: '收入 / 支出',
            child: _MonthlyTrendChart(
              incomeData: trendIncome,
              expenseData: trendExpense,
            ),
          ),
          const SizedBox(height: 12),

          // 本月每日支出（phase 3）
          _ChartCard(
            title: '本月每日支出',
            trailing: MoneyFormatter.format(expense),
            child: DailyTrendChart(data: dailyTrend),
          ),
          const SizedBox(height: 12),

          // 分类消费趋势（phase 3）
          _ChartCard(
            title: '分类消费趋势',
            trailing: '近6个月',
            child: CategoryTrendChart(
              data: categoryTrend,
              categoryNames: categoryNames,
            ),
          ),
          const SizedBox(height: 12),

          // Month-over-month comparison
          _MonthCompareCard(
            currentMonth: month,
            currentIncome: income,
            currentExpense: expense,
            currentBalance: balance,
            trendIncome: trendIncome,
            trendExpense: trendExpense,
          ),
          const SizedBox(height: 12),

          // Category breakdown - expense
          if (catExpense.isNotEmpty) ...[
            _ChartCard(
              title: '支出分类占比',
              trailing: '支出 ${MoneyFormatter.format(expense)}',
              child: _CategoryBreakdownList(
                rows: catExpense,
                amountType: 'expense',
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Category breakdown - income
          if (catIncome.isNotEmpty) ...[
            _ChartCard(
              title: '收入分类占比',
              trailing: '收入 ${MoneyFormatter.format(income)}',
              child: _CategoryBreakdownList(
                rows: catIncome,
                amountType: 'income',
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Project stats
          _ChartCard(
            title: '项目统计',
            trailing: '项目收入 ${MoneyFormatter.format(projectIncome)}',
            child: Column(
              children: [
                _CategoryRow(
                  icon: '收',
                  label: '本月项目收入',
                  subtitle: '已关联项目的收入账单',
                  amount: MoneyFormatter.format(projectIncome),
                  color: AppColors.income,
                ),
                _CategoryRow(
                  icon: '进',
                  label: '进行中项目',
                  subtitle: '当前活跃',
                  amount: '${activeProjects.length} 个',
                  color: AppColors.income,
                ),
                _CategoryRow(
                  icon: '完',
                  label: '已完成项目',
                  subtitle: '已交付/归档',
                  amount: '${completedProjects.length} 个',
                  color: AppColors.completed,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Original trend chart
          _ChartCard(
            title: '收支趋势',
            trailing: expense == 0
                ? '暂无支出'
                : '支出占收入 ${_ratioText(expense, income)}',
            child: _BalanceBars(
              income: income,
              expense: expense,
              forecast: forecast,
            ),
          ),
          const SizedBox(height: 12),
          _ForecastCard(forecast: forecast, overdue: overdue),
          const SizedBox(height: 12),
          _BudgetRiskCard(expense: expense, budget: budget),
        ],
      ),
    );
  }

  void _changeMonth(WidgetRef ref, DateTime current, int delta) {
    ref.read(statsMonthProvider.notifier).state = DateTime(
      current.year,
      current.month + delta,
    );
  }
}

// --- Multi-month trend chart ---

class _MonthlyTrendChart extends StatelessWidget {
  const _MonthlyTrendChart({
    required this.incomeData,
    required this.expenseData,
  });

  final List<MonthlySumRow> incomeData;
  final List<MonthlySumRow> expenseData;

  @override
  Widget build(BuildContext context) {
    if (incomeData.isEmpty && expenseData.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text('暂无趋势数据', style: TextStyle(color: AppColors.textHint)),
        ),
      );
    }

    // Build month labels and values
    final allMonths = <int>{};
    for (final r in incomeData) {
      allMonths.add(r.yearMonth);
    }
    for (final r in expenseData) {
      allMonths.add(r.yearMonth);
    }
    final sortedMonths = allMonths.toList()..sort();

    final incomeMap = {for (final r in incomeData) r.yearMonth: r.sum};
    final expenseMap = {for (final r in expenseData) r.yearMonth: r.sum};

    final allValues = <int>[...incomeMap.values, ...expenseMap.values];
    final maxValue = allValues.isEmpty
        ? 1
        : allValues.reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 140,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final ym in sortedMonths)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _monthLabel(ym),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _MiniBar(
                          value: incomeMap[ym] ?? 0,
                          maxValue: maxValue,
                          color: AppColors.income,
                        ),
                        const SizedBox(width: 2),
                        _MiniBar(
                          value: expenseMap[ym] ?? 0,
                          maxValue: maxValue,
                          color: AppColors.expense,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _monthLabel(int yearMonth) {
    final m = yearMonth % 100;
    return '$m月';
  }
}

class _MiniBar extends StatelessWidget {
  const _MiniBar({
    required this.value,
    required this.maxValue,
    required this.color,
  });

  final int value;
  final int maxValue;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final height = maxValue > 0 ? (value / maxValue) * 80 : 0.0;
    return Container(
      width: 12,
      height: height.clamp(2.0, 80.0),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.8),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
      ),
    );
  }
}

// --- Month comparison card ---

class _MonthCompareCard extends StatelessWidget {
  const _MonthCompareCard({
    required this.currentMonth,
    required this.currentIncome,
    required this.currentExpense,
    required this.currentBalance,
    required this.trendIncome,
    required this.trendExpense,
  });

  final DateTime currentMonth;
  final int currentIncome;
  final int currentExpense;
  final int currentBalance;
  final List<MonthlySumRow> trendIncome;
  final List<MonthlySumRow> trendExpense;

  @override
  Widget build(BuildContext context) {
    final prevYm = currentMonth.year * 100 + currentMonth.month - 1;
    final prevIncome = _findSum(trendIncome, prevYm);
    final prevExpense = _findSum(trendExpense, prevYm);
    final prevBalance = prevIncome - prevExpense;

    return _ChartCard(
      title: '月度环比',
      trailing: DateFormatter.formatMonth(currentMonth),
      child: Column(
        children: [
          _CompareRow(
            label: '收入',
            current: currentIncome,
            previous: prevIncome,
          ),
          _CompareRow(
            label: '支出',
            current: currentExpense,
            previous: prevExpense,
          ),
          _CompareRow(
            label: '结余',
            current: currentBalance,
            previous: prevBalance,
          ),
        ],
      ),
    );
  }

  int _findSum(List<MonthlySumRow> data, int yearMonth) {
    for (final r in data) {
      if (r.yearMonth == yearMonth) return r.sum;
    }
    return 0;
  }
}

class _CompareRow extends StatelessWidget {
  const _CompareRow({
    required this.label,
    required this.current,
    required this.previous,
  });

  final String label;
  final int current;
  final int previous;

  @override
  Widget build(BuildContext context) {
    final diff = current - previous;
    final hasData = previous > 0;
    final percentChange = hasData
        ? ((diff / previous) * 100).round()
        : (current > 0 ? 100 : 0);
    final isUp = diff > 0;
    final color = isUp
        ? AppColors.income
        : (diff < 0 ? AppColors.expense : AppColors.textHint);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Expanded(
            child: Text(
              MoneyFormatter.format(current),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          if (previous > 0 || current > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                previous == 0
                    ? (current > 0 ? '新增' : '无数据')
                    : '${isUp ? '+' : ''}$percentChange%',
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            Text(
              '无上月数据',
              style: TextStyle(color: AppColors.textHint, fontSize: 12),
            ),
        ],
      ),
    );
  }
}

// --- Category breakdown list ---

class _CategoryBreakdownList extends ConsumerStatefulWidget {
  const _CategoryBreakdownList({
    required this.rows,
    required this.amountType,
  });

  final List<CategoryBreakdownRow> rows;
  final String amountType;

  @override
  ConsumerState<_CategoryBreakdownList> createState() =>
      _CategoryBreakdownListState();
}

class _CategoryBreakdownListState
    extends ConsumerState<_CategoryBreakdownList> {
  Map<int, String> _categoryNames = {};

  @override
  void initState() {
    super.initState();
    _loadCategoryNames();
  }

  Future<void> _loadCategoryNames() async {
    try {
      final db = ref.read(databaseProvider);
      final cats = await db.categoryDao.getAll();
      if (!mounted) return;
      setState(() {
        _categoryNames = {for (final c in cats) c.id: c.name};
      });
    } catch (_) {
      // Keep empty map; names will show as '未分类'.
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = widget.rows;
    final total = rows.fold<int>(0, (sum, r) => sum + r.sum);
    final displayRows = rows.take(5).toList();
    final otherSum = rows.skip(5).fold<int>(0, (sum, r) => sum + r.sum);
    final color = widget.amountType == 'income'
        ? AppColors.income
        : AppColors.expense;

    return Column(
      children: [
        for (final row in displayRows)
          _CategoryRowWithPercent(
            row: row,
            total: total,
            name: _categoryNames[row.categoryId] ?? '未分类',
            color: color,
          ),
        if (otherSum > 0)
          _CategoryRow(
            icon: '他',
            label: '其他',
            subtitle: '${total > 0 ? ((otherSum / total) * 100).round() : 0}%',
            amount: MoneyFormatter.format(otherSum),
            color: AppColors.textSecondary,
          ),
      ],
    );
  }
}

class _CategoryRowWithPercent extends StatelessWidget {
  const _CategoryRowWithPercent({
    required this.row,
    required this.total,
    required this.name,
    required this.color,
  });

  final CategoryBreakdownRow row;
  final int total;
  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final percent = total > 0 ? ((row.sum / total) * 100).round() : 0;
    return _CategoryRow(
      icon: name.isNotEmpty ? name.characters.first : '?',
      label: name,
      subtitle: '$percent%',
      amount: MoneyFormatter.format(row.sum),
      color: color,
    );
  }
}

// --- Existing widgets (kept) ---

class _BudgetRiskCard extends StatelessWidget {
  const _BudgetRiskCard({required this.expense, required this.budget});

  final int expense;
  final int budget;

  @override
  Widget build(BuildContext context) {
    final message = budget <= 0
        ? '本月还没有设置预算；设置预算后，这里会展示超支风险。'
        : expense > budget
        ? '本月支出已超过预算 ${MoneyFormatter.format(expense - budget)}，建议检查高频支出分类。'
        : '本月预算剩余 ${MoneyFormatter.format(budget - expense)}，当前现金流风险可控。';
    return _ChartCard(
      title: '预算风险',
      trailing: budget <= 0 ? '未设置' : MoneyFormatter.format(budget),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.textSecondary,
          height: 1.5,
        ),
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.month,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: '上个月',
          icon: const Icon(Icons.chevron_left),
          onPressed: onPrevious,
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                DateFormatter.formatMonth(month),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                '趋势和风险提示',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: '下个月',
          icon: const Icon(Icons.chevron_right),
          onPressed: onNext,
        ),
      ],
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.cells});

  final List<_SummaryCellData> cells;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cells.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        childAspectRatio: 1.1,
      ),
      itemBuilder: (context, index) => _SummaryCell(data: cells[index]),
    );
  }
}

class _SummaryCell extends StatelessWidget {
  const _SummaryCell({required this.data});

  final _SummaryCellData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              data.label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              data.value,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: data.color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCellData {
  const _SummaryCellData({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.trailing,
    required this.child,
  });

  final String title;
  final String trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Text(
                trailing,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _BalanceBars extends StatelessWidget {
  const _BalanceBars({
    required this.income,
    required this.expense,
    required this.forecast,
  });

  final int income;
  final int expense;
  final int forecast;

  @override
  Widget build(BuildContext context) {
    final maxValue = [
      income,
      expense,
      forecast,
      1,
    ].reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 132,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _Bar(
            label: '收入',
            value: income,
            maxValue: maxValue,
            color: AppColors.income,
          ),
          _Bar(
            label: '支出',
            value: expense,
            maxValue: maxValue,
            color: AppColors.expense,
          ),
          _Bar(
            label: '预测',
            value: forecast,
            maxValue: maxValue,
            color: AppColors.upcoming,
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.color,
  });

  final String label;
  final int value;
  final int maxValue;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final height = 24 + (value / maxValue) * 52;

    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              MoneyFormatter.format(value),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 34,
            height: height,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.84),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(6),
              ),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.amount,
    required this.color,
  });

  final String icon;
  final String label;
  final String subtitle;
  final String amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 42),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              icon,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              amount,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ForecastCard extends StatelessWidget {
  const _ForecastCard({required this.forecast, required this.overdue});

  final int forecast;
  final int overdue;

  @override
  Widget build(BuildContext context) {
    final message = forecast > 0
        ? '未来固定支出预计 ${MoneyFormatter.format(forecast)}，建议预留现金流并优先处理临近到期事项。'
        : '未来固定支出暂无记录；新增周期账单后，这里会汇总接下来 30 天的预计支出。';

    return _ChartCard(
      title: '下月预测',
      trailing: overdue > 0 ? '逾期 $overdue 项' : '暂无逾期',
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.textSecondary,
          height: 1.5,
        ),
      ),
    );
  }
}

String _ratioText(int numerator, int denominator) {
  if (denominator <= 0) return '0%';
  return '${((numerator / denominator) * 100).round().clamp(0, 999)}%';
}
