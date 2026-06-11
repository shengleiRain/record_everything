import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/project_events_table.dart';

part 'project_event_dao.g.dart';

@DriftAccessor(tables: [ProjectEvents])
class ProjectEventDao extends DatabaseAccessor<AppDatabase>
    with _$ProjectEventDaoMixin {
  ProjectEventDao(super.db);

  Stream<List<ProjectEvent>> watchByProject(int projectId) =>
      (select(projectEvents)
            ..where((t) => t.projectId.equals(projectId))
            ..orderBy([(t) => OrderingTerm.desc(t.eventTime)]))
          .watch();

  Future<List<ProjectEvent>> getByProject(int projectId) =>
      (select(projectEvents)
            ..where((t) => t.projectId.equals(projectId))
            ..orderBy([(t) => OrderingTerm.desc(t.eventTime)]))
          .get();

  Future<ProjectEvent> insertOne(ProjectEventsCompanion entry) =>
      into(projectEvents).insertReturning(entry);

  Future<int> deleteById(int id) =>
      (delete(projectEvents)..where((t) => t.id.equals(id))).go();

  Future<int> deleteByProject(int projectId) =>
      (delete(projectEvents)..where((t) => t.projectId.equals(projectId))).go();
}
