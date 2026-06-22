import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record_everything/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('英文 locale 下 appName 为 Life Items', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Text(AppLocalizations.of(context).appName),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Life Items'), findsOneWidget);
  });

  testWidgets('中文 locale 下 appName 为 生活事项', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Text(AppLocalizations.of(context).appName),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('生活事项'), findsOneWidget);
  });

  testWidgets('英文 locale 下 common_save 为 Save', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Text(AppLocalizations.of(context).common_save),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('中文 locale 下 common_save 为 保存', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Text(AppLocalizations.of(context).common_save),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('保存'), findsOneWidget);
  });
}
