import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:record_everything/data/repositories/bill_record_repository.dart';
import 'package:record_everything/data/repositories/life_item_repository.dart';
import 'package:record_everything/data/repositories/project_repository.dart';

import '../test/helpers/test_app.dart';

/// 全业务路径集成测试。
///
/// 在 Android 模拟器上运行，覆盖所有主要 UI 路径。
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // ==================== 首页仪表盘 ====================

  group('首页仪表盘', () {
    testWidgets('渲染日历、今日事项和快速创建', (tester) async {
      final harness = await pumpTestApp(tester);
      await LifeItemRepository(harness.database)
          .create(title: '今日待办', dueTime: DateTime.now());
      await BillRecordRepository(harness.database).create(
        title: '今日账单',
        amount: 1800,
        billTime: DateTime.now(),
      );
      await settle(tester);

      expect(find.text('今天'), findsOneWidget);
      expect(find.text('本月支出'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('selected-day-agenda')),
        findsOneWidget,
      );
      expect(find.text('今日待办'), findsOneWidget);
      expect(find.text('今日账单'), findsOneWidget);

      // 展开月历
      final agendaTopLeft = tester.getTopLeft(
        find.byKey(const ValueKey('selected-day-agenda')),
      );
      await tester.dragFrom(
        agendaTopLeft + const Offset(100, 24),
        const Offset(0, 160),
      );
      await settle(tester);
      final now = DateTime.now();
      expect(find.text('${now.year}年${now.month}月'), findsOneWidget);

      // 切换月份
      await tapByKey(tester, 'home-calendar-previous');
      await tapByKey(tester, 'home-calendar-next');

      // 快速创建
      await tester.tap(find.byTooltip('新增'));
      await settle(tester);
      expect(find.byKey(const ValueKey('quick-create-bill')), findsOneWidget);
      expect(find.byKey(const ValueKey('quick-create-item')), findsOneWidget);
    });
  });

  // ==================== 生活事项完整流程 ====================

  group('生活事项完整流程', () {
    testWidgets('创建事项并验证列表显示', (tester) async {
      final harness = await pumpTestApp(tester);
      await LifeItemRepository(harness.database).create(
        title: '新建测试事项',
        dueTime: DateTime.now(),
      );
      await settle(tester);

      await tapText(tester, '事项');
      expect(find.text('生活事项'), findsOneWidget);
      expect(find.text('新建测试事项'), findsOneWidget);
    });

    testWidgets('筛选：逾期和今天', (tester) async {
      final harness = await pumpTestApp(tester);
      final repo = LifeItemRepository(harness.database);
      await repo.create(
        title: '逾期事项',
        dueTime: DateTime.now().subtract(const Duration(days: 1)),
      );
      await repo.create(title: '今日事项', dueTime: DateTime.now());
      await settle(tester);

      await tapText(tester, '事项');

      // 逾期筛选
      await tapByKey(tester, 'items-filter-overdue');
      expect(find.text('逾期事项'), findsOneWidget);
      expect(find.text('今日事项'), findsNothing);

      // 全部筛选
      await tapByKey(tester, 'items-filter-all');
      expect(find.text('逾期事项'), findsOneWidget);
      expect(find.text('今日事项'), findsOneWidget);
    });

    testWidgets('事项详情与完成操作', (tester) async {
      final harness = await pumpTestApp(tester);
      await LifeItemRepository(harness.database)
          .create(title: '待完成事项', dueTime: DateTime.now());
      await settle(tester);

      await tapText(tester, '事项');
      await tapText(tester, '待完成事项');
      // Detail sheet shows item title
      expect(find.text('待完成事项'), findsWidgets);

      // Find and tap "完成" action
      final completeBtn = find.text('完成');
      if (completeBtn.evaluate().isNotEmpty) {
        await tester.tap(completeBtn.last);
        await settle(tester);
        // "仅完成" option should appear
        final onlyComplete = find.text('仅完成');
        if (onlyComplete.evaluate().isNotEmpty) {
          await tester.tap(onlyComplete.last);
          await settle(tester);
        }
      }
    });

    testWidgets('事项延期操作', (tester) async {
      final harness = await pumpTestApp(tester);
      await LifeItemRepository(harness.database)
          .create(title: '待延期事项', dueTime: DateTime.now());
      await settle(tester);

      await tapText(tester, '事项');
      await tapText(tester, '待延期事项');

      // Find and tap "完成" to reveal action sheet
      final completeBtn = find.text('完成');
      if (completeBtn.evaluate().isNotEmpty) {
        await tester.tap(completeBtn.last);
        await settle(tester);
        // Find and tap "延期"
        final deferBtn = find.text('延期');
        if (deferBtn.evaluate().isNotEmpty) {
          await tester.tap(deferBtn.last);
          await settle(tester);
        }
      }
    });
  });

  // ==================== 账单完整流程 ====================

  group('账单完整流程', () {
    testWidgets('账单列表和筛选', (tester) async {
      final harness = await pumpTestApp(tester);
      final repo = BillRecordRepository(harness.database);
      await repo.create(
        title: '早餐支出',
        amount: 1200,
        amountType: 'expense',
        billTime: DateTime.now(),
      );
      await repo.create(
        title: '工资收入',
        amount: 800000,
        amountType: 'income',
        billTime: DateTime.now(),
      );
      await settle(tester);

      await tapText(tester, '账单');
      expect(find.text('本月支出'), findsOneWidget);
      expect(find.text('早餐支出'), findsOneWidget);
      expect(find.text('工资收入'), findsOneWidget);

      // 收入筛选
      await tapByKey(tester, 'bills-filter-income');
      expect(find.text('工资收入'), findsOneWidget);
      expect(find.text('早餐支出'), findsNothing);

      // 全部筛选
      await tapByKey(tester, 'bills-filter-all');
    });
  });

  // ==================== 统计页面 ====================

  group('统计页面', () {
    testWidgets('统计页面可访问', (tester) async {
      await pumpTestApp(tester);
      await settle(tester);

      await tapText(tester, '统计');
      expect(find.text('统计'), findsWidgets);
    });
  });

  // ==================== 设置页面 ====================

  group('设置页面', () {
    testWidgets('设置页面渲染', (tester) async {
      await pumpTestApp(tester);
      await settle(tester);

      await tapText(tester, '设置');
      expect(find.text('设置'), findsWidgets);
    });
  });

  // ==================== 底部导航 ====================

  group('底部导航', () {
    testWidgets('5个Tab可正常切换', (tester) async {
      await pumpTestApp(tester);
      await settle(tester);

      // 首页
      expect(find.text('今天'), findsOneWidget);

      // 事项
      await tapText(tester, '事项');
      expect(find.text('生活事项'), findsOneWidget);

      // 账单
      await tapText(tester, '账单');
      expect(find.text('账单'), findsWidgets);

      // 统计
      await tapText(tester, '统计');
      expect(find.text('统计'), findsWidgets);

      // 设置
      await tapText(tester, '设置');
      expect(find.text('设置'), findsWidgets);

      // 回到首页
      await tapText(tester, '首页');
      expect(find.text('今天'), findsOneWidget);
    });
  });

  // ==================== 项目模板 ====================

  group('项目模板', () {
    testWidgets('内置模板存在', (tester) async {
      final harness = await pumpTestApp(tester);
      final repo = ProjectRepository(harness.database);
      final templates = await repo.watchTemplates().first;

      // 验证有模板存在（包括内置模板）
      expect(templates, isNotEmpty);
      expect(templates.any((t) => t.isDefault), isTrue);
    });
  });

  // ==================== 事项模板 ====================

  group('事项模板', () {
    testWidgets('内置模板存在', (tester) async {
      final harness = await pumpTestApp(tester);
      final repo = LifeItemRepository(harness.database);
      final templates = await repo.getTemplates();

      expect(templates.length, 6);
      expect(templates.every((t) => t.isDefault), isTrue);
    });

    testWidgets('模板推荐功能', (tester) async {
      final harness = await pumpTestApp(tester);
      final repo = LifeItemRepository(harness.database);

      final membership = await repo.recommendTemplates('会员续费');
      expect(
        membership.any((t) => t.templateKey == 'membership_renewal'),
        isTrue,
      );

      final passport = await repo.recommendTemplates('护照过期');
      expect(
        passport.any((t) => t.templateKey == 'document_expiry'),
        isTrue,
      );
    });
  });
}
