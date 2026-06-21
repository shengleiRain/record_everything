import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:record_everything/core/theme/app_theme.dart';
import 'package:record_everything/l10n/generated/app_localizations.dart';
import 'package:record_everything/data/database/app_database.dart';
import 'package:record_everything/data/database/database_provider.dart';
import 'package:record_everything/features/project/pages/project_template_edit_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    // The edit page now persists an input draft via SharedPreferences with a
    // 500ms debounce. Pre-seed the mock so draft saves resolve synchronously
    // and don't stall pumpAndSettle.
    SharedPreferences.setMockInitialValues({});
  });
  for (final viewport in <Size>[const Size(360, 800), const Size(430, 932)]) {
    testWidgets(
      'template editor fits ${viewport.width.toInt()}x${viewport.height.toInt()} mobile viewport',
      (tester) async {
        await _setMobileViewport(tester, viewport);
        await _pumpTemplateEditor(tester);

        await tester.drag(
          find.byKey(const ValueKey('project-template-scroll-view')),
          const Offset(0, -360),
        );
        await tester.pumpAndSettle();

        expect(find.text('默认节点'), findsNothing);
        expect(
          find
              .byKey(const ValueKey('project-template-step-tab-button-0'))
              .hitTestable(),
          findsOneWidget,
        );
      },
    );
  }

  testWidgets('template info scrolls away and returns below pinned step tabs', (
    tester,
  ) async {
    await _setMobileViewport(tester, const Size(390, 844));
    await _pumpTemplateEditor(tester);

    expect(find.text('模板信息').hitTestable(), findsOneWidget);
    expect(find.text('默认节点'), findsNothing);
    expect(find.text('默认节点 1'), findsNothing);
    expect(find.text('下一步行动'), findsNWidgets(2));
    expect(
      find.byKey(const ValueKey('project-template-step-tabs')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('project-template-add-step')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.close), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    expect(find.text('保存模板'), findsNothing);
    final offsetInput = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const ValueKey('project-template-step-offset-field')),
        matching: find.byType(TextField),
      ),
    );
    expect(offsetInput.decoration?.helperMaxLines, 3);

    await tester.drag(
      find.byKey(const ValueKey('project-template-scroll-view')),
      const Offset(0, -360),
    );
    await tester.pumpAndSettle();

    expect(find.text('模板信息').hitTestable(), findsNothing);
    expect(
      find
          .byKey(const ValueKey('project-template-step-tab-button-0'))
          .hitTestable(),
      findsOneWidget,
    );

    await tester.drag(
      find.byKey(const ValueKey('project-template-scroll-view')),
      const Offset(0, 360),
    );
    await tester.pumpAndSettle();

    expect(find.text('模板信息').hitTestable(), findsOneWidget);
  });

  testWidgets('template node offset switches between key and creation date', (
    tester,
  ) async {
    await _setMobileViewport(tester, const Size(390, 844));
    await _pumpTemplateEditor(tester);

    expect(find.text('相对关键日期'), findsOneWidget);
    expect(find.text('相对创建日期'), findsOneWidget);

    var offsetInput = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const ValueKey('project-template-step-offset-field')),
        matching: find.byType(TextField),
      ),
    );
    expect(offsetInput.decoration?.labelText, '关键日期偏移天数');

    await tester.tap(
      find.byKey(const ValueKey('project-template-date-anchor-created')),
    );
    await tester.pumpAndSettle();

    offsetInput = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const ValueKey('project-template-step-offset-field')),
        matching: find.byType(TextField),
      ),
    );
    expect(offsetInput.decoration?.labelText, '创建日期偏移天数');
  });

  testWidgets('node content fills the remaining viewport below pinned tabs', (
    tester,
  ) async {
    await _setMobileViewport(tester, const Size(390, 844));
    await _pumpTemplateEditor(tester);

    await tester.drag(
      find.byKey(const ValueKey('project-template-scroll-view')),
      const Offset(0, -360),
    );
    await tester.pumpAndSettle();

    final tabBottom = tester
        .getBottomLeft(find.byKey(const ValueKey('project-template-step-tabs')))
        .dy;
    final bodyBottom = tester
        .getBottomLeft(
          find.byKey(const ValueKey('project-template-scroll-view')),
        )
        .dy;

    expect(bodyBottom - tabBottom, greaterThan(520));
  });

  testWidgets(
    'empty node title uses stable fallback instead of ordinal label',
    (tester) async {
      await _setMobileViewport(tester, const Size(390, 844));
      await _pumpTemplateEditor(tester);

      await tester.enterText(
        find.byKey(const ValueKey('project-template-step-title-field')),
        '',
      );
      await tester.pump();

      expect(find.text('节点 1'), findsNothing);
      expect(find.text('未命名节点'), findsOneWidget);
    },
  );

  testWidgets('node page height follows workspace minus pinned tabs', (
    tester,
  ) async {
    await _setMobileViewport(tester, const Size(390, 844));
    await _pumpTemplateEditor(tester);

    final scrollHeight = tester
        .getSize(find.byKey(const ValueKey('project-template-scroll-view')))
        .height;
    final tabHeaderHeight = tester
        .getSize(find.byKey(const ValueKey('project-template-step-tab-header')))
        .height;
    final pageView = find.byKey(
      const ValueKey('project-template-step-page-view'),
    );
    final pageHeight = tester.getSize(pageView).height;

    expect(
      pageHeight,
      moreOrLessEquals(scrollHeight - tabHeaderHeight, epsilon: 0.5),
    );

    final pageBottom = tester.getBottomLeft(pageView).dy;
    final cardBottom = tester
        .getBottomLeft(
          find.byKey(const ValueKey('project-template-step-card-frame-0')),
        )
        .dy;
    expect(pageBottom - cardBottom, lessThanOrEqualTo(80));
  });

  testWidgets('vertical drag from the node page moves the sliver header', (
    tester,
  ) async {
    await _setMobileViewport(tester, const Size(390, 844));
    await _pumpTemplateEditor(tester);

    expect(find.text('模板信息').hitTestable(), findsOneWidget);

    await tester.drag(
      find.byKey(const ValueKey('project-template-step-card-frame-0')),
      const Offset(0, -360),
    );
    await tester.pumpAndSettle();

    expect(find.text('模板信息').hitTestable(), findsNothing);

    await _dragStepPageBlankArea(tester, const Offset(0, 360));
    await tester.pumpAndSettle();

    expect(find.text('模板信息').hitTestable(), findsOneWidget);
  });

  testWidgets('step tabs shrink to content and keep add button adjacent', (
    tester,
  ) async {
    await _setMobileViewport(tester, const Size(390, 844));
    await _pumpTemplateEditor(tester);

    final firstTabLeft = tester
        .getTopLeft(
          find.byKey(const ValueKey('project-template-step-tab-button-0')),
        )
        .dx;
    final firstCardLeft = tester
        .getTopLeft(
          find.byKey(const ValueKey('project-template-step-card-frame-0')),
        )
        .dx;
    expect(firstTabLeft, moreOrLessEquals(firstCardLeft, epsilon: 0.5));

    final firstTabRight = tester
        .getTopRight(
          find.byKey(const ValueKey('project-template-step-tab-button-0')),
        )
        .dx;
    final initialAddLeft = tester
        .getTopLeft(find.byKey(const ValueKey('project-template-add-step')))
        .dx;
    expect(initialAddLeft - firstTabRight, moreOrLessEquals(8, epsilon: 0.5));

    for (var index = 0; index < 6; index++) {
      await tester.tap(find.byKey(const ValueKey('project-template-add-step')));
      await tester.pumpAndSettle();
    }

    final lastTabRight = tester
        .getTopRight(
          find.byKey(const ValueKey('project-template-step-tab-button-6')),
        )
        .dx;
    final addButtonLeft = tester
        .getTopLeft(find.byKey(const ValueKey('project-template-add-step')))
        .dx;
    expect(addButtonLeft - lastTabRight, moreOrLessEquals(8, epsilon: 0.5));
  });

  testWidgets('add button morphs between circle and pill at empty boundary', (
    tester,
  ) async {
    await _setMobileViewport(tester, const Size(390, 844));
    await _pumpTemplateEditor(tester);

    final addButton = find.byKey(const ValueKey('project-template-add-step'));
    expect(tester.getSize(addButton).width, moreOrLessEquals(44, epsilon: 0.5));
    expect(find.text('添加节点'), findsNothing);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('project-template-step-tab-button-0')),
      findsNothing,
    );
    expect(
      tester.getSize(addButton).width,
      moreOrLessEquals(112, epsilon: 0.5),
    );
    expect(find.text('添加节点'), findsOneWidget);

    await tester.tap(addButton);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('project-template-step-tab-button-0')),
      findsOneWidget,
    );
    expect(tester.getSize(addButton).width, moreOrLessEquals(44, epsilon: 0.5));
    expect(find.text('添加节点'), findsNothing);
    expect(find.text('新节点'), findsAtLeast(1));
  });

  testWidgets(
    'node card scrolls instead of overflowing when keyboard is shown',
    (tester) async {
      await _setMobileViewport(tester, const Size(390, 844));
      await _pumpTemplateEditor(tester);

      await tester.tap(
        find.byKey(const ValueKey('project-template-step-title-field')),
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 340);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      final offsetField = find.byKey(
        const ValueKey('project-template-step-offset-field'),
      );
      await tester.ensureVisible(offsetField);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(offsetField.hitTestable(), findsOneWidget);
    },
  );

  testWidgets(
    'adding a step selects the new tab and tab tap restores previous card',
    (tester) async {
      await _setMobileViewport(tester, const Size(390, 844));
      await _pumpTemplateEditor(tester);

      await tester.enterText(
        find.byKey(const ValueKey('project-template-step-title-field')),
        '第一步',
      );
      await tester.tap(find.byKey(const ValueKey('project-template-add-step')));
      await tester.pumpAndSettle();

      expect(find.text('默认节点'), findsNothing);
      expect(find.text('默认节点 2'), findsNothing);
      expect(find.text('第一步'), findsAtLeast(1));
      expect(find.text('新节点'), findsAtLeast(1));

      await tester.enterText(
        find.byKey(const ValueKey('project-template-step-title-field')),
        '第二步',
      );
      await tester.tap(
        find.byKey(const ValueKey('project-template-step-tab-button-0')),
      );
      await tester.pumpAndSettle();

      expect(find.text('第一步'), findsAtLeast(1));
      expect(find.text('第二步'), findsAtLeast(1));
    },
  );

  testWidgets('selected tab is kept fully visible after add and page swipe', (
    tester,
  ) async {
    await _setMobileViewport(tester, const Size(390, 844));
    await _pumpTemplateEditor(tester);

    for (var index = 0; index < 6; index++) {
      await tester.tap(find.byKey(const ValueKey('project-template-add-step')));
      await tester.pumpAndSettle();
    }

    expect(
      find
          .byKey(const ValueKey('project-template-step-tab-button-6'))
          .hitTestable(),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('project-template-step-tab-button-4')),
    );
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('project-template-step-tabs')),
      const Offset(500, 0),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const ValueKey('project-template-scroll-view')),
      const Offset(0, -360),
    );
    await tester.pumpAndSettle();
    await _dragStepPageBlankArea(tester, const Offset(-320, 0));
    await tester.pumpAndSettle();

    expect(
      find
          .byKey(const ValueKey('project-template-step-tab-button-5'))
          .hitTestable(),
      findsOneWidget,
    );
  });

  testWidgets('horizontal card swipe switches between node tabs', (
    tester,
  ) async {
    await _setMobileViewport(tester, const Size(390, 844));
    await _pumpTemplateEditor(tester);

    await tester.enterText(
      find.byKey(const ValueKey('project-template-step-title-field')),
      '第一步',
    );
    await tester.tap(find.byKey(const ValueKey('project-template-add-step')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('project-template-step-title-field')),
      '第二步',
    );
    await tester.drag(
      find.byKey(const ValueKey('project-template-scroll-view')),
      const Offset(0, -360),
    );
    await tester.pumpAndSettle();

    await _dragStepPageBlankArea(tester, const Offset(320, 0));
    await tester.pumpAndSettle();

    // step 1 visible: tab shows "第一步", card may also show it
    expect(find.text('第一步'), findsAtLeast(1));
    // step 2 tab also shows "第二步"
    expect(find.text('第二步'), findsAtLeast(1));

    await _dragStepPageBlankArea(tester, const Offset(-320, 0));
    await tester.pumpAndSettle();

    // step 2 now visible in PageView
    expect(find.text('第二步'), findsAtLeast(1));
    expect(find.text('第一步'), findsAtLeast(1));
  });

  testWidgets('long-press tab reorder saves in the visible tab order', (
    tester,
  ) async {
    await _setMobileViewport(tester, const Size(390, 844));
    final harness = await _pumpTemplateEditor(tester);

    await tester.enterText(
      find.byKey(const ValueKey('project-template-name-field')),
      '流程模板',
    );
    await tester.enterText(
      find.byKey(const ValueKey('project-template-step-title-field')),
      '第一步',
    );
    await tester.tap(find.byKey(const ValueKey('project-template-add-step')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('project-template-step-title-field')),
      '第二步',
    );
    await tester.tap(find.byKey(const ValueKey('project-template-add-step')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('project-template-step-title-field')),
      '第三步',
    );

    await _longPressDrag(
      tester,
      find.byKey(const ValueKey('project-template-step-tab-button-2')),
      const Offset(-420, 0),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('保存'));
    await tester.pumpAndSettle();

    final template = (await harness.database.projectTemplateDao.getAll())
        .singleWhere((template) => template.name == '流程模板');
    final steps = await harness.database.projectTemplateDao.getSteps(
      template.id,
    );

    expect(steps.map((step) => step.title), ['第三步', '第一步', '第二步']);
  });
}

