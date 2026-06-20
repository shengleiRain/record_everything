import 'package:flutter_test/flutter_test.dart';
import 'package:record_everything/domain/models/repeat_rule.dart';
import 'package:record_everything/domain/enums/repeat_period.dart';

/// 重复规则全业务路径测试。
///
/// 覆盖：
/// - 所有重复周期的序列化/反序列化
/// - 所有重复周期的 nextDate 计算
/// - 自定义天数的序列化/反序列化
/// - 月末日期钳位（如 1月31日 → 2月28日）
/// - 闰年处理
/// - 边界情况
void main() {
  group('RepeatRule 序列化与反序列化', () {
    test('daily 序列化与反序列化', () {
      const rule = RepeatRule(period: RepeatPeriod.daily);
      expect(rule.toStorageString(), 'daily');
      expect(RepeatRule.fromStorageString('daily').period, RepeatPeriod.daily);
    });

    test('weekly 序列化与反序列化', () {
      const rule = RepeatRule(period: RepeatPeriod.weekly);
      expect(rule.toStorageString(), 'weekly');
      expect(
        RepeatRule.fromStorageString('weekly').period,
        RepeatPeriod.weekly,
      );
    });

    test('monthly 序列化与反序列化', () {
      const rule = RepeatRule(period: RepeatPeriod.monthly);
      expect(rule.toStorageString(), 'monthly');
      expect(
        RepeatRule.fromStorageString('monthly').period,
        RepeatPeriod.monthly,
      );
    });

    test('yearly 序列化与反序列化', () {
      const rule = RepeatRule(period: RepeatPeriod.yearly);
      expect(rule.toStorageString(), 'yearly');
      expect(
        RepeatRule.fromStorageString('yearly').period,
        RepeatPeriod.yearly,
      );
    });

    test('自定义天数序列化与反序列化', () {
      const rule = RepeatRule(
        period: RepeatPeriod.custom,
        customDays: 14,
      );
      expect(rule.toStorageString(), 'every:14:days');
      final parsed = RepeatRule.fromStorageString('every:14:days');
      expect(parsed.period, RepeatPeriod.custom);
      expect(parsed.customDays, 14);
    });

    test('自定义 30 天序列化', () {
      const rule = RepeatRule(
        period: RepeatPeriod.custom,
        customDays: 30,
      );
      expect(rule.toStorageString(), 'every:30:days');
    });

    test('自定义 90 天序列化', () {
      const rule = RepeatRule(
        period: RepeatPeriod.custom,
        customDays: 90,
      );
      expect(rule.toStorageString(), 'every:90:days');
    });
  });

  group('RepeatRule nextDate 计算', () {
    test('daily 加 1 天', () {
      const rule = RepeatRule(period: RepeatPeriod.daily);
      expect(
        rule.nextDate(DateTime(2026, 7, 1)),
        DateTime(2026, 7, 2),
      );
    });

    test('daily 跨月', () {
      const rule = RepeatRule(period: RepeatPeriod.daily);
      expect(
        rule.nextDate(DateTime(2026, 7, 31)),
        DateTime(2026, 8, 1),
      );
    });

    test('daily 跨年', () {
      const rule = RepeatRule(period: RepeatPeriod.daily);
      expect(
        rule.nextDate(DateTime(2026, 12, 31)),
        DateTime(2027, 1, 1),
      );
    });

    test('weekly 加 7 天', () {
      const rule = RepeatRule(period: RepeatPeriod.weekly);
      expect(
        rule.nextDate(DateTime(2026, 7, 1)),
        DateTime(2026, 7, 8),
      );
    });

    test('weekly 跨月', () {
      const rule = RepeatRule(period: RepeatPeriod.weekly);
      expect(
        rule.nextDate(DateTime(2026, 7, 28)),
        DateTime(2026, 8, 4),
      );
    });

    test('monthly 正常月份', () {
      const rule = RepeatRule(period: RepeatPeriod.monthly);
      expect(
        rule.nextDate(DateTime(2026, 7, 15)),
        DateTime(2026, 8, 15),
      );
    });

    test('monthly 月末钳位（1月31日 → 2月28日）', () {
      const rule = RepeatRule(period: RepeatPeriod.monthly);
      expect(
        rule.nextDate(DateTime(2026, 1, 31)),
        DateTime(2026, 2, 28),
      );
    });

    test('monthly 闰年月末钳位（1月31日 → 2月29日）', () {
      const rule = RepeatRule(period: RepeatPeriod.monthly);
      expect(
        rule.nextDate(DateTime(2028, 1, 31)),
        DateTime(2028, 2, 29),
      );
    });

    test('monthly 30日 → 31日钳位', () {
      const rule = RepeatRule(period: RepeatPeriod.monthly);
      // 4月有30天，5月有31天
      expect(
        rule.nextDate(DateTime(2026, 4, 30)),
        DateTime(2026, 5, 30),
      );
    });

    test('monthly 跨年', () {
      const rule = RepeatRule(period: RepeatPeriod.monthly);
      expect(
        rule.nextDate(DateTime(2026, 12, 15)),
        DateTime(2027, 1, 15),
      );
    });

    test('yearly 正常年份', () {
      const rule = RepeatRule(period: RepeatPeriod.yearly);
      expect(
        rule.nextDate(DateTime(2026, 7, 15)),
        DateTime(2027, 7, 15),
      );
    });

    test('yearly 闰年到非闰年钳位（2月29日 → 2月28日）', () {
      const rule = RepeatRule(period: RepeatPeriod.yearly);
      expect(
        rule.nextDate(DateTime(2028, 2, 29)),
        DateTime(2029, 2, 28),
      );
    });

    test('自定义 14 天', () {
      const rule = RepeatRule(
        period: RepeatPeriod.custom,
        customDays: 14,
      );
      expect(
        rule.nextDate(DateTime(2026, 7, 1)),
        DateTime(2026, 7, 15),
      );
    });

    test('自定义 90 天', () {
      const rule = RepeatRule(
        period: RepeatPeriod.custom,
        customDays: 90,
      );
      expect(
        rule.nextDate(DateTime(2026, 7, 1)),
        DateTime(2026, 9, 29),
      );
    });

    test('自定义天数为 null 时默认 30 天', () {
      const rule = RepeatRule(
        period: RepeatPeriod.custom,
        customDays: null,
      );
      expect(
        rule.nextDate(DateTime(2026, 7, 1)),
        DateTime(2026, 7, 31),
      );
    });
  });

  group('RepeatRule 连续计算', () {
    test('连续 monthly 计算正确', () {
      const rule = RepeatRule(period: RepeatPeriod.monthly);
      var date = DateTime(2026, 1, 31);
      final dates = <DateTime>[];
      for (var i = 0; i < 3; i++) {
        date = rule.nextDate(date);
        dates.add(date);
      }
      expect(dates, [
        DateTime(2026, 2, 28),
        DateTime(2026, 3, 28),
        DateTime(2026, 4, 28),
      ]);
    });

    test('连续 daily 计算正确', () {
      const rule = RepeatRule(period: RepeatPeriod.daily);
      var date = DateTime(2026, 7, 30);
      final dates = <DateTime>[];
      for (var i = 0; i < 3; i++) {
        date = rule.nextDate(date);
        dates.add(date);
      }
      expect(dates, [
        DateTime(2026, 7, 31),
        DateTime(2026, 8, 1),
        DateTime(2026, 8, 2),
      ]);
    });
  });
}
