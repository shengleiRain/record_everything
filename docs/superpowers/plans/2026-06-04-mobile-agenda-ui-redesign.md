# Mobile Agenda UI Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the mobile UI to match `docs/ui-mockups/mobile-agenda-redesign.html`, led by a calendar-based home agenda that mixes bills, due reminders, and tasks by selected date.

**Architecture:** Keep the existing feature-first Flutter structure, Riverpod providers, Drift database, and GoRouter shell. Add view models and providers that aggregate existing `LifeItem` and `BillRecord` data by day; avoid database schema changes unless later product requirements require persisted UI preferences. UI implementation should be decomposed into small widgets so the home calendar, agenda rows, and page summary components are testable independently.

**Tech Stack:** Flutter Material 3, Dart 3.11, Riverpod, Drift SQLite, go_router, flutter_test, integration_test.

---

## Assumptions, Constraints, And Success Criteria

**Assumptions**

- The app remains a hybrid "life item + bill + reminder" app, not a pure accounting app.
- Existing tables already contain the required domain fields: `LifeItem.dueTime`, `LifeItem.status`, `LifeItem.amount`, `LifeItem.amountType`, `BillRecord.billTime`, `BillRecord.amount`, `BillRecord.amountType`.
- The home calendar should use Sunday-first weeks: Sunday, Monday, Tuesday, Wednesday, Thursday, Friday, Saturday.
- The home page default state is collapsed week view; users can expand to month view.
- Collapsed week view navigates by week; expanded month view navigates by month.
- The list below the calendar shows only the selected date.

**Constraints**

- Do not redesign data storage first. Add query methods and view models before considering migrations.
- Keep bottom navigation routes: `/home`, `/items`, `/bills`, `/statistics`, `/settings`.
- Keep existing create/edit/detail pages functional while replacing their visual layout incrementally.
- Preserve current tests and automation scripts.
- Use Material icons from Flutter; do not keep placeholder glyph icons from the HTML mockup.

**Measurable Success Criteria**

- Home first viewport shows: monthly summary, week/month calendar, selected date summary, and at least 3 selected-date rows on a 390x844 viewport.
- Week calendar has exactly 7 cells ordered Sunday to Saturday.
- Month calendar shows a complete month grid including leading/trailing adjacent-month days.
- Selecting a calendar day changes the below-list contents to that date only.
- Week left/right changes selected visible week by 7 days; month left/right changes visible month by 1 month.
- `flutter test` passes.
- `flutter analyze` has no new issues.
- A mobile screenshot at 390x844 visually matches the mockup hierarchy: compact cards, green primary selected state, right-aligned amounts, bottom navigation.
- With 1000 generated rows, provider aggregation and scrolling remain responsive in manual smoke testing.

---

## File Structure

**Create**

- `lib/features/home/models/agenda_item_view_model.dart`  
  Unified row model for mixed `LifeItem` and `BillRecord` display.
- `lib/features/home/models/day_bucket_view_model.dart`  
  Per-day calendar summary: date, item count, income, expense, overdue count, selected/month-adjacent flags.
- `lib/features/home/models/calendar_window.dart`  
  Pure helpers for Sunday-first week and month grid calculations.
- `lib/features/home/widgets/home_calendar.dart`  
  Collapsed week and expanded month calendar UI.
- `lib/features/home/widgets/home_summary_strip.dart`  
  Compact monthly summary strip.
- `lib/features/home/widgets/agenda_row.dart`  
  Shared compact row used by home, item list, and bill list where appropriate.
- `lib/features/home/widgets/selected_day_agenda.dart`  
  Selected-date summary and rows below calendar.
- `lib/features/home/widgets/quick_create_sheet.dart`  
  Bottom sheet matching "快速新增".
- `test/calendar_window_test.dart`  
  Unit tests for Sunday-first week/month date grids.
- `test/home_agenda_provider_test.dart`  
  Provider aggregation tests for mixed bill/item data.
- `test/home_calendar_widget_test.dart`  
  Widget tests for calendar state and selected date.

**Modify**

- `lib/features/home/pages/home_page.dart`  
  Replace current large cards with summary strip, calendar, selected-date agenda, and quick-create entry.
- `lib/features/home/providers/home_providers.dart`  
  Add selected date, calendar mode, visible anchor date, selected-day rows, and day-bucket providers.
- `lib/data/database/daos/life_item_dao.dart`  
  Add date-range query streams for calendar windows.
- `lib/data/database/daos/bill_record_dao.dart`  
  Add date-range query streams for calendar windows.
- `lib/data/repositories/life_item_repository.dart`  
  Expose date-range item watch method.
- `lib/data/repositories/bill_record_repository.dart`  
  Expose date-range bill watch method.
- `lib/features/life_item/pages/life_item_list_page.dart` and `lib/features/life_item/widgets/life_item_card.dart`  
  Move toward compact list treatment and filter chips from mockup.
- `lib/features/bill/pages/bill_list_page.dart` and `lib/features/bill/widgets/bill_card.dart`  
  Move toward month summary + grouped daily流水.
