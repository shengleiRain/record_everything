import '../models/backup_file_entry.dart';

abstract class BackupFileGateway {
  Future<String?> pickBackupJson();
  Future<String?> saveBackupJson({
    required String fileName,
    required String content,
  });

  /// Lists backup files in the remote directory (WebDAV only).
  Future<List<BackupFileEntry>> listBackupFiles() async =>
      throw UnimplementedError('listBackupFiles not supported');

  /// Fetches a specific backup file's content by name (WebDAV only).
  Future<String?> fetchBackupJson(String fileName) async =>
      throw UnimplementedError('fetchBackupJson not supported');

  /// Deletes a specific backup file by name (WebDAV only).
  Future<void> deleteBackupFile(String fileName) async =>
      throw UnimplementedError('deleteBackupFile not supported');
}

class UnconfiguredBackupFileGateway extends BackupFileGateway {
  UnconfiguredBackupFileGateway();

  @override
  Future<String?> pickBackupJson() async {
    throw StateError('BackupFileGateway is not configured');
  }

  @override
  Future<String?> saveBackupJson({
    required String fileName,
    required String content,
  }) async {
    throw StateError('BackupFileGateway is not configured');
  }
}
