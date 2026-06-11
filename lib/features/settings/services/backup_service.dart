import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../data/database/app_database.dart';

class BackupFormatException implements Exception {
  const BackupFormatException(this.message);

  final String message;

  @override
  String toString() => message;
}

class BackupImportSummary {
  const BackupImportSummary({
    required this.categoriesImported,
    required this.projectsImported,
    required this.lifeItemsImported,
    required this.billRecordsImported,
    required this.projectEventsImported,
  });

  final int categoriesImported;
  final int projectsImported;
  final int lifeItemsImported;
  final int billRecordsImported;
  final int projectEventsImported;
}

class BackupService {
  const BackupService(this._db);

  final AppDatabase _db;

  Future<String> exportToJson() async {
    final lifeItems = await _db.lifeItemDao.getAll();
    final billRecords = await _db.billRecordDao.getAll();
    final categories = await _db.categoryDao.getAll();
    final projects = await _db.projectDao.getAll();

    final projectEvents = <ProjectEvent>[];
    for (final project in projects) {
      final events = await _db.projectEventDao.getByProject(project.id);
      projectEvents.addAll(events);
    }

    final data = {
      'version': 2,
      'exportedAt': DateTime.now().toIso8601String(),
      'categories': categories.map(_categoryToMap).toList(),
      'projects': projects.map(_projectToMap).toList(),
      'lifeItems': lifeItems.map(_lifeItemToMap).toList(),
      'billRecords': billRecords.map(_billRecordToMap).toList(),
      'projectEvents': projectEvents.map(_projectEventToMap).toList(),
    };

    return const JsonEncoder.withIndent('  ').convert(data);
  }

