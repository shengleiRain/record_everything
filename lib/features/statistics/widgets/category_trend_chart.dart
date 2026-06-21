import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../data/database/daos/bill_record_dao.dart';

/// 最近 6 个月分类消费趋势堆叠柱状图。spec §3.3。
class CategoryTrendChart extends StatelessWidget {
  const CategoryTrendChart({
    super.key,
    required this.data,
    required this.categoryNames,
  });

  final List<CategoryMonthlySumRow> data;
  final Map<int, String> categoryNames; // categoryId → name

  List<Color> _colors(BuildContext context) => [
        AppColors.primary(context),
        AppColors.expense(context),
        AppColors.income(context),
        AppColors.upcoming(context),
        AppColors.completed(context),
        chartPaletteExtras[0], // 紫色
      ];

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Text('暂无数据', style: TextStyle(color: AppColors.textSecondary(context))),
        ),
      );
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

    // 找出总消费 Top 5 分类。
    final catTotals = <int, int>{};
    for (final row in data) {
      catTotals[row.categoryId] =
          (catTotals[row.categoryId] ?? 0) + row.total;
    }
    final topCats = catTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topCatIds = topCats.take(5).map((e) => e.key).toList();

    final maxY = months.values
        .map((m) => m.values.fold(0, (a, b) => a + b))
        .reduce((a, b) => a > b ? a : b) / 100;

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              minY: 0,
              maxY: maxY * 1.2,
              alignment: BarChartAlignment.spaceAround,
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (i >= 0 && i < sortedMonths.length) {
                        final parts = sortedMonths[i].split('-');
                        return Text(
                          '${parts[1]}月',
                          style: const TextStyle(fontSize: 10),
                        );
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
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              gridData: const FlGridData(show: true, drawVerticalLine: false),
              borderData: FlBorderData(show: false),
              barGroups: sortedMonths.asMap().entries.map((entry) {
                final monthData = months[entry.value]!;
                final rods = <BarChartRodData>[];
                for (final catId in topCatIds) {
                  final value = (monthData[catId] ?? 0) / 100;
                  if (value > 0) {
                    rods.add(
                      BarChartRodData(
                        toY: value,
                        color: _colors(context)[topCatIds.indexOf(catId) %
                            _colors(context).length],
                        width: 16,
                      ),
                    );
                  }
                }
                return BarChartGroupData(x: entry.key, barRods: rods);
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // 图例
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: topCatIds.map((catId) {
            final color =
                _colors(context)[topCatIds.indexOf(catId) % _colors(context).length];
            final name = categoryNames[catId] ?? '分类$catId';
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 4),
                Text(name, style: const TextStyle(fontSize: 11)),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}
