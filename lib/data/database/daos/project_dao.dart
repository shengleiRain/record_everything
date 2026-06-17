import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/projects_table.dart';

part 'project_dao.g.dart';

@DriftAccessor(tables: [Projects])
class ProjectDao extends DatabaseAccessor<AppDatabase>
    with _$ProjectDaoMixin {
  ProjectDao(super.db);

  Future<List<Project>> getAll() =>
      (select(projects)
            ..where((t) => t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
          .get();

  Stream<List<Project>> watchAll() =>
      (select(projects)
            ..where((t) => t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
          .watch();

  Stream<List<Project>> watchByStatus(String status) =>
      (select(projects)
            ..where((t) => t.projectStatus.equals(status) & t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm.asc(t.startDate)]))
          .watch();

  Stream<List<Project>> watchBetweenKeyDate(DateTime start, DateTime end) =>
      (select(projects)
            ..where(
              (t) =>
                  t.startDate.isBiggerOrEqualValue(start) &
                  t.startDate.isSmallerThanValue(end) &
                  t.deletedAt.isNull(),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.startDate)]))
          .watch();

  Stream<List<Project>> watchByCategory(int categoryId) =>
      (select(projects)
            ..where(
              (t) => t.categoryId.equals(categoryId) & t.deletedAt.isNull(),
            )
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
          .watch();

  Future<Project> getById(int id) =>
      (select(projects)..where((t) => t.id.equals(id))).getSingle();

  Stream<Project> watchById(int id) =>
      (select(projects)..where((t) => t.id.equals(id))).watchSingle();

  Future<Project> insertOne(ProjectsCompanion entry) =>
      into(projects).insertReturning(entry);

  Future updateOne(ProjectsCompanion entry) =>
      update(projects).replace(entry);

  Future<int> softDeleteById(int id) =>
      (update(projects)..where((t) => t.id.equals(id))).write(
        ProjectsCompanion(deletedAt: Value(DateTime.now())),
      );

  Future<void> deleteById(int id) =>
      (delete(projects)..where((t) => t.id.equals(id))).go();

  Future<int> restoreById(int id) =>
      (update(projects)..where((t) => t.id.equals(id))).write(
        const ProjectsCompanion(deletedAt: Value(null)),
      );

  Future<bool> hasLinkedLifeItems(int projectId) async {
    final count = await customSelect(
      'SELECT COUNT(*) AS cnt FROM life_items WHERE project_id = ? AND deleted_at IS NULL',
      variables: [Variable.withInt(projectId)],
    ).getSingle();
    return (count.data['cnt'] as int) > 0;
  }

  Future<bool> hasLinkedBillRecords(int projectId) async {
    final count = await customSelect(
      'SELECT COUNT(*) AS cnt FROM bill_records WHERE project_id = ? AND deleted_at IS NULL',
      variables: [Variable.withInt(projectId)],
    ).getSingle();
    return (count.data['cnt'] as int) > 0;
  }

  Future<bool> hasLinkedRecords(int projectId) async {
    return await hasLinkedLifeItems(projectId) ||
        await hasLinkedBillRecords(projectId);
  }
}
