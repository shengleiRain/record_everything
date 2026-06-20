class BackupFileEntry {
  const BackupFileEntry({
    required this.fileName,
    required this.sizeBytes,
    required this.modifiedAt,
  });

  final String fileName;
  final int sizeBytes;
  final DateTime modifiedAt;

  String get displaySize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
