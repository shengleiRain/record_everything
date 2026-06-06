import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record_everything/core/theme/app_theme.dart';
import 'package:record_everything/data/database/app_database.dart';
import 'package:record_everything/features/settings/pages/category_management_page.dart';
import 'package:record_everything/features/settings/pages/data_safety_page.dart';
import 'package:record_everything/features/settings/pages/settings_page.dart';
import 'package:record_everything/features/settings/providers/settings_providers.dart';

import 'helpers/test_app.dart';

void main() {
  testWidgets('settings lists category and data safety entries', (
    tester,
  ) async {
    await pumpPageWithDatabase(tester, const SettingsPage());

    expect(find.text('分类管理'), findsOneWidget);
    expect(find.text('数据安全'), findsOneWidget);
    expect(find.text('导入数据'), findsOneWidget);
    expect(find.text('导出备份'), findsOneWidget);
  });

  testWidgets('category management page exposes add action', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoriesProvider.overrideWith(
            (ref) => Stream.value(const [
              Category(
                id: 1,
                name: '餐饮',
                type: 'expense',
                icon: 'restaurant',
                isDefault: true,
              ),
            ]),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme(),
          home: const CategoryManagementPage(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('分类管理'), findsWidgets);
    expect(find.text('新增分类'), findsOneWidget);
    expect(find.text('支出'), findsOneWidget);
    expect(find.text('收入'), findsOneWidget);
    expect(find.text('事项'), findsOneWidget);
  });

  testWidgets('data safety page exposes file import and export actions', (
    tester,
  ) async {
    await pumpPageWithDatabase(tester, const DataSafetyPage());

    expect(find.text('数据安全'), findsWidgets);
    expect(find.text('导出备份'), findsOneWidget);
    expect(find.text('导入备份'), findsOneWidget);
  });
}
