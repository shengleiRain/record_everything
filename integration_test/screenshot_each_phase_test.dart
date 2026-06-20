// 为三个阶段生成可视化截图证据。
// 使用 integration_test binding.takeScreenshot 在断言通过的各关键节点截图，
// 输出到 integration_test/screenshots/ 目录（由 --screenshots-dir 指定）。

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record_everything/core/router/app_router.dart'
    show createAppRouter;
import 'package:record_everything/core/theme/app_theme.dart';
import 'package:record_everything/data/database/app_database.dart';
import 'package:record_everything/data/database/database_provider.dart';
import 'package:record_everything/data/repositories/bill_record_repository.dart';
import 'package:record_everything/features/smart_entry/services/secure_key_store.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late Directory outDir;

  setUpAll(() async {
    // 优先写到 App 专属外部目录；失败则回退 /data/local/tmp（emulator 上可写且卸载后保留）。
    Directory? base;
    try {
      base = await getExternalStorageDirectory();
    } catch (_) {
      base = null;
    }
    final root = base?.path ?? '/data/local/tmp';
    outDir = Directory('$root/phase_screenshots');
    try {
      if (!outDir.existsSync()) {
        outDir.createSync(recursive: true);
      }
    } catch (_) {
      // 回退到可写临时目录。
      outDir = Directory('/data/local/tmp/phase_screenshots');
      if (!outDir.existsSync()) {
        outDir.createSync(recursive: true);
      }
    }
  });

  Future<AppDatabase> pumpApp(WidgetTester tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await db.close();
    });
    // Android 上像素级截图需要先把 surface 转成可截取的 image。
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          secureKeyStoreProvider.overrideWithValue(
            SecureKeyStore.forTesting(const AiConfig()),
          ),
        ],
        child: MaterialApp.router(
          title: '生活事项',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme(),
          routerConfig: createAppRouter(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }
    return db;
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await tester.pump(const Duration(milliseconds: 400));
    final bytes = await binding.takeScreenshot(name);
    final file = File('${outDir.path}/$name.png');
    await file.writeAsBytes(bytes);
  }

  testWidgets('capture key screens for phases 1/2/3', (tester) async {
    final db = await pumpApp(tester);

    // === 阶段一：智能录入 ===
    // 1) 快速创建面板（智能输入入口横幅）
    await tester.tap(find.byTooltip('新增'));
    await tester.pump(const Duration(milliseconds: 300));
    await shot(tester, 'p1_quick_create_sheet');
    await tester.tap(find.text('智能输入').last);
    await tester.pump(const Duration(milliseconds: 300));
    await shot(tester, 'p1_smart_entry_input');

    // 2) 输入自然语言并解析 → 草稿确认页
    await tester.enterText(
      find.byKey(const ValueKey('smart-entry-input-field')),
      '明天3点开会，午餐花了25',
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(const ValueKey('smart-entry-parse-btn')));
    await tester.pump(const Duration(milliseconds: 400));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }
    await shot(tester, 'p1_draft_confirm');

    // 保存落库
    final saveBtn = find.textContaining('保存全部');
    await tester.ensureVisible(saveBtn);
    await tester.tap(saveBtn);
    await tester.pump(const Duration(milliseconds: 400));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }
    await shot(tester, 'p1_saved_snackbar');

    // === 阶段一：BYOK AI 助手设置页（用路由直接跳，避免依赖底部 Tab）===
    final navContext = tester.element(find.byType(Navigator).first);
    GoRouter.of(navContext).go('/settings/ai-assistant');
    await tester.pump(const Duration(milliseconds: 400));
    await shot(tester, 'p1_ai_assistant_settings');

    // === 阶段三：统计页趋势图表（先注入当月数据）===
    final cats = await db.categoryDao.getAll();
    final expenseCat = cats.firstWhere(
      (c) => c.type == 'expense',
      orElse: () => cats.first,
    );
    await BillRecordRepository(db).create(
      title: '午餐',
      amount: 3200,
      amountType: 'expense',
      billTime: DateTime.now(),
      categoryId: expenseCat.id,
    );
    await BillRecordRepository(db).create(
      title: '打车',
      amount: 4500,
      amountType: 'expense',
      billTime: DateTime.now().subtract(const Duration(days: 2)),
      categoryId: expenseCat.id,
    );

    GoRouter.of(navContext).go('/statistics');
    await tester.pump(const Duration(milliseconds: 400));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }
    await shot(tester, 'p3_statistics_trend');

    // 滚动到分类趋势图区域
    await tester.scrollUntilVisible(
      find.text('分类消费趋势'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 300));
    await shot(tester, 'p3_category_trend_chart');

    // === 阶段三：自动分类推荐 chip（账单编辑页）===
    GoRouter.of(navContext).go('/bills/new');
    await tester.pump(const Duration(milliseconds: 400));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }
    // 确保“标题 *”字段已渲染。
    expect(find.widgetWithText(TextFormField, '标题 *'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, '标题 *'), '午餐');
    await tester.pump(const Duration(milliseconds: 900)); // debounce + provider
    await shot(tester, 'p3_category_suggestion_chip');
  });
}
