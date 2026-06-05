import 'package:flutter_test/flutter_test.dart';
import 'package:record_everything/features/home/models/calendar_window.dart';

void main() {
  group('calendar window date math', () {
    test('weekFor returns a Sunday-first seven-day window', () {
      final week = CalendarWindow.weekFor(DateTime(2026, 6, 4));

      expect(week, hasLength(7));
      expect(week.first, DateTime(2026, 5, 31));
      expect(week.last, DateTime(2026, 6, 6));
      expect(week.map((date) => date.weekday), [7, 1, 2, 3, 4, 5, 6]);
    });

    test('monthGridFor returns complete Sunday-first weeks for the month', () {
      final grid = CalendarWindow.monthGridFor(DateTime(2026, 6, 4));

      expect(grid, hasLength(35));
      expect(grid.first, DateTime(2026, 5, 31));
      expect(grid[4], DateTime(2026, 6, 4));
      expect(grid.last, DateTime(2026, 7, 4));
    });

    test('isSameDate ignores time of day', () {
      expect(
        CalendarWindow.isSameDate(
          DateTime(2026, 6, 4, 8, 30),
          DateTime(2026, 6, 4, 23, 59, 59),
        ),
        isTrue,
      );
      expect(
        CalendarWindow.isSameDate(
          DateTime(2026, 6, 4, 23, 59, 59),
          DateTime(2026, 6, 5),
        ),
        isFalse,
      );
    });
  });
}
