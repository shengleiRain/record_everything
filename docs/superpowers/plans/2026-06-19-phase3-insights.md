# 阶段三：智能洞察与自动化 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 record_everything 添加消费趋势图表（周/日/分类）和自动分类建议，帮用户理解消费模式并减少重复操作。

**Architecture:** 趋势数据通过新增 DAO 方法从 Drift 聚合，Provider 层暴露给 UI，用 `fl_chart` 渲染图表。自动分类通过标题模糊匹配历史账单的分类频率实现，在编辑页以 chip 形式展示推荐。

**Tech Stack:** Flutter（现有），Drift（现有），`fl_chart`（已有依赖，首次使用），Riverpod（现有）

**对应 Spec:** `docs/superpowers/specs/2026-06-19-phase3-insights-design.md`

---

## Task 1: 新增 DAO 方法

**Files:**
- Modify: `lib/data/database/daos/bill_record_dao.dart`
- Test: `test/bill_dao_trend_test.dart`

- [ ] **Step 1: 在 BillRecordDao 中添加 watchDailySumsForMonth**

在 `bill_record_dao.dart` 中添加：

```dart
/// 当月按日聚合支出/收入。返回 [{date (DateTime, 仅年月日), total (int, 分)}]。
Stream<List<DailySumRow>> watchDailySumsForMonth(
  DateTime month,
  String amountType,
) {
  final start = DateTime(month.year, month.month, 1);
  final end = DateTime(month.year, month.month + 1, 1);
  final query = selectOnly(billRecords)
    ..addColumns([billRecords.billTime.date, billRecords.amount.sum()])
    ..where(billRecords.billTime.isBetweenValues(start, end))
    ..where(billRecords.amountType.equals(amountType))
    ..where(billRecords.deletedAt.isNull())
    ..groupBy([billRecords.billTime.date]);
  return query.watch().map((rows) => rows.map((r) {
    final date = r.read(billRecords.billTime.date)!;
    final total = r.read(billRecords.amount.sum()) ?? 0;
    return DailySumRow(date: date, total: total);
  }).toList());
}

/// 最近 N 个月按月+分类聚合。返回 Top N 分类的月度数据。
Stream<List<CategoryMonthlySumRow>> watchCategoryMonthlySums(
  DateTime start,
  DateTime end,
  String amountType,
) {
  final query = selectOnly(billRecords)
    ..addColumns([
      billRecords.billTime.year,
      billRecords.billTime.month,
      billRecords.categoryId,
      billRecords.amount.sum(),
    ])
    ..where(billRecords.billTime.isBetweenValues(start, end))
    ..where(billRecords.amountType.equals(amountType))
    ..where(billRecords.deletedAt.isNull())
    ..where(billRecords.categoryId.isNotNull())
    ..groupBy([
      billRecords.billTime.year,
      billRecords.billTime.month,
      billRecords.categoryId,
    ]);
  return query.watch().map((rows) => rows.map((r) {
    return CategoryMonthlySumRow(
      year: r.read(billRecords.billTime.year)!,
      month: r.read(billRecords.billTime.month)!,
      categoryId: r.read(billRecords.categoryId)!,
      total: r.read(billRecords.amount.sum()) ?? 0,
    );
  }).toList());
}

/// 根据标题关键词推荐分类。查询标题包含 keyword 的账单，
/// 按 category_id 分组计数，返回使用最多的 category_id。
/// keyword 长度 < 2 时返回 null（避免误匹配）。
Future<int?> suggestCategoryByTitle(String keyword, String amountType) async {
  if (keyword.trim().length < 2) return null;
  final query = selectOnly(billRecords)
    ..addColumns([billRecords.categoryId, billRecords.categoryId.count()])
    ..where(billRecords.title.like('%$keyword%'))
    ..where(billRecords.amountType.equals(amountType))
    ..where(billRecords.deletedAt.isNull())
    ..where(billRecords.categoryId.isNotNull())
    ..groupBy([billRecords.categoryId])
    ..orderBy([OrderingTerm.desc(billRecords.categoryId.count())])
    ..limit(1);
  final result = await query.getSingleOrNull();
  return result?.read(billRecords.categoryId);
}
```

- [ ] **Step 2: 添加 DailySumRow 和 CategoryMonthlySumRow 数据类**

在 `bill_record_dao.dart` 末尾（或独立文件）添加：

