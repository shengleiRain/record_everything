import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../bill/providers/bill_providers.dart';
import '../../life_item/providers/life_item_providers.dart';
import '../../project/providers/project_providers.dart';
import '../models/agenda_item_view_model.dart';
import '../models/calendar_window.dart';
import '../models/day_bucket_view_model.dart';

enum HomeCalendarMode { week, month }

final homeSelectedDateProvider = StateProvider<DateTime>((ref) {
  return CalendarWindow.dateOnly(DateTime.now());
});

final homeVisibleAnchorDateProvider = StateProvider<DateTime>((ref) {
  final selected = ref.watch(homeSelectedDateProvider);
  return CalendarWindow.dateOnly(selected);
});

final homeCalendarModeProvider = StateProvider<HomeCalendarMode>((ref) {
  return HomeCalendarMode.week;
});

final homeSelectedDayAgendaProvider = StreamProvider<List<AgendaItemViewModel>>(
  (ref) {
    final selectedDate = CalendarWindow.dateOnly(
      ref.watch(homeSelectedDateProvider),
    );
    final end = selectedDate.add(const Duration(days: 1));
    final today = CalendarWindow.dateOnly(DateTime.now());

    return _watchAgendaItems(
      ref: ref,
      start: selectedDate,
      end: end,
      today: today,
      sortItems: true,
    );
  },
);

final homeCalendarBucketsProvider = StreamProvider<List<DayBucketViewModel>>((
  ref,
) {
  final selectedDate = CalendarWindow.dateOnly(
    ref.watch(homeSelectedDateProvider),
  );
  final visibleAnchorDate = CalendarWindow.dateOnly(
    ref.watch(homeVisibleAnchorDateProvider),
  );
  // Always fetch full month grid; week view is derived by filtering
  final visibleDates = CalendarWindow.monthGridFor(visibleAnchorDate);
  final start = visibleDates.first;
  final end = visibleDates.last.add(const Duration(days: 1));
  final today = CalendarWindow.dateOnly(DateTime.now());

  return _watchAgendaItems(
    ref: ref,
    start: start,
    end: end,
    today: today,
    sortItems: false,
  ).map((items) {
    final itemsByDate = <DateTime, List<AgendaItemViewModel>>{};
    for (final item in items) {
      itemsByDate.putIfAbsent(item.date, () => []).add(item);
    }

    return [
      for (final date in visibleDates)
        DayBucketViewModel.fromItems(
          date: date,
          selectedDate: selectedDate,
          visibleAnchorDate: visibleAnchorDate,
          items: itemsByDate[date] ?? const [],
        ),
    ];
  });
});

final homeMonthlyIncomeProvider = StreamProvider<int>((ref) {
  final now = DateTime.now();
  return ref.watch(billRepoProvider).watchIncomeForMonth(now);
});

final homeMonthlyExpenseProvider = StreamProvider<int>((ref) {
  final now = DateTime.now();
  return ref.watch(billRepoProvider).watchExpenseForMonth(now);
});

final homeBalanceProvider = StreamProvider<int>((ref) {
  final income = ref.watch(homeMonthlyIncomeProvider).valueOrNull ?? 0;
  final expense = ref.watch(homeMonthlyExpenseProvider).valueOrNull ?? 0;
  return Stream.value(income - expense);
});

final homeForecastExpenseProvider = StreamProvider<int>((ref) {
  return ref
      .watch(forecastExpensesProvider)
      .maybeWhen(
        data: (items) => Stream.value(
          items.fold<int>(0, (sum, item) => sum + (item.amount ?? 0)),
        ),
        orElse: () => Stream.value(0),
      );
});

Stream<List<AgendaItemViewModel>> _watchAgendaItems({
  required Ref ref,
  required DateTime start,
  required DateTime end,
  required DateTime today,
  required bool sortItems,
}) {
  final controller = StreamController<List<AgendaItemViewModel>>();
  List<AgendaItemViewModel>? lifeItems;
  List<AgendaItemViewModel>? billRecords;
  List<AgendaItemViewModel>? projects;

  void emitIfReady() {
    final currentLifeItems = lifeItems;
    final currentBillRecords = billRecords;
    final currentProjects = projects;
    if (currentLifeItems == null ||
        currentBillRecords == null ||
        currentProjects == null) {
      return;
    }
    if (controller.isClosed) return;

    final combined = <AgendaItemViewModel>[
      ...currentLifeItems,
      ...currentBillRecords,
      ...currentProjects,
    ];
    if (sortItems) combined.sort(_compareAgendaItems);
    controller.add(combined);
  }

  final lifeSubscription = ref
      .watch(lifeItemRepoProvider)
      .watchBetween(start, end)
      .listen((items) {
        lifeItems = [
          for (final item in items)
            AgendaItemViewModel.fromLifeItem(item, today),
        ];
        emitIfReady();
      }, onError: controller.addError);

  final billSubscription = ref
      .watch(billRepoProvider)
      .watchBetween(start, end)
      .listen((records) {
        billRecords = [
          for (final record in records)
            AgendaItemViewModel.fromBillRecord(record),
        ];
        emitIfReady();
      }, onError: controller.addError);

  final projectSubscription = ref
      .watch(projectRepoProvider)
      .watchBetweenKeyDate(start, end)
      .listen((projectList) {
        projects = [
          for (final p in projectList)
            AgendaItemViewModel.fromProject(p),
        ];
        emitIfReady();
      }, onError: controller.addError);

  ref.onDispose(() {
    unawaited(lifeSubscription.cancel());
    unawaited(billSubscription.cancel());
    unawaited(projectSubscription.cancel());
    unawaited(controller.close());
  });

  return controller.stream;
}

int _compareAgendaItems(AgendaItemViewModel a, AgendaItemViewModel b) {
  if (a.isOverdue != b.isOverdue) return a.isOverdue ? -1 : 1;

  final dateCompare = a.date.compareTo(b.date);
  if (dateCompare != 0) return dateCompare;

  final kindCompare = _agendaKindSortValue(
    a,
  ).compareTo(_agendaKindSortValue(b));
  if (kindCompare != 0) return kindCompare;

  return a.id.compareTo(b.id);
}

int _agendaKindSortValue(AgendaItemViewModel item) {
  return switch (item.kind) {
    AgendaItemKind.billRecord => 0,
    AgendaItemKind.project => 1,
    AgendaItemKind.lifeItem => 2,
  };
}
