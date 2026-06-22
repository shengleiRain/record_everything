import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record_everything/core/theme/app_theme.dart';
import 'package:record_everything/l10n/generated/app_localizations.dart';

/// 黄金图测试：验证关键页面在浅色/深色主题下的视觉回归。spec §7.1 第四层。
///
/// 首次运行：flutter test --update-goldens test/golden/
/// 后续运行：flutter test test/golden/（对比基线）
void main() {
  group('settings page golden', () {
    testWidgets('浅色主题', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme(),
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            appBar: AppBar(title: const Text('设置')),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.lightTheme().colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.lightTheme().dividerTheme.color ??
                          Colors.grey.shade200,
                    ),
                  ),
                  child: const Text('设置项示例'),
                ),
              ],
            ),
          ),
          debugShowCheckedModeBanner: false,
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/settings_light.png'),
      );
    });

    testWidgets('深色主题', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme(),
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            appBar: AppBar(title: const Text('设置')),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.darkTheme().colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.darkTheme().dividerTheme.color ??
                          Colors.grey.shade800,
                    ),
                  ),
                  child: const Text('设置项示例'),
                ),
              ],
            ),
          ),
          debugShowCheckedModeBanner: false,
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/settings_dark.png'),
      );
    });
  });

  group('card golden', () {
    testWidgets('浅色主题卡片', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme(),
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '测试卡片标题',
                        style: AppTheme.lightTheme().textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '这是卡片内容文字',
                        style: AppTheme.lightTheme().textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          debugShowCheckedModeBanner: false,
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/card_light.png'),
      );
    });

    testWidgets('深色主题卡片', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme(),
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '测试卡片标题',
                        style: AppTheme.darkTheme().textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '这是卡片内容文字',
                        style: AppTheme.darkTheme().textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          debugShowCheckedModeBanner: false,
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/card_dark.png'),
      );
    });
  });
}
