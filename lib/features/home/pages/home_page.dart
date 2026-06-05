import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/date_formatter.dart';
import '../models/calendar_window.dart';
import '../models/agenda_item_view_model.dart';
import '../models/day_bucket_view_model.dart';
import '../../life_item/providers/life_item_providers.dart';
import '../providers/home_providers.dart';
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

  @override
  Widget build(BuildContext context) {
    final todayAsync = ref.watch(todayPendingProvider);
    final overdueAsync = ref.watch(overdueItemsProvider);
    final incomeAsync = ref.watch(homeMonthlyIncomeProvider);
    final expenseAsync = ref.watch(homeMonthlyExpenseProvider);
    final mode = ref.watch(homeCalendarModeProvider);
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
              tooltip: '搜索',
              icon: const Icon(Icons.search),
              onPressed: () => context.push('/items'),
            ),
            IconButton(
              tooltip: '新增',
              icon: const Icon(Icons.add),
              onPressed: () => showQuickCreateSheet(context),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            HomeSummaryStrip(
              monthlyExpense: expenseAsync.valueOrNull ?? 0,
              monthlyIncome: incomeAsync.valueOrNull ?? 0,
              pendingCount: todayAsync.valueOrNull?.length ?? 0,
              overdueCount: overdueAsync.valueOrNull?.length ?? 0,
            ),
            if (buckets == null)
              const SizedBox(height: 220)
            else
              HomeCalendar(
                mode: mode,
                visibleAnchorDate: visibleAnchorDate,
                selectedDate: selectedDate,
                buckets: buckets,
                onPrevious: () => _moveWindow(ref, mode, -1),
                onNext: () => _moveWindow(ref, mode, 1),
                onSelectDate: (date) => _selectDate(ref, date, buckets),
                onSetMode: (nextMode) {
                  ref.read(homeCalendarModeProvider.notifier).state = nextMode;
                  if (nextMode == HomeCalendarMode.week) {
                    ref.read(homeVisibleAnchorDateProvider.notifier).state =
                        CalendarWindow.dateOnly(selectedDate);
                  }
                },
              ),
            SelectedDayAgenda(
              selectedDate: selectedDate,
              items: agendaItems ?? const [],
            ),
          ],
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

  void _moveWindow(WidgetRef ref, HomeCalendarMode mode, int direction) {
    final current = ref.read(homeVisibleAnchorDateProvider);
    final next = mode == HomeCalendarMode.week
        ? CalendarWindow.addWeeks(current, direction)
        : CalendarWindow.addMonths(current, direction);
    ref.read(homeVisibleAnchorDateProvider.notifier).state = next;
  }
}
