import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// BYOK API Key 存储。Android 用 Keystore，iOS 用 Keychain。spec §8.2。
/// 不进 SQLite / shared_preferences 明文 / 备份导出。
class SecureKeyStore {
  SecureKeyStore(this._storage);

  /// 测试用：直接传入 AiConfig，不依赖原生 FlutterSecureStorage。
  SecureKeyStore.forTesting(AiConfig config)
    : _storage = null,
      _testConfig = config;

  final FlutterSecureStorage? _storage;
  AiConfig? _testConfig;

  static const _kProvider = 'smart_entry.ai.provider';
  static const _kApiKey = 'smart_entry.ai.api_key';
  static const _kModel = 'smart_entry.ai.model';
  static const _kEnabled = 'smart_entry.ai.enabled';
  static const _kAlwaysCloud = 'smart_entry.ai.always_cloud';

  Future<void> save({
    required String? provider,
    required String? apiKey,
    String? model,
    bool enabled = false,
    bool alwaysCloud = false,
  }) async {
    final s = _storage;
    if (s == null) return; // 测试模式：忽略写入
    await s.write(key: _kProvider, value: provider);
    await s.write(key: _kApiKey, value: apiKey);
    await s.write(key: _kModel, value: model);
    await s.write(key: _kEnabled, value: enabled.toString());
    await s.write(key: _kAlwaysCloud, value: alwaysCloud.toString());
  }

  Future<AiConfig> load() async {
    if (_testConfig != null) return _testConfig!;
    final s = _storage!;
    final enabled = await s.read(key: _kEnabled);
    final always = await s.read(key: _kAlwaysCloud);
    return AiConfig(
      provider: await s.read(key: _kProvider),
      apiKey: await s.read(key: _kApiKey),
      model: await s.read(key: _kModel),
      enabled: enabled == 'true',
      alwaysCloud: always == 'true',
    );
  }

  Future<void> clear() async {
    final s = _storage;
    if (s == null) return;
    await s.deleteAll();
  }
}

class AiConfig {
  const AiConfig({
    this.provider,
    this.apiKey,
    this.model,
    this.enabled = false,
    this.alwaysCloud = false,
  });

  final String? provider;
  final String? apiKey;
  final String? model;
  final bool enabled;
  final bool alwaysCloud;

  bool get isConfigured =>
      apiKey != null && apiKey!.isNotEmpty && provider != null;
}

final secureKeyStoreProvider = Provider<SecureKeyStore>((ref) {
  return SecureKeyStore(const FlutterSecureStorage());
});
