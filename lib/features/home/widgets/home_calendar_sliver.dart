import 'package:flutter/material.dart';

import '../models/calendar_window.dart';
import '../models/day_bucket_view_model.dart';
import 'calendar_collapse_geometry.dart';
import 'home_calendar.dart';
import 'home_summary_strip.dart';

class HomeHeaderLayout {
  const HomeHeaderLayout._();

  static const double summaryExtent = 86;
}

class CalendarSliver extends SliverPersistentHeaderDelegate {
  CalendarSliver({
    required this.summaryStrip,
    required this.visibleAnchorDate,
    required this.selectedDate,
    required this.monthBuckets,
    required this.onPrevious,
    required this.onNext,
    required this.onSelectDate,
    required this.screenWidth,
  });

  final HomeSummaryStrip summaryStrip;
  final DateTime visibleAnchorDate;
  final DateTime selectedDate;
  final List<DayBucketViewModel> monthBuckets;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<DateTime> onSelectDate;
  final double screenWidth;

  late final int _totalRows = (monthBuckets.length / 7).ceil();
  late final double _maxExtent =
      HomeHeaderLayout.summaryExtent +
      CalendarLayout.fullHeight(_totalRows, screenWidth);
  late final double _minExtent =
      HomeHeaderLayout.summaryExtent +
      CalendarLayout.fullHeight(1, screenWidth);

  @override
  double get maxExtent => _maxExtent;

  @override
  double get minExtent => _minExtent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final range = maxExtent - minExtent;
    final t = range > 0 ? (shrinkOffset / range).clamp(0.0, 1.0) : 0.0;
    final isWeek = t >= 0.5;

    final selectedRow = _findSelectedRowIndex();
    final geometry = CalendarCollapseGeometry.resolve(
      totalRows: _totalRows,
      selectedRow: selectedRow,
      rowHeight: CalendarLayout.cellHeight(screenWidth),
      rowSpacing: CalendarLayout.mainAxisSpacing,
      collapseProgress: t,
    );
    final currentExtent = maxExtent - shrinkOffset.clamp(0.0, range);

    return SizedBox(
      height: currentExtent,
      child: ClipRect(
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            SizedBox(
              height: HomeHeaderLayout.summaryExtent,
              child: summaryStrip,
            ),
            HomeCalendar(
              isWeek: isWeek,
              visibleAnchorDate: visibleAnchorDate,
              visibleBuckets: monthBuckets,
              onPrevious: onPrevious,
              onNext: onNext,
              onSelectDate: onSelectDate,
              gridHeight: geometry.visibleHeight,
              gridVerticalOffset: -geometry.viewportTop,
            ),
          ],
        ),
      ),
    );
  }

  int _findSelectedRowIndex() {
    final normalizedSelected = CalendarWindow.dateOnly(selectedDate);
    for (int i = 0; i < monthBuckets.length; i++) {
      if (CalendarWindow.isSameDate(monthBuckets[i].date, normalizedSelected)) {
        return i ~/ 7;
      }
    }
    return 0;
  }

  @override
  bool shouldRebuild(covariant CalendarSliver oldDelegate) =>
      visibleAnchorDate != oldDelegate.visibleAnchorDate ||
      selectedDate != oldDelegate.selectedDate ||
      monthBuckets != oldDelegate.monthBuckets ||
      summaryStrip.monthlyExpense != oldDelegate.summaryStrip.monthlyExpense ||
      summaryStrip.monthlyIncome != oldDelegate.summaryStrip.monthlyIncome ||
      summaryStrip.pendingCount != oldDelegate.summaryStrip.pendingCount ||
      summaryStrip.overdueCount != oldDelegate.summaryStrip.overdueCount ||
      screenWidth != oldDelegate.screenWidth;
}
