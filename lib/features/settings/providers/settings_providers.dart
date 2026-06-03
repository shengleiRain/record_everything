import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/database_provider.dart';

class SettingsNotifier extends Notifier<void> {
  @override
  void build() {}

  AppDatabase get _db => ref.read(databaseProvider);

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

    final json = const JsonEncoder.withIndent('  ').convert(data);
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/life_items_backup_${DateTime.now().millisecondsSinceEpoch}.json');
    await file.writeAsString(json);
    return file.path;
  }

  Future<void> importFromJson(String jsonString) async {
    final data = jsonDecode(jsonString) as Map<String, dynamic>;

    for (final catMap in data['categories'] as List) {
      await _db.categoryDao.insertOne(CategoriesCompanion.insert(
        name: catMap['name'] as String,
        type: catMap['type'] as String,
        icon: Value(catMap['icon'] as String? ?? 'category'),
      ));
    }

    for (final itemMap in data['lifeItems'] as List) {
      await _db.lifeItemDao.insertOne(LifeItemsCompanion.insert(
        title: itemMap['title'] as String,
        description: Value(itemMap['description'] as String?),
        categoryId: Value(itemMap['categoryId'] as int?),
        itemType: Value(itemMap['itemType'] as String? ?? 'todo'),
        amount: Value(itemMap['amount'] as int?),
        amountType: Value(itemMap['amountType'] as String? ?? 'none'),
        dueTime: DateTime.parse(itemMap['dueTime'] as String),
        remindTime: Value(itemMap['remindTime'] != null ? DateTime.parse(itemMap['remindTime'] as String) : null),
        repeatRule: Value(itemMap['repeatRule'] as String?),
        status: Value(itemMap['status'] as String? ?? 'pending'),
      ));
    }

    for (final billMap in data['billRecords'] as List) {
      await _db.billRecordDao.insertOne(BillRecordsCompanion.insert(
        title: billMap['title'] as String,
        amount: billMap['amount'] as int,
        amountType: Value(billMap['amountType'] as String? ?? 'expense'),
        categoryId: Value(billMap['categoryId'] as int?),
        billTime: DateTime.parse(billMap['billTime'] as String),
        note: Value(billMap['note'] as String?),
        lifeItemId: Value(billMap['lifeItemId'] as int?),
      ));
    }
  }
}

final settingsNotifierProvider = NotifierProvider<SettingsNotifier, void>(SettingsNotifier.new);

Map<String, dynamic> _lifeItemToMap(LifeItem item) => {
      'id': item.id, 'title': item.title, 'description': item.description,
      'categoryId': item.categoryId, 'itemType': item.itemType, 'amount': item.amount,
      'amountType': item.amountType, 'dueTime': item.dueTime.toIso8601String(),
      'remindTime': item.remindTime?.toIso8601String(), 'repeatRule': item.repeatRule,
      'status': item.status, 'createdAt': item.createdAt.toIso8601String(),
    };

Map<String, dynamic> _billRecordToMap(BillRecord bill) => {
      'id': bill.id, 'lifeItemId': bill.lifeItemId, 'title': bill.title,
      'categoryId': bill.categoryId, 'amount': bill.amount, 'amountType': bill.amountType,
      'billTime': bill.billTime.toIso8601String(), 'note': bill.note,
      'createdAt': bill.createdAt.toIso8601String(),
    };

Map<String, dynamic> _categoryToMap(Category cat) => {
      'id': cat.id, 'name': cat.name, 'type': cat.type, 'icon': cat.icon,
    };
