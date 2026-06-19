import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../models/draft_item.dart';
import '../providers/smart_entry_providers.dart';

/// 快速输入页。spec §6.1。
class SmartEntryInputPage extends ConsumerStatefulWidget {
  const SmartEntryInputPage({super.key});

  @override
  ConsumerState<SmartEntryInputPage> createState() =>
      _SmartEntryInputPageState();
}

class _SmartEntryInputPageState extends ConsumerState<SmartEntryInputPage> {
  final _controller = TextEditingController();
  bool _parsing = false;

  Future<void> _parse() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _parsing = true);
    final parser = ref.read(smartEntryParserProvider);
    final draft = await parser.parse(text, source: DraftSource.nl);
    if (!mounted) return;
    setState(() => _parsing = false);
    context.push('/smart-entry/confirm', extra: draft);
  }

  @override
  void dispose() {
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
          ],
        ),
      ),
    );
  }
}
