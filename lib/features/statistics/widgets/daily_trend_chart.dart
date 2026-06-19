import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/database/daos/bill_record_dao.dart';

/// 当月每日支出柱状图。spec §3.3。
class DailyTrendChart extends StatelessWidget {
  const DailyTrendChart({super.key, required this.data});
  final List<DailySumRow> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('暂无数据', style: TextStyle(color: AppColors.textSecondary))),
      );
    }
    final avg =
        data.map((d) => d.total).reduce((a, b) => a + b) / data.length / 100;
    final maxY = data
            .map((d) => d.total)
            .reduce((a, b) => a > b ? a : b) /
        100;

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          minY: 0,
          maxY: maxY * 1.2,
          alignment: BarChartAlignment.spaceAround,
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
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  // 每 5 天显示一个标签，避免拥挤。
                  if (i >= 0 && i < data.length && (i % 5 == 0 || i == data.length - 1)) {
                    return Text(
                      '${data[i].date.day}',
                      style: const TextStyle(fontSize: 9),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          barGroups: data.asMap().entries.map((entry) {
            final value = entry.value.total / 100;
            final isHigh = value > avg * 1.5;
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: value,
                  color: isHigh ? AppColors.expense : AppColors.primary,
                  width: data.length > 20 ? 4 : 8,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(2)),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