  Future<BackupImportSummary> importFromJson(String jsonString) async {
    final data = _decodeAndValidate(jsonString);
    final version = data['version'] as int;
    final categories = data['categories'] as List<Map<String, Object?>>;
    final lifeItems = data['lifeItems'] as List<Map<String, Object?>>;
    final billRecords = data['billRecords'] as List<Map<String, Object?>>;
    final projects = version >= 2
        ? data['projects'] as List<Map<String, Object?>>
        : <Map<String, Object?>>[];
    final projectEvents = version >= 2
        ? data['projectEvents'] as List<Map<String, Object?>>
        : <Map<String, Object?>>[];

    return _db.transaction(() async {
      final categoryIdMap = <int, int>{};
      var categoriesImported = 0;

      for (final map in categories) {
        final oldId = _optionalInt(map, 'id');
        final name = _requiredString(map, 'name');
        final type = _requiredString(map, 'type');
        final icon = _optionalString(map, 'icon') ?? 'category';
        final isDefault = _optionalBool(map, 'isDefault') ?? false;

        final existing = (await _db.categoryDao.getByType(
          type,
        )).where((category) => category.name == name).firstOrNull;
        final category =
            existing ??
            await _db.categoryDao.insertOne(
              CategoriesCompanion.insert(
                name: name,
                type: type,
                icon: Value(icon),
                isDefault: Value(isDefault),
              ),
            );
        if (existing == null) categoriesImported++;
        if (oldId != null) categoryIdMap[oldId] = category.id;
      }

      // Import projects
      final projectIdMap = <int, int>{};
      var projectsImported = 0;
      for (final map in projects) {
        final oldId = _optionalInt(map, 'id');
        final title = _requiredString(map, 'title');
        final createdAt = _requiredDate(map, 'createdAt');
        final existingProject = (await _db.projectDao.getAll()).where((p) {
          return p.title == title && p.createdAt == createdAt;
        }).firstOrNull;
        if (existingProject != null) {
          if (oldId != null) projectIdMap[oldId] = existingProject.id;
          continue;
        }
        final inserted = await _db.projectDao.insertOne(
          ProjectsCompanion.insert(
            title: title,
            categoryId: Value(
              _mappedId(_optionalInt(map, 'categoryId'), categoryIdMap),
            ),
            participant: Value(_optionalString(map, 'participant')),
            projectStatus: Value(
              _optionalString(map, 'projectStatus') ?? 'planned',
            ),
            startDate: Value(_optionalDate(map, 'startDate')),
            endDate: Value(_optionalDate(map, 'endDate')),
            totalAmount: Value(_optionalInt(map, 'totalAmount')),
            templateKey: Value(_optionalString(map, 'templateKey')),
            note: Value(_optionalString(map, 'note')),
            createdAt: Value(createdAt),
            updatedAt: Value(_optionalDate(map, 'updatedAt') ?? createdAt),
          ),
        );
        if (oldId != null) projectIdMap[oldId] = inserted.id;
        projectsImported++;
      }

      // Import life items
      var lifeItemsImported = 0;
      final lifeItemIdMap = <int, int>{};
      for (final map in lifeItems) {
        final oldId = _optionalInt(map, 'id');
        final categoryId = _optionalInt(map, 'categoryId');
        final projectId = _optionalInt(map, 'projectId');
        final title = _requiredString(map, 'title');
        final dueTime = _requiredDate(map, 'dueTime');
        final existingItem = (await _db.lifeItemDao.getAll()).where((item) {
          return item.title == title && item.dueTime == dueTime;
        }).firstOrNull;
        if (existingItem != null) {
          if (oldId != null) lifeItemIdMap[oldId] = existingItem.id;
          continue;
        }
        final inserted = await _db.lifeItemDao.insertOne(
          LifeItemsCompanion.insert(
            title: title,
            description: Value(_optionalString(map, 'description')),
            categoryId: Value(_mappedId(categoryId, categoryIdMap)),
            projectId: Value(_mappedId(projectId, projectIdMap)),
            itemType: Value(_optionalString(map, 'itemType') ?? 'todo'),
            amount: Value(_optionalInt(map, 'amount')),
            amountType: Value(_optionalString(map, 'amountType') ?? 'none'),
            dueTime: dueTime,
            remindTime: Value(_optionalDate(map, 'remindTime')),
            repeatRule: Value(_optionalString(map, 'repeatRule')),
            status: Value(_optionalString(map, 'status') ?? 'pending'),
            createdAt: Value(_optionalDate(map, 'createdAt') ?? dueTime),
            updatedAt: Value(
              _optionalDate(map, 'updatedAt') ??
                  _optionalDate(map, 'createdAt') ??
                  dueTime,
            ),
          ),
        );
        if (oldId != null) lifeItemIdMap[oldId] = inserted.id;
        lifeItemsImported++;
      }

      // Import bill records
      var billRecordsImported = 0;
      for (final map in billRecords) {
        final categoryId = _optionalInt(map, 'categoryId');
        final lifeItemId = _optionalInt(map, 'lifeItemId');
        final projectId = _optionalInt(map, 'projectId');
        final title = _requiredString(map, 'title');
        final amount = _requiredInt(map, 'amount');
        final billTime = _requiredDate(map, 'billTime');
        final existingBill = (await _db.billRecordDao.getAll()).where((bill) {
          return bill.title == title &&
              bill.amount == amount &&
              bill.billTime == billTime;
        }).firstOrNull;
        if (existingBill != null) continue;
        await _db.billRecordDao.insertOne(
          BillRecordsCompanion.insert(
            title: title,
            amount: amount,
            amountType: Value(_optionalString(map, 'amountType') ?? 'expense'),
            categoryId: Value(_mappedId(categoryId, categoryIdMap)),
            projectId: Value(_mappedId(projectId, projectIdMap)),
            billTime: billTime,
            note: Value(_optionalString(map, 'note')),
            lifeItemId: Value(_mappedId(lifeItemId, lifeItemIdMap)),
            createdAt: Value(_optionalDate(map, 'createdAt') ?? billTime),
            updatedAt: Value(
              _optionalDate(map, 'updatedAt') ??
                  _optionalDate(map, 'createdAt') ??
                  billTime,
            ),
          ),
        );
        billRecordsImported++;
      }

      // Import project events
      var projectEventsImported = 0;
      for (final map in projectEvents) {
        final oldProjectId = _optionalInt(map, 'projectId');
        final mappedProjectId = oldProjectId != null
            ? projectIdMap[oldProjectId]
            : null;
        if (mappedProjectId == null) continue;
        final title = _requiredString(map, 'title');
        final eventTime = _requiredDate(map, 'eventTime');
        final eventType = _optionalString(map, 'eventType') ?? 'note';
        final existingEvent =
            (await _db.projectEventDao.getByProject(mappedProjectId))
                .where(
                  (event) =>
                      event.title == title &&
                      event.eventTime == eventTime &&
                      event.eventType == eventType,
                )
                .firstOrNull;
        if (existingEvent != null) continue;
        await _db.projectEventDao.insertOne(
          ProjectEventsCompanion.insert(
            projectId: mappedProjectId,
            eventType: eventType,
            title: title,
            description: Value(_optionalString(map, 'description')),
            eventTime: eventTime,
            isSystem: Value(_optionalBool(map, 'isSystem') ?? false),
            createdAt: Value(_optionalDate(map, 'createdAt') ?? eventTime),
          ),
        );
        projectEventsImported++;
      }

      return BackupImportSummary(
        categoriesImported: categoriesImported,
        projectsImported: projectsImported,
        lifeItemsImported: lifeItemsImported,
        billRecordsImported: billRecordsImported,
        projectEventsImported: projectEventsImported,
      );
    });
  }

