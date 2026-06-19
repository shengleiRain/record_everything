import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:record_everything/data/database/app_database.dart';
import 'package:record_everything/data/database/database_provider.dart';
import 'package:record_everything/features/smart_entry/models/draft_item.dart';
import 'package:record_everything/features/smart_entry/pages/smart_entry_confirm_page.dart';
import 'package:record_everything/features/smart_entry/pages/smart_entry_input_page.dart';
import 'package:record_everything/features/smart_entry/services/secure_key_store.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.categoryDao.getAll();
  });
  tearDown(() async => db.close());

  Future<void> pumpApp(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/smart-entry/input',
      routes: [
        GoRoute(
          path: '/smart-entry/input',
          builder: (_, __) => const SmartEntryInputPage(),
        ),
        GoRoute(
          path: '/smart-entry/confirm',
          builder: (context, state) =>
              SmartEntryConfirmPage(draft: state.extra! as EntryDraft),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          secureKeyStoreProvider.overrideWithValue(
            SecureKeyStore.forTesting(const AiConfig()),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('输入 → 解析 → 确认 → 保存 → 账单入库', (tester) async {
    await pumpApp(tester);

    // 输入一句话
    await tester.enterText(
      find.byKey(const ValueKey('smart-entry-input-field')),
      '午餐花了25',
    );
    // 点击解析
    await tester.tap(find.byKey(const ValueKey('smart-entry-parse-btn')));
    await tester.pumpAndSettle();

    // 确认页显示
    expect(find.text('解析结果'), findsOneWidget);
    expect(find.text('午餐'), findsOneWidget);

    // 点击保存
    await tester.tap(find.text('保存全部 1 条'));
    await tester.pumpAndSettle();

    // 验证 SnackBar
    expect(find.textContaining('已保存'), findsOneWidget);

    // 验证落库
    final bills = await db.billRecordDao.getAll();
    expect(bills, hasLength(1));
    expect(bills.first.title, '午餐');
    expect(bills.first.amount, 2500);
  });

  testWidgets('一句话拆多条：事项+账单同时入库', (tester) async {
    await pumpApp(tester);

    await tester.enterText(
      find.byKey(const ValueKey('smart-entry-input-field')),
      '明天下午3点开会,午餐花了25',
    );
    await tester.tap(find.byKey(const ValueKey('smart-entry-parse-btn')));
    await tester.pumpAndSettle();

    // 确认页应显示两条
    expect(find.text('解析结果'), findsOneWidget);
    expect(find.text('保存全部 2 条'), findsOneWidget);

    await tester.tap(find.text('保存全部 2 条'));
    await tester.pumpAndSettle();

    expect(find.textContaining('已保存'), findsOneWidget);

    // 验证分别入库
    final bills = await db.billRecordDao.getAll();
    final items = await db.lifeItemDao.getAll();
    expect(bills, hasLength(1));
    expect(items, isNotEmpty); // 开会 → lifeItem
  });
}
