import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:record_everything/core/theme/app_theme.dart';
import 'package:record_everything/data/database/app_database.dart';
import 'package:record_everything/data/database/database_provider.dart';
import 'package:record_everything/features/bill/pages/bill_edit_page.dart';
import 'package:record_everything/features/bill/pages/bill_list_page.dart';
import 'package:record_everything/features/home/pages/home_page.dart';
import 'package:record_everything/features/life_item/pages/life_item_detail_page.dart';
import 'package:record_everything/features/life_item/pages/life_item_edit_page.dart';
import 'package:record_everything/features/life_item/pages/life_item_list_page.dart';
import 'package:record_everything/features/settings/pages/settings_page.dart';
import 'package:record_everything/features/statistics/pages/statistics_page.dart';

class TestAppHarness {
  TestAppHarness._(this.database, this.widget);

  final AppDatabase database;
  final Widget widget;
}

Future<TestAppHarness> pumpPageWithDatabase(
  WidgetTester tester,
  Widget page,
) async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);

  final widget = ProviderScope(
    overrides: [databaseProvider.overrideWithValue(db)],
    child: MaterialApp(theme: AppTheme.lightTheme(), home: page),
  );
  await tester.pumpWidget(widget);
  await tester.pump(const Duration(milliseconds: 100));

  return TestAppHarness._(db, widget);
}

TestAppHarness createTestApp() {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  final router = _createTestRouter();

  return TestAppHarness._(
    db,
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp.router(
        title: '生活事项',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme(),
        routerConfig: router,
      ),
    ),
  );
}

GoRouter _createTestRouter() {
  return GoRouter(
    initialLocation: '/home',
    routes: [
      ShellRoute(
        builder: (context, state, child) => Scaffold(
          body: child,
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex(state),
            onTap: (index) {
              context.go(
                [
                  '/home',
                  '/items',
                  '/bills',
                  '/statistics',
                  '/settings',
                ][index],
              );
            },
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: '首页',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.check_circle_outline),
                activeIcon: Icon(Icons.check_circle),
                label: '事项',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.receipt_long_outlined),
                activeIcon: Icon(Icons.receipt_long),
                label: '账单',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.bar_chart_outlined),
                activeIcon: Icon(Icons.bar_chart),
                label: '统计',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.settings_outlined),
                activeIcon: Icon(Icons.settings),
                label: '设置',
              ),
            ],
          ),
        ),
        routes: [
          GoRoute(path: '/home', builder: (context, state) => const HomePage()),
          GoRoute(
            path: '/items',
            builder: (context, state) => const LifeItemListPage(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (context, state) => const LifeItemEditPage(),
              ),
              GoRoute(
                path: ':id',
                builder: (context, state) => const LifeItemDetailPage(),
              ),
              GoRoute(
                path: ':id/edit',
                builder: (context, state) => const LifeItemEditPage(),
              ),
            ],
          ),
          GoRoute(
            path: '/bills',
            builder: (context, state) => const BillListPage(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (context, state) => const BillEditPage(),
              ),
              GoRoute(
                path: ':id/edit',
                builder: (context, state) => const BillEditPage(),
              ),
            ],
          ),
          GoRoute(
            path: '/statistics',
            builder: (context, state) => const StatisticsPage(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsPage(),
          ),
        ],
      ),
    ],
  );
}

int _currentIndex(GoRouterState state) {
  final path = state.uri.path;
  if (path.startsWith('/bills')) return 2;
  if (path.startsWith('/statistics')) return 3;
  if (path.startsWith('/settings')) return 4;
  if (path.startsWith('/items')) return 1;
  return 0;
}

Future<TestAppHarness> pumpTestApp(WidgetTester tester) async {
  final harness = createTestApp();
  addTearDown(harness.database.close);

  await tester.pumpWidget(harness.widget);
  await tester.pump(const Duration(milliseconds: 100));
  return harness;
}

Future<void> settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pumpAndSettle();
}

Future<void> tapByKey(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await settle(tester);
}

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.tap(find.text(text).last);
  await settle(tester);
}
