import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:record_everything/features/settings/providers/settings_providers.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    sharedPrefsInstance = null; // Reset global state between tests
    await initSharedPrefs();
  });

  group('ThemeModeNotifier', () {
    test('默认为 ThemeMode.system', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(themeModeProvider), ThemeMode.system);
    });

    test('set 后持久化并更新 state', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(themeModeProvider.notifier).set(ThemeMode.dark);
      expect(container.read(themeModeProvider), ThemeMode.dark);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_theme_mode'), 'dark');
    });

    test('已保存的值在重建时恢复', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_theme_mode', 'light');
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(themeModeProvider), ThemeMode.light);
    });
  });

  group('LocaleNotifier', () {
    test('默认跟随系统', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final locale = container.read(localeProvider);
      expect(['zh', 'en'], contains(locale.languageCode));
    });

    test('set(en) 持久化并更新 state', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(localeProvider.notifier).set(const Locale('en'));
      expect(container.read(localeProvider).languageCode, 'en');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_locale'), 'en');
    });

    test('followSystem 清除持久化', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_locale', 'en');
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(localeProvider.notifier).followSystem();
      expect(prefs.getString('app_locale'), isNull);
      expect(container.read(localeProvider.notifier).isFollowingSystem, true);
    });
  });
}
