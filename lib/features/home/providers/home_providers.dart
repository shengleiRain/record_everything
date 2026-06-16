import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../bill/providers/bill_providers.dart';
import '../../life_item/providers/life_item_providers.dart';
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
  // Global set of life-item ids that already have a bill, regardless of date.
  // Lets us hide a life item on its dueTime once its completion has been
  // recorded as a bill (which then shows up on its own billTime), matching the
  // project detail page. Window-scoped bill data alone can't see a bill whose
  // billTime falls on a different day than the item's dueTime.
  Set<int> billedItemIds = const {};

  void emitIfReady() {
    final currentLifeItems = lifeItems;
    final currentBillRecords = billRecords;
    if (currentLifeItems == null || currentBillRecords == null) {
      return;
    }
    if (controller.isClosed) return;

    // Deduplicate life items against their linked bills, mirroring the project
    // detail page: when a life item already has a bill (created on completion),
    // it is shown via that bill record (which carries the real settlement date
    // as billTime) and the life-item row is dropped to avoid showing the same
    // business twice. A life item without a bill still appears on its dueTime.
    //
    // Projects are intentionally excluded from the home agenda (they have a
    // dedicated list page); the home agenda focuses on a day's items and bills.
    final combined = <AgendaItemViewModel>[
      for (final item in currentLifeItems)
        if (!billedItemIds.contains(item.id)) item,
      ...currentBillRecords,
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

  final billedSubscription = ref
      .watch(billRepoProvider)
      .watchLifeItemIdsWithBills()
      .listen((ids) {
        billedItemIds = ids;
        emitIfReady();
      }, onError: controller.addError);

  ref.onDispose(() {
    unawaited(lifeSubscription.cancel());
    unawaited(billSubscription.cancel());
    unawaited(billedSubscription.cancel());
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