class _Harness {
  const _Harness(this.database);

  final AppDatabase database;
}

Future<void> _longPressDrag(
  WidgetTester tester,
  Finder finder,
  Offset offset,
) async {
  final gesture = await tester.startGesture(tester.getCenter(finder));
  await tester.pump(const Duration(milliseconds: 650));
  await gesture.moveBy(offset);
  await tester.pump();
  await gesture.up();
}

Future<void> _dragStepPageBlankArea(WidgetTester tester, Offset offset) async {
  final pageView = find.byKey(
    const ValueKey('project-template-step-page-view'),
  );
  final box = tester.renderObject<RenderBox>(pageView);
  final visibleBottom = tester.view.physicalSize.height - 24;
  final pageBottom = box.localToGlobal(Offset(0, box.size.height)).dy - 24;
  final y = pageBottom < visibleBottom ? pageBottom : visibleBottom;
  final start = Offset(
    box.localToGlobal(Offset.zero).dx + box.size.width / 2,
    y,
  );
  await tester.flingFrom(start, offset, 1200);
}

Future<_Harness> _pumpTemplateEditor(WidgetTester tester) async {
  final database = AppDatabase.forTesting(NativeDatabase.memory());
  late final GoRouter router;
  router = GoRouter(
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
          GoRoute(
            path: ':id/edit',
            builder: (context, state) => const ProjectTemplateEditPage(),
          ),
        ],
      ),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    await database.close();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(database)],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.lightTheme(),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  unawaited(router.push<void>('/projects/templates/new'));
  await tester.pumpAndSettle();

  return _Harness(database);
}

Future<void> _setMobileViewport(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
