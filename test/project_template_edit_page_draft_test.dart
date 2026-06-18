import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:record_everything/core/theme/app_theme.dart';
import 'package:record_everything/data/database/app_database.dart';
import 'package:record_everything/data/database/database_provider.dart';
import 'package:record_everything/features/project/pages/project_template_edit_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Widget tests covering the dirty-guard + draft behavior that was added to
/// [ProjectTemplateEditPage] in batch 5. Before this batch the page never
/// called `markDirty`, so editing and returning gave no "unsaved changes"
/// prompt; these tests pin that the guard now activates.

GoRouter _buildRouter() {
  return GoRouter(
    initialLocation: '/projects/templates',
    routes: [
      GoRoute(
        path: '/projects/templates',
        builder: (context, state) => const Scaffold(body: Text('项目模板列表')),
        routes: [
          GoRoute(
            path: 'new',
            builder: (context, state) => const ProjectTemplateEditPage(),
          ),
        ],
      ),
    ],
  );
}

Future<AppDatabase> _pumpApp(WidgetTester tester, GoRouter router) async {
  final database = AppDatabase.forTesting(NativeDatabase.memory());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(database)],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme(),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return database;
}

void main() {
  testWidgets(
    'editing the template name then backing out shows the discard guard',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(430, 932);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final router = _buildRouter();
      final database = await _pumpApp(tester, router);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        router.dispose();
        await database.close();
      });

      // Open the "new template" page.
      unawaited(router.push<void>('/projects/templates/new'));
      await tester.pumpAndSettle();
      expect(find.text('新建项目模板'), findsOneWidget);

      // Type into the name field — this must mark the form dirty.
      await tester.enterText(
        find.byKey(const ValueKey('project-template-step-title-field')),
        '我的节点',
      );
      await tester.pump();

      // Trigger a system back: the guard must block the pop and show the
      // confirmation dialog.
      await tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .maybePop();
      await tester.pumpAndSettle();

      expect(find.text('保存草稿并离开？'), findsOneWidget, reason: '编辑后返回必须弹出保存草稿提示');

      // Confirm saving the draft -> the page is actually left.
      await tester.tap(find.text('保存草稿并离开'));
      await tester.pumpAndSettle();

      expect(find.text('保存草稿并离开？'), findsNothing);
      expect(find.text('项目模板列表'), findsOneWidget, reason: '确认放弃后必须返回列表页');
    },
  );
}
