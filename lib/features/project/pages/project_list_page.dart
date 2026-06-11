import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/database_provider.dart';
import '../../../domain/enums/project_status.dart';
import '../providers/project_providers.dart';
import '../widgets/project_card.dart';

class ProjectListPage extends ConsumerWidget {
  const ProjectListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(projectsProvider);
    final statusFilter = ref.watch(projectStatusFilterProvider);
    final categoryFilter = ref.watch(projectCategoryFilterProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('项目')),
      body: projectsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (projects) {
          final filtered = projects.where((project) {
            final matchesStatus =
                statusFilter == null || project.projectStatus == statusFilter;
            final matchesCategory =
                categoryFilter == null || project.categoryId == categoryFilter;
            return matchesStatus && matchesCategory;
          }).toList();

          return Column(
            children: [
              _StatusFilterBar(
                selected: statusFilter,
                onChanged: (v) =>
                    ref.read(projectStatusFilterProvider.notifier).state = v,
              ),
              _CategoryFilterBar(
                selected: categoryFilter,
                onChanged: (v) =>
                    ref.read(projectCategoryFilterProvider.notifier).state = v,
              ),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.folder_outlined,
                              size: 64,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              statusFilter == null && categoryFilter == null
                                  ? '还没有项目'
                                  : '没有符合条件的项目',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '点击右下角按钮创建第一个项目',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      )
                    : _ProjectListWithIncome(projects: filtered),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/projects/new'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _ProjectListWithIncome extends ConsumerWidget {
  const _ProjectListWithIncome({required this.projects});
  final List<Project> projects;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: projects.length,
      itemBuilder: (context, index) {
        final project = projects[index];
        return _ProjectCardWithIncome(project: project);
      },
    );
  }
}

class _ProjectCardWithIncome extends ConsumerWidget {
  const _ProjectCardWithIncome({required this.project});
  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incomeAsync = ref.watch(projectIncomeProvider(project.id));

    return ProjectCard(
      project: project,
      incomeReceived: incomeAsync.valueOrNull ?? 0,
      onTap: () => context.push('/projects/${project.id}'),
    );
  }
}

class _StatusFilterBar extends StatelessWidget {
  const _StatusFilterBar({required this.selected, required this.onChanged});

  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          _chip(context, null, '全部'),
          ...ProjectStatus.values.map((s) => _chip(context, s.value, s.label)),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String? value, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected == value,
        onSelected: (_) => onChanged(value),
        showCheckmark: false,
      ),
    );
  }
}

class _CategoryFilterBar extends ConsumerWidget {
  const _CategoryFilterBar({required this.selected, required this.onChanged});

  final int? selected;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<Category>>(
      future: ref.read(databaseProvider).categoryDao.getByType('project'),
      builder: (context, snapshot) {
        final categories = snapshot.data ?? const <Category>[];
        if (categories.isEmpty) return const SizedBox.shrink();
        return SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            children: [
              _chip(context, null, '全部类型'),
              ...categories.map(
                (category) => _chip(context, category.id, category.name),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _chip(BuildContext context, int? value, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected == value,
        onSelected: (_) => onChanged(value),
        showCheckmark: false,
      ),
    );
  }
}
