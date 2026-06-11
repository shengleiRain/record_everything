import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/database/app_database.dart';
import '../bill/providers/bill_providers.dart';
import '../life_item/providers/life_item_providers.dart';
import '../project/providers/project_providers.dart';
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
    final projects = ref.watch(projectsProvider).valueOrNull ?? const [];

    return Scaffold(
      appBar: AppBar(title: const Text('搜索')),
      body: StreamBuilder<List<BillRecord>>(
        stream: bills,
        builder: (context, snapshot) {
          final results = SearchService.search(
            query: _query,
            lifeItems: lifeItems,
            billRecords: snapshot.data ?? const [],
            projects: projects,
          );
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              TextField(
                controller: _controller,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '搜索事项、账单和项目',
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
                          : result.kind == SearchResultKind.project
                              ? Icons.folder_outlined
                              : Icons.receipt_long,
                    ),
                    title: Text(result.title),
                    subtitle: Text(result.subtitle),
                    onTap: () {
                      if (result.kind == SearchResultKind.lifeItem) {
                        context.push('/items/${result.id}');
                      } else if (result.kind == SearchResultKind.project) {
                        context.push('/projects/${result.id}');
                      } else {
                        context.push('/bills/${result.id}/edit');
                      }
                    },
                  ),
            ],
          );
        },
      ),
    );
  }
}
