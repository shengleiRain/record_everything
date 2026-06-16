import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/swipe_action_reveal.dart';
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
      appBar: AppBar(
        title: const Text('项目'),
        actions: [
          IconButton(
            tooltip: '项目模板',
            icon: const Icon(Icons.view_timeline_outlined),
            onPressed: () => context.push('/projects/templates'),
          ),
        ],
      ),
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
                child: Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: (event) =>
                      SwipeRevealController.closeIfOutside(event.position),
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
                      : _GroupedProjectList(projects: filtered),
                ),
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

class _GroupedProjectList extends ConsumerWidget {
  const _GroupedProjectList({required this.projects});

  final List<Project> projects;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<Category>>(
      future: ref.read(databaseProvider).categoryDao.getByType('project'),
      builder: (context, snapshot) {
        final categories = snapshot.data ?? const <Category>[];
        final grouped = _groupProjects(projects, categories);
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 88),
          itemCount: grouped.length,
          itemBuilder: (context, index) {
            final group = grouped[index];
            return _ProjectCategorySection(group: group);
          },
        );
      },
    );
  }

  List<_ProjectGroup> _groupProjects(
    List<Project> projects,
    List<Category> categories,
  ) {
    final categoryMap = {
      for (final category in categories) category.id: category,
    };
    final grouped = <int?, List<Project>>{};
    for (final project in projects) {
      grouped.putIfAbsent(project.categoryId, () => []).add(project);
    }

    final result = <_ProjectGroup>[];
    for (final category in categories) {
      final items = grouped.remove(category.id);
      if (items == null || items.isEmpty) continue;
      result.add(_ProjectGroup(label: category.name, projects: items));
    }
    const nullCategorySortValue = 1 << 30;
    final remainingKeys = grouped.keys.toList()
      ..sort(
        (a, b) =>
            (a ?? nullCategorySortValue).compareTo(b ?? nullCategorySortValue),
      );
    for (final key in remainingKeys) {
      final items = grouped[key] ?? const <Project>[];
      if (items.isEmpty) continue;
      result.add(
        _ProjectGroup(
          label: key == null ? '未分类' : categoryMap[key]?.name ?? '其他项目',
          projects: items,
        ),
      );
    }
    return result;
  }
}

class _ProjectCategorySection extends ConsumerWidget {
  const _ProjectCategorySection({required this.group});

  final _ProjectGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Text(
                  group.label,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${group.projects.length}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ],
            ),
          ),
          for (final project in group.projects)
            ProjectCard(
              project: project,
              onTap: () => context.push('/projects/${project.id}'),
              onEdit: () => context.push('/projects/${project.id}/edit'),
              onArchive: () => _archiveProject(context, ref, project),
              onDelete: () => _confirmDelete(context, ref, project),
            ),
        ],
      ),
    );
  }

  void _archiveProject(BuildContext context, WidgetRef ref, Project project) {
    final archived = project.copyWith(
      projectStatus: ProjectStatus.archived.value,
    );
    ref.read(projectNotifierProvider.notifier).update(archived);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已归档项目')));
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Project project) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('删除后可在回收站恢复，确认要删除这个项目吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(projectNotifierProvider.notifier).delete(project.id);
              Navigator.of(dialogContext).pop();
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

class _ProjectGroup {
  const _ProjectGroup({required this.label, required this.projects});

  final String label;
  final List<Project> projects;
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
