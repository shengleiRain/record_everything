import 'package:record_everything/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record_everything/features/home/models/day_bucket_view_model.dart';
import 'package:record_everything/features/home/widgets/home_calendar.dart';

void main() {
  testWidgets('renders Sunday-first week calendar controls', (tester) async {
    DateTime? selectedDate;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme(),
        home: Scaffold(
          body: HomeCalendar(
            isWeek: true,
            visibleAnchorDate: DateTime(2026, 6, 4),
            visibleBuckets: List.generate(7, (index) {
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
          ),
        ),
      ),
    );

    expect(find.text('2026年6月 第1周'), findsOneWidget);
    for (final label in const ['周日', '周一', '周二', '周三', '周四', '周五', '周六']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('4'), findsOneWidget);

    await tester.tap(find.text('3'));
    expect(selectedDate, DateTime(2026, 6, 3));
  });

  testWidgets('renders month view with correct title', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: HomeCalendar(
              isWeek: false,
              visibleAnchorDate: DateTime(2026, 6, 1),
              visibleBuckets: List.generate(35, (index) {
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
            ),
          ),
        ),
      ),
    );

    expect(find.text('2026年6月'), findsOneWidget);
  });

  testWidgets('clips a full month grid to a translated week window', (
    tester,
  ) async {
    final screenWidth =
        tester.view.physicalSize.width / tester.view.devicePixelRatio;
    final weekHeight = CalendarLayout.gridHeight(1, screenWidth);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme(),
        home: Scaffold(
          body: HomeCalendar(
            isWeek: true,
            visibleAnchorDate: DateTime(2026, 6, 4),
            visibleBuckets: List.generate(35, (index) {
              final date = DateTime(2026, 5, 31).add(Duration(days: index));
              return DayBucketViewModel(
                date: date,
                isSelected: date == DateTime(2026, 6, 18),
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
            gridHeight: weekHeight,
            gridVerticalOffset:
                -2 * (weekHeight + CalendarLayout.mainAxisSpacing),
          ),
        ),
      ),
    );

    final gridClip = tester.widget<SizedBox>(
      find.byKey(const ValueKey('home-calendar-grid-clip')),
    );
    final transform = tester.widget<Transform>(
      find.byKey(const ValueKey('home-calendar-grid-transform')),
    );

    expect(gridClip.height, weekHeight);
    expect(transform.transform.getTranslation().y, lessThan(0));
    expect(
      find.byKey(const ValueKey('home-calendar-day-2026-6-18')),
      findsOneWidget,
    );
  });
}
