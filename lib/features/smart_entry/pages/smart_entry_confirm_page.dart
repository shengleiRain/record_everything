import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../models/draft_item.dart';
import '../providers/smart_entry_providers.dart';
import '../widgets/draft_item_card.dart';

/// 草稿确认页。所有入口解析后的唯一汇聚点。spec §7。
class SmartEntryConfirmPage extends ConsumerStatefulWidget {
  const SmartEntryConfirmPage({super.key, required this.draft});

  /// 通过路由 extra 传入。
  final EntryDraft draft;

  @override
  ConsumerState<SmartEntryConfirmPage> createState() =>
      _SmartEntryConfirmPageState();
}

class _SmartEntryConfirmPageState extends ConsumerState<SmartEntryConfirmPage> {
  late List<DraftItem> _items = List.of(widget.draft.items);
  bool _saving = false;

  void _onChanged(int i, DraftItem item) => _items[i] = item;

  void _onDelete(int i) => setState(() => _items.removeAt(i));

  Future<void> _saveAll() async {
    setState(() => _saving = true);
    final result = await ref.read(smartEntryPersistProvider).persist(_items);
    if (!mounted) return;
    setState(() => _saving = false);

    if (result.failed.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已保存 ${result.saved.length} 条')),
      );
      context.pop();
    } else {
      setState(() => _items = result.failed); // 保留失败项供重试
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('部分保存失败 ${result.failed.length} 条，请核对')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('解析结果'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _items.isEmpty || _saving ? null : _saveAll,
          ),
        ],
      ),
      body: _items.isEmpty
          ? _buildEmpty()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
              children: [
                if (widget.draft.rawInput.isNotEmpty) _SourceBanner(draft: widget.draft),
                for (var i = 0; i < _items.length; i++)
                  DraftItemCard(
                    key: ValueKey('draft-$i'),
                    item: _items[i],
                    onChanged: (item) => _onChanged(i, item),
                    onDeleted: () => _onDelete(i),
                  ),
              ],
            ),
      bottomNavigationBar: _items.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton(
                  onPressed: _saving ? null : _saveAll,
                  child: Text(_saving ? '保存中…' : '保存全部 ${_items.length} 条'),
                ),
              ),
            ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.sentiment_dissatisfied,
            size: 48,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 12),
          const Text('没识别到可记录的内容'),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => context.go('/items/new'),
            child: const Text('手动新建事项'),
          ),
        ],
      ),
    );
  }
}

class _SourceBanner extends StatelessWidget {
  const _SourceBanner({required this.draft});
  final EntryDraft draft;

  @override
  Widget build(BuildContext context) {
    final sourceLabel = const {
      DraftSource.nl: '快速输入',
      DraftSource.ocr: '识图记账',
      DraftSource.share: '来自分享',
      DraftSource.voice: '语音输入',
    }[draft.source];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '来自：$sourceLabel',
            style: const TextStyle(fontSize: 12, color: AppColors.primary),
          ),
          const SizedBox(height: 4),
          Text(draft.rawInput, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}
