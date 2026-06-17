import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import '../../core/constants/default_categories.dart';
import '../../core/constants/item_template_keys.dart';
import '../../core/constants/project_template_keys.dart';
import 'tables/categories_table.dart';
import 'tables/life_items_table.dart';
import 'tables/bill_records_table.dart';
import 'tables/accounts_table.dart';
import 'tables/monthly_budgets_table.dart';
import 'tables/projects_table.dart';
import 'tables/project_events_table.dart';
import 'tables/project_templates_table.dart';
import 'tables/project_template_steps_table.dart';
import 'tables/item_templates_table.dart';
import 'daos/life_item_dao.dart';
import 'daos/bill_record_dao.dart';
import 'daos/category_dao.dart';
import 'daos/project_dao.dart';
import 'daos/project_event_dao.dart';
import 'daos/project_template_dao.dart';
import 'daos/item_template_dao.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Categories,
    LifeItems,
    BillRecords,
    Accounts,
    MonthlyBudgets,
    Projects,
    ProjectEvents,
    ProjectTemplates,
    ProjectTemplateSteps,
    ItemTemplates,
  ],
  daos: [
    LifeItemDao,
    BillRecordDao,
    CategoryDao,
    ProjectDao,
    ProjectEventDao,
    ProjectTemplateDao,
    ItemTemplateDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 7;

  static QueryExecutor openConnection() {
    return driftDatabase(name: 'life_items.db');
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      await _insertDefaultCategories();
      await _insertDefaultAccount();
      await _insertDefaultProjectCategories();
      await _createProjectIndexes();
      await _createProjectTemplateIndexes();
      await _createItemTemplateIndexes();
      await _ensureDefaultProjectTemplates();
      await _ensureDefaultItemTemplates();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        await m.createTable(accounts);
        await m.createTable(monthlyBudgets);
        await m.addColumn(lifeItems, lifeItems.deletedAt);
        await m.addColumn(billRecords, billRecords.accountId);
        await m.addColumn(billRecords, billRecords.deletedAt);
        await _insertDefaultAccount();
      }
      if (from < 3) {
        await m.createTable(projects);
        await m.createTable(projectEvents);
        await m.addColumn(lifeItems, lifeItems.projectId);
        await m.addColumn(billRecords, billRecords.projectId);
        await _insertDefaultProjectCategories();
        await _createProjectIndexes();
      }
      if (from < 4) {
        await m.createTable(projectTemplates);
        await m.createTable(projectTemplateSteps);
        await _createProjectTemplateIndexes();
      }
      if (from >= 4 && from < 5) {
        await m.addColumn(projectTemplates, projectTemplates.templateKey);
      }
      if (from < 5) {
        await _createProjectTemplateIndexes();
        await _ensureDefaultProjectTemplates();
      }
      if (from < 6) {
        await m.addColumn(categories, categories.isHidden);
        await m.addColumn(categories, categories.isPinned);
        await m.addColumn(categories, categories.lastUsedAt);
        await m.createTable(itemTemplates);
        await _createItemTemplateIndexes();
        await _ensureDefaultItemTemplates();
      }
      if (from < 7) {
        // 项目状态精简：移除「计划中(planned)/等待中(waiting)」，
        // 已废弃的旧值统一归并到「进行中(active)」。schema 本身不变
        //（project_status 仍是 TEXT），只迁移存量行。
        await customStatement(
          "UPDATE projects SET project_status = 'active' "
          "WHERE project_status IN ('planned', 'waiting')",
        );
      }
    },
  );

  Future<void> _insertDefaultCategories() async {
    for (final c in DefaultCategories.income) {
      await into(categories).insert(
        CategoriesCompanion.insert(
          name: c['name']!,
          type: 'income',
          icon: Value(c['icon']!),
          isDefault: const Value(true),
        ),
      );
    }
    for (final c in DefaultCategories.expense) {
      await into(categories).insert(
        CategoriesCompanion.insert(
          name: c['name']!,
          type: 'expense',
          icon: Value(c['icon']!),
          isDefault: const Value(true),
        ),
      );
    }
    for (final c in DefaultCategories.item) {
      await into(categories).insert(
        CategoriesCompanion.insert(
          name: c['name']!,
          type: 'item',
          icon: Value(c['icon']!),
          isDefault: const Value(true),
        ),
      );
    }
  }

  Future<void> _insertDefaultAccount() async {
    final existing = await (select(
      accounts,
    )..where((t) => t.isDefault.equals(true))).get();
    if (existing.isNotEmpty) return;
    await into(accounts).insert(
      AccountsCompanion.insert(name: '默认账户', isDefault: const Value(true)),
    );
  }

  Future<void> _insertDefaultProjectCategories() async {
    for (final c in DefaultCategories.project) {
      await into(categories).insert(
        CategoriesCompanion.insert(
          name: c['name']!,
          type: 'project',
          icon: Value(c['icon']!),
          isDefault: const Value(true),
        ),
      );
    }
  }

  Future<void> _createProjectIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_projects_category_deleted ON projects(category_id, deleted_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_projects_start_deleted ON projects(start_date, deleted_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_projects_status_deleted ON projects(project_status, deleted_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_life_items_project_due ON life_items(project_id, due_time, deleted_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_bill_records_project_time ON bill_records(project_id, bill_time, deleted_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_project_events_project_time ON project_events(project_id, event_time)',
    );
  }

  Future<void> _createProjectTemplateIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_project_templates_deleted ON project_templates(deleted_at, updated_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_project_templates_key ON project_templates(template_key)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_project_template_steps_template_order ON project_template_steps(template_id, sort_order)',
    );
  }

  Future<void> _createItemTemplateIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_item_templates_deleted ON item_templates(deleted_at, is_pinned, updated_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_item_templates_key ON item_templates(template_key)',
    );
  }

  Future<void> _ensureDefaultProjectTemplates() async {
    final photographyCategory =
        await (select(categories)
              ..where((t) => t.type.equals('project') & t.name.equals('摄影接单')))
            .getSingleOrNull();
    final photographyCategoryId = photographyCategory?.id;

    final existingByKey =
        await (select(projectTemplates)..where(
              (t) =>
                  t.templateKey.equals(ProjectTemplateKeys.photographyOrder) &
                  t.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    final deletedByKey =
        await (select(projectTemplates)..where(
              (t) =>
                  t.templateKey.equals(ProjectTemplateKeys.photographyOrder) &
                  t.deletedAt.isNotNull(),
            ))
            .getSingleOrNull();
    if (existingByKey == null && deletedByKey != null) return;
    final existingByName =
        existingByKey ??
        await (select(projectTemplates)..where(
              (t) =>
                  t.templateKey.isNull() &
                  t.name.equals('摄影接单模板') &
                  t.deletedAt.isNull(),
            ))
            .getSingleOrNull();

    final ProjectTemplate template;
    if (existingByName == null) {
      template = await into(projectTemplates).insertReturning(
        ProjectTemplatesCompanion.insert(
          name: '摄影接单模板',
          templateKey: const Value(ProjectTemplateKeys.photographyOrder),
          categoryId: Value(photographyCategoryId),
          note: const Value('内置模板，可按你的接单流程调整默认节点。'),
          isDefault: const Value(true),
        ),
      );
    } else {
      template = existingByName;
      await (update(
        projectTemplates,
      )..where((t) => t.id.equals(template.id))).write(
        ProjectTemplatesCompanion(
          templateKey: const Value(ProjectTemplateKeys.photographyOrder),
          categoryId: template.categoryId == null
              ? Value(photographyCategoryId)
              : const Value.absent(),
          isDefault: const Value(true),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }

    final steps = await (select(
      projectTemplateSteps,
    )..where((t) => t.templateId.equals(template.id))).get();
    if (steps.isNotEmpty) return;

    final defaults = <ProjectTemplateStepsCompanion>[
      ProjectTemplateStepsCompanion.insert(
        templateId: template.id,
        title: '收定金',
        itemType: const Value('payment_due'),
        amountType: const Value('income'),
        offsetDays: const Value(-7),
        sortOrder: const Value(0),
      ),
      ProjectTemplateStepsCompanion.insert(
        templateId: template.id,
        title: '拍摄日提醒',
        itemType: const Value('milestone'),
        offsetDays: const Value(0),
        sortOrder: const Value(1),
      ),
      ProjectTemplateStepsCompanion.insert(
        templateId: template.id,
        title: '选片/确认交付内容',
        itemType: const Value('todo'),
        offsetDays: const Value(3),
        sortOrder: const Value(2),
      ),
      ProjectTemplateStepsCompanion.insert(
        templateId: template.id,
        title: '修图交付',
        itemType: const Value('delivery'),
        offsetDays: const Value(14),
        sortOrder: const Value(3),
      ),
      ProjectTemplateStepsCompanion.insert(
        templateId: template.id,
        title: '收尾款',
        itemType: const Value('payment_due'),
        amountType: const Value('income'),
        offsetDays: const Value(14),
        sortOrder: const Value(4),
      ),
    ];
    for (final step in defaults) {
      await into(projectTemplateSteps).insert(step);
    }
  }

  Future<void> _ensureDefaultItemTemplates() async {
    final categoryRows = await (select(
      categories,
    )..where((t) => t.type.equals('item'))).get();
    int? categoryId(String name) =>
        categoryRows.where((category) => category.name == name).firstOrNull?.id;

    final defaults = [
      _DefaultItemTemplate(
        key: ItemTemplateKeys.membershipRenewal,
        name: '会员续费',
        itemType: 'subscription',
        amountType: 'expense',
        categoryId: categoryId('订阅会员'),
        dueOffsetDays: 30,
        reminderOffsetDays: -3,
        repeatRule: 'monthly',
        keywords: '会员,续费,订阅,netflix,spotify,icloud,apple,视频,云盘',
        pinned: true,
      ),
      _DefaultItemTemplate(
        key: ItemTemplateKeys.documentExpiry,
        name: '证件到期',
        itemType: 'expiration',
        amountType: 'none',
        categoryId: categoryId('证件'),
        dueOffsetDays: 30,
        reminderOffsetDays: -14,
        keywords: '证件,护照,身份证,驾照,驾驶证,签证,港澳通行证',
        pinned: true,
      ),
      _DefaultItemTemplate(
        key: ItemTemplateKeys.medicineRestock,
        name: '药品补货',
        itemType: 'consumable',
        amountType: 'expense',
        categoryId: categoryId('药品'),
        dueOffsetDays: 14,
        reminderOffsetDays: -3,
        keywords: '药,药品,补货,复诊,处方,维生素,感冒药',
        pinned: true,
      ),
      _DefaultItemTemplate(
        key: ItemTemplateKeys.householdBill,
        name: '家庭账单',
        itemType: 'bill',
        amountType: 'expense',
        categoryId: categoryId('家庭账单'),
        dueOffsetDays: 7,
        reminderOffsetDays: -2,
        repeatRule: 'monthly',
        keywords: '水电,燃气,物业,房租,宽带,电费,水费,家庭账单',
        pinned: true,
      ),
      _DefaultItemTemplate(
        key: ItemTemplateKeys.warranty,
        name: '保修',
        itemType: 'expiration',
        amountType: 'none',
        categoryId: categoryId('保修'),
        dueOffsetDays: 365,
        reminderOffsetDays: -30,
        keywords: '保修,质保,维修,售后,发票',
        pinned: true,
      ),
      _DefaultItemTemplate(
        key: ItemTemplateKeys.consumableReplacement,
        name: '耗材更换',
        itemType: 'consumable',
        amountType: 'expense',
        categoryId: categoryId('家庭耗材'),
        dueOffsetDays: 180,
        reminderOffsetDays: -7,
        repeatRule: 'every:180:days',
        keywords: '滤芯,耗材,更换,电池,牙刷头,净水器,空气滤网',
        pinned: true,
      ),
    ];

    for (final template in defaults) {
      final existing =
          await (select(itemTemplates)..where(
                (t) =>
                    t.templateKey.equals(template.key) & t.deletedAt.isNull(),
              ))
              .getSingleOrNull();
      if (existing != null) continue;
      final deleted =
          await (select(itemTemplates)..where(
                (t) =>
                    t.templateKey.equals(template.key) &
                    t.deletedAt.isNotNull(),
              ))
              .getSingleOrNull();
      if (deleted != null) continue;

      await into(itemTemplates).insert(
        ItemTemplatesCompanion.insert(
          name: template.name,
          templateKey: Value(template.key),
          categoryId: Value(template.categoryId),
          itemType: Value(template.itemType),
          amountType: Value(template.amountType),
          dueOffsetDays: Value(template.dueOffsetDays),
          reminderOffsetDays: Value(template.reminderOffsetDays),
          repeatRule: Value(template.repeatRule),
          keywords: Value(template.keywords),
          isDefault: const Value(true),
          isPinned: Value(template.pinned),
        ),
      );
    }
  }
}

class _DefaultItemTemplate {
  const _DefaultItemTemplate({
    required this.key,
    required this.name,
    required this.itemType,
    required this.amountType,
    required this.categoryId,
    required this.dueOffsetDays,
    required this.reminderOffsetDays,
    required this.keywords,
    this.repeatRule,
    this.pinned = false,
  });

  final String key;
  final String name;
  final String itemType;
  final String amountType;
  final int? categoryId;
  final int dueOffsetDays;
  final int? reminderOffsetDays;
  final String? repeatRule;
  final String keywords;
  final bool pinned;
}
