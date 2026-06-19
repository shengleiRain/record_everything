import 'package:flutter_test/flutter_test.dart';
import 'package:record_everything/features/smart_entry/models/draft_item.dart';
import 'package:record_everything/features/smart_entry/parser/local_rule_engine.dart';

void main() {
  // 固定"现在"为 2026-06-19 10:00（周五），保证相对时间测试稳定。
  final now = DateTime(2026, 6, 19, 10);
  final engine = LocalRuleEngine(now: now);

  test('消费动词+金额 → 支出账单', () {
    final items = engine.parse('午餐花了25');
    expect(items, hasLength(1));
    final item = items.single;
    expect(item.kind, DraftKind.bill);
    expect(item.amountCents, 2500);
    expect(item.amountType, DraftAmountType.expense);
    expect(item.categoryGuess, '餐饮');
    expect(item.confidence, greaterThan(0.6));
  });

  test('任务动词 → 事项', () {
    final items = engine.parse('明天3点开会');
    expect(items, hasLength(1));
    final item = items.single;
    expect(item.kind, DraftKind.lifeItem);
    // 无上午/下午标记时按字面小时解析（3 点 = 03:00）。
    expect(item.time, DateTime(2026, 6, 20, 3));
    expect(item.amountCents, isNull);
  });

  test('下午标记推后小时', () {
    final items = engine.parse('明天下午3点开会');
    expect(items.single.time, DateTime(2026, 6, 20, 15));
  });

  test('收入动词+金额 → 收入账单', () {
    final items = engine.parse('工资到账5000');
    final item = items.single;
    expect(item.kind, DraftKind.bill);
    expect(item.amountType, DraftAmountType.income);
    expect(item.amountCents, 500000);
  });

  test('仅金额无动词 → 默认支出账单', () {
    final items = engine.parse('25');
    final item = items.single;
    expect(item.kind, DraftKind.bill);
    expect(item.amountType, DraftAmountType.expense);
  });

  test('重复规则 → 事项', () {
    final items = engine.parse('每月15号交房租');
    final item = items.single;
    expect(item.kind, DraftKind.lifeItem);
    expect(item.repeatRule, isNotNull);
  });

  test('完全无法解析 → 返回空', () {
    expect(engine.parse('随便一句话没有任何信息'), isEmpty);
  });

  test('相对时间：后天', () {
    final items = engine.parse('后天下午开会');
    final item = items.single;
    expect(item.time.day, 21); // 6/19 + 2
  });
}
