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
    String projectStatus = 'planned',
    DateTime? startDate,
    DateTime? endDate,
    int? totalAmount,
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
      totalAmount: totalAmount,
      templateKey: templateKey,
      note: note,
    );
  }

  Future<Project> createPhotography({
    required String title,
    required String participant,
    required DateTime shootDate,
    required int totalAmount,
    String? shootType,
    int? depositAmount,
    DateTime? depositDueDate,
    int? finalPaymentAmount,
    DateTime? finalPaymentDueDate,
    String? note,
    int? projectCategoryId,
  }) {
    return _repo.createPhotographyProjectFromTemplate(
      title: title,
      participant: participant,
      shootDate: shootDate,
      totalAmount: totalAmount,
      shootType: shootType,
      depositAmount: depositAmount,
      depositDueDate: depositDueDate,
      finalPaymentAmount: finalPaymentAmount,
      finalPaymentDueDate: finalPaymentDueDate,
      note: note,
      projectCategoryId: projectCategoryId,
    );
  }

  Future<void> update(Project project) => _repo.updateProject(project);

  Future<void> delete(int id) => _repo.softDeleteProject(id);

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
