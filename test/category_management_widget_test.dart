import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record_everything/core/theme/app_theme.dart';
import 'package:record_everything/data/database/app_database.dart';
import 'package:record_everything/features/settings/pages/category_management_page.dart';
import 'package:record_everything/features/settings/providers/settings_providers.dart';

void main() {
  testWidgets('category rows render configured material icons', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoriesProvider.overrideWith(
            (ref) => Stream.value([
              Category(
                id: 1,
                name: '咖啡',
                type: 'expense',
                icon: 'local_cafe',
                isDefault: false,
                isHidden: false,
                isPinned: false,
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

    expect(find.text('咖啡'), findsOneWidget);
    expect(find.byIcon(Icons.local_cafe_outlined), findsOneWidget);
  });

  testWidgets('category dialog previews a selected real icon', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoriesProvider.overrideWith((ref) => Stream.value(const [])),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme(),
          home: const CategoryManagementPage(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(const ValueKey('add-category')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('选择图标'), findsOneWidget);
    expect(find.byIcon(Icons.category_outlined), findsWidgets);

    await tester.enterText(
      find.byKey(const ValueKey('category-name-field')),
      '咖啡',
    );
    await tester.tap(
      find.byKey(const ValueKey('category-icon-option-local_cafe')),
    );
    await tester.pump();

    expect(find.text('咖啡'), findsWidgets);
    expect(find.byIcon(Icons.local_cafe_outlined), findsWidgets);
  });
}
