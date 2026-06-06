abstract class BackupFileGateway {
  Future<String?> pickBackupJson();
  Future<String?> saveBackupJson({
    required String fileName,
    required String content,
  });
}

class UnconfiguredBackupFileGateway implements BackupFileGateway {
  const UnconfiguredBackupFileGateway();

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
