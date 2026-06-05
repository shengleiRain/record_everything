import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/day_bucket_view_model.dart';
import '../providers/home_providers.dart';

class HomeCalendar extends StatefulWidget {
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
  State<HomeCalendar> createState() => _HomeCalendarState();
}

class _HomeCalendarState extends State<HomeCalendar>
    with SingleTickerProviderStateMixin {
  static const double _modeSwitchThreshold = 56;

  double _verticalDragDistance = 0;

  void _handlePointerMove(PointerMoveEvent event) {
    _verticalDragDistance += event.delta.dy;
  }

  void _handlePointerEnd() {
    final distance = _verticalDragDistance;
    _verticalDragDistance = 0;

    if (distance > _modeSwitchThreshold &&
        widget.mode == HomeCalendarMode.week) {
      widget.onSetMode(HomeCalendarMode.month);
    } else if (distance < -_modeSwitchThreshold &&
        widget.mode == HomeCalendarMode.month) {
      widget.onSetMode(HomeCalendarMode.week);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWeek = widget.mode == HomeCalendarMode.week;
    final visibleBuckets = isWeek
        ? widget.buckets.take(7).toList()
        : widget.buckets;

    return Listener(
      key: const ValueKey('home-calendar-surface'),
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _verticalDragDistance = 0,
      onPointerMove: _handlePointerMove,
      onPointerUp: (_) => _handlePointerEnd(),
      onPointerCancel: (_) => _verticalDragDistance = 0,
      child: Container(
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
                    onPressed: widget.onPrevious,
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        isWeek
                            ? _formatWeekTitle(widget.visibleAnchorDate)
                            : _formatMonthTitle(widget.visibleAnchorDate),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isWeek ? '下拉展开月历 · 按周翻页' : '上滑收起周视图 · 按月翻页',
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
                    onPressed: widget.onNext,
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
            AnimatedSize(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: GridView.builder(
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
                    onTap: () => widget.onSelectDate(bucket.date),
                  );
                },
              ),
            ),
          ],
        ),
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
