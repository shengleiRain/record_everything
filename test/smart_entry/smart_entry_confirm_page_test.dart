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
import 'package:record_everything/data/repositories/bill_record_repository.dart';
import 'package:record_everything/l10n/generated/app_localizations.dart';
import 'package:record_everything/data/repositories/life_item_repository.dart';
import 'package:record_everything/l10n/generated/app_localizations.dart';
import 'package:record_everything/features/smart_entry/models/draft_item.dart';
import 'package:record_everything/l10n/generated/app_localizations.dart';
import 'package:record_everything/features/smart_entry/pages/smart_entry_confirm_page.dart';
import 'package:record_everything/l10n/generated/app_localizations.dart';
import 'package:record_everything/features/smart_entry/providers/smart_entry_providers.dart';
import 'package:record_everything/l10n/generated/app_localizations.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.categoryDao.getAll();
  });
  tearDown(() async => db.close());

  /// 用 go_router 挂载，保证 context.pop() 可用（真实导航行为）。
  Future<void> pumpConfirm(
    WidgetTester tester, {
    required List<DraftItem> items,
  }) async {
    final draft = EntryDraft(
      items: items,
      source: DraftSource.nl,
      rawInput: '测试',
    );
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: Text('home')),
          routes: [
            GoRoute(
              path: 'confirm',
              builder: (context, state) =>
                  SmartEntryConfirmPage(draft: state.extra! as EntryDraft),
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          smartEntryPersistProvider.overrideWith(
            (ref) => _TestPersistService(ref, db),
          ),
        ],
        child: MaterialApp.router(locale: const Locale('zh'), localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales, theme: AppTheme.lightTheme(), routerConfig: router),
      ),
    );
    // 跳到 confirm 页（带 extra）。
    final homeContext = tester.element(find.text('home'));
    homeContext.push('/confirm', extra: draft);
    await tester.pumpAndSettle();
  }

  testWidgets('渲染所有卡片 + 保存全部按钮', (tester) async {
    await pumpConfirm(
      tester,
      items: [
        DraftItem(
          kind: DraftKind.bill,
          title: '午餐',
          amountCents: 2500,
          amountType: DraftAmountType.expense,
          time: DateTime(2026, 6, 19),
          source: DraftSource.nl,
          confidence: 0.9,
        ),
        DraftItem(
          kind: DraftKind.lifeItem,
          title: '开会',
          amountCents: null,
          amountType: DraftAmountType.none,
          time: DateTime(2026, 6, 20),
          source: DraftSource.nl,
          confidence: 0.9,
        ),
      ],
    );
    expect(find.text('午餐'), findsOneWidget);
    expect(find.text('开会'), findsOneWidget);
    expect(find.text('保存全部 2 条'), findsOneWidget);
  });

  testWidgets('删除一条后进入空态', (tester) async {
    await pumpConfirm(
      tester,
      items: [
        DraftItem(
          kind: DraftKind.bill,
          title: '咖啡',
          amountCents: 1500,
          amountType: DraftAmountType.expense,
          time: DateTime(2026, 6, 19),
          source: DraftSource.nl,
          confidence: 0.9,
        ),
      ],
    );
    await tester.tap(find.byKey(const ValueKey('draft-card-delete')));
    await tester.pump();
    expect(find.textContaining('没识别到'), findsOneWidget);
  });

  testWidgets('空态显示引导', (tester) async {
    await pumpConfirm(tester, items: const []);
    expect(find.textContaining('没识别到'), findsOneWidget);
  });

  testWidgets('保存全部后落库并显示成功 Toast', (tester) async {
    await pumpConfirm(
      tester,
      items: [
        DraftItem(
          kind: DraftKind.bill,
          title: '午餐',
          amountCents: 2500,
          amountType: DraftAmountType.expense,
          time: DateTime(2026, 6, 19),
          source: DraftSource.nl,
          confidence: 0.9,
          categoryGuess: '餐饮',
        ),
      ],
    );
    await tester.tap(find.text('保存全部 1 条'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('已保存'), findsOneWidget);
    // 验证落库
    expect((await db.billRecordDao.getAll()).length, 1);
    // Advance past Toast auto-dismiss timer.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
  });
}

class _TestPersistService extends SmartEntryPersistService {
  _TestPersistService(super.ref, this.db);

  final AppDatabase db;

  @override
  Future<DraftPersistResult> persist(List<DraftItem> items) async {
    final saved = <DraftItem>[];
    for (final item in items) {
      if (item.kind == DraftKind.bill) {
        await BillRecordRepository(db).create(
          title: item.title,
          amount: item.amountCents ?? 0,
          amountType: item.amountType == DraftAmountType.income
              ? 'income'
              : 'expense',
          billTime: item.time,
          categoryId: item.categoryId,
        );
      } else {
        await LifeItemRepository(db).create(
          title: item.title,
          amount: item.amountCents,
          amountType: item.amountType.value,
          dueTime: item.time,
          categoryId: item.categoryId,
        );
      }
      saved.add(item);
    }
    return DraftPersistResult(saved: saved, failed: const []);
  }
}
