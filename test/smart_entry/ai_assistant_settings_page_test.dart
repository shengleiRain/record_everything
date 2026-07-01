import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record_everything/core/theme/app_theme.dart';
import 'package:record_everything/features/smart_entry/models/ai_assistant_config.dart';
import 'package:record_everything/features/smart_entry/pages/ai_assistant_settings_page.dart';
import 'package:record_everything/features/smart_entry/services/secure_key_store.dart';
import 'package:record_everything/l10n/generated/app_localizations.dart';

void main() {
  Future<void> pumpPage(WidgetTester tester, SecureKeyStore store) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [secureKeyStoreProvider.overrideWithValue(store)],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.lightTheme().copyWith(
            splashFactory: NoSplash.splashFactory,
          ),
          home: const AiAssistantSettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('显示 OpenAI 兼容配置字段和本地规则区域', (tester) async {
    final profile = AiProfileTemplate.openAiCompatible.createProfile(
      id: 'proxy',
      name: '代理',
      apiKey: 'sk-proxy',
      baseUrl: 'https://proxy.example.com/v1',
      model: 'proxy-model',
    );
    final store = SecureKeyStore.forTesting(
      AiAssistantConfig.defaults().copyWith(
        enabled: true,
        activeProfileId: profile.id,
        profiles: [...AiAssistantConfig.defaults().profiles, profile],
      ),
    );

    await pumpPage(tester, store);

    expect(find.byKey(const ValueKey('ai-profile-selector')), findsOneWidget);
    expect(find.byKey(const ValueKey('ai-base-url-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('ai-model-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('ai-api-key-field')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('本地规则'),
      320,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('本地规则'), findsOneWidget);
    expect(find.text('https://proxy.example.com/v1'), findsOneWidget);
  });

  testWidgets('新增 OpenAI 兼容配置并保存为当前配置', (tester) async {
    final store = SecureKeyStore.forTesting(AiAssistantConfig.defaults());

    await pumpPage(tester, store);
    await tester.tap(find.byKey(const ValueKey('ai-add-openai-profile')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('ai-profile-name-field')),
      '公司代理',
    );
    await tester.enterText(
      find.byKey(const ValueKey('ai-base-url-field')),
      'https://llm.example.com/v1/',
    );
    await tester.enterText(
      find.byKey(const ValueKey('ai-model-field')),
      'company-model',
    );
    await tester.enterText(
      find.byKey(const ValueKey('ai-api-key-field')),
      'sk-company',
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('ai-save-btn')),
      320,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('ai-save-btn')));
    await tester.pumpAndSettle();

    final saved = await store.loadConfig();
    expect(saved.activeProfile.providerId, AiProviderIds.openAiCompatible);
    expect(saved.activeProfile.name, '公司代理');
    expect(saved.activeProfile.baseUrl, 'https://llm.example.com/v1');
    expect(saved.activeProfile.model, 'company-model');
    expect(saved.activeProfile.apiKey, 'sk-company');
    await tester.pump(const Duration(seconds: 2));
  });
}