  Map<String, Object?> _decodeAndValidate(String jsonString) {
    final Object? decoded;
    try {
      decoded = jsonDecode(jsonString);
    } catch (_) {
      throw const BackupFormatException('备份文件不是有效 JSON');
    }
    if (decoded is! Map<String, Object?>) {
      throw const BackupFormatException('备份文件结构无效');
    }
    final version = decoded['version'];
    if (version != 1 && version != 2) {
      throw const BackupFormatException('备份版本不受支持');
    }
    final result = <String, Object?>{
      'version': version,
      'categories': _requiredMapList(decoded, 'categories'),
      'lifeItems': _requiredMapList(decoded, 'lifeItems'),
      'billRecords': _requiredMapList(decoded, 'billRecords'),
    };
    if (version == 2) {
      result['projects'] = _optionalMapList(decoded, 'projects');
      result['projectEvents'] = _optionalMapList(decoded, 'projectEvents');
    } else {
      result['projects'] = <Map<String, Object?>>[];
      result['projectEvents'] = <Map<String, Object?>>[];
    }
    return result;
  }
}

List<Map<String, Object?>> _requiredMapList(
  Map<String, Object?> data,
  String key,
) {
  final value = data[key];
  if (value is! List) {
    throw BackupFormatException('缺少 $key 数据');
  }
  return value.map((entry) {
    if (entry is! Map) {
      throw BackupFormatException('$key 包含无效记录');
    }
    return entry.cast<String, Object?>();
  }).toList();
}

List<Map<String, Object?>> _optionalMapList(
  Map<String, Object?> data,
  String key,
) {
  final value = data[key];
  if (value is! List) return <Map<String, Object?>>[];
  return value.map((entry) {
    if (entry is! Map) return <String, Object?>{};
    return entry.cast<String, Object?>();
  }).toList();
}

int? _mappedId(int? oldId, Map<int, int> idMap) =>
    oldId == null ? null : idMap[oldId];

String _requiredString(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is String && value.trim().isNotEmpty) return value.trim();
  throw BackupFormatException('$key 不能为空');
}

String? _optionalString(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value == null) return null;
  if (value is String) return value;
  throw BackupFormatException('$key 必须是文本');
}

int _requiredInt(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is int) return value;
  throw BackupFormatException('$key 必须是整数');
}

int? _optionalInt(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value == null) return null;
  if (value is int) return value;
  throw BackupFormatException('$key 必须是整数');
}

bool? _optionalBool(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value == null) return null;
  if (value is bool) return value;
  throw BackupFormatException('$key 必须是真假值');
}

DateTime _requiredDate(Map<String, Object?> map, String key) {
  final value = _optionalDate(map, key);
  if (value != null) return value;
  throw BackupFormatException('$key 不能为空');
}

DateTime? _optionalDate(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value == null) return null;
  if (value is! String) throw BackupFormatException('$key 必须是日期文本');
  final parsed = DateTime.tryParse(value);
  if (parsed == null) throw BackupFormatException('$key 日期格式无效');
  return parsed;
}

Map<String, Object?> _lifeItemToMap(LifeItem item) => {
  'id': item.id,
  'title': item.title,
  'description': item.description,
  'categoryId': item.categoryId,
  'projectId': item.projectId,
  'itemType': item.itemType,
  'amount': item.amount,
  'amountType': item.amountType,
  'dueTime': item.dueTime.toIso8601String(),
  'remindTime': item.remindTime?.toIso8601String(),
  'repeatRule': item.repeatRule,
  'status': item.status,
  'createdAt': item.createdAt.toIso8601String(),
  'updatedAt': item.updatedAt.toIso8601String(),
};

Map<String, Object?> _billRecordToMap(BillRecord bill) => {
  'id': bill.id,
  'lifeItemId': bill.lifeItemId,
  'projectId': bill.projectId,
  'title': bill.title,
  'categoryId': bill.categoryId,
  'amount': bill.amount,
  'amountType': bill.amountType,
  'billTime': bill.billTime.toIso8601String(),
  'note': bill.note,
  'createdAt': bill.createdAt.toIso8601String(),
  'updatedAt': bill.updatedAt.toIso8601String(),
};

Map<String, Object?> _categoryToMap(Category cat) => {
  'id': cat.id,
  'name': cat.name,
  'type': cat.type,
  'icon': cat.icon,
  'isDefault': cat.isDefault,
};

Map<String, Object?> _projectToMap(Project project) => {
  'id': project.id,
  'title': project.title,
  'categoryId': project.categoryId,
  'participant': project.participant,
  'projectStatus': project.projectStatus,
  'startDate': project.startDate?.toIso8601String(),
  'endDate': project.endDate?.toIso8601String(),
  'totalAmount': project.totalAmount,
  'templateKey': project.templateKey,
  'note': project.note,
  'createdAt': project.createdAt.toIso8601String(),
  'updatedAt': project.updatedAt.toIso8601String(),
};

Map<String, Object?> _projectEventToMap(ProjectEvent event) => {
  'id': event.id,
  'projectId': event.projectId,
  'eventType': event.eventType,
  'title': event.title,
  'description': event.description,
  'eventTime': event.eventTime.toIso8601String(),
  'isSystem': event.isSystem,
  'createdAt': event.createdAt.toIso8601String(),
};
