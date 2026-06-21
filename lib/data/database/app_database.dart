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
  int get schemaVersion => 11;

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
      if (from < 8) {
        // 事项类型已从新 schema 中移除。用户确认无需兼容旧数据，
        // 因此这里不做旧表改写或数据迁移。
      }
      if (from < 9) {
        await m.addColumn(
          projectTemplateSteps,
          projectTemplateSteps.keyDateOffsetDays,
        );
        await m.addColumn(
          projectTemplateSteps,
          projectTemplateSteps.createdDateOffsetDays,
        );
        await customStatement(
          'UPDATE project_template_steps '
          'SET key_date_offset_days = offset_days '
          'WHERE key_date_offset_days IS NULL '
          'AND created_date_offset_days IS NULL',
        );
        await m.addColumn(lifeItems, lifeItems.projectDateAnchor);
        await m.addColumn(lifeItems, lifeItems.projectDateOffsetDays);
        await m.addColumn(lifeItems, lifeItems.projectDateManuallyEdited);
      }
      if (from < 10) {
        // 补插新增的默认项目类型「跟拍」与两个内置跟拍模板。
        // 幂等：已存在则跳过，与 onCreate 行为一致。
        await _ensureDefaultProjectCategory('跟拍', 'photo_camera');
        await _ensureDefaultProjectTemplates();
      }
      if (from < 11) {
        // schema v11：分类新增 builtin_key / original_name 列（i18n 支持）。
        // spec §5.2。对所有内置分类回填 key 和原始名。
        await m.addColumn(categories, categories.builtinKey);
        await m.addColumn(categories, categories.originalName);
        await _backfillBuiltinCategoryKeys();
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
          builtinKey: Value(c['key']),
          originalName: Value(c['name']),
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
          builtinKey: Value(c['key']),
          originalName: Value(c['name']),
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
          builtinKey: Value(c['key']),
          originalName: Value(c['name']),
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
          builtinKey: Value(c['key']),
          originalName: Value(c['name']),
        ),
      );
    }
  }

  /// 幂等地补插单个默认项目类型分类。升级迁移时用：只插入缺失的分类，
  /// 避免重跑 [_insertDefaultProjectCategories] 造成已存在分类的重复行。
  Future<void> _ensureDefaultProjectCategory(String name, String icon) async {
    final existing =
        await (select(categories)
              ..where(
                (t) => t.type.equals('project') & t.name.equals(name),
              ))
            .getSingleOrNull();
    if (existing != null) return;
    // 查找 key（跟拍 → cat_photo_follow）。
    final match = DefaultCategories.project.cast<Map<String, String?>>().firstWhere(
      (c) => c['name'] == name,
      orElse: () => <String, String?>{'name': name, 'icon': icon, 'key': null},
    );
    final key = match['key'];
    await into(categories).insert(
      CategoriesCompanion.insert(
        name: name,
        type: 'project',
        icon: Value(icon),
        isDefault: const Value(true),
        builtinKey: key != null ? Value(key) : const Value.absent(),
        originalName: Value(name),
      ),
    );
  }

  /// v11 迁移：为已存在的内置分类回填 builtin_key 和 original_name。
  /// 按 name 匹配 DefaultCategories 的内置分类清单。
  Future<void> _backfillBuiltinCategoryKeys() async {
    final all = <Map<String, String?>>[
      ...DefaultCategories.income,
      ...DefaultCategories.expense,
      ...DefaultCategories.item,
      ...DefaultCategories.project,
    ];
    for (final c in all) {
      await (categories.update()
            ..where((t) => t.name.equals(c['name']!) & t.isDefault.equals(true)))
          .write(CategoriesCompanion(
            builtinKey: Value(c['key']),
            originalName: Value(c['name']),
          ));
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
    await _ensureDefaultTemplate(
      templateKey: ProjectTemplateKeys.weddingPhotography,
      name: '婚礼跟拍模板',
      note: '婚礼跟拍预设模板，可根据自己的情况修改。',
      categoryName: '跟拍',
      steps: const [
        _DefaultTemplateStep(title: '定金', amountType: 'income', createdDateOffsetDays: 0),
        _DefaultTemplateStep(title: '拍摄', keyDateOffsetDays: 0),
        _DefaultTemplateStep(title: '交付预告片', keyDateOffsetDays: 0),
        _DefaultTemplateStep(title: '交付剩余照片', keyDateOffsetDays: 15),
        _DefaultTemplateStep(title: '尾款', amountType: 'income', keyDateOffsetDays: 0),
      ],
    );
    await _ensureDefaultTemplate(
      templateKey: ProjectTemplateKeys.certificatePhotography,
      name: '领证跟拍模板',
      note: '领证跟拍预设模板，可根据自己的情况修改。',
      categoryName: '跟拍',
      steps: const [
        _DefaultTemplateStep(title: '定金', amountType: 'income', createdDateOffsetDays: 0),
        _DefaultTemplateStep(title: '拍摄', keyDateOffsetDays: 0),
        _DefaultTemplateStep(title: '交付照片', keyDateOffsetDays: 0),
        _DefaultTemplateStep(title: '尾款', amountType: 'income', keyDateOffsetDays: 0),
      ],
    );
  }

  /// 幂等地确保某个内置项目模板存在并带有预设节点。
  ///
  /// 规则（与历史版本单模板逻辑一致）：
  /// - 若该 key 已被用户软删除，则不再复活（尊重用户的删除）。
  /// - 若存在（按 key，或 key 为空时按名称兜底），回填 templateKey/isDefault，
  ///   并在分类缺失时补上；已有节点的模板不覆盖节点。
  /// - 否则新建模板并写入预设节点。
  /// 节点同时写 [ProjectTemplateStepInput.offsetDays] 与对应锚点字段
  /// （keyDateOffsetDays/createdDateOffsetDays），保持与历史迁移行格式一致。
  Future<void> _ensureDefaultTemplate({
    required String templateKey,
    required String name,
    required String note,
    required String categoryName,
    required List<_DefaultTemplateStep> steps,
  }) async {
    final category =
        await (select(categories)
              ..where((t) => t.type.equals('project') & t.name.equals(categoryName)))
            .getSingleOrNull();
    final categoryId = category?.id;

    final existingByKey =
        await (select(projectTemplates)..where(
              (t) =>
                  t.templateKey.equals(templateKey) & t.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    final deletedByKey =
        await (select(projectTemplates)..where(
              (t) =>
                  t.templateKey.equals(templateKey) &
                  t.deletedAt.isNotNull(),
            ))
            .getSingleOrNull();
    // 用户已删除该预置模板：不复活。
    if (existingByKey == null && deletedByKey != null) return;
    final existingByName =
        existingByKey ??
        await (select(projectTemplates)..where(
              (t) =>
                  t.templateKey.isNull() &
                  t.name.equals(name) &
                  t.deletedAt.isNull(),
            ))
            .getSingleOrNull();

    final ProjectTemplate template;
    if (existingByName == null) {
      template = await into(projectTemplates).insertReturning(
        ProjectTemplatesCompanion.insert(
          name: name,
          templateKey: Value(templateKey),
          categoryId: Value(categoryId),
          note: Value(note),
          isDefault: const Value(true),
        ),
      );
    } else {
      template = existingByName;
      await (update(
        projectTemplates,
      )..where((t) => t.id.equals(template.id))).write(
        ProjectTemplatesCompanion(
          templateKey: Value(templateKey),
          categoryId: template.categoryId == null
              ? Value(categoryId)
              : const Value.absent(),
          isDefault: const Value(true),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }

    final savedSteps = await (select(
      projectTemplateSteps,
    )..where((t) => t.templateId.equals(template.id))).get();
    if (savedSteps.isNotEmpty) return;

    for (var index = 0; index < steps.length; index++) {
      final step = steps[index];
      final isCreatedAnchor = step.createdDateOffsetDays != null;
      final offset = step.keyDateOffsetDays ?? step.createdDateOffsetDays ?? 0;
      await into(projectTemplateSteps).insert(
        ProjectTemplateStepsCompanion.insert(
          templateId: template.id,
          title: step.title,
          amountType: Value(step.amountType),
          offsetDays: Value(offset),
          keyDateOffsetDays: Value(isCreatedAnchor ? null : offset),
          createdDateOffsetDays: Value(isCreatedAnchor ? offset : null),
          sortOrder: Value(index),
        ),
      );
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
        amountType: 'expense',
        categoryId: categoryId('订阅续费'),
        dueOffsetDays: 30,
        reminderOffsetDays: -3,
        repeatRule: 'monthly',
        keywords: '会员,续费,订阅,netflix,spotify,icloud,apple,视频,云盘',
        pinned: true,
      ),
      _DefaultItemTemplate(
        key: ItemTemplateKeys.documentExpiry,
        name: '证件到期',
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
        amountType: 'expense',
        categoryId: categoryId('药品健康'),
        dueOffsetDays: 14,
        reminderOffsetDays: -3,
        keywords: '药,药品,补货,复诊,处方,维生素,感冒药',
        pinned: true,
      ),
      _DefaultItemTemplate(
        key: ItemTemplateKeys.householdBill,
        name: '家庭账单',
        amountType: 'expense',
        categoryId: categoryId('账单提醒'),
        dueOffsetDays: 7,
        reminderOffsetDays: -2,
        repeatRule: 'monthly',
        keywords: '水电,燃气,物业,房租,宽带,电费,水费,家庭账单',
        pinned: true,
      ),
      _DefaultItemTemplate(
        key: ItemTemplateKeys.warranty,
        name: '保修',
        amountType: 'none',
        categoryId: categoryId('保修售后'),
        dueOffsetDays: 365,
        reminderOffsetDays: -30,
        keywords: '保修,质保,维修,售后,发票',
        pinned: true,
      ),
      _DefaultItemTemplate(
        key: ItemTemplateKeys.consumableReplacement,
        name: '耗材更换',
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

class _DefaultTemplateStep {
  const _DefaultTemplateStep({
    required this.title,
    this.amountType = 'none',
    this.keyDateOffsetDays,
    this.createdDateOffsetDays,
  }) : assert(
         (keyDateOffsetDays == null ? 0 : 1) +
                 (createdDateOffsetDays == null ? 0 : 1) <=
             1,
         'A default template step can only anchor to one date base.',
       );

  final String title;
  final String amountType;
  final int? keyDateOffsetDays;
  final int? createdDateOffsetDays;
}

class _DefaultItemTemplate {
  const _DefaultItemTemplate({
    required this.key,
    required this.name,
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
  final String amountType;
  final int? categoryId;
  final int dueOffsetDays;
  final int? reminderOffsetDays;
  final String? repeatRule;
  final String keywords;
  final bool pinned;
}