- `lib/features/statistics/pages/statistics_page.dart`  
  Restyle summary and chart sections to match compact mockup.
- `lib/features/settings/pages/settings_page.dart`  
  Restyle settings groups and text to match compact mockup.
- `lib/core/theme/app_theme.dart` and `lib/core/theme/app_colors.dart`  
  Align radii, surface colors, compact card spacing, and selected green states.

---

## Task 1: Calendar Date Math

**Files:**
- Create: `lib/features/home/models/calendar_window.dart`
- Test: `test/calendar_window_test.dart`

- [ ] **Step 1: Write failing tests**

Create `test/calendar_window_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:record_everything/features/home/models/calendar_window.dart';

void main() {
  group('CalendarWindow', () {
    test('week starts on Sunday and contains seven dates', () {
      final week = CalendarWindow.weekFor(DateTime(2026, 6, 4));

      expect(week, hasLength(7));
      expect(week.first, DateTime(2026, 5, 31));
      expect(week.last, DateTime(2026, 6, 6));
      expect(week.map((date) => date.weekday), [7, 1, 2, 3, 4, 5, 6]);
    });

    test('month grid includes leading and trailing days in Sunday-first order', () {
      final grid = CalendarWindow.monthGridFor(DateTime(2026, 6, 4));

      expect(grid, hasLength(35));
      expect(grid.first, DateTime(2026, 5, 31));
      expect(grid[4], DateTime(2026, 6, 4));
      expect(grid.last, DateTime(2026, 7, 4));
    });

    test('date identity ignores time of day', () {
      expect(
        CalendarWindow.isSameDate(
          DateTime(2026, 6, 4, 8),
          DateTime(2026, 6, 4, 23, 59),
        ),
        isTrue,
      );
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```powershell
flutter test test/calendar_window_test.dart
```

Expected: fail because `calendar_window.dart` does not exist.

- [ ] **Step 3: Implement calendar helper**

Create `lib/features/home/models/calendar_window.dart`:

```dart
class CalendarWindow {
  const CalendarWindow._();

  static DateTime dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  static bool isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static DateTime startOfSundayWeek(DateTime anchor) {
    final date = dateOnly(anchor);
    return date.subtract(Duration(days: date.weekday % 7));
  }

  static List<DateTime> weekFor(DateTime anchor) {
    final start = startOfSundayWeek(anchor);
    return List.generate(7, (index) => start.add(Duration(days: index)));
  }

  static List<DateTime> monthGridFor(DateTime anchor) {
    final firstOfMonth = DateTime(anchor.year, anchor.month, 1);
    final firstVisible = startOfSundayWeek(firstOfMonth);
    final nextMonth = DateTime(anchor.year, anchor.month + 1, 1);
    final lastOfMonth = nextMonth.subtract(const Duration(days: 1));
    final lastVisible = startOfSundayWeek(lastOfMonth).add(
      const Duration(days: 6),
    );
    final days = lastVisible.difference(firstVisible).inDays + 1;
    return List.generate(days, (index) => firstVisible.add(Duration(days: index)));
  }

  static DateTime addWeeks(DateTime anchor, int weeks) {
    return dateOnly(anchor).add(Duration(days: weeks * 7));
  }

