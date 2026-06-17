import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/database_provider.dart';
import '../../../data/repositories/project_repository.dart';

final projectRepoProvider = Provider<ProjectRepository>((ref) {
  return ProjectRepository(ref.watch(databaseProvider));
});

final projectsProvider = StreamProvider<List<Project>>((ref) {
  return ref.watch(projectRepoProvider).watchAll();
});

final projectByIdProvider = StreamProvider.family<Project, int>((ref, id) {
  return ref.watch(projectRepoProvider).watchById(id);
});

final projectsByStatusProvider = StreamProvider.family<List<Project>, String>((
  ref,
  status,
) {
  return ref.watch(projectRepoProvider).watchByStatus(status);
});

final projectsByCategoryProvider = StreamProvider.family<List<Project>, int>((
  ref,
  categoryId,
) {
  return ref.watch(projectRepoProvider).watchByCategory(categoryId);
});

final projectLifeItemsProvider = StreamProvider.family<List<LifeItem>, int>((
  ref,
  projectId,
) {
  return ref.watch(projectRepoProvider).watchProjectLifeItems(projectId);
});

final projectPaymentDuesProvider = StreamProvider.family<List<LifeItem>, int>((
  ref,
  projectId,
) {
  return ref.watch(projectRepoProvider).watchProjectPaymentDues(projectId);
});

final projectBillsProvider = StreamProvider.family<List<BillRecord>, int>((
  ref,
  projectId,
) {
  return ref.watch(projectRepoProvider).watchProjectBills(projectId);
});

final projectIncomeProvider = StreamProvider.family<int, int>((ref, projectId) {
  return ref.watch(projectRepoProvider).watchProjectIncome(projectId);
});

final projectExpenseProvider = StreamProvider.family<int, int>((
  ref,
  projectId,
) {
  return ref.watch(projectRepoProvider).watchProjectExpense(projectId);
});

final projectEventsProvider = StreamProvider.family<List<ProjectEvent>, int>((
  ref,
  projectId,
) {
  return ref.watch(projectRepoProvider).watchProjectEvents(projectId);
});

final projectTemplatesProvider = StreamProvider<List<ProjectTemplate>>((ref) {
  return ref.watch(projectRepoProvider).watchTemplates();
});

final projectTemplateStepsProvider =
    StreamProvider.family<List<ProjectTemplateStep>, int>((ref, templateId) {
      return ref.watch(projectRepoProvider).watchTemplateSteps(templateId);
    });

// UI state
final projectStatusFilterProvider = StateProvider<String?>((ref) => null);
final projectCategoryFilterProvider = StateProvider<int?>((ref) => null);

class ProjectNotifier extends Notifier<void> {
  @override
  void build() {}

  ProjectRepository get _repo => ref.read(projectRepoProvider);

  Future<Project> create({
    required String title,
    int? categoryId,
    String? participant,
    String projectStatus = 'active',
    DateTime? startDate,
    DateTime? endDate,
    String? templateKey,
    String? note,
  }) {
    return _repo.createProject(
      title: title,
      categoryId: categoryId,
      participant: participant,
      projectStatus: projectStatus,
      startDate: startDate,
      endDate: endDate,
      templateKey: templateKey,
      note: note,
    );
  }

  Future<Project> createFromTemplate({
    required int templateId,
    required String title,
    List<ProjectTemplateStepInput>? steps,
    int? categoryId,
    String? participant,
    String projectStatus = 'active',
    DateTime? startDate,
    DateTime? endDate,
    String? note,
  }) async {
    final template = await _repo.getTemplateById(templateId);
    final resolvedSteps =
        steps ??
        (await _repo.getTemplateSteps(templateId))
            .map(
              (step) => ProjectTemplateStepInput(
                title: step.title,
                itemType: step.itemType,
                amountType: step.amountType,
                amount: step.amount,
                offsetDays: step.offsetDays,
              ),
            )
            .toList(growable: false);
    return _repo.createProjectFromTemplate(
      template: template,
      steps: resolvedSteps,
      title: title,
      categoryId: categoryId,
      participant: participant,
      projectStatus: projectStatus,
      startDate: startDate,
      endDate: endDate,
      note: note,
    );
  }

  Future<ProjectTemplate> createTemplate({
    required String name,
    int? categoryId,
    String? note,
    required List<ProjectTemplateStepInput> steps,
  }) {
    return _repo.createProjectTemplate(
      name: name,
      categoryId: categoryId,
      note: note,
      steps: steps,
    );
  }

  Future<void> updateTemplate({
    required ProjectTemplate template,
    required List<ProjectTemplateStepInput> steps,
  }) {
    return _repo.updateProjectTemplate(template: template, steps: steps);
  }

  Future<void> deleteTemplate(int id) => _repo.deleteProjectTemplate(id);

  Future<void> update(Project project) => _repo.updateProject(project);

  Future<void> delete(int id) => _repo.softDeleteProject(id);

  Future<void> permanentDelete(int id) => _repo.permanentDeleteProject(id);

  Future<void> restore(int id) => _repo.restoreProject(id);

  Future<bool> hasLinkedRecords(int id) => _repo.hasLinkedRecords(id);

  Future<ProjectEvent> addEvent({
    required int projectId,
    required String eventType,
    required String title,
    String? description,
    required DateTime eventTime,
    bool isSystem = false,
  }) {
    return _repo.addEvent(
      projectId: projectId,
      eventType: eventType,
      title: title,
      description: description,
      eventTime: eventTime,
      isSystem: isSystem,
    );
  }
}

final projectNotifierProvider = NotifierProvider<ProjectNotifier, void>(
  ProjectNotifier.new,
);
