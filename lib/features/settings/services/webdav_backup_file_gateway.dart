import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;

import '../models/backup_file_entry.dart';
import '../models/webdav_config.dart';
import 'backup_file_gateway.dart';

class WebDavBackupFileGateway implements BackupFileGateway {
  WebDavBackupFileGateway(this._config) : _client = _createClient(_config);

  final WebDavConfig _config;
  final webdav.Client _client;

  static webdav.Client _createClient(WebDavConfig config) {
    return webdav.newClient(
      config.baseUrl,
      user: config.username,
      password: config.password,
    );
  }

  @override
  Future<String?> pickBackupJson() async {
    throw UnimplementedError('Use listBackupFiles + fetchBackupJson instead');
  }

  @override
  Future<String?> saveBackupJson({
    required String fileName,
    required String content,
  }) async {
    await _ensureRemoteDir();

    // Write to temp file then upload
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/$fileName');
    await tempFile.writeAsString(content, encoding: utf8);

    try {
      final remotePath = '${_config.normalizedPath}/$fileName';
      await _client.writeFromFile(tempFile.path, remotePath);
      return remotePath;
    } finally {
      if (await tempFile.exists()) await tempFile.delete();
    }
  }

  @override
  Future<List<BackupFileEntry>> listBackupFiles() async {
    try {
      await _ensureRemoteDir();
      final files = await _client.readDir(_config.normalizedPath);
      return files
          .where((f) => f.name != null && f.name!.endsWith('.json'))
          .map(
            (f) => BackupFileEntry(
              fileName: f.name ?? '',
              sizeBytes: f.size ?? 0,
              modifiedAt: f.mTime ?? DateTime.now(),
            ),
          )
          .toList()
        ..sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    } catch (e) {
      throw Exception('无法列出备份文件: $e');
    }
  }

  @override
  Future<String?> fetchBackupJson(String fileName) async {
    try {
      final remotePath = '${_config.normalizedPath}/$fileName';
      final bytes = await _client.read(remotePath);
      return utf8.decode(bytes);
    } catch (e) {
      throw Exception('无法下载备份文件: $e');
    }
  }

  @override
  Future<void> deleteBackupFile(String fileName) async {
    try {
      final remotePath = '${_config.normalizedPath}/$fileName';
      await _client.remove(remotePath);
    } catch (e) {
      throw Exception('无法删除备份文件: $e');
    }
  }

  /// Ensures the remote directory exists, creating it recursively if needed.
  Future<void> _ensureRemoteDir() async {
    try {
      await _client.readDir(_config.normalizedPath);
    } catch (_) {
      await _client.mkdirAll(_config.normalizedPath);
    }
  }
}