  static DateTime addMonths(DateTime anchor, int months) {
    return DateTime(anchor.year, anchor.month + months, anchor.day);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```powershell
flutter test test/calendar_window_test.dart
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

```powershell
git add lib/features/home/models/calendar_window.dart test/calendar_window_test.dart
git commit -m "feat: add calendar window helpers"
```

---

## Task 2: Date-Range Repository Queries

**Files:**
- Modify: `lib/data/database/daos/life_item_dao.dart`
- Modify: `lib/data/database/daos/bill_record_dao.dart`
- Modify: `lib/data/repositories/life_item_repository.dart`
- Modify: `lib/data/repositories/bill_record_repository.dart`
- Test: `test/home_agenda_provider_test.dart`

- [ ] **Step 1: Add failing provider-oriented test setup**

Create `test/home_agenda_provider_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record_everything/data/database/app_database.dart';
import 'package:record_everything/data/database/database_provider.dart';
import 'package:record_everything/features/bill/providers/bill_providers.dart';
import 'package:record_everything/features/home/providers/home_providers.dart';
import 'package:record_everything/features/life_item/providers/life_item_providers.dart';

void main() {
  test('selected day agenda mixes life items and bills for one date only', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    addTearDown(db.close);

    container.read(homeSelectedDateProvider.notifier).state = DateTime(2026, 6, 4);

    await container.read(lifeItemNotifierProvider.notifier).create({
      'title': '信用卡还款',
      'dueTime': DateTime(2026, 6, 4, 18),
      'itemType': 'bill',
      'amount': 68000,
      'amountType': 'expense',
    });
    await container.read(lifeItemNotifierProvider.notifier).create({
      'title': '明天宽带续费',
      'dueTime': DateTime(2026, 6, 5, 20),
      'amount': 9900,
      'amountType': 'expense',
    });
    await container.read(billNotifierProvider.notifier).create(
      title: '买菜记录',
      amount: 5600,
      billTime: DateTime(2026, 6, 4, 12, 40),
    );

    final agenda = await _waitForAgenda(container, expectedCount: 2);

    expect(agenda.map((item) => item.title), ['买菜记录', '信用卡还款']);
    expect(agenda.every((item) => item.date == DateTime(2026, 6, 4)), isTrue);
  });
}

Future<List<dynamic>> _waitForAgenda(
  ProviderContainer container, {
  required int expectedCount,
}) async {
  final end = DateTime.now().add(const Duration(seconds: 3));
  while (DateTime.now().isBefore(end)) {
    final value = container.read(homeSelectedDayAgendaProvider).valueOrNull;
    if (value != null && value.length == expectedCount) {
      return value;
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  fail('Expected selected-day agenda count $expectedCount');
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```powershell
flutter test test/home_agenda_provider_test.dart
```

Expected: fail because `homeSelectedDateProvider` and `homeSelectedDayAgendaProvider` do not exist.

- [ ] **Step 3: Add date-range DAO methods**

In `LifeItemDao`, add:

```dart
Stream<List<LifeItem>> watchBetween(DateTime start, DateTime end) {
  return (select(lifeItems)
        ..where(
          (t) =>
              t.dueTime.isBiggerOrEqualValue(start) &
              t.dueTime.isSmallerThanValue(end),
        )
        ..orderBy([(t) => OrderingTerm.asc(t.dueTime)]))
      .watch();
}
```

In `BillRecordDao`, add:

```dart
Stream<List<BillRecord>> watchBetween(DateTime start, DateTime end) {
  return (select(billRecords)
        ..where(
          (t) =>
              t.billTime.isBiggerOrEqualValue(start) &
              t.billTime.isSmallerThanValue(end),
        )
        ..orderBy([(t) => OrderingTerm.desc(t.billTime)]))
      .watch();
}
```

- [ ] **Step 4: Expose repository methods**

In `LifeItemRepository`, add:

```dart
Stream<List<LifeItem>> watchBetween(DateTime start, DateTime end) {
  return _db.lifeItemDao.watchBetween(start, end);
}
```

In `BillRecordRepository`, add:

```dart
Stream<List<BillRecord>> watchBetween(DateTime start, DateTime end) {
  return _db.billRecordDao.watchBetween(start, end);
}
```

- [ ] **Step 5: Run code generation if Drift generated files change**

Run:

```powershell
dart run build_runner build --delete-conflicting-outputs
```

Expected: generated DAO mixins remain valid or regenerate cleanly.

- [ ] **Step 6: Commit**

```powershell
git add lib/data/database/daos lib/data/repositories
git commit -m "feat: add date range data queries"
```

---

## Task 3: Home Agenda View Models And Providers

**Files:**
- Create: `lib/features/home/models/agenda_item_view_model.dart`
- Create: `lib/features/home/models/day_bucket_view_model.dart`
- Modify: `lib/features/home/providers/home_providers.dart`
- Test: `test/home_agenda_provider_test.dart`

- [ ] **Step 1: Add agenda item model**

Create `lib/features/home/models/agenda_item_view_model.dart`:

```dart
import '../../../data/database/app_database.dart';

enum AgendaItemKind { lifeItem, billRecord }

class AgendaItemViewModel {
  final AgendaItemKind kind;
  final int id;
  final DateTime date;
  final String title;
  final String subtitle;
  final int? amount;
  final String amountType;
  final String status;
  final bool isOverdue;
  final bool isCompleted;
  final LifeItem? lifeItem;
  final BillRecord? billRecord;

  const AgendaItemViewModel({
    required this.kind,
    required this.id,
    required this.date,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.amountType,
    required this.status,
    required this.isOverdue,
    required this.isCompleted,
    this.lifeItem,
    this.billRecord,
  });

  factory AgendaItemViewModel.fromLifeItem(LifeItem item, DateTime today) {
    final date = DateTime(item.dueTime.year, item.dueTime.month, item.dueTime.day);
    final todayOnly = DateTime(today.year, today.month, today.day);
    return AgendaItemViewModel(
      kind: AgendaItemKind.lifeItem,
      id: item.id,
      date: date,
      title: item.title,
      subtitle: item.itemType == 'bill' ? '账单事项' : '事项提醒',
      amount: item.amount,
      amountType: item.amountType,
      status: item.status,
      isOverdue: item.status == 'pending' && date.isBefore(todayOnly),
      isCompleted: item.status == 'completed',
      lifeItem: item,
    );
  }

  factory AgendaItemViewModel.fromBillRecord(BillRecord record) {
    return AgendaItemViewModel(
      kind: AgendaItemKind.billRecord,
      id: record.id,
      date: DateTime(record.billTime.year, record.billTime.month, record.billTime.day),
      title: record.title,
      subtitle: record.note?.isNotEmpty == true ? record.note! : '账单流水',
      amount: record.amount,
      amountType: record.amountType,
      status: 'recorded',
      isOverdue: false,
      isCompleted: true,
      billRecord: record,
    );
  }
}
```

- [ ] **Step 2: Add day bucket model**

Create `lib/features/home/models/day_bucket_view_model.dart`:

```dart
class DayBucketViewModel {
  final DateTime date;
  final bool isSelected;
  final bool isInVisibleMonth;
  final int itemCount;
  final int overdueCount;
  final int income;
  final int expense;

  const DayBucketViewModel({
    required this.date,
    required this.isSelected,
    required this.isInVisibleMonth,
    required this.itemCount,
    required this.overdueCount,
    required this.income,
    required this.expense,
  });

  String get compactLabel {
    if (overdueCount > 0) return '逾期';
    if (expense > 0) return '¥${(expense / 100).round()}';
    if (income > 0) return '+¥${(income / 100).round()}';
    if (itemCount > 0) return '$itemCount项';
    return '空';
  }
}
```

- [ ] **Step 3: Add home state providers**

In `home_providers.dart`, add imports:

```dart
import 'dart:async';
import '../../../data/database/app_database.dart';
import '../models/agenda_item_view_model.dart';
import '../models/calendar_window.dart';
import '../models/day_bucket_view_model.dart';
```

Then add:

```dart
enum HomeCalendarMode { week, month }

final homeSelectedDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

final homeVisibleAnchorDateProvider = StateProvider<DateTime>((ref) {
  final selected = ref.watch(homeSelectedDateProvider);
  return DateTime(selected.year, selected.month, selected.day);
});

final homeCalendarModeProvider = StateProvider<HomeCalendarMode>((ref) {
  return HomeCalendarMode.week;
});
```

- [ ] **Step 4: Add selected day agenda provider**

In `home_providers.dart`, add:

```dart
final homeSelectedDayAgendaProvider =
    StreamProvider<List<AgendaItemViewModel>>((ref) {
  final selected = ref.watch(homeSelectedDateProvider);
  final start = DateTime(selected.year, selected.month, selected.day);
  final end = start.add(const Duration(days: 1));
  final lifeRepo = ref.watch(lifeItemRepoProvider);
  final billRepo = ref.watch(billRepoProvider);

  final controller = StreamController<List<AgendaItemViewModel>>();
  List<LifeItem> latestItems = const [];
  List<BillRecord> latestBills = const [];

  void emit() {
    final today = DateTime.now();
    final rows = <AgendaItemViewModel>[
      ...latestBills.map(AgendaItemViewModel.fromBillRecord),
      ...latestItems.map((item) => AgendaItemViewModel.fromLifeItem(item, today)),
    ]..sort((a, b) {
        if (a.isOverdue != b.isOverdue) return a.isOverdue ? -1 : 1;
        return a.date.compareTo(b.date);
      });
    controller.add(rows);
  }

  final itemSub = lifeRepo.watchBetween(start, end).listen((items) {
    latestItems = items;
    emit();
  });
  final billSub = billRepo.watchBetween(start, end).listen((bills) {
    latestBills = bills;
    emit();
  });

  ref.onDispose(() async {
    await itemSub.cancel();
    await billSub.cancel();
    await controller.close();
  });

  return controller.stream;
});
```

- [ ] **Step 5: Add visible calendar buckets provider**

In `home_providers.dart`, add:

```dart
final homeCalendarBucketsProvider =
    StreamProvider<List<DayBucketViewModel>>((ref) {
  final mode = ref.watch(homeCalendarModeProvider);
  final anchor = ref.watch(homeVisibleAnchorDateProvider);
  final selected = ref.watch(homeSelectedDateProvider);
  final dates = mode == HomeCalendarMode.week
      ? CalendarWindow.weekFor(anchor)
      : CalendarWindow.monthGridFor(anchor);
  final start = dates.first;
  final end = dates.last.add(const Duration(days: 1));
  final lifeRepo = ref.watch(lifeItemRepoProvider);
  final billRepo = ref.watch(billRepoProvider);

  final controller = StreamController<List<DayBucketViewModel>>();
  List<LifeItem> latestItems = const [];
  List<BillRecord> latestBills = const [];

  void emit() {
    final today = CalendarWindow.dateOnly(DateTime.now());
    final buckets = dates.map((date) {
      final day = CalendarWindow.dateOnly(date);
      final items = latestItems.where(
        (item) => CalendarWindow.isSameDate(item.dueTime, day),
      );
      final bills = latestBills.where(
        (bill) => CalendarWindow.isSameDate(bill.billTime, day),
      );
      final income = bills
          .where((bill) => bill.amountType == 'income')
          .fold<int>(0, (sum, bill) => sum + bill.amount);
      final expense = bills
          .where((bill) => bill.amountType == 'expense')
          .fold<int>(0, (sum, bill) => sum + bill.amount);
      final overdueCount = items
          .where(
            (item) =>
                item.status == 'pending' &&
                CalendarWindow.dateOnly(item.dueTime).isBefore(today),
          )
          .length;
      return DayBucketViewModel(
        date: day,
        isSelected: CalendarWindow.isSameDate(day, selected),
        isInVisibleMonth: day.month == anchor.month,
        itemCount: items.length + bills.length,
        overdueCount: overdueCount,
        income: income,
        expense: expense,
      );
    }).toList();
    controller.add(buckets);
  }

  final itemSub = lifeRepo.watchBetween(start, end).listen((items) {
    latestItems = items;
    emit();
  });
  final billSub = billRepo.watchBetween(start, end).listen((bills) {
    latestBills = bills;
    emit();
  });

  ref.onDispose(() async {
    await itemSub.cancel();
    await billSub.cancel();
    await controller.close();
  });

  return controller.stream;
});
```

- [ ] **Step 6: Run provider test**

Run:

```powershell
flutter test test/home_agenda_provider_test.dart
```

Expected: provider aggregation test passes.

- [ ] **Step 7: Commit**

```powershell
git add lib/features/home/models lib/features/home/providers/home_providers.dart test/home_agenda_provider_test.dart
git commit -m "feat: aggregate home agenda data"
```

---

## Task 4: Home Calendar UI

**Files:**
- Create: `lib/features/home/widgets/home_summary_strip.dart`
- Create: `lib/features/home/widgets/home_calendar.dart`
- Create: `lib/features/home/widgets/selected_day_agenda.dart`
- Create: `lib/features/home/widgets/agenda_row.dart`
- Modify: `lib/features/home/pages/home_page.dart`
- Test: `test/home_calendar_widget_test.dart`

- [ ] **Step 1: Write widget test**

Create `test/home_calendar_widget_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record_everything/features/home/models/day_bucket_view_model.dart';
import 'package:record_everything/features/home/providers/home_providers.dart';
import 'package:record_everything/features/home/widgets/home_calendar.dart';

void main() {
  testWidgets('collapsed home calendar renders Sunday-first week and switches to month', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: HomeCalendar(
              mode: HomeCalendarMode.week,
              visibleAnchorDate: DateTime(2026, 6, 4),
              selectedDate: DateTime(2026, 6, 4),
              buckets: [
                DayBucketViewModel(date: DateTime(2026, 5, 31), isSelected: false, isInVisibleMonth: false, itemCount: 0, overdueCount: 0, income: 0, expense: 0),
                DayBucketViewModel(date: DateTime(2026, 6, 1), isSelected: false, isInVisibleMonth: true, itemCount: 2, overdueCount: 0, income: 0, expense: 0),
                DayBucketViewModel(date: DateTime(2026, 6, 2), isSelected: false, isInVisibleMonth: true, itemCount: 1, overdueCount: 0, income: 0, expense: 8800),
                DayBucketViewModel(date: DateTime(2026, 6, 3), isSelected: false, isInVisibleMonth: true, itemCount: 1, overdueCount: 1, income: 0, expense: 0),
                DayBucketViewModel(date: DateTime(2026, 6, 4), isSelected: true, isInVisibleMonth: true, itemCount: 5, overdueCount: 1, income: 0, expense: 12000),
                DayBucketViewModel(date: DateTime(2026, 6, 5), isSelected: false, isInVisibleMonth: true, itemCount: 3, overdueCount: 0, income: 0, expense: 0),
                DayBucketViewModel(date: DateTime(2026, 6, 6), isSelected: false, isInVisibleMonth: true, itemCount: 1, overdueCount: 0, income: 0, expense: 0),
              ],
              onPrevious: () {},
              onNext: () {},
              onSelectDate: (_) {},
              onSetMode: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('周日'), findsOneWidget);
    expect(find.text('周六'), findsOneWidget);
    expect(find.text('2026年6月 第1周'), findsOneWidget);
    expect(find.text('展开月历'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```powershell
flutter test test/home_calendar_widget_test.dart
```

Expected: fail because `HomeCalendar` does not exist.

- [ ] **Step 3: Implement `HomeSummaryStrip`**

Create a compact four-cell widget in `lib/features/home/widgets/home_summary_strip.dart` with props:

```dart
class HomeSummaryStrip extends StatelessWidget {
  final int monthlyExpense;
  final int monthlyIncome;
  final int pendingCount;
  final int overdueCount;

  const HomeSummaryStrip({
    super.key,
    required this.monthlyExpense,
    required this.monthlyIncome,
    required this.pendingCount,
    required this.overdueCount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _SummaryCell(label: '本月支出', value: MoneyFormatter.format(monthlyExpense), tone: _SummaryTone.expense),
        _SummaryCell(label: '收入', value: MoneyFormatter.format(monthlyIncome), tone: _SummaryTone.income),
        _SummaryCell(label: '待办', value: '$pendingCount项', tone: _SummaryTone.normal),
        _SummaryCell(label: '逾期', value: '$overdueCount项', tone: _SummaryTone.danger),
      ].map((child) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 6), child: child))).toList(),
    );
  }
}
```

Use existing `MoneyFormatter`, `AppColors`, and 8px radius.

- [ ] **Step 4: Implement `HomeCalendar`**

Create `lib/features/home/widgets/home_calendar.dart` with:

```dart
class HomeCalendar extends StatelessWidget {
  final HomeCalendarMode mode;
  final DateTime visibleAnchorDate;
  final DateTime selectedDate;
  final List<DayBucketViewModel> buckets;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<DateTime> onSelectDate;
  final ValueChanged<HomeCalendarMode> onSetMode;

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
}
```

Implementation requirements:

- Header layout: left arrow, centered title, right arrow.
- Week mode title: `YYYY年M月 第N周`.
- Month mode title: `YYYY年M月`.
- Week labels must be `周日` through `周六`.
- Week mode grid renders 7 cells.
- Month mode grid renders all buckets from `CalendarWindow.monthGridFor`, usually 35 or 42 cells.
- Selected cell uses primary green background.
- Adjacent-month cells use muted opacity.
- Cell compact label uses `DayBucketViewModel.compactLabel`.

- [ ] **Step 5: Implement compact agenda row**

Create `lib/features/home/widgets/agenda_row.dart`:

```dart
class AgendaRow extends StatelessWidget {
  final AgendaItemViewModel item;
  final VoidCallback? onTap;
  final VoidCallback? onComplete;

