import 'package:flutter_test/flutter_test.dart';
import 'package:record_everything/domain/enums/repeat_period.dart';
import 'package:record_everything/domain/models/repeat_rule.dart';

void main() {
  group('RepeatRule edge dates', () {
    test('monthly repeat clamps end-of-month dates', () {
      const rule = RepeatRule(period: RepeatPeriod.monthly);

      expect(rule.nextDate(DateTime(2026, 1, 31)), DateTime(2026, 2, 28));
      expect(rule.nextDate(DateTime(2026, 3, 31)), DateTime(2026, 4, 30));
    });

    test('yearly repeat clamps leap day to Feb 28 on non-leap years', () {
      const rule = RepeatRule(period: RepeatPeriod.yearly);

      expect(rule.nextDate(DateTime(2024, 2, 29)), DateTime(2025, 2, 28));
    });
  });
}
