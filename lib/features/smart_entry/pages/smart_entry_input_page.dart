import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../core/theme/app_colors.dart';
import '../models/draft_item.dart';
import '../providers/smart_entry_providers.dart';
import '../services/ocr_service.dart';

/// 快速输入页。spec §6.1。
class SmartEntryInputPage extends ConsumerStatefulWidget {
  const SmartEntryInputPage({super.key});

  @override
  ConsumerState<SmartEntryInputPage> createState() =>
      _SmartEntryInputPageState();
}

class _SmartEntryInputPageState extends ConsumerState<SmartEntryInputPage> {
  final _controller = TextEditingController();
  final _ocr = OcrService();
  final _speech = SpeechToText();
  bool _parsing = false;
  bool _speechAvailable = false;

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize();
  }

  Future<void> _listen() async {
    if (!_speechAvailable) {
      await _initSpeech();
    }
    if (!_speechAvailable) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('设备不支持语音输入，请用键盘的麦克风')),
      );
      return;
    }
    await _speech.listen(
      onResult: (r) {
        if (r.finalResult) {
          _controller.text = _controller.text + r.recognizedWords;
        }
      },
      localeId: 'zh_CN',
    );
  }

  Future<void> _parse() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _parsing = true);
    final parser = await ref.read(smartEntryParserProvider.future);
    final draft = await parser.parse(text, source: DraftSource.nl);
    if (!mounted) return;
    setState(() => _parsing = false);
    context.push('/smart-entry/confirm', extra: draft);
  }

  Future<void> _pickAndRecognize() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery);
    if (xfile == null) return;
    setState(() => _parsing = true);
    try {
      final text = await _ocr.recognize(File(xfile.path));
      if (!mounted) return;
      final parser = await ref.read(smartEntryParserProvider.future);
      final draft = await parser.parse(
        text,
        source: DraftSource.ocr,
        ocrFullText: text,
      );
      if (!mounted) return;
      setState(() => _parsing = false);
      context.push('/smart-entry/confirm', extra: draft);
    } catch (_) {
      if (!mounted) return;
      setState(() => _parsing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('识别失败，请重试或换个清晰的图片')),
      );
    }
  }

  @override
  void dispose() {
    _ocr.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('智能输入')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '试着用一句话描述，例如：',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            const Text('“明天3点开会，午餐花了25”'),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('smart-entry-input-field'),
              controller: _controller,
              minLines: 3,
              maxLines: 6,
              autofocus: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '输入要记录的事项或账单…',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const ValueKey('smart-entry-parse-btn'),
              icon: const Icon(Icons.auto_awesome),
              label: Text(_parsing ? '解析中…' : '解析'),
              onPressed: _parsing ? null : _parse,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const ValueKey('smart-entry-ocr-btn'),
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('拍照 / 选图记账'),
              onPressed: _parsing ? null : _pickAndRecognize,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const ValueKey('smart-entry-voice-btn'),
              icon: const Icon(Icons.mic_none_rounded),
              label: const Text('语音输入'),
              onPressed: _listen,
            ),
          ],
        ),
      ),
    );
  }
}
