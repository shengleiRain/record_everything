import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../database/daos/bill_record_dao.dart';
import '../../domain/enums/project_event_type.dart';
import '../../domain/enums/project_status.dart';

const String projectDateAnchorKeyDate = 'keyDate';
const String projectDateAnchorCreatedDate = 'createdDate';

class ProjectTemplateStepInput {
  const ProjectTemplateStepInput({
    required this.title,
    required this.amountType,
    this.amount,
    int? offsetDays,
    int? keyDateOffsetDays,
    this.createdDateOffsetDays,
    this.absoluteDueTime,
  }) : assert(
         (keyDateOffsetDays == null ? 0 : 1) +
                 (createdDateOffsetDays == null ? 0 : 1) +
                 (absoluteDueTime == null ? 0 : 1) <=
             1,
         'Only one date rule can be set for a project step.',
       ),
       keyDateOffsetDays =
           keyDateOffsetDays ??
           (createdDateOffsetDays == null && absoluteDueTime == null
               ? (offsetDays ?? 0)
               : null);

  factory ProjectTemplateStepInput.fromTemplateStep(ProjectTemplateStep step) {
    final createdOffset = step.createdDateOffsetDays;
    return ProjectTemplateStepInput(
      title: step.title,
      amountType: step.amountType,
      amount: step.amount,
      keyDateOffsetDays: createdOffset == null
          ? (step.keyDateOffsetDays ?? step.offsetDays)
          : null,
      createdDateOffsetDays: createdOffset,
    );
  }

  final String title;
  final String amountType;
  final int? keyDateOffsetDays;
  final int? createdDateOffsetDays;
  final DateTime? absoluteDueTime;
  final int? amount;

  int get offsetDays => keyDateOffsetDays ?? createdDateOffsetDays ?? 0;

  String? get projectDateAnchor {
    if (keyDateOffsetDays != null) return projectDateAnchorKeyDate;
    if (createdDateOffsetDays != null) return projectDateAnchorCreatedDate;
    return null;
  }

  int? get projectDateOffsetDays => keyDateOffsetDays ?? createdDateOffsetDays;

  DateTime resolveDueTime({
    required DateTime? keyDate,
    required DateTime createdAt,
  }) {
    final absolute = absoluteDueTime;
    if (absolute != null) return _dateOnly(absolute);
    final keyOffset = keyDateOffsetDays;
    if (keyOffset != null) {
      return _dateOnly(keyDate ?? createdAt).add(Duration(days: keyOffset));
    }
    final createdOffset = createdDateOffsetDays;
    if (createdOffset != null) {
      return _dateOnly(createdAt).add(Duration(days: createdOffset));
    }
    return _dateOnly(keyDate ?? createdAt);
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}

class ProjectRepository {
  final AppDatabase _db;
  ProjectRepository(this._db);

  // --- Project CRUD ---

  Stream<List<Project>> watchAll() => _db.projectDao.watchAll();

  Stream<List<Project>> watchByStatus(String status) =>
      _db.projectDao.watchByStatus(status);

  Stream<List<Project>> watchByCategory(int categoryId) =>
      _db.projectDao.watchByCategory(categoryId);

  Stream<List<Project>> watchBetweenKeyDate(DateTime start, DateTime end) =>
      _db.projectDao.watchBetweenKeyDate(start, end);

  Stream<Project> watchById(int id) => _db.projectDao.watchById(id);

  Future<Project> getById(int id) => _db.projectDao.getById(id);

  Future<Project> createProject({
    required String title,
    int? categoryId,
    String? participant,
    String projectStatus = 'active',
    DateTime? startDate,
    DateTime? endDate,
    int? totalAmount,
    String? templateKey,
    String? note,
  }) async {
    final project = await _db.projectDao.insertOne(
      ProjectsCompanion.insert(
        title: title,
        categoryId: Value(categoryId),
        participant: Value(participant),
        projectStatus: Value(projectStatus),
        startDate: Value(startDate),
        endDate: Value(endDate),
        totalAmount: Value(totalAmount),
        templateKey: Value(templateKey),
        note: Value(note),
      ),
    );
    await _markCategoryUsed(categoryId);
    return project;
  }

