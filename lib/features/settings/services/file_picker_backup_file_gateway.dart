import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import 'backup_file_gateway.dart';

class FilePickerBackupFileGateway extends BackupFileGateway {
  FilePickerBackupFileGateway();

  @override
  Future<String?> pickBackupJson() async {
    final result = await FilePicker.pickFiles(
      dialogTitle: '选择 JSON 备份文件',
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: true,
      allowMultiple: false,
      lockParentWindow: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final bytes = result.files.single.bytes;
    if (bytes == null) return null;
    return utf8.decode(bytes);
  }

  @override
  Future<String?> saveBackupJson({
    required String fileName,
    required String content,
  }) {
    return FilePicker.saveFile(
      dialogTitle: '导出 JSON 备份',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: const ['json'],
      bytes: Uint8List.fromList(utf8.encode(content)),
      lockParentWindow: true,
    );
  }
}
