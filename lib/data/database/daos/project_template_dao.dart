import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/project_template_steps_table.dart';
import '../tables/project_templates_table.dart';

part 'project_template_dao.g.dart';

@DriftAccessor(tables: [ProjectTemplates, ProjectTemplateSteps])
class ProjectTemplateDao extends DatabaseAccessor<AppDatabase>
    with _$ProjectTemplateDaoMixin {
  ProjectTemplateDao(super.db);

  Stream<List<ProjectTemplate>> watchAll() =>
      (select(projectTemplates)
            ..where((t) => t.deletedAt.isNull())
            ..orderBy([
              (t) => OrderingTerm.desc(t.updatedAt),
            ]))
          .watch();

  Future<List<ProjectTemplate>> getAll() =>
      (select(projectTemplates)
            ..where((t) => t.deletedAt.isNull())
            ..orderBy([
              (t) => OrderingTerm.desc(t.updatedAt),
            ]))
          .get();

  Future<ProjectTemplate> getById(int id) =>
      (select(projectTemplates)..where((t) => t.id.equals(id))).getSingle();

  Future<ProjectTemplate?> getByTemplateKey(String templateKey) =>
      (select(projectTemplates)..where(
            (t) => t.templateKey.equals(templateKey) & t.deletedAt.isNull(),
          ))
          .getSingleOrNull();

  Future<ProjectTemplate> insertTemplate(ProjectTemplatesCompanion entry) =>
      into(projectTemplates).insertReturning(entry);

  Future<void> updateTemplate(ProjectTemplatesCompanion entry) =>
      update(projectTemplates).replace(entry);

  Future<int> softDeleteTemplate(int id) =>
      (update(projectTemplates)..where((t) => t.id.equals(id))).write(
        ProjectTemplatesCompanion(deletedAt: Value(DateTime.now())),
      );

  Stream<List<ProjectTemplateStep>> watchSteps(int templateId) =>
      (select(projectTemplateSteps)
            ..where((t) => t.templateId.equals(templateId))
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .watch();

  Future<List<ProjectTemplateStep>> getSteps(int templateId) =>
      (select(projectTemplateSteps)
            ..where((t) => t.templateId.equals(templateId))
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .get();

  Future<void> replaceSteps(
    int templateId,
    List<ProjectTemplateStepsCompanion> entries,
  ) async {
    await transaction(() async {
      await (delete(
        projectTemplateSteps,
      )..where((t) => t.templateId.equals(templateId))).go();
      for (final entry in entries) {
        await into(projectTemplateSteps).insert(entry);
      }
    });
  }
}