  const AgendaRow({
    super.key,
    required this.item,
    this.onTap,
    this.onComplete,
  });
}
```

Implementation requirements:

- Left icon: check circle for pending item, receipt icon for bill, warning icon for overdue.
- Main text: title + subtitle.
- Right side: amount if present; otherwise time or status.
- Expense amount uses expense color; income uses income color.
- Minimum row height 56px.
- Do not show permanent "延期/完成" buttons in the row.

- [ ] **Step 6: Implement selected day agenda**

Create `lib/features/home/widgets/selected_day_agenda.dart`:

```dart
class SelectedDayAgenda extends StatelessWidget {
  final DateTime selectedDate;
  final List<AgendaItemViewModel> rows;

  const SelectedDayAgenda({
    super.key,
    required this.selectedDate,
    required this.rows,
  });
}
```

Implementation requirements:

- Header: `选中日期` and `只显示M月D日`.
- Summary strip: selected date + expense/item/overdue summary.
- Empty state: compact text `这天没有事项或账单`.
- Rows use `AgendaRow`.

- [ ] **Step 7: Replace home page body**

Modify `HomePage` so the body order is:

1. App title row: `今天`, date subtitle, search and add icon buttons.
2. `HomeSummaryStrip`.
3. `HomeCalendar`.
4. `SelectedDayAgenda`.

Provider interactions:

```dart
final mode = ref.watch(homeCalendarModeProvider);
final selectedDate = ref.watch(homeSelectedDateProvider);
final visibleAnchor = ref.watch(homeVisibleAnchorDateProvider);
final bucketsAsync = ref.watch(homeCalendarBucketsProvider);
final agendaAsync = ref.watch(homeSelectedDayAgendaProvider);
```

Navigation logic:

```dart
void previous() {
  final notifier = ref.read(homeVisibleAnchorDateProvider.notifier);
  notifier.state = mode == HomeCalendarMode.week
      ? CalendarWindow.addWeeks(visibleAnchor, -1)
      : CalendarWindow.addMonths(visibleAnchor, -1);
}

