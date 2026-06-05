import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:record_everything/data/repositories/bill_record_repository.dart';
import 'package:record_everything/data/repositories/life_item_repository.dart';

import '../test/helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('home agenda renders calendar, quick create, and selected day', (
    tester,
  ) async {
    final harness = await pumpTestApp(tester);
    await LifeItemRepository(
      harness.database,
    ).create(title: '集成今日事项', dueTime: DateTime.now());
    await BillRecordRepository(
      harness.database,
    ).create(title: '集成今日账单', amount: 1800, billTime: DateTime.now());
    await settle(tester);

    expect(find.text('今天'), findsOneWidget);
    expect(find.text('本月支出'), findsOneWidget);
    expect(find.byKey(const ValueKey('selected-day-agenda')), findsOneWidget);
    expect(find.text('集成今日事项'), findsOneWidget);
    expect(find.text('集成今日账单'), findsOneWidget);

    await tapByKey(tester, 'home-calendar-month-mode');
    expect(find.text('月视图'), findsOneWidget);
    await tapByKey(tester, 'home-calendar-previous');
    await tapByKey(tester, 'home-calendar-next');

    await tester.tap(find.byTooltip('新增'));
    await settle(tester);
    expect(find.byKey(const ValueKey('quick-create-bill')), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-create-item')), findsOneWidget);
  });

  testWidgets('life item flow covers create, filters, detail and complete', (
    tester,
  ) async {
    final harness = await pumpTestApp(tester);
    final repository = LifeItemRepository(harness.database);
    await repository.create(
      title: '集成逾期事项',
      dueTime: DateTime.now().subtract(const Duration(days: 1)),
    );
    await repository.create(title: '集成今日事项', dueTime: DateTime.now());

    await tapText(tester, '事项');
    expect(find.text('生活事项'), findsOneWidget);

    await tapByKey(tester, 'items-filter-overdue');
    expect(find.text('集成逾期事项'), findsOneWidget);
    expect(find.text('集成今日事项'), findsNothing);

    await tapByKey(tester, 'items-filter-all');
    await tapText(tester, '集成今日事项');
    expect(find.text('事项详情'), findsOneWidget);
    await tapText(tester, '完成');
    expect(find.text('仅完成'), findsOneWidget);
    await tapText(tester, '仅完成');
    await settle(tester);
    expect(find.text('生活事项'), findsOneWidget);
  });

  testWidgets('bill flow covers grouping, filters, navigation and edit route', (
    tester,
  ) async {
    final harness = await pumpTestApp(tester);
    final repository = BillRecordRepository(harness.database);
    await repository.create(
      title: '集成早餐',
      amount: 1200,
      amountType: 'expense',
      billTime: DateTime.now(),
    );
    await repository.create(
      title: '集成工资',
      amount: 800000,
      amountType: 'income',
      billTime: DateTime.now(),
    );
    await repository.create(
      title: '集成会员订阅',
      amount: 3000,
      amountType: 'expense',
      billTime: DateTime.now(),
    );

    await tapText(tester, '账单');
    expect(find.text('本月支出'), findsOneWidget);
    expect(find.text('集成早餐'), findsOneWidget);
    expect(find.text('集成工资'), findsOneWidget);

    await tapByKey(tester, 'bills-filter-income');
    expect(find.text('集成工资'), findsOneWidget);
    expect(find.text('集成早餐'), findsNothing);

    await tapByKey(tester, 'bills-filter-subscription');
    expect(find.text('集成会员订阅'), findsOneWidget);

    await tapByKey(tester, 'bills-filter-all');
    await tapText(tester, '集成早餐');
    expect(find.text('编辑账单'), findsOneWidget);
  });

  testWidgets('statistics and settings smoke paths stay reachable', (
    tester,
  ) async {
    await pumpTestApp(tester);

    await tapText(tester, '统计');
    expect(find.text('统计'), findsWidgets);
    expect(find.text('本月收入'), findsOneWidget);
    expect(find.text('收支趋势'), findsOneWidget);
    expect(find.text('分类占比'), findsOneWidget);

    await tapText(tester, '设置');
    expect(find.text('设置'), findsWidgets);
    expect(find.text('导入数据'), findsOneWidget);
    expect(find.text('导出备份'), findsOneWidget);
    expect(find.text('提醒设置'), findsOneWidget);
  });
}
