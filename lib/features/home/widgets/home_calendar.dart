import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/day_bucket_view_model.dart';
import '../providers/home_providers.dart';

class HomeCalendar extends StatelessWidget {
  const HomeCalendar({
    super.key,
    required this.mode,
    required this.visibleAnchorDate,
    required this.selectedDate,
    required this.buckets,
    required this.onPrevious,
    required this.onNext,
    required this.onSelectDate,
    required this.onSetMode,
  });

  final HomeCalendarMode mode;
  final DateTime visibleAnchorDate;
  final DateTime selectedDate;
  final List<DayBucketViewModel> buckets;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<DateTime> onSelectDate;
  final ValueChanged<HomeCalendarMode> onSetMode;

  @override
  Widget build(BuildContext context) {
    final isWeek = mode == HomeCalendarMode.week;
    final visibleBuckets = isWeek ? buckets.take(7).toList() : buckets;

    return Container(
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
                child: Column(
                  children: [
                    Text(
                      isWeek
                          ? _formatWeekTitle(visibleAnchorDate)
                          : _formatMonthTitle(visibleAnchorDate),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isWeek ? '左右切换按周翻页' : '左右切换按月翻页',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
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
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Semantics(
                label: 'home_calendar_toggle_week',
                button: true,
                child: ChoiceChip(
                  key: const ValueKey('home-calendar-week-mode'),
                  label: Text(isWeek ? '周视图' : '收起周视图'),
                  selected: isWeek,
                  onSelected: (_) => onSetMode(HomeCalendarMode.week),
                  selectedColor: AppColors.primaryLight,
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                label: 'home_calendar_toggle_month',
                button: true,
                child: ChoiceChip(
                  key: const ValueKey('home-calendar-month-mode'),
                  label: Text(isWeek ? '展开月历' : '月视图'),
                  selected: !isWeek,
                  onSelected: (_) => onSetMode(HomeCalendarMode.month),
                  selectedColor: AppColors.primaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final label in ['周日', '周一', '周二', '周三', '周四', '周五', '周六'])
                Expanded(child: _WeekdayLabel(label)),
            ],
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: visibleBuckets.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 4,
              childAspectRatio: 0.82,
            ),
            itemBuilder: (context, index) {
              final bucket = visibleBuckets[index];
              return _DayCell(
                key: ValueKey(
                  'home-calendar-day-${bucket.date.year}-${bucket.date.month}-${bucket.date.day}',
                ),
                bucket: bucket,
                onTap: () => onSelectDate(bucket.date),
              );
            },
          ),
        ],
      ),
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
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
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
            const SizedBox(height: 3),
            Text(
              bucket.compactLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: labelColor, fontSize: 10),
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