  Future<Project> createProjectWithSteps({
    required String title,
    required List<ProjectTemplateStepInput> steps,
    int? categoryId,
    String? participant,
    String projectStatus = 'active',
    DateTime? startDate,
    DateTime? endDate,
    int? totalAmount,
    String? templateKey,
    String? note,
  }) async {
    final project = await createProject(
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
    await _createProjectLifeItems(project: project, steps: steps);
    return project;
  }

  Future<void> updateProject(Project project) async {
    final previous = await _db.projectDao.getById(project.id);
    final shouldRecalculateKeyDateItems = !_sameDate(
      previous.startDate,
      project.startDate,
    );
    await _db.projectDao.updateOne(
      ProjectsCompanion(
        id: Value(project.id),
        title: Value(project.title),
        categoryId: Value(project.categoryId),
        participant: Value(project.participant),
        projectStatus: Value(project.projectStatus),
        startDate: Value(project.startDate),
        endDate: Value(project.endDate),
        totalAmount: Value(project.totalAmount),
        templateKey: Value(project.templateKey),
        note: Value(project.note),
        createdAt: Value(project.createdAt),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await _markCategoryUsed(project.categoryId);
    if (shouldRecalculateKeyDateItems) {
      await _recalculateKeyDateLifeItems(project);
    }
  }

  Future<Project> changeStatus(Project project, ProjectStatus next) async {
    final previous = ProjectStatus.fromString(project.projectStatus);
    if (!previous.canTransitionTo(next)) {
      throw StateError(
        'Invalid project status transition: ${previous.value} -> ${next.value}',
      );
    }
    final now = DateTime.now();
    final updated = project.copyWith(projectStatus: next.value, updatedAt: now);
    await updateProject(updated);
    await addEvent(
      projectId: project.id,
      eventType: ProjectEventType.statusChange.value,
      title: '状态变更: ${previous.label} -> ${next.label}',
      description: '项目状态从 ${previous.label} 变为 ${next.label}',
      eventTime: now,
      isSystem: true,
    );
    return updated;
  }

  Future<void> softDeleteProject(int id) => _db.projectDao.softDeleteById(id);

  Future<void> permanentDeleteProject(int id) => _db.projectDao.deleteById(id);

  Future<void> restoreProject(int id) => _db.projectDao.restoreById(id);

  Future<bool> hasLinkedRecords(int id) => _db.projectDao.hasLinkedRecords(id);

  // --- Project templates ---

  Stream<List<ProjectTemplate>> watchTemplates() =>
      _db.projectTemplateDao.watchAll();

  Future<ProjectTemplate> getTemplateById(int id) =>
      _db.projectTemplateDao.getById(id);

  Future<ProjectTemplate?> getTemplateByKey(String templateKey) =>
      _db.projectTemplateDao.getByTemplateKey(templateKey);

  Future<List<ProjectTemplateStep>> getTemplateSteps(int templateId) =>
      _db.projectTemplateDao.getSteps(templateId);

  Stream<List<ProjectTemplateStep>> watchTemplateSteps(int templateId) =>
      _db.projectTemplateDao.watchSteps(templateId);

  Future<ProjectTemplate> createProjectTemplate({
    required String name,
    int? categoryId,
    String? note,
    bool isDefault = false,
    required List<ProjectTemplateStepInput> steps,
  }) async {
    final template = await _db.projectTemplateDao.insertTemplate(
      ProjectTemplatesCompanion.insert(
        name: name,
        categoryId: Value(categoryId),
        note: Value(note),
        isDefault: Value(isDefault),
      ),
    );
    await _replaceTemplateSteps(template.id, steps);
    return template;
  }

  Future<void> updateProjectTemplate({
    required ProjectTemplate template,
    required List<ProjectTemplateStepInput> steps,
  }) async {
    await _db.projectTemplateDao.updateTemplate(
      ProjectTemplatesCompanion(
        id: Value(template.id),
        name: Value(template.name),
        templateKey: Value(template.templateKey),
        categoryId: Value(template.categoryId),
        note: Value(template.note),
        isDefault: Value(template.isDefault),
        createdAt: Value(template.createdAt),
        updatedAt: Value(DateTime.now()),
        deletedAt: Value(template.deletedAt),
      ),
    );
    await _replaceTemplateSteps(template.id, steps);
  }

  Future<void> deleteProjectTemplate(int id) =>
      _db.projectTemplateDao.softDeleteTemplate(id);

  Future<Project> createProjectFromTemplate({
    required ProjectTemplate template,
    required List<ProjectTemplateStepInput> steps,
    required String title,
    int? categoryId,
    String? participant,
    String projectStatus = 'active',
    DateTime? startDate,
    DateTime? endDate,
    int? totalAmount,
    String? note,
  }) async {
    final project = await createProject(
      title: title,
      categoryId: categoryId ?? template.categoryId,
      participant: participant,
      projectStatus: projectStatus,
      startDate: startDate,
      endDate: endDate,
      totalAmount: totalAmount,
      templateKey: template.templateKey ?? 'custom:${template.id}',
      note: _mergeTemplateNote(template.note, note),
    );

    await _createProjectLifeItems(project: project, steps: steps);
    return project;
  }

  // --- Project Events ---

  Stream<List<ProjectEvent>> watchProjectEvents(int projectId) =>
      _db.projectEventDao.watchByProject(projectId);

  Future<ProjectEvent> addEvent({
    required int projectId,
    required String eventType,
    required String title,
    String? description,
    required DateTime eventTime,
    bool isSystem = false,
  }) {
    return _db.projectEventDao.insertOne(
      ProjectEventsCompanion.insert(
        projectId: projectId,
        eventType: eventType,
        title: title,
        description: Value(description),
        eventTime: eventTime,
        isSystem: Value(isSystem),
      ),
    );
  }

  // --- Life items for project ---

  Stream<List<LifeItem>> watchProjectLifeItems(int projectId) =>
      _db.lifeItemDao.watchByProjectId(projectId);

  Stream<List<LifeItem>> watchProjectPaymentDues(int projectId) =>
      _db.lifeItemDao.watchPaymentDueByProjectId(projectId);

  // --- Bill records for project ---

  Stream<List<BillRecord>> watchProjectBills(int projectId) =>
      _db.billRecordDao.watchByProjectId(projectId);

  Stream<int> watchProjectIncome(int projectId) =>
      _db.billRecordDao.watchSumByProjectId(projectId, 'income');

  Stream<int> watchProjectExpense(int projectId) =>
      _db.billRecordDao.watchSumByProjectId(projectId, 'expense');

  // --- Statistics queries ---

  Stream<List<MonthlySumRow>> watchMonthlySums(
    DateTime start,
    DateTime end,
    String amountType,
  ) => _db.billRecordDao.watchMonthlySumsForRange(start, end, amountType);

  Stream<List<CategoryBreakdownRow>> watchCategoryBreakdown(
    DateTime month,
    String amountType,
  ) => _db.billRecordDao.watchCategoryBreakdown(month, amountType);

  Stream<int> watchProjectIncomeForMonth(int projectId, DateTime month) =>
      _db.billRecordDao.watchProjectIncomeForMonth(projectId, month);

  Stream<int> watchAllProjectIncomeForMonth(DateTime month) =>
      _db.billRecordDao.watchAllProjectIncomeForMonth(month);

  Stream<int> watchCompletedCountInMonth(DateTime month) =>
      _db.lifeItemDao.watchCompletedCountInMonth(month);

  Future<void> _replaceTemplateSteps(
    int templateId,
    List<ProjectTemplateStepInput> steps,
  ) {
    return _db.projectTemplateDao.replaceSteps(templateId, [
      for (var index = 0; index < steps.length; index++)
        ProjectTemplateStepsCompanion.insert(
          templateId: templateId,
          title: steps[index].title,
          amountType: Value(steps[index].amountType),
          amount: Value(steps[index].amount),
          offsetDays: Value(steps[index].offsetDays),
          keyDateOffsetDays: Value(steps[index].keyDateOffsetDays),
          createdDateOffsetDays: Value(steps[index].createdDateOffsetDays),
          sortOrder: Value(index),
        ),
    ]);
  }

  Future<void> _createProjectLifeItems({
    required Project project,
    required List<ProjectTemplateStepInput> steps,
  }) async {
    for (final step in steps) {
      await _db.lifeItemDao.insertOne(
        LifeItemsCompanion.insert(
          title: step.title,
          dueTime: step.resolveDueTime(
            keyDate: project.startDate,
            createdAt: project.createdAt,
          ),
          projectId: Value(project.id),
          amountType: Value(step.amountType),
          amount: Value(step.amount),
          projectDateAnchor: Value(step.projectDateAnchor),
          projectDateOffsetDays: Value(step.projectDateOffsetDays),
          projectDateManuallyEdited: Value(step.projectDateAnchor == null),
        ),
      );
    }
  }

  Future<void> _recalculateKeyDateLifeItems(Project project) async {
    final keyDate = project.startDate;
    if (keyDate == null) return;
    final items = await _db.lifeItemDao.getByProjectId(project.id);
    final now = DateTime.now();
    for (final item in items) {
      if (item.projectDateAnchor != projectDateAnchorKeyDate) continue;
      if (item.projectDateManuallyEdited) continue;
      final offset = item.projectDateOffsetDays;
      if (offset == null) continue;
      final dueTime = ProjectTemplateStepInput._dateOnly(
        keyDate,
      ).add(Duration(days: offset));
      await _db.lifeItemDao.updateOne(
        LifeItemsCompanion(
          id: Value(item.id),
          title: Value(item.title),
          description: Value(item.description),
          categoryId: Value(item.categoryId),
          projectId: Value(item.projectId),
          amount: Value(item.amount),
          amountType: Value(item.amountType),
          dueTime: Value(dueTime),
          remindTime: Value(item.remindTime),
          repeatRule: Value(item.repeatRule),
          status: Value(item.status),
          createdAt: Value(item.createdAt),
          updatedAt: Value(now),
          projectDateAnchor: Value(item.projectDateAnchor),
          projectDateOffsetDays: Value(item.projectDateOffsetDays),
          projectDateManuallyEdited: Value(item.projectDateManuallyEdited),
          deletedAt: Value(item.deletedAt),
        ),
      );
    }
  }

  bool _sameDate(DateTime? first, DateTime? second) {
    if (first == null || second == null) return first == second;
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  String? _mergeTemplateNote(String? templateNote, String? projectNote) {
    final parts = [
      if (templateNote != null && templateNote.trim().isNotEmpty)
        templateNote.trim(),
      if (projectNote != null && projectNote.trim().isNotEmpty)
        projectNote.trim(),
    ];
    return parts.isEmpty ? null : parts.join('\n');
  }

  Future<void> _markCategoryUsed(int? categoryId) async {
    if (categoryId == null) return;
    await _db.categoryDao.markUsed(categoryId);
  }
}
