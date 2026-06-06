import 'package:flutter_test/flutter_test.dart';
import 'package:record_everything/features/life_item/models/reminder_preset.dart';

void main() {
  group('ReminderPreset', () {
    test('returns null when reminder is disabled', () {
      expect(ReminderPreset.none.remindTimeFor(DateTime(2026, 6, 6)), isNull);
    });

    test('uses 9 AM on due day for due day morning reminder', () {
      expect(
        ReminderPreset.dueDayMorning.remindTimeFor(DateTime(2026, 6, 6, 18)),
        DateTime(2026, 6, 6, 9),
      );
    });

    test('uses 9 AM one day before due date for day before reminder', () {
      expect(
        ReminderPreset.dayBeforeMorning.remindTimeFor(DateTime(2026, 6, 6, 18)),
        DateTime(2026, 6, 5, 9),
      );
    });

    test('uses the supplied custom reminder time', () {
      final custom = DateTime(2026, 6, 6, 16, 30);

      expect(
        ReminderPreset.custom.remindTimeFor(
          DateTime(2026, 6, 6, 18),
          customTime: custom,
        ),
        custom,
      );
      expect(
        ReminderPreset.fromRemindTime(custom, DateTime(2026, 6, 6, 18)),
        ReminderPreset.custom,
      );
    });
  });
}