void next() {
  final notifier = ref.read(homeVisibleAnchorDateProvider.notifier);
  notifier.state = mode == HomeCalendarMode.week
      ? CalendarWindow.addWeeks(visibleAnchor, 1)
      : CalendarWindow.addMonths(visibleAnchor, 1);
}
```

Mode switching:

```dart
ref.read(homeCalendarModeProvider.notifier).state = nextMode;
ref.read(homeVisibleAnchorDateProvider.notifier).state = selectedDate;
```

- [ ] **Step 8: Run widget test**

Run:

```powershell
flutter test test/home_calendar_widget_test.dart
```

Expected: pass.

- [ ] **Step 9: Commit**

```powershell
git add lib/features/home test/home_calendar_widget_test.dart
git commit -m "feat: rebuild home agenda calendar UI"
```

---

## Task 5: Quick Create Bottom Sheet

**Files:**
- Create: `lib/features/home/widgets/quick_create_sheet.dart`
- Modify: `lib/features/home/pages/home_page.dart`
- Test: `test/widget_test.dart`

- [ ] **Step 1: Add quick create behavior**

Create `quick_create_sheet.dart` with four actions:

- `记一笔`: navigate to `/bills/new`
- `建事项`: navigate to `/items/new`
- `账单到期`: navigate to `/items/new` with future enhancement for prefilled bill type
- `周期模板`: open existing `QuickTemplateSheet` or navigate to `/items/new`

- [ ] **Step 2: Wire add icon**

In `HomePage`, replace direct add behavior with:

```dart
showQuickCreateSheet(context);
```

- [ ] **Step 3: Test sheet opens**

Add a widget test that pumps `HomePage` with a test database, taps the add button, and expects:

```dart
expect(find.text('快速新增'), findsOneWidget);
expect(find.text('记一笔'), findsOneWidget);
expect(find.text('建事项'), findsOneWidget);
expect(find.text('账单到期'), findsOneWidget);
expect(find.text('周期模板'), findsOneWidget);
```

- [ ] **Step 4: Run tests**

Run:

```powershell
flutter test
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

