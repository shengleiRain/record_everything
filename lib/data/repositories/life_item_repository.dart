import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../../domain/models/repeat_rule.dart';

class LifeItemRepository {
  final AppDatabase _db;
  LifeItemRepository(this._db);

  Stream<List<LifeItem>> watchAll() => _db.lifeItemDao.watchAll();
  Stream<List<LifeItem>> watchTodayPending() => _db.lifeItemDao.watchTodayPending();
  Stream<List<LifeItem>> watchUpcoming(int days) => _db.lifeItemDao.watchUpcoming(days);
  Stream<List<LifeItem>> watchOverdue() => _db.lifeItemDao.watchOverdue();
  Stream<List<LifeItem>> watchForecastExpenses(int days) => _db.lifeItemDao.watchForecastExpenses(days);
  Stream<LifeItem> watchById(int id) => _db.lifeItemDao.watchById(id);

  Future<LifeItem> create({
    required String title,
    String? description,
    int? categoryId,
    String itemType = 'todo',
    int? amount,
    String amountType = 'none',
    required DateTime dueTime,
    DateTime? remindTime,
    String? repeatRule,
    String status = 'pending',
  }) {
    return _db.lifeItemDao.insertOne(LifeItemsCompanion.insert(
      title: title,
      description: Value(description),
      categoryId: Value(categoryId),
      itemType: Value(itemType),
      amount: Value(amount),
      amountType: Value(amountType),
      dueTime: dueTime,
      remindTime: Value(remindTime),
      repeatRule: Value(repeatRule),
      status: Value(status),
    ));
  }

  Future<LifeItem> updateItem(LifeItem item) {
    return _db.lifeItemDao.updateOne(LifeItemsCompanion(
      id: Value(item.id),
      title: Value(item.title),
      description: Value(item.description),
      categoryId: Value(item.categoryId),
      itemType: Value(item.itemType),
      amount: Value(item.amount),
      amountType: Value(item.amountType),
      dueTime: Value(item.dueTime),
      remindTime: Value(item.remindTime),
      repeatRule: Value(item.repeatRule),
      status: Value(item.status),
      createdAt: Value(item.createdAt),
      updatedAt: Value(DateTime.now()),
    )).then((_) => item);
  }

  Future<void> deleteItem(int id) => _db.lifeItemDao.deleteById(id);

  Future<LifeItem> complete(int id) async {
    final item = await _db.lifeItemDao.getById(id);
    final updated = item.copyWith(status: 'completed', updatedAt: DateTime.now());
    await _db.lifeItemDao.updateOne(LifeItemsCompanion(
      id: Value(updated.id),
      title: Value(updated.title),
      description: Value(updated.description),
      categoryId: Value(updated.categoryId),
      itemType: Value(updated.itemType),
      amount: Value(updated.amount),
      amountType: Value(updated.amountType),
      dueTime: Value(updated.dueTime),
      remindTime: Value(updated.remindTime),
      repeatRule: Value(updated.repeatRule),
      status: Value(updated.status),
      createdAt: Value(updated.createdAt),
      updatedAt: Value(updated.updatedAt),
    ));
    return updated;
  }

  Future<LifeItem> defer(int id, DateTime newDueTime) async {
    final item = await _db.lifeItemDao.getById(id);
    final updated = item.copyWith(dueTime: newDueTime, updatedAt: DateTime.now());
    await _db.lifeItemDao.updateOne(LifeItemsCompanion(
      id: Value(updated.id),
      title: Value(updated.title),
      description: Value(updated.description),
      categoryId: Value(updated.categoryId),
      itemType: Value(updated.itemType),
      amount: Value(updated.amount),
      amountType: Value(updated.amountType),
      dueTime: Value(updated.dueTime),
      remindTime: Value(updated.remindTime),
      repeatRule: Value(updated.repeatRule),
      status: Value(updated.status),
      createdAt: Value(updated.createdAt),
      updatedAt: Value(updated.updatedAt),
    ));
    return updated;
  }

  Future<LifeItem> completeAndGenerateNext(int id) async {
    final item = await _db.lifeItemDao.getById(id);
    await complete(id);

    final rule = RepeatRule.fromStorageString(item.repeatRule!);
    final nextDue = rule.nextDate(item.dueTime);

    return create(
      title: item.title,
      description: item.description,
      categoryId: item.categoryId,
      itemType: item.itemType,
      amount: item.amount,
      amountType: item.amountType,
      dueTime: nextDue,
      remindTime: item.remindTime != null ? rule.nextDate(item.remindTime!) : null,
      repeatRule: item.repeatRule,
      status: 'pending',
    );
  }

  Future<int> countCompletedInMonth(DateTime month) => _db.lifeItemDao.countCompletedInMonth(month);
}
