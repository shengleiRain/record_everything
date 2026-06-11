import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/date_formatter.dart';
import '../models/calendar_window.dart';
import '../models/agenda_item_view_model.dart';
import '../models/day_bucket_view_model.dart';
import '../../life_item/providers/life_item_providers.dart';
import '../providers/home_providers.dart';
import '../widgets/calendar_snap_behavior.dart';
import '../widgets/home_agenda_scroll_fill.dart';
import '../widgets/home_calendar_sliver.dart';
import '../widgets/home_calendar.dart';
import '../widgets/home_summary_strip.dart';
import '../widgets/quick_create_sheet.dart';
import '../widgets/selected_day_agenda.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  List<DayBucketViewModel>? _lastBuckets;
  List<AgendaItemViewModel>? _lastAgendaItems;
  late final ScrollController _scrollController = ScrollController();
  bool _didApplyInitialCalendarCollapse = false;
  bool _isSnappingCalendar = false;
  HomeCalendarMode _settledCalendarMode = HomeCalendarMode.week;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final todayAsync = ref.watch(todayPendingProvider);
    final overdueAsync = ref.watch(overdueItemsProvider);
    final incomeAsync = ref.watch(homeMonthlyIncomeProvider);
    final expenseAsync = ref.watch(homeMonthlyExpenseProvider);
    final selectedDate = ref.watch(homeSelectedDateProvider);
    final visibleAnchorDate = ref.watch(homeVisibleAnchorDateProvider);
    final bucketsAsync = ref.watch(homeCalendarBucketsProvider);
    final agendaAsync = ref.watch(homeSelectedDayAgendaProvider);
    final currentBuckets = bucketsAsync.valueOrNull;
    final currentAgendaItems = agendaAsync.valueOrNull;

    if (currentBuckets != null) _lastBuckets = currentBuckets;
    if (currentAgendaItems != null) _lastAgendaItems = currentAgendaItems;

    final buckets = currentBuckets ?? _lastBuckets;
    final agendaItems = currentAgendaItems ?? _lastAgendaItems;
    final screenWidth = MediaQuery.of(context).size.width;
    if (buckets != null) {
      _scheduleInitialCalendarCollapse(buckets, screenWidth);
    }

    return Semantics(
      label: 'home_dashboard_screen',
      container: true,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('今天', style: TextStyle(fontSize: 18)),
              Text(
                DateFormatter.formatDate(DateTime.now()),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: '项目',
              icon: const Icon(Icons.folder_outlined),
              onPressed: () => context.push('/projects'),
            ),
            IconButton(
              tooltip: '搜索',
              icon: const Icon(Icons.search),
              onPressed: () => context.push('/search'),
            ),
            IconButton(
              tooltip: '新增',
              icon: const Icon(Icons.add),
              onPressed: () => showQuickCreateSheet(context),
            ),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final agendaMinHeight = buckets != null
                ? (constraints.maxHeight -
                          _calendarCollapsedExtent(screenWidth))
                      .clamp(0.0, double.infinity)
                      .toDouble()
                : 0.0;

            return NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (buckets != null) {
                  _handleScrollNotification(notification, buckets, screenWidth);
                }
                return false;
              },
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  // 1. Pinned summary + collapsible calendar. The calendar
                  // consumes the first scroll range, so the agenda pushes it
                  // immediately instead of scrolling under a separate summary.
                  if (buckets != null)
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: CalendarSliver(
                        summaryStrip: HomeSummaryStrip(
                          monthlyExpense: expenseAsync.valueOrNull ?? 0,
                          monthlyIncome: incomeAsync.valueOrNull ?? 0,
                          pendingCount: todayAsync.valueOrNull?.length ?? 0,
                          overdueCount: overdueAsync.valueOrNull?.length ?? 0,
                        ),
                        visibleAnchorDate: visibleAnchorDate,
                        selectedDate: selectedDate,
                        monthBuckets: buckets,
                        onPrevious: () => _moveWindow(ref, -1),
                        onNext: () => _moveWindow(ref, 1),
                        onSelectDate: (date) => _selectDate(ref, date, buckets),
                        screenWidth: screenWidth,
                      ),
                    )
                  else
                    SliverToBoxAdapter(
                      child: HomeSummaryStrip(
                        monthlyExpense: expenseAsync.valueOrNull ?? 0,
                        monthlyIncome: incomeAsync.valueOrNull ?? 0,
                        pendingCount: todayAsync.valueOrNull?.length ?? 0,
                        overdueCount: overdueAsync.valueOrNull?.length ?? 0,
                      ),
                    ),

                  // 2. Agenda + background fill. Its height is
                  // max(collapsed-week remainder, natural agenda height + gap).
                  HomeAgendaScrollFill(
                    minHeight: agendaMinHeight,
                    child: SelectedDayAgenda(
                      selectedDate: selectedDate,
                      items: agendaItems ?? const [],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _selectDate(
    WidgetRef ref,
    DateTime date,
    List<DayBucketViewModel> visibleBuckets,
  ) {
    final normalized = CalendarWindow.dateOnly(date);
    ref.read(homeSelectedDateProvider.notifier).state = normalized;

    final isVisible = visibleBuckets.any(
      (bucket) => CalendarWindow.isSameDate(bucket.date, normalized),
    );
    if (!isVisible) {
      ref.read(homeVisibleAnchorDateProvider.notifier).state = normalized;
    }
  }

  void _moveWindow(WidgetRef ref, int direction) {
    final mode = ref.read(homeCalendarModeProvider);
    final current = ref.read(homeVisibleAnchorDateProvider);
    final next = mode == HomeCalendarMode.week
        ? CalendarWindow.addWeeks(current, direction)
        : CalendarWindow.addMonths(current, direction);
    ref.read(homeSelectedDateProvider.notifier).state = next;
    ref.read(homeVisibleAnchorDateProvider.notifier).state = next;
  }

  void _scheduleInitialCalendarCollapse(
    List<DayBucketViewModel> buckets,
    double screenWidth,
  ) {
    if (_didApplyInitialCalendarCollapse) return;
    _didApplyInitialCalendarCollapse = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final target = _calendarCollapsedScrollOffset(buckets, screenWidth);
      final clamped = target.clamp(
        _scrollController.position.minScrollExtent,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.jumpTo(clamped.toDouble());
    });
  }

  void _snapCalendarIfNeeded(
    List<DayBucketViewModel> buckets,
    double screenWidth,
  ) {
    if (!_scrollController.hasClients || _isSnappingCalendar) return;

    const start = 0.0;
    final range = _calendarCollapseRange(buckets, screenWidth);
    if (range <= 0) return;

    final end = start + range;
    final reachableEnd = end
        .clamp(
          _scrollController.position.minScrollExtent,
          _scrollController.position.maxScrollExtent,
        )
        .toDouble();
    if (reachableEnd <= start) return;

    final offset = _scrollController.offset;
    const tolerance = 0.5;
    if (offset <= start + tolerance) {
      _setCalendarMode(HomeCalendarMode.month);
      return;
    }
    if (offset >= reachableEnd - tolerance) {
      _setCalendarMode(HomeCalendarMode.week);
      return;
    }

    final progress = ((offset - start) / (reachableEnd - start)).clamp(
      0.0,
      1.0,
    );
    final snapToCollapsed = CalendarSnapBehavior.shouldSnapToCollapsed(
      collapseProgress: progress,
      currentlyCollapsed: _settledCalendarMode == HomeCalendarMode.week,
    );
    final target = snapToCollapsed ? reachableEnd : start;
    if ((target - offset).abs() <= tolerance) return;

    final mode = snapToCollapsed
        ? HomeCalendarMode.week
        : HomeCalendarMode.month;
    _setCalendarMode(mode);

    _isSnappingCalendar = true;
    _scrollController
        .animateTo(
          target,
          duration: CalendarSnapBehavior.snapDuration,
          curve: CalendarSnapBehavior.snapCurve,
        )
        .whenComplete(() {
          if (mounted) _isSnappingCalendar = false;
        });
  }

  void _handleScrollNotification(
    ScrollNotification notification,
    List<DayBucketViewModel> buckets,
    double screenWidth,
  ) {
    final shouldSnap =
        notification is ScrollEndNotification ||
        (notification is UserScrollNotification &&
            notification.direction == ScrollDirection.idle);
    if (!shouldSnap) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _snapCalendarIfNeeded(buckets, screenWidth);
    });
  }

  void _setCalendarMode(HomeCalendarMode mode) {
    _settledCalendarMode = mode;
    if (ref.read(homeCalendarModeProvider) != mode) {
      ref.read(homeCalendarModeProvider.notifier).state = mode;
    }
    if (mode == HomeCalendarMode.week) {
      final selected = CalendarWindow.dateOnly(
        ref.read(homeSelectedDateProvider),
      );
      final anchor = ref.read(homeVisibleAnchorDateProvider);
      if (!CalendarWindow.isSameDate(anchor, selected)) {
        ref.read(homeVisibleAnchorDateProvider.notifier).state = selected;
      }
    }
  }

  double _calendarCollapsedScrollOffset(
    List<DayBucketViewModel> buckets,
    double screenWidth,
  ) {
    return _calendarCollapseRange(buckets, screenWidth);
  }

  double _calendarCollapsedExtent(double screenWidth) {
    return HomeHeaderLayout.summaryExtent +
        CalendarLayout.fullHeight(1, screenWidth);
  }

  double _calendarCollapseRange(
    List<DayBucketViewModel> buckets,
    double screenWidth,
  ) {
    final rowCount = (buckets.length / CalendarLayout.crossAxisCount).ceil();
    return CalendarLayout.fullHeight(rowCount, screenWidth) -
        CalendarLayout.fullHeight(1, screenWidth);
  }
}
