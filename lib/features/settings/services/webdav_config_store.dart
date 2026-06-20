import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/webdav_config.dart';

class WebDavConfigStore {
  WebDavConfigStore({
    required SharedPreferences prefs,
    required FlutterSecureStorage secureStorage,
  })  : _prefs = prefs,
        _secureStorage = secureStorage;

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secureStorage;

  static const _keyServerUrl = 'webdav.server_url';
  static const _keyUsername = 'webdav.username';
  static const _keyPassword = 'webdav.password';
  static const _keyRemotePath = 'webdav.remote_path';

  Future<WebDavConfig?> load() async {
    final serverUrl = _prefs.getString(_keyServerUrl);
    final username = _prefs.getString(_keyUsername);
    final remotePath = _prefs.getString(_keyRemotePath);
    final password = await _secureStorage.read(key: _keyPassword);

    if (serverUrl == null ||
        serverUrl.isEmpty ||
        username == null ||
        password == null) {
      return null;
    }

    return WebDavConfig(
      serverUrl: serverUrl,
      username: username,
      password: password,
      remotePath: remotePath ?? '/backups/life-items/',
    );
  }

  Future<void> save(WebDavConfig config) async {
    await _prefs.setString(_keyServerUrl, config.serverUrl);
    await _prefs.setString(_keyUsername, config.username);
    await _prefs.setString(_keyRemotePath, config.remotePath);
    await _secureStorage.write(key: _keyPassword, value: config.password);
  }

  Future<void> clear() async {
    await _prefs.remove(_keyServerUrl);
    await _prefs.remove(_keyUsername);
    await _prefs.remove(_keyRemotePath);
    await _secureStorage.delete(key: _keyPassword);
  }
}
