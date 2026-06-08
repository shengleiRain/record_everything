import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/database/app_database.dart';
import '../bill/providers/bill_providers.dart';
import '../life_item/providers/life_item_providers.dart';
import 'search_service.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lifeItems = ref.watch(lifeItemsProvider).valueOrNull ?? const [];
    final bills = ref.watch(billRepoProvider).watchAll();

    return Scaffold(
      appBar: AppBar(title: const Text('搜索')),
      body: StreamBuilder<List<BillRecord>>(
        stream: bills,
        builder: (context, snapshot) {
          final results = SearchService.search(
            query: _query,
            lifeItems: lifeItems,
            billRecords: snapshot.data ?? const [],
          );
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              TextField(
                controller: _controller,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '搜索事项和账单',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 12),
              if (_query.trim().isEmpty)
                const Center(child: Text('输入关键词开始搜索'))
              else if (results.isEmpty)
                const Center(child: Text('没有匹配结果'))
              else
                for (final result in results)
                  ListTile(
                    leading: Icon(
                      result.kind == SearchResultKind.lifeItem
                          ? Icons.event_note
                          : Icons.receipt_long,
                    ),
                    title: Text(result.title),
                    subtitle: Text(result.subtitle),
                    onTap: () => result.kind == SearchResultKind.lifeItem
                        ? context.push('/items/${result.id}')
                        : context.push('/bills/${result.id}/edit'),
                  ),
            ],
          );
        },
      ),
    );
  }
}
