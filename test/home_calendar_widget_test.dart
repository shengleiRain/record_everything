import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record_everything/features/home/models/day_bucket_view_model.dart';
import 'package:record_everything/features/home/providers/home_providers.dart';
import 'package:record_everything/features/home/widgets/home_calendar.dart';

void main() {
  testWidgets('renders Sunday-first week calendar controls', (tester) async {
    DateTime? selectedDate;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeCalendar(
            mode: HomeCalendarMode.week,
            visibleAnchorDate: DateTime(2026, 6, 4),
            selectedDate: DateTime(2026, 6, 4),
            buckets: List.generate(7, (index) {
              final date = DateTime(2026, 5, 31).add(Duration(days: index));
              return DayBucketViewModel(
                date: date,
                isSelected: date == DateTime(2026, 6, 4),
                isInVisibleMonth: date.month == 6,
                itemCount: 0,
                overdueCount: 0,
                income: 0,
                expense: 0,
              );
            }),
            onPrevious: () {},
            onNext: () {},
            onSelectDate: (date) => selectedDate = date,
            onSetMode: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('2026年6月 第1周'), findsOneWidget);
    expect(find.text('下拉展开月历 · 按周翻页'), findsOneWidget);
    for (final label in const ['周日', '周一', '周二', '周三', '周四', '周五', '周六']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('4'), findsOneWidget);

    await tester.tap(find.text('3'));
    expect(selectedDate, DateTime(2026, 6, 3));
  });

  testWidgets('switches week and month by vertical drag threshold', (
    tester,
  ) async {
    HomeCalendarMode? selectedMode;

    Future<void> pump(HomeCalendarMode mode) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeCalendar(
              mode: mode,
              visibleAnchorDate: DateTime(2026, 6, 4),
              selectedDate: DateTime(2026, 6, 4),
              buckets: List.generate(mode == HomeCalendarMode.week ? 7 : 42, (
                index,
              ) {
                final date = DateTime(2026, 5, 31).add(Duration(days: index));
                return DayBucketViewModel(
                  date: date,
                  isSelected: date == DateTime(2026, 6, 4),
                  isInVisibleMonth: date.month == 6,
                  itemCount: 0,
                  overdueCount: 0,
                  income: 0,
                  expense: 0,
                );
              }),
              onPrevious: () {},
              onNext: () {},
              onSelectDate: (_) {},
              onSetMode: (mode) => selectedMode = mode,
            ),
          ),
        ),
      );
    }

    await pump(HomeCalendarMode.week);

    await tester.drag(
      find.byKey(const ValueKey('home-calendar-surface')),
      const Offset(0, 18),
    );
    await tester.pump();
    expect(selectedMode, isNull);

    await tester.drag(
      find.byKey(const ValueKey('home-calendar-surface')),
      const Offset(0, 72),
    );
    await tester.pump();
    expect(selectedMode, HomeCalendarMode.month);

    selectedMode = null;
    await pump(HomeCalendarMode.month);
    await tester.drag(
      find.byKey(const ValueKey('home-calendar-surface')),
      const Offset(0, -72),
    );
    await tester.pump();
    expect(selectedMode, HomeCalendarMode.week);
  });
}
