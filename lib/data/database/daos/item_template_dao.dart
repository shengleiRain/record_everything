import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/item_templates_table.dart';

part 'item_template_dao.g.dart';

@DriftAccessor(tables: [ItemTemplates])
class ItemTemplateDao extends DatabaseAccessor<AppDatabase>
    with _$ItemTemplateDaoMixin {
  ItemTemplateDao(super.db);

  Stream<List<ItemTemplate>> watchAll() =>
      (select(itemTemplates)
            ..where((t) => t.deletedAt.isNull())
            ..orderBy([
              (t) => OrderingTerm.desc(t.isPinned),
              (t) => OrderingTerm.desc(t.isDefault),
              (t) => OrderingTerm.desc(t.updatedAt),
            ]))
          .watch();

  Future<List<ItemTemplate>> getAll() =>
      (select(itemTemplates)
            ..where((t) => t.deletedAt.isNull())
            ..orderBy([
              (t) => OrderingTerm.desc(t.isPinned),
              (t) => OrderingTerm.desc(t.isDefault),
              (t) => OrderingTerm.desc(t.updatedAt),
            ]))
          .get();

  Future<ItemTemplate> getById(int id) =>
      (select(itemTemplates)..where((t) => t.id.equals(id))).getSingle();

  Future<ItemTemplate?> getByTemplateKey(String templateKey) =>
      (select(itemTemplates)..where(
            (t) => t.templateKey.equals(templateKey) & t.deletedAt.isNull(),
          ))
          .getSingleOrNull();

  Future<ItemTemplate> insertTemplate(ItemTemplatesCompanion entry) =>
      into(itemTemplates).insertReturning(entry);

  Future<void> updateTemplate(ItemTemplatesCompanion entry) =>
      update(itemTemplates).replace(entry);

  Future<int> softDeleteTemplate(int id) =>
      (update(itemTemplates)..where((t) => t.id.equals(id))).write(
        ItemTemplatesCompanion(deletedAt: Value(DateTime.now())),
      );
}
