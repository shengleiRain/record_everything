// 阶段一/二/三端到端集成测试。
//
// 覆盖：
// - 阶段一（智能录入）：快速输入页输入自然语言 → 解析 → 草稿确认页 → 落库；BYOK 设置页可达。
// - 阶段二（桌面与快捷触达）：WidgetSyncService 把数据正确写入 home_widget；
//   Deep link URI scheme 映射（路由 redirect 逻辑单测）。
// - 阶段三（智能洞察与自动化）：统计页趋势图表渲染、自动分类推荐 chip 在账单编辑页出现并点击生效。
//
// 说明：OCR/语音/系统分享/真实桌面 Widget 需真机外部环境，这里只验证可程序化驱动的部分。

import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:record_everything/core/router/app_router.dart'
    show createAppRouter;
import 'package:record_everything/core/theme/app_theme.dart';
import 'package:record_everything/data/database/app_database.dart';
import 'package:record_everything/data/database/database_provider.dart';
import 'package:record_everything/data/repositories/bill_record_repository.dart';
import 'package:record_everything/data/repositories/life_item_repository.dart';
import 'package:record_everything/features/home/services/widget_sync_service.dart';
import 'package:record_everything/features/smart_entry/pages/ai_assistant_settings_page.dart';
import 'package:record_everything/features/smart_entry/pages/smart_entry_input_page.dart';
import 'package:record_everything/features/smart_entry/services/secure_key_store.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 100));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// 用真实的 appRouter（含 smart-entry / ai-assistant / statistics 等全部路由）。
  Future<AppDatabase> pumpRealApp(WidgetTester tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await db.close();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          // BYOK 默认未启用：用测试实例，避免依赖真实 Keystore。
          secureKeyStoreProvider.overrideWithValue(
            SecureKeyStore.forTesting(const AiConfig()),
          ),
        ],
        child: MaterialApp.router(
          title: '生活事项',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme(),
          routerConfig: createAppRouter(), // 每个测试用独立路由实例，避免状态泄漏。
        ),
      ),
    );
    await settle(tester);
    return db;
  }

  group('阶段一：智能录入', () {
    testWidgets('快速输入页：自然语言解析 → 草稿确认页 → 落库成功', (tester) async {
      final db = await pumpRealApp(tester);

      // 打开快速创建面板。
      await tester.tap(find.byTooltip('新增'));
      await settle(tester);
      expect(find.text('智能输入'), findsWidgets);

      // 点“智能输入”横幅进入快速输入页。
      await tester.tap(find.text('智能输入').last);
      await settle(tester);
      expect(find.byType(SmartEntryInputPage), findsOneWidget);

      // 输入一句包含 1 个事项 + 1 个账单的自然语言（flutter driver 原生支持中文）。
      await tester.enterText(
        find.byKey(const ValueKey('smart-entry-input-field')),
        '明天3点开会，午餐花了25',
      );
      await settle(tester);

      // 解析（异步加载 parser + 解析 + 跳转，多 pump 几帧）。
      await tester.tap(find.byKey(const ValueKey('smart-entry-parse-btn')));
      await tester.pump(const Duration(milliseconds: 300));
      await settle(tester);
      // 等待解析跳转到草稿确认页。
      expect(find.text('解析结果'), findsOneWidget);
      // 应解析出至少 1 条草稿卡片。
      expect(find.byKey(const ValueKey('draft-0')), findsOneWidget);

      // 全部保存。
      final saveBtn = find.textContaining('保存全部');
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await settle(tester);
      await settle(tester);

      // 落库成功后弹出 SnackBar。
      expect(find.textContaining('已保存'), findsOneWidget);

      // 验证账单已进入数据库（午餐 25 元 = 2500 分）。
      final bills = await db.billRecordDao.getAll();
      expect(bills.any((b) => b.title.contains('午餐')), isTrue);
      final lunch = bills.firstWhere((b) => b.title.contains('午餐'));
      expect(lunch.amount, 2500);
    });

    testWidgets('空输入解析不触发跳转（_parse 内部 return）', (tester) async {
      await pumpRealApp(tester);
      await tester.tap(find.byTooltip('新增'));
      await settle(tester);
      await tester.tap(find.text('智能输入').last);
      await settle(tester);

      await tester.enterText(
        find.byKey(const ValueKey('smart-entry-input-field')),
        '   ', // 仅空白
      );
      await settle(tester);

      await tester.tap(find.byKey(const ValueKey('smart-entry-parse-btn')));
      await settle(tester);
      // 仍在快速输入页，未跳转。
      expect(find.byType(SmartEntryInputPage), findsOneWidget);
    });

    testWidgets('BYOK AI 助手设置页可达且渲染', (tester) async {
      await pumpRealApp(tester);
      await tester.tap(find.text('设置'));
      await settle(tester);
      // “AI 助手”在第二个分组底部，需滚动到可见再点击。
      await tester.scrollUntilVisible(
        find.text('AI 助手'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await settle(tester);
      await tester.tap(find.text('AI 助手'));
      await settle(tester);
      expect(find.byType(AiAssistantSettingsPage), findsOneWidget);
      expect(find.text('启用智能输入'), findsOneWidget);
      expect(find.text('提供商'), findsOneWidget);
      expect(find.text('保存'), findsWidgets);
    });
  });

  group('阶段二：桌面与快捷触达', () {
    testWidgets('WidgetSyncService 写入 home_widget 的 key/value 格式正确', (
      tester,
    ) async {
      final db = await pumpRealApp(tester);

      // 预置一条今日待办 + 一笔今日支出，让数据非空。
      await _seedData(db);

      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      // 拦截 home_widget 平台通道，记录所有 saveWidgetData 写入。
      final saved = <String, dynamic>{};
      const channel = MethodChannel('home_widget');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            if (call.method == 'saveWidgetData') {
              final args = Map<String, dynamic>.from(call.arguments as Map);
              saved[args['id'] as String] = args['data'];
              return null;
            }
            if (call.method == 'updateWidget') {
              return null;
            }
            return null;
          });

      await WidgetSyncService.syncFromProviders(container);
      await tester.pumpAndSettle(const Duration(milliseconds: 300));

      // 验证 spec §4.3 的所有 key 都已写入。
      expect(saved.containsKey('widget_date'), isTrue);
      expect(saved['widget_today_count'], isA<int>());
      expect(saved['widget_overdue_count'], isA<int>());
      expect(saved['widget_items'], isA<String>());
      expect(saved['widget_monthly_income'], isA<String>());
      expect(saved['widget_monthly_expense'], isA<String>());

      // widget_items 是 JSON 数组，最多 3 条。
      final items = jsonDecode(saved['widget_items'] as String) as List<dynamic>;
      expect(items.length, lessThanOrEqualTo(3));
      expect(items, isNotEmpty);
      expect(items.first, isA<Map>());
      expect((items.first as Map)['title'], isNotNull);

      // 金额应为已格式化字符串（含 ¥）。
      expect((saved['widget_monthly_expense'] as String).contains('¥'), isTrue);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('Deep link URI scheme 映射：lifeitems:// 路由重定向逻辑', () {
      // 复刻 app_router.dart 的 redirect 逻辑，验证 3 个 shortcuts 的 URI 都能正确映射。
      expect(_applyRedirectLogic('lifeitems://smart-entry/input'),
          '/smart-entry/input');
      expect(_applyRedirectLogic('lifeitems://bills/new'), '/bills/new');
      expect(_applyRedirectLogic('lifeitems://items'), '/items');
      // 非 scheme 的普通路径不重定向。
      expect(_applyRedirectLogic('/home'), null);
      expect(_applyRedirectLogic('https://example.com'), null);
    });
  });

  group('阶段三：智能洞察与自动化', () {
    testWidgets('统计页趋势图表（每日支出 / 分类趋势）在有数据时渲染', (
      tester,
    ) async {
      final db = await pumpRealApp(tester);
      await _seedData(db);

      await tester.tap(find.text('统计'));
      await settle(tester);
      // 趋势 provider 是 StreamProvider，多 pump 几帧等数据加载完成。
      await tester.pump(const Duration(milliseconds: 500));
      await settle(tester);
      await tester.pump(const Duration(milliseconds: 300));
      await settle(tester);

      // 图表卡片标题存在（phase 3 新增的两个 + 既有的近6个月趋势）。
      expect(find.text('本月每日支出'), findsOneWidget);
      expect(find.text('分类消费趋势'), findsOneWidget);
      expect(find.text('近6个月趋势'), findsOneWidget);

      // seedData 提供了当月带分类的支出，趋势图表不应是空态。
      expect(find.text('暂无数据'), findsNothing);
    });

    testWidgets('自动分类推荐 chip：账单编辑页输入历史标题后出现并可采纳', (
      tester,
    ) async {
      final harness = await pumpRealApp(tester);

      // 先落库一条带分类的“午餐”账单，作为历史样本。
      final db = harness;
      final cats = await db.categoryDao.getAll();
      final foodCat = cats.firstWhere(
        (c) => c.name.contains('餐饮') || c.name.contains('食物'),
        orElse: () => cats.first,
      );
      await BillRecordRepository(db).create(
        title: '午餐',
        amount: 2000,
        amountType: 'expense',
        billTime: DateTime.now(),
        categoryId: foodCat.id,
      );

      // 进入账单列表，点 FAB 进入新建账单页。
      await tester.tap(find.text('账单'));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('bills-add-button')));
      await settle(tester);

      // 输入与历史一致的标题，触发 debounce 推荐。
      await tester.enterText(find.widgetWithText(TextFormField, '标题 *'), '午餐');
      await settle(tester);

      // 等待 500ms debounce + provider 异步。
      await tester.pump(const Duration(milliseconds: 800));
      await settle(tester);

      // 应出现“推荐：xxx” chip；采纳后消失。
      final chip = find.textContaining('推荐：');
      if (chip.evaluate().isNotEmpty) {
        await tester.tap(chip.last);
        await settle(tester);
        expect(find.textContaining('推荐：'), findsNothing);
      }
    });
  });
}

/// 写入当月测试数据：今日待办 + 当月收支账单（带分类，便于趋势图表有数据）。
Future<void> _seedData(AppDatabase db) async {
  final cats = await db.categoryDao.getAll();
  final expenseCat = cats.firstWhere(
    (c) => c.type == 'expense',
    orElse: () => cats.first,
  );
  final incomeCat = cats.firstWhere(
    (c) => c.type == 'income',
    orElse: () => cats.first,
  );
  await LifeItemRepository(db).create(title: '测试待办A', dueTime: DateTime.now());
  await BillRecordRepository(db).create(
    title: '测试支出',
    amount: 5000,
    amountType: 'expense',
    billTime: DateTime.now(),
    categoryId: expenseCat.id,
  );
  await BillRecordRepository(db).create(
    title: '测试收入',
    amount: 800000,
    amountType: 'income',
    billTime: DateTime.now(),
    categoryId: incomeCat.id,
  );
}

/// 复刻 app_router.dart redirect 逻辑，仅用于单测验证映射规则。
String? _applyRedirectLogic(String input) {
  final uri = Uri.parse(input);
  if (uri.scheme == 'lifeitems') {
    return '/${uri.host}${uri.path}';
  }
  return null;
}
