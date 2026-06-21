import 'package:record_everything/core/theme/app_theme.dart';
import 'package:record_everything/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record_everything/core/utils/toast.dart';
import 'package:record_everything/l10n/generated/app_localizations.dart';

void main() {
  group('Toast', () {
    testWidgets('shows success toast with message', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
        theme: AppTheme.lightTheme(),
        home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Toast.success(context, '操作成功'),
                child: const Text('show'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('show'));
      await tester.pump();
      expect(find.text('操作成功'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);

      // Advance past auto-dismiss timer to avoid pending timer error.
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
    });

    testWidgets('shows error toast with message', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
        theme: AppTheme.lightTheme(),
        home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Toast.error(context, '操作失败'),
                child: const Text('show'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('show'));
      await tester.pump();
      expect(find.text('操作失败'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
    });

    testWidgets('shows info toast with message', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
        theme: AppTheme.lightTheme(),
        home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Toast.info(context, '提示信息'),
                child: const Text('show'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('show'));
      await tester.pump();
      expect(find.text('提示信息'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
    });

    testWidgets('auto-dismisses after duration', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
        theme: AppTheme.lightTheme(),
        home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Toast.info(context, '将消失'),
                child: const Text('show'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('show'));
      await tester.pump();
      expect(find.text('将消失'), findsOneWidget);

      // Advance past the 2-second auto-dismiss duration.
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(find.text('将消失'), findsNothing);
    });
  });
}
