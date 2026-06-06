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
    required this.lifeItemsImported,
    required this.billRecordsImported,
  });

  final int categoriesImported;
  final int lifeItemsImported;
  final int billRecordsImported;
}

class BackupService {
  const BackupService(this._db);

  final AppDatabase _db;

  Future<String> exportToJson() async {
    final lifeItems = await _db.lifeItemDao.getAll();
    final billRecords = await _db.billRecordDao.getAll();
    final categories = await _db.categoryDao.getAll();

    final data = {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'lifeItems': lifeItems.map(_lifeItemToMap).toList(),
      'billRecords': billRecords.map(_billRecordToMap).toList(),
      'categories': categories.map(_categoryToMap).toList(),
    };

    return const JsonEncoder.withIndent('  ').convert(data);
  }

  Future<BackupImportSummary> importFromJson(String jsonString) async {
    final data = _decodeAndValidate(jsonString);
    final categories = data['categories'] as List<Map<String, Object?>>;
    final lifeItems = data['lifeItems'] as List<Map<String, Object?>>;
    final billRecords = data['billRecords'] as List<Map<String, Object?>>;

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

      var lifeItemsImported = 0;
      final lifeItemIdMap = <int, int>{};
      for (final map in lifeItems) {
        final oldId = _optionalInt(map, 'id');
        final categoryId = _optionalInt(map, 'categoryId');
        final inserted = await _db.lifeItemDao.insertOne(
          LifeItemsCompanion.insert(
            title: _requiredString(map, 'title'),
            description: Value(_optionalString(map, 'description')),
            categoryId: Value(_mappedId(categoryId, categoryIdMap)),
            itemType: Value(_optionalString(map, 'itemType') ?? 'todo'),
            amount: Value(_optionalInt(map, 'amount')),
            amountType: Value(_optionalString(map, 'amountType') ?? 'none'),
            dueTime: _requiredDate(map, 'dueTime'),
            remindTime: Value(_optionalDate(map, 'remindTime')),
            repeatRule: Value(_optionalString(map, 'repeatRule')),
            status: Value(_optionalString(map, 'status') ?? 'pending'),
          ),
        );
        if (oldId != null) lifeItemIdMap[oldId] = inserted.id;
        lifeItemsImported++;
      }

      var billRecordsImported = 0;
      for (final map in billRecords) {
        final categoryId = _optionalInt(map, 'categoryId');
        final lifeItemId = _optionalInt(map, 'lifeItemId');
        await _db.billRecordDao.insertOne(
          BillRecordsCompanion.insert(
            title: _requiredString(map, 'title'),
            amount: _requiredInt(map, 'amount'),
            amountType: Value(_optionalString(map, 'amountType') ?? 'expense'),
            categoryId: Value(_mappedId(categoryId, categoryIdMap)),
            billTime: _requiredDate(map, 'billTime'),
            note: Value(_optionalString(map, 'note')),
            lifeItemId: Value(_mappedId(lifeItemId, lifeItemIdMap)),
          ),
        );
        billRecordsImported++;
      }

      return BackupImportSummary(
        categoriesImported: categoriesImported,
        lifeItemsImported: lifeItemsImported,
        billRecordsImported: billRecordsImported,
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
    if (decoded['version'] != 1) {
      throw const BackupFormatException('备份版本不受支持');
    }
    return {
      'categories': _requiredMapList(decoded, 'categories'),
      'lifeItems': _requiredMapList(decoded, 'lifeItems'),
      'billRecords': _requiredMapList(decoded, 'billRecords'),
    };
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
  'itemType': item.itemType,
  'amount': item.amount,
  'amountType': item.amountType,
  'dueTime': item.dueTime.toIso8601String(),
  'remindTime': item.remindTime?.toIso8601String(),
  'repeatRule': item.repeatRule,
  'status': item.status,
  'createdAt': item.createdAt.toIso8601String(),
};

Map<String, Object?> _billRecordToMap(BillRecord bill) => {
  'id': bill.id,
  'lifeItemId': bill.lifeItemId,
  'title': bill.title,
  'categoryId': bill.categoryId,
  'amount': bill.amount,
  'amountType': bill.amountType,
  'billTime': bill.billTime.toIso8601String(),
  'note': bill.note,
  'createdAt': bill.createdAt.toIso8601String(),
};

Map<String, Object?> _categoryToMap(Category cat) => {
  'id': cat.id,
  'name': cat.name,
  'type': cat.type,
  'icon': cat.icon,
  'isDefault': cat.isDefault,
};
