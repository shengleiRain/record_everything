import 'package:flutter_test/flutter_test.dart';
import 'package:record_everything/features/smart_entry/models/ai_assistant_config.dart';
import 'package:record_everything/features/smart_entry/services/secure_key_store.dart';

void main() {
  group('AiAssistantConfig', () {
    test('defaults keep only Zhipu and DeepSeek built-in profiles', () {
      final config = AiAssistantConfig.defaults();

      expect(config.profiles.map((profile) => profile.providerId), [
        AiProviderIds.zhipu,
        AiProviderIds.deepSeek,
      ]);
      expect(config.activeProfile.providerId, AiProviderIds.zhipu);
      expect(
        config.profiles.any(
          (profile) => profile.providerId == AiProviderIds.qwen,
        ),
        isFalse,
      );
      expect(
        config.profiles.any(
          (profile) => profile.providerId == AiProviderIds.openAiCompatible,
        ),
        isFalse,
      );
    });

    test('creates OpenAI-compatible profile with common editable fields', () {
      final profile = AiProfileTemplate.openAiCompatible.createProfile(
        id: 'work-openai',
        name: '工作代理',
        apiKey: 'sk-work',
        baseUrl: 'https://proxy.example.com/v1/',
        model: 'gpt-compatible',
      );

      expect(profile.providerId, AiProviderIds.openAiCompatible);
      expect(profile.name, '工作代理');
      expect(profile.apiKey, 'sk-work');
      expect(profile.baseUrl, 'https://proxy.example.com/v1');
      expect(profile.model, 'gpt-compatible');
      expect(
        profile.chatCompletionsUri.toString(),
        'https://proxy.example.com/v1/chat/completions',
      );
    });

    test('round trips multiple profiles and active selection through json', () {
      final custom = AiProfileTemplate.openAiCompatible.createProfile(
        id: 'custom-1',
        name: 'OpenAI 兼容',
        apiKey: 'sk-custom',
        baseUrl: 'https://llm.example.com/v1',
        model: 'custom-model',
      );
      final config = AiAssistantConfig.defaults().copyWith(
        enabled: true,
        alwaysCloud: true,
        activeProfileId: custom.id,
        profiles: [...AiAssistantConfig.defaults().profiles, custom],
      );

      final restored = AiAssistantConfig.fromJson(config.toJson());

      expect(restored.enabled, isTrue);
      expect(restored.alwaysCloud, isTrue);
      expect(restored.activeProfile.id, 'custom-1');
      expect(restored.activeProfile.baseUrl, 'https://llm.example.com/v1');
      expect(restored.activeProfile.model, 'custom-model');
    });

    test('migrates legacy single provider config into an active profile', () {
      final migrated = AiAssistantConfig.fromLegacy(
        provider: 'deepseek',
        apiKey: 'sk-old',
        model: 'deepseek-chat',
        enabled: true,
        alwaysCloud: false,
      );

      expect(migrated.enabled, isTrue);
      expect(migrated.activeProfile.providerId, AiProviderIds.deepSeek);
      expect(migrated.activeProfile.apiKey, 'sk-old');
      expect(migrated.activeProfile.model, 'deepseek-chat');
    });
  });

  group('SecureKeyStore', () {
    test('forTesting loads and saves versioned AI assistant config', () async {
      final store = SecureKeyStore.forTesting(AiAssistantConfig.defaults());
      final custom = AiProfileTemplate.openAiCompatible.createProfile(
        id: 'custom',
        name: '代理',
        apiKey: 'sk-custom',
        baseUrl: 'https://proxy.example.com/v1',
        model: 'custom-model',
      );

      await store.saveConfig(
        AiAssistantConfig.defaults().copyWith(
          enabled: true,
          activeProfileId: custom.id,
          profiles: [...AiAssistantConfig.defaults().profiles, custom],
        ),
      );
      final loaded = await store.loadConfig();

      expect(loaded.enabled, isTrue);
      expect(loaded.activeProfile.id, 'custom');
      expect(loaded.activeProfile.apiKey, 'sk-custom');
    });
  });
}
