import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// OCR 服务封装。spec §6.2。
/// 用 ML Kit 端侧文字识别，输入图片文件返回全文本。
///
/// 真实识别需真机/模拟器；本类不写单测，OCR 文本→草稿的链路由
/// SmartEntryParser（含本服务产出的文本）覆盖测试。
class OcrService {
  OcrService({TextRecognizer? recognizer})
    : _recognizer = recognizer ?? TextRecognizer();

  final TextRecognizer _recognizer;

  Future<String> recognize(File image) async {
    final input = InputImage.fromFile(image);
    final result = await _recognizer.processImage(input);
    return result.text;
  }

  Future<void> dispose() => _recognizer.close();
}