```powershell
git add lib/features/home/widgets/quick_create_sheet.dart lib/features/home/pages/home_page.dart test
git commit -m "feat: add quick create sheet"
```

---

## Task 6: Items Page Compact Redesign

**Files:**
- Modify: `lib/features/life_item/pages/life_item_list_page.dart`
- Modify: `lib/features/life_item/widgets/life_item_card.dart`
- Optional create: `lib/features/life_item/widgets/life_item_filter_chips.dart`

- [ ] **Step 1: Add filter state**

Add a local enum or provider-backed filter:

```dart
enum LifeItemFilter { all, overdue, today, repeat, completed }
```

Use a `StateProvider<LifeItemFilter>` if the filter should survive rebuilds.

- [ ] **Step 2: Add chips**

Render chips:

```dart
全部
逾期 1
今天 5
重复
已完成
```

Apply filtering in memory after `lifeItemsProvider` initially. If performance becomes a problem, add DAO-level filters later.

- [ ] **Step 3: Compact `LifeItemCard`**

Change card requirements:

- Minimum row height 56px.
- Remove always-visible `延期` and `完成` buttons from the row.
- Keep tap to detail.
- Use trailing status/amount.
- Move complete/defer to detail page, bottom sheet, or swipe action in a later pass.

- [ ] **Step 4: Run visual and widget checks**

