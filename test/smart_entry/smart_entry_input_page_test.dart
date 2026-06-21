import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:record_everything/core/theme/app_theme.dart';
import 'package:record_everything/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:record_everything/data/database/app_database.dart';
import 'package:record_everything/l10n/generated/app_localizations.dart';
import 'package:record_everything/data/database/database_provider.dart';
import 'package:record_everything/l10n/generated/app_localizations.dart';
import 'package:record_everything/features/smart_entry/models/draft_item.dart';
import 'package:record_everything/l10n/generated/app_localizations.dart';
import 'package:record_everything/features/smart_entry/pages/smart_entry_confirm_page.dart';
import 'package:record_everything/l10n/generated/app_localizations.dart';
import 'package:record_everything/features/smart_entry/pages/smart_entry_input_page.dart';
import 'package:record_everything/l10n/generated/app_localizations.dart';
import 'package:record_everything/features/smart_entry/services/secure_key_store.dart';
import 'package:record_everything/l10n/generated/app_localizations.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.categoryDao.getAll();
  });
  tearDown(() async => db.close());

  /// 用 go_router 挂载 input + confirm，路径与真实 appRouter 一致（/smart-entry/*）。
  /// override secureKeyStoreProvider 以避免依赖原生 FlutterSecureStorage。
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
          secureKeyStoreProvider.overrideWithValue(_FakeSecureKeyStore()),
        ],
        child: MaterialApp.router(locale: const Locale('zh'), localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales, theme: AppTheme.lightTheme(), routerConfig: router),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('输入文本后点解析按钮跳转确认页', (tester) async {
    await pumpApp(tester);

    await tester.enterText(
      find.byKey(const ValueKey('smart-entry-input-field')),
      '午餐花了25',
    );
    await tester.tap(find.byKey(const ValueKey('smart-entry-parse-btn')));
    await tester.pumpAndSettle();

    // 跳到确认页，AppBar 标题为"解析结果"，且能看到账单标题。
    expect(find.text('解析结果'), findsOneWidget);
    expect(find.text('午餐'), findsOneWidget);
  });

  testWidgets('解析后确认页显示来源横幅与原文', (tester) async {
    await pumpApp(tester);

    await tester.enterText(
      find.byKey(const ValueKey('smart-entry-input-field')),
      '咖啡花了20',
    );
    await tester.tap(find.byKey(const ValueKey('smart-entry-parse-btn')));
    await tester.pumpAndSettle();

    expect(find.text('来自：快速输入'), findsOneWidget);
    expect(find.text('咖啡花了20'), findsOneWidget);
  });

  testWidgets('识图入口存在', (tester) async {
    await pumpApp(tester);
    expect(find.byKey(const ValueKey('smart-entry-ocr-btn')), findsOneWidget);
  });

  testWidgets('语音入口存在', (tester) async {
    await pumpApp(tester);
    expect(find.byKey(const ValueKey('smart-entry-voice-btn')), findsOneWidget);
  });
}

/// 测试用 FakeSecureKeyStore：不依赖原生 FlutterSecureStorage。
class _FakeSecureKeyStore extends SecureKeyStore {
  _FakeSecureKeyStore() : super.forTesting(const AiConfig());
}
