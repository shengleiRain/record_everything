import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/day_bucket_view_model.dart';

/// Calendar grid layout constants used by both [HomeCalendar] and
/// [CalendarSliverDelegate] to compute heights.
class CalendarLayout {
  static const double marginVertical = 16; // top 8 + bottom 8
  static const double paddingVertical = 24; // top 10 + bottom 14
  static const double navRowHeight = 48;
  static const double headerGap = 12;
  static const double weekdayRowHeight = 20;
  static const double gridTopGap = 8;
  static const double mainAxisSpacing = 6;
  static const double crossAxisSpacing = 4;
  static const int crossAxisCount = 7;
  static const double childAspectRatio = 0.72;

  static double get fixedHeaderHeight =>
      navRowHeight + headerGap + weekdayRowHeight + gridTopGap;

  static double containerExtras(double screenWidth) =>
      marginVertical +
      paddingVertical +
      (screenWidth - 32 - 24 - (crossAxisSpacing * (crossAxisCount - 1))) /
          crossAxisCount /
          childAspectRatio;

  static double cellHeight(double screenWidth) =>
      (screenWidth - 32 - 24 - (crossAxisSpacing * (crossAxisCount - 1))) /
      crossAxisCount /
      childAspectRatio;

  static double gridHeight(int rowCount, double screenWidth) =>
      rowCount * cellHeight(screenWidth) + (rowCount - 1) * mainAxisSpacing;

  static double fullHeight(int rowCount, double screenWidth) =>
      marginVertical +
      paddingVertical +
      fixedHeaderHeight +
      gridHeight(rowCount, screenWidth);
}

class HomeCalendar extends StatelessWidget {
  const HomeCalendar({
    super.key,
    required this.isWeek,
    required this.visibleAnchorDate,
    required this.visibleBuckets,
    required this.onPrevious,
    required this.onNext,
    required this.onSelectDate,
    this.gridHeight,
    this.gridVerticalOffset = 0,
  });

  final bool isWeek;
  final DateTime visibleAnchorDate;
  final List<DayBucketViewModel> visibleBuckets;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<DateTime> onSelectDate;

  /// When provided, the grid is clipped to this height for smooth collapse.
  final double? gridHeight;

  /// Vertical translation applied to the full month grid inside the clip.
  final double gridVerticalOffset;

  @override
  Widget build(BuildContext context) {
    final grid = _CalendarGrid(
      buckets: visibleBuckets,
      gridHeight: gridHeight,
      gridVerticalOffset: gridVerticalOffset,
      onSelectDate: onSelectDate,
    );

    return Container(
      key: const ValueKey('home-calendar-surface'),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Semantics(
                label: 'home_calendar_previous',
                button: true,
                child: IconButton(
                  key: const ValueKey('home-calendar-previous'),
                  icon: const Icon(Icons.chevron_left),
                  onPressed: onPrevious,
                ),
              ),
              Expanded(
                child: Text(
                  isWeek
                      ? _formatWeekTitle(visibleAnchorDate)
                      : _formatMonthTitle(visibleAnchorDate),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Semantics(
                label: 'home_calendar_next',
                button: true,
                child: IconButton(
                  key: const ValueKey('home-calendar-next'),
                  icon: const Icon(Icons.chevron_right),
                  onPressed: onNext,
                ),
              ),
            ],
          ),
          const SizedBox(height: CalendarLayout.headerGap),
          Row(
            children: [
              for (final label in ['周日', '周一', '周二', '周三', '周四', '周五', '周六'])
                Expanded(child: _WeekdayLabel(label)),
            ],
          ),
          const SizedBox(height: CalendarLayout.gridTopGap),
          grid,
        ],
      ),
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
    required this.buckets,
    required this.gridHeight,
    required this.gridVerticalOffset,
    required this.onSelectDate,
  });

  final List<DayBucketViewModel> buckets;
  final double? gridHeight;
  final double gridVerticalOffset;
  final ValueChanged<DateTime> onSelectDate;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final rowCount = (buckets.length / CalendarLayout.crossAxisCount)
            .ceil();
        final cellWidth =
            (constraints.maxWidth -
                CalendarLayout.crossAxisSpacing *
                    (CalendarLayout.crossAxisCount - 1)) /
            CalendarLayout.crossAxisCount;
        final cellHeight = cellWidth / CalendarLayout.childAspectRatio;
        final fullGridHeight =
            rowCount * cellHeight +
            (rowCount - 1) * CalendarLayout.mainAxisSpacing;
        final fullGrid = SizedBox(
          height: fullGridHeight,
          child: Column(
            children: [
              for (var row = 0; row < rowCount; row++) ...[
                SizedBox(
                  height: cellHeight,
                  child: Row(
                    children: [
                      for (
                        var column = 0;
                        column < CalendarLayout.crossAxisCount;
                        column++
                      ) ...[
                        Expanded(
                          child: _DayCell(
                            key: _dayCellKey(row, column),
                            bucket:
                                buckets[row * CalendarLayout.crossAxisCount +
                                    column],
                            onTap: () => onSelectDate(
                              buckets[row * CalendarLayout.crossAxisCount +
                                      column]
                                  .date,
                            ),
                          ),
                        ),
                        if (column < CalendarLayout.crossAxisCount - 1)
                          const SizedBox(
                            width: CalendarLayout.crossAxisSpacing,
                          ),
                      ],
                    ],
                  ),
                ),
                if (row < rowCount - 1)
                  const SizedBox(height: CalendarLayout.mainAxisSpacing),
              ],
            ],
          ),
        );

        final clippedHeight = gridHeight;
        if (clippedHeight == null) return fullGrid;

        return ClipRect(
          child: SizedBox(
            key: const ValueKey('home-calendar-grid-clip'),
            height: clippedHeight,
            child: OverflowBox(
              alignment: Alignment.topCenter,
              minHeight: 0,
              maxHeight: fullGridHeight,
              child: Transform.translate(
                key: const ValueKey('home-calendar-grid-transform'),
                offset: Offset(0, gridVerticalOffset),
                child: fullGrid,
              ),
            ),
          ),
        );
      },
    );
  }

  ValueKey<String> _dayCellKey(int row, int column) {
    final bucket = buckets[row * CalendarLayout.crossAxisCount + column];
    return ValueKey(
      'home-calendar-day-${bucket.date.year}-${bucket.date.month}-${bucket.date.day}',
    );
  }
}

class _WeekdayLabel extends StatelessWidget {
  const _WeekdayLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({super.key, required this.bucket, required this.onTap});

  final DayBucketViewModel bucket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isSelected = bucket.isSelected;
    final foreground = isSelected
        ? Colors.white
        : bucket.isInVisibleMonth
        ? AppColors.textPrimary
        : AppColors.textHint;
    final labelColor = isSelected
        ? Colors.white.withValues(alpha: 0.88)
        : bucket.overdueCount > 0
        ? AppColors.upcoming
        : AppColors.textSecondary;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : Colors.black.withValues(alpha: 0.05),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${bucket.date.day}',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                bucket.compactLabel,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: labelColor,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatWeekTitle(DateTime date) {
  final week = ((date.day - 1) / 7).floor() + 1;
  return '${date.year}年${date.month}月 第$week周';
}

String _formatMonthTitle(DateTime date) => '${date.year}年${date.month}月';
