import 'dart:io';

import 'package:flutter/material.dart';

/// OCR 原图缩略图 + 全文折叠面板。spec §7 / §6.2。
class OcrPreviewPanel extends StatelessWidget {
  const OcrPreviewPanel({
    super.key,
    required this.imagePath,
    required this.fullText,
  });

  final String imagePath;
  final String fullText;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.file(
          File(imagePath),
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const SizedBox(
            width: 40,
            height: 40,
            child: Icon(Icons.broken_image_outlined, size: 20),
          ),
        ),
      ),
      title: const Text('识图原文', style: TextStyle(fontSize: 13)),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Align(
            alignment: Alignment.topLeft,
            child: SelectableText(
              fullText.isEmpty ? '（未识别到文字）' : fullText,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }
}