```dart
class DailySumRow {
  const DailySumRow({required this.date, required this.total});
  final DateTime date;
  final int total; // 分
}

class CategoryMonthlySumRow {
  const CategoryMonthlySumRow({
    required this.year,
    required this.month,
    required this.categoryId,
    required this.total,
  });
  final int year;
  final int month;
  final int categoryId;
  final int total; // 分
}
```

- [ ] **Step 3: 写 DAO 测试**

`test/bill_dao_trend_test.dart`：
```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record_everything/data/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.categoryDao.getAll(); // 触发播种
  });
  tearDown(() async => db.close());

  test('suggestCategoryByTitle 匹配历史分类', () async {
    // 创建一个分类
    final cat = await db.categoryDao.insertOne(
      db.categories.companion.insert(name: '餐饮', type: 'expense'),
    );
    // 插入带该分类的账单
    await db.billRecordDao.create(
      title: '午餐',
      amount: 2500,
      amountType: 'expense',
      categoryId: cat.id,
      accountId: 1,
      billTime: DateTime.now(),
    );
    await db.billRecordDao.create(
      title: '午餐外卖',
      amount: 3000,
      amountType: 'expense',
      categoryId: cat.id,
      accountId: 1,
      billTime: DateTime.now(),
    );

    final suggested = await db.billRecordDao.suggestCategoryByTitle('午餐', 'expense');
    expect(suggested, cat.id);
  });

  test('suggestCategoryByTitle 短关键词返回 null', () async {
    final suggested = await db.billRecordDao.suggestCategoryByTitle('a', 'expense');
    expect(suggested, isNull);
  });

  test('watchDailySumsForMonth 返回按日聚合数据', () async {
    final now = DateTime(2026, 6, 15);
    await db.billRecordDao.create(
      title: '早餐',
      amount: 1000,
      amountType: 'expense',
      accountId: 1,
      billTime: DateTime(2026, 6, 10),
    );
    await db.billRecordDao.create(
      title: '午餐',
      amount: 2500,
      amountType: 'expense',
      accountId: 1,
      billTime: DateTime(2026, 6, 10),
    );
    await db.billRecordDao.create(
      title: '晚餐',
      amount: 3000,
      amountType: 'expense',
      accountId: 1,
      billTime: DateTime(2026, 6, 15),
    );

    final rows = await db.billRecordDao
        .watchDailySumsForMonth(DateTime(2026, 6), 'expense')
        .first;
    expect(rows, hasLength(2));
    final day10 = rows.firstWhere((r) => r.date.day == 10);
    expect(day10.total, 3500); // 1000 + 2500
  });
}
```

> 注意：`db.categories.companion.insert(...)` 和 `db.billRecordDao.create(...)` 的确切语法需参照现有测试。`accountId: 1` 假设默认账户已被播种（内存库 onCreate 会播种默认账户）。

- [ ] **Step 4: 运行测试**

Run: `flutter test test/bill_dao_trend_test.dart`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add lib/data/database/daos/bill_record_dao.dart test/bill_dao_trend_test.dart
git commit -m "feat(phase3): add DAO methods for trend analysis and category suggestion"
```

---

## Task 2: 新增 Provider

**Files:**
- Modify: `lib/features/statistics/providers/statistics_providers.dart`
- Modify: `lib/features/smart_entry/providers/smart_entry_providers.dart`

- [ ] **Step 1: 统计页 Provider**

在 `statistics_providers.dart` 末尾添加：

```dart
/// 最近 8 周每周支出总额。
final statsWeeklyTrendProvider =
    StreamProvider<List<WeeklySumRow>>((ref) {
  final db = ref.watch(databaseProvider);
  final now = DateTime.now();
  final start = now.subtract(const Duration(days: 56)); // 8 周前
  return db.billRecordDao.watchWeeklySums(start, now, 'expense');
});

/// 当月每日支出总额。
final statsDailyTrendProvider =
    StreamProvider<List<DailySumRow>>((ref) {
  final db = ref.watch(databaseProvider);
  final month = ref.watch(statsMonthProvider);
  return db.billRecordDao.watchDailySumsForMonth(month, 'expense');
});