Run:

```powershell
flutter test
flutter analyze
```

Expected: no regressions.

- [ ] **Step 5: Commit**

```powershell
git add lib/features/life_item
git commit -m "feat: compact life item list"
```

---

## Task 7: Bills Page Redesign

**Files:**
- Modify: `lib/features/bill/pages/bill_list_page.dart`
- Modify: `lib/features/bill/widgets/bill_card.dart`
- Optional create: `lib/features/bill/widgets/month_summary_card.dart`
- Optional create: `lib/features/bill/widgets/bill_day_group.dart`

- [ ] **Step 1: Preserve current month provider**

Keep `currentMonthProvider`, `monthlyIncomeProvider`, `monthlyExpenseProvider`, and `billsByMonthProvider`.

- [ ] **Step 2: Add month summary card**

Render:

- `本月支出`
- `本月收入`
- `预算使用 68%`

Use a static budget denominator initially if no budget model exists. Do not add a budget table in this phase.

- [ ] **Step 3: Group bills by date**

In `BillListPage`, transform `List<BillRecord>` into groups:

```dart
final groups = <DateTime, List<BillRecord>>{};
for (final bill in bills) {
  final day = DateTime(bill.billTime.year, bill.billTime.month, bill.billTime.day);
  groups.putIfAbsent(day, () => []).add(bill);
}
```

Render headers like:

```text
6月4日 周四        3笔 · -¥736
```

- [ ] **Step 4: Compact `BillCard`**

Use 56px row, receipt icon, title/subtitle, right-aligned amount and time/status.

- [ ] **Step 5: Run tests**

```powershell
flutter test
flutter analyze
```

- [ ] **Step 6: Commit**

```powershell
git add lib/features/bill
git commit -m "feat: redesign bills by day"
```

---

## Task 8: Detail And Edit Page Visual Alignment

**Files:**
- Modify: `lib/features/life_item/pages/life_item_detail_page.dart`
- Modify: `lib/features/life_item/pages/life_item_edit_page.dart`
- Modify: `lib/features/bill/pages/bill_edit_page.dart`

- [ ] **Step 1: Detail page hero**

Restyle detail page to match mockup:

- Top back button + overflow button.
- Hero section with item type chip, title, description.
- 2-column metadata grid: due time, amount, repeat rule, category.
- Primary action `完成并记账`; secondary `延期`.
- History records section can be static-empty until a proper history query exists.

- [ ] **Step 2: Edit page segmented type selector**

Use chips/segmented buttons:

```text
待办 / 到期 / 账单 / 订阅
```

Keep current form fields but restyle into grouped fields.

- [ ] **Step 3: Bill edit page**

Align input surfaces, spacing, and save action with item edit page.

- [ ] **Step 4: Run smoke tests**

```powershell
flutter test
flutter analyze
```

- [ ] **Step 5: Commit**

```powershell
git add lib/features/life_item/pages lib/features/bill/pages
git commit -m "feat: align detail and edit screens"
```

---

## Task 9: Statistics And Settings Visual Alignment

**Files:**
- Modify: `lib/features/statistics/pages/statistics_page.dart`
- Modify: `lib/features/settings/pages/settings_page.dart`
- Optional create: shared compact setting row widget if duplication becomes meaningful.

- [ ] **Step 1: Statistics page**

Implement compact mockup hierarchy:

- Four summary cells: 结余, 预计支出, 完成率, 逾期.
- Existing charts remain powered by current providers.
- Category rows use compact icons and right-aligned amounts.
- Add forecast card text based on `forecastExpensesProvider`.

- [ ] **Step 2: Settings page**

Group settings into:

- 默认账本 / 分类管理 / 提醒设置
- 导入数据 / 导出备份 / 数据安全
- 应用偏好 explanatory card

