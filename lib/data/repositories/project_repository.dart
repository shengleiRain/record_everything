import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../database/daos/bill_record_dao.dart';

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
    String projectStatus = 'planned',
    DateTime? startDate,
    DateTime? endDate,
    int? totalAmount,
    String? templateKey,
    String? note,
  }) {
    return _db.projectDao.insertOne(
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
  }

  Future<void> updateProject(Project project) {
    return _db.projectDao.updateOne(
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
  }

  Future<void> softDeleteProject(int id) => _db.projectDao.softDeleteById(id);

  Future<void> restoreProject(int id) => _db.projectDao.restoreById(id);

  Future<bool> hasLinkedRecords(int id) => _db.projectDao.hasLinkedRecords(id);

  // --- Photography template ---

  Future<Project> createPhotographyProjectFromTemplate({
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
  }) async {
    final noteBuffer = StringBuffer();
    if (shootType != null && shootType.isNotEmpty) {
      noteBuffer.writeln('拍摄类型: $shootType');
    }
    if (note != null && note.isNotEmpty) {
      noteBuffer.write(note);
    }

    final project = await createProject(
      title: title,
      categoryId: projectCategoryId,
      participant: participant,
      projectStatus: 'active',
      startDate: shootDate,
      totalAmount: totalAmount,
      templateKey: 'photography_order',
      note: noteBuffer.toString().trim(),
    );

    // Auto-generate life items
    final lifeItemDao = _db.lifeItemDao;

    // Deposit payment due
    if (depositAmount != null && depositAmount > 0) {
      await lifeItemDao.insertOne(
        LifeItemsCompanion.insert(
          title: '收定金',
          dueTime:
              depositDueDate ?? shootDate.subtract(const Duration(days: 7)),
          projectId: Value(project.id),
          itemType: const Value('payment_due'),
          amountType: const Value('income'),
          amount: Value(depositAmount),
        ),
      );
    }

    // Shoot day reminder
    await lifeItemDao.insertOne(
      LifeItemsCompanion.insert(
        title: '拍摄日提醒',
        dueTime: shootDate,
        projectId: Value(project.id),
        itemType: const Value('milestone'),
      ),
    );

    // Selection/delivery confirmation
    await lifeItemDao.insertOne(
      LifeItemsCompanion.insert(
        title: '选片/确认交付内容',
        dueTime: shootDate.add(const Duration(days: 3)),
        projectId: Value(project.id),
        itemType: const Value('todo'),
      ),
    );

    // Retouching delivery
    await lifeItemDao.insertOne(
      LifeItemsCompanion.insert(
        title: '修图交付',
        dueTime: shootDate.add(const Duration(days: 14)),
        projectId: Value(project.id),
        itemType: const Value('delivery'),
      ),
    );

    // Final payment due
    if (finalPaymentAmount != null && finalPaymentAmount > 0) {
      await lifeItemDao.insertOne(
        LifeItemsCompanion.insert(
          title: '收尾款',
          dueTime:
              finalPaymentDueDate ?? shootDate.add(const Duration(days: 14)),
          projectId: Value(project.id),
          itemType: const Value('payment_due'),
          amountType: const Value('income'),
          amount: Value(finalPaymentAmount),
        ),
      );
    }

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
}