/// 最近 6 个月 Top 5 分类月度支出。
final statsCategoryTrendProvider =
    StreamProvider<List<CategoryMonthlySumRow>>((ref) {
  final db = ref.watch(databaseProvider);
  final now = DateTime.now();
  final start = DateTime(now.year, now.month - 5, 1);
  final end = DateTime(now.year, now.month + 1, 1);
  return db.billRecordDao.watchCategoryMonthlySums(start, end, 'expense');
});
```

> 注意：`statsWeeklyTrendProvider` 需要一个新的 DAO 方法 `watchWeeklySums`（按周聚合）。如果 DAO 层不提供按周聚合，可以在 Provider 层用 `watchDailySumsForMonth` 的结果手动按周分组。或者在 DAO 中添加 `watchWeeklySums` 方法。

- [ ] **Step 2: 自动分类 Provider**

在 `smart_entry_providers.dart` 中添加：

```dart
/// 根据账单标题推荐分类 id。
final categorySuggestionProvider =
    FutureProvider.family<int?, (String title, String amountType)>(
  (ref, params) async {
    final (title, amountType) = params;
    final db = ref.read(databaseProvider);
    return db.billRecordDao.suggestCategoryByTitle(title, amountType);
  },
);
```

- [ ] **Step 3: 静态检查**

Run: `flutter analyze lib/features/statistics/providers/ lib/features/smart_entry/providers/`
Expected: No issues

- [ ] **Step 4: 提交**

```bash
git add lib/features/statistics/providers/statistics_providers.dart lib/features/smart_entry/providers/smart_entry_providers.dart
git commit -m "feat(phase3): add trend and category suggestion providers"
```

---

## Task 3: 趋势图表 UI

**Files:**
- Create: `lib/features/statistics/widgets/weekly_trend_chart.dart`
- Create: `lib/features/statistics/widgets/daily_trend_chart.dart`
- Create: `lib/features/statistics/widgets/category_trend_chart.dart`
- Modify: `lib/features/statistics/pages/statistics_page.dart`

- [ ] **Step 1: 周趋势折线图**

`lib/features/statistics/widgets/weekly_trend_chart.dart`：
```dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money_formatter.dart';
import '../../bill/daos/bill_record_dao.dart';