Keep existing export/import actions.

- [ ] **Step 3: Run tests**

```powershell
flutter test
flutter analyze
```

- [ ] **Step 4: Commit**

```powershell
git add lib/features/statistics lib/features/settings
git commit -m "feat: align statistics and settings UI"
```

---

## Task 10: Theme, Accessibility, And Visual QA

**Files:**
- Modify: `lib/core/theme/app_theme.dart`
- Modify: `lib/core/theme/app_colors.dart`
- Modify: `integration_test/app_smoke_test.dart`
- Optional modify: `.maestro` flows if existing UI labels change.

- [ ] **Step 1: Theme alignment**

Apply these system choices:

- Card radius: 8px unless a ModalBottomSheet requires larger top corners.
- Background: soft green-gray.
- Selected state: primary green.
- Expense: red.
- Income: green.
- Warning/due: orange.
- Body list rows: 56-72px.

- [ ] **Step 2: Accessibility labels**

Add stable semantics labels:

- `home_calendar_screen`
- `home_calendar_previous`
- `home_calendar_next`
- `home_calendar_toggle_week`
- `home_calendar_toggle_month`
- `home_selected_day_agenda`
- `quick_create_sheet`

- [ ] **Step 3: Update integration smoke test**

Ensure smoke test still navigates:

```text
首页 -> 事项 -> 账单 -> 统计 -> 设置
```

Add checks for:

- Home calendar exists.
- Week toggle exists.
- Month toggle exists.
- Selected-day agenda exists.

- [ ] **Step 4: Run full verification**

Run:

```powershell
flutter analyze
flutter test
flutter test integration_test/app_smoke_test.dart
```

Expected:

- Analyze exits 0.
- Unit/widget tests pass.
- Integration smoke test passes on configured target.

- [ ] **Step 5: Capture mobile screenshots**

Run existing automation if available:

```powershell
.\tool\automation\capture_pages.ps1
```

Expected screenshots:

- Home collapsed week view.
- Home expanded month view.
- Quick create sheet.
- Items page.
- Bills page.
- Statistics page.
- Settings page.

- [ ] **Step 6: Commit**

```powershell
git add lib integration_test tool screenshot
git commit -m "test: verify mobile agenda redesign"
```

---

## Edge Cases, Failure Modes, And Risks

- **Week boundary:** June 1, 2026 is Monday, so the first visible cell in Sunday-first week is May 31. Tests must cover this.
- **Month grid height:** Some months require 42 cells. The month view must remain scroll-safe and not push selected-date rows completely off-screen.
- **Selected date outside visible month:** If user selects a leading/trailing day, the visible anchor should move only when intentionally navigating, not on accidental selection unless product chooses otherwise.
- **Mixed rows duplicate:** A completed life item that generated a bill may appear as both item and bill if both occur on same day. This is acceptable initially if visually distinct; later deduping can use `BillRecord.lifeItemId`.
- **Amount formatting:** Existing `MoneyFormatter` expects cents. All new display code must use it.
- **Provider streams:** Combining multiple streams manually can leak if subscriptions are not cancelled in `ref.onDispose`.
- **No persisted calendar mode:** Mode resets on app restart. This is acceptable for this phase.
- **Large datasets:** Calendar bucket provider should query only visible week/month date ranges, not all history.
- **Swipe actions:** Mockup implies compact rows; completing/defer actions must remain available via detail/sheet if not implemented as swipe actions.

---

## Internal Agent Review

**Builder**

The lowest-risk build path is to add view models/providers first, then replace the home page, then align secondary pages. Database schema changes are not needed for the current mockup.

**Critic**

The biggest product risk is overloading calendar cells with both money and item counts. Keep each cell to one compact label and move full detail to the selected-day summary.

**Test**

The critical tests are Sunday-first date math, selected-day-only filtering, mixed bill/item aggregation, and home calendar widget mode rendering.

**Performance**

The plan uses visible date-range queries for week/month windows, which prevents querying all historical data on the home page. If stream combining becomes noisy, replace manual `StreamController` combination with a small tested combiner helper.

---

## Verification Checklist

- [ ] `flutter test test/calendar_window_test.dart`
- [ ] `flutter test test/home_agenda_provider_test.dart`
- [ ] `flutter test test/home_calendar_widget_test.dart`
- [ ] `flutter test`
- [ ] `flutter analyze`
- [ ] `flutter test integration_test/app_smoke_test.dart`
- [ ] Mobile screenshots show both home calendar states.
- [ ] Selected-day list changes when tapping another date.
- [ ] Week arrows move by week; month arrows move by month.
- [ ] No text overflow in 360x800, 390x844, and 412x915 viewport checks.

---

## Confidence

Confidence: `0.86`

Main uncertainties:

- Whether the selected-day list should show both the originating `LifeItem` and generated `BillRecord`, or dedupe them when `lifeItemId` matches.
- Whether calendar mode should be persisted in settings.
- Whether month cells should prioritize amount, item count, or overdue status when multiple signals exist.
- Whether budget usage on the bills/statistics page needs a real budget data model or can remain derived/static for the first UI pass.