class WeeklyTrendChart extends StatelessWidget {
  const WeeklyTrendChart({super.key, required this.data});
  final List<WeeklySumRow> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const SizedBox(height: 200, child: Center(child: Text('暂无数据')));
    }
    final spots = data.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.total / 100);
    }).toList();
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY * 1.2,
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                getTitlesWidget: (v, _) => Text(
                  '¥${v.toInt()}',
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) => Text(
                  'W${v.toInt() + 1}',
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: AppColors.primary,
              barWidth: 2,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.primary.withValues(alpha: 0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: 日消费柱状图**

`lib/features/statistics/widgets/daily_trend_chart.dart`：
```dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../bill/daos/bill_record_dao.dart';

class DailyTrendChart extends StatelessWidget {
  const DailyTrendChart({super.key, required this.data});
  final List<DailySumRow> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const SizedBox(height: 200, child: Center(child: Text('暂无数据')));
    }
    final avg = data.map((d) => d.total).reduce((a, b) => a + b) / data.length;
    final maxY = data.map((d) => d.total).reduce((a, b) => a > b ? a : b) / 100;

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          minY: 0,
          maxY: maxY * 1.2,
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                getTitlesWidget: (v, _) => Text(
                  '¥${v.toInt()}',
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) => Text(
                  '${v.toInt()}',
                  style: const TextStyle(fontSize: 9),
                ),
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          barGroups: data.asMap().entries.map((e) {
            final isHigh = e.value.total > avg * 1.5;
            return BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  toY: e.value.total / 100,
                  color: isHigh ? AppColors.expense : AppColors.primary,
                  width: 8,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: 分类趋势堆叠图**

`lib/features/statistics/widgets/category_trend_chart.dart`：
```dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../bill/daos/bill_record_dao.dart';

class CategoryTrendChart extends StatelessWidget {
  const CategoryTrendChart({
    super.key,
    required this.data,
    required this.categoryNames,
  });
  final List<CategoryMonthlySumRow> data;
  final Map<int, String> categoryNames; // categoryId → name

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const SizedBox(height: 200, child: Center(child: Text('暂无数据')));
    }
    // 按月分组，每月按分类堆叠。
    final months = <String, Map<int, int>>{};
    for (final row in data) {
      final key = '${row.year}-${row.month.toString().padLeft(2, '0')}';
      months.putIfAbsent(key, () => {});
      months[key]![row.categoryId] =
          (months[key]![row.categoryId] ?? 0) + row.total;
    }
    final sortedMonths = months.keys.toList()..sort();
    final allCatIds = data.map((r) => r.categoryId).toSet().toList();

    final colors = [
      AppColors.primary,
      AppColors.expense,
      AppColors.income,
      AppColors.upcoming,
      AppColors.completed,
    ];

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i >= 0 && i < sortedMonths.length) {
                    final parts = sortedMonths[i].split('-');
                    return Text('${parts[1]}月', style: const TextStyle(fontSize: 10));
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                getTitlesWidget: (v, _) => Text(
                  '¥${v.toInt()}',
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          barGroups: sortedMonths.asMap().entries.map((entry) {
            final monthData = months[entry.value]!;
            final rods = <BarChartRodData>[];
            for (final catId in allCatIds) {
              final value = (monthData[catId] ?? 0) / 100;
              if (value > 0) {
                rods.add(BarChartRodData(
                  toY: value,
                  color: colors[allCatIds.indexOf(catId) % colors.length],
                  width: 16,
                ));
              }
            }
            return BarChartGroupData(x: entry.key, barRods: rods);
          }).toList(),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: 接入统计页**

在 `statistics_page.dart` 的 `_MonthlyTrendChart` 之后插入三个新 section：

```dart
// 周消费趋势
_buildSection('周消费趋势', [
  ref.watch(statsWeeklyTrendProvider).when(
    data: (data) => WeeklyTrendChart(data: data),
    loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
    error: (e, _) => Text('加载失败: $e'),
  ),
]),
// 日消费柱状图
_buildSection('本月每日支出', [
  ref.watch(statsDailyTrendProvider).when(
    data: (data) => DailyTrendChart(data: data),
    loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
    error: (e, _) => Text('加载失败: $e'),
  ),
]),
// 分类趋势
_buildSection('分类消费趋势', [
  ref.watch(statsCategoryTrendProvider).when(
    data: (data) => CategoryTrendChart(
      data: data,
      categoryNames: _categoryNames, // 需要从分类表加载
    ),
    loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
    error: (e, _) => Text('加载失败: $e'),
  ),
]),
```

> 注意：`_categoryNames` 需要从分类表加载。在统计页 initState 中用 `db.categoryDao.getAll()` 加载并缓存为 `Map<int, String>`。`_buildSection` 是统计页已有的 section 构建辅助方法（需确认确切名称）。

- [ ] **Step 5: 运行测试 + 分析**

Run: `flutter analyze lib/features/statistics/`
Expected: No issues

- [ ] **Step 6: 提交**

```bash
git add lib/features/statistics/widgets/ lib/features/statistics/pages/statistics_page.dart
git commit -m "feat(phase3): add trend charts (weekly/daily/category) to statistics page"
```

---

## Task 4: 自动分类建议 UI

**Files:**
- Modify: `lib/features/bill/pages/bill_edit_page.dart`
- Modify: `lib/features/smart_entry/widgets/draft_item_card.dart`

- [ ] **Step 1: 账单编辑页添加推荐 chip**

在 `bill_edit_page.dart` 的分类选择器旁添加：

```dart
// 标题输入框 onChanged 回调中：
void _onTitleChanged(String title) {
  _debounce?.cancel();
  _debounce = Timer(const Duration(milliseconds: 500), () {
    if (title.trim().length >= 2 && _selectedCategoryId == null) {
      ref.read(categorySuggestionProvider((title, _amountType.value)))
          .then((id) {
        if (id != null && mounted) {
          setState(() => _suggestedCategoryId = id);
        }
      });
    }
  });
}

// 分类选择器旁：
if (_suggestedCategoryId != null && _selectedCategoryId == null)
  ActionChip(
    avatar: const Icon(Icons.lightbulb_outline, size: 16),
    label: Text('推荐：${_categoryName(_suggestedCategoryId!)}'),
    onPressed: () {
      setState(() {
        _selectedCategoryId = _suggestedCategoryId;
        _suggestedCategoryId = null;
      });
    },
  ),
```

- [ ] **Step 2: 草稿卡片添加推荐 chip**

在 `draft_item_card.dart` 的分类字段旁添加类似逻辑。当 `item.categoryId` 为空且 `item.categoryGuess` 不为空时，查询推荐并显示 chip。

- [ ] **Step 3: 运行测试 + 分析**

Run: `flutter analyze lib/features/bill/pages/bill_edit_page.dart lib/features/smart_entry/widgets/draft_item_card.dart`
Expected: No issues

- [ ] **Step 4: 提交**

```bash
git add lib/features/bill/pages/bill_edit_page.dart lib/features/smart_entry/widgets/draft_item_card.dart
git commit -m "feat(phase3): add auto-category suggestion chip to bill edit and draft card"
```
