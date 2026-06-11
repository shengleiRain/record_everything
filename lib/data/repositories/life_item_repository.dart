import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../../domain/models/repeat_rule.dart';

class LifeItemRepository {
  final AppDatabase _db;
  LifeItemRepository(this._db);

  Stream<List<LifeItem>> watchAll() => _db.lifeItemDao.watchAll();
  Stream<List<LifeItem>> watchBetween(DateTime start, DateTime end) =>
      _db.lifeItemDao.watchBetween(start, end);
  Stream<List<LifeItem>> watchTodayPending() =>
      _db.lifeItemDao.watchTodayPending();
  Stream<List<LifeItem>> watchUpcoming(int days) =>
      _db.lifeItemDao.watchUpcoming(days);
  Stream<List<LifeItem>> watchOverdue() => _db.lifeItemDao.watchOverdue();
  Stream<List<LifeItem>> watchForecastExpenses(int days) =>
      _db.lifeItemDao.watchForecastExpenses(days);
  Stream<LifeItem> watchById(int id) => _db.lifeItemDao.watchById(id);

  Stream<List<ItemTemplate>> watchTemplates() => _db.itemTemplateDao.watchAll();

  Future<List<ItemTemplate>> getTemplates() => _db.itemTemplateDao.getAll();

  Future<ItemTemplate> getTemplateById(int id) =>
      _db.itemTemplateDao.getById(id);

  Future<List<ItemTemplate>> recommendTemplates(String title) async {
    final normalized = title.trim().toLowerCase();
    if (normalized.isEmpty) return const [];
    final templates = await _db.itemTemplateDao.getAll();
    final matches = templates.where((template) {
      final words = [
        template.name,
        ...template.keywords
            .split(',')
            .map((word) => word.trim())
            .where((word) => word.isNotEmpty),
      ];
      return words.any((word) => normalized.contains(word.toLowerCase()));
    }).toList();
    return matches.take(3).toList(growable: false);
  }

  Future<LifeItem> create({
    required String title,
    String? description,
    int? categoryId,
    int? projectId,
    String itemType = 'todo',
    int? amount,
    String amountType = 'none',
    required DateTime dueTime,
    DateTime? remindTime,
    String? repeatRule,
    String status = 'pending',
  }) async {
    final item = await _db.lifeItemDao.insertOne(
      LifeItemsCompanion.insert(
        title: title,
        description: Value(description),
        categoryId: Value(categoryId),
        projectId: Value(projectId),
        itemType: Value(itemType),
        amount: Value(amount),
        amountType: Value(amountType),
        dueTime: dueTime,
        remindTime: Value(remindTime),
        repeatRule: Value(repeatRule),
        status: Value(status),
      ),
    );
    await _markCategoryUsed(categoryId);
    return item;
  }

  Future<LifeItem> updateItem(LifeItem item) async {
    await _db.lifeItemDao.updateOne(
      LifeItemsCompanion(
        id: Value(item.id),
        title: Value(item.title),
        description: Value(item.description),
        categoryId: Value(item.categoryId),
        projectId: Value(item.projectId),
        itemType: Value(item.itemType),
        amount: Value(item.amount),
        amountType: Value(item.amountType),
        dueTime: Value(item.dueTime),
        remindTime: Value(item.remindTime),
        repeatRule: Value(item.repeatRule),
        status: Value(item.status),
        createdAt: Value(item.createdAt),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await _markCategoryUsed(item.categoryId);
    return item;
  }

  Future<void> deleteItem(int id) => _db.lifeItemDao.softDeleteById(id);

  Future<void> restoreItem(int id) => _db.lifeItemDao.restoreById(id);

  Future<LifeItem> complete(int id) async {
    final item = await _db.lifeItemDao.getById(id);
    final updated = item.copyWith(
      status: 'completed',
      updatedAt: DateTime.now(),
    );
    await _db.lifeItemDao.updateOne(
      LifeItemsCompanion(
        id: Value(updated.id),
        title: Value(updated.title),
        description: Value(updated.description),
        categoryId: Value(updated.categoryId),
        projectId: Value(updated.projectId),
        itemType: Value(updated.itemType),
        amount: Value(updated.amount),
        amountType: Value(updated.amountType),
        dueTime: Value(updated.dueTime),
        remindTime: Value(updated.remindTime),
        repeatRule: Value(updated.repeatRule),
        status: Value(updated.status),
        createdAt: Value(updated.createdAt),
        updatedAt: Value(updated.updatedAt),
      ),
    );
    await _markCategoryUsed(updated.categoryId);
    return updated;
  }

  Future<LifeItem> defer(int id, DateTime newDueTime) async {
    final item = await _db.lifeItemDao.getById(id);
    final updated = item.copyWith(
      dueTime: newDueTime,
      updatedAt: DateTime.now(),
    );
    await _db.lifeItemDao.updateOne(
      LifeItemsCompanion(
        id: Value(updated.id),
        title: Value(updated.title),
        description: Value(updated.description),
        categoryId: Value(updated.categoryId),
        projectId: Value(updated.projectId),
        itemType: Value(updated.itemType),
        amount: Value(updated.amount),
        amountType: Value(updated.amountType),
        dueTime: Value(updated.dueTime),
        remindTime: Value(updated.remindTime),
        repeatRule: Value(updated.repeatRule),
        status: Value(updated.status),
        createdAt: Value(updated.createdAt),
        updatedAt: Value(updated.updatedAt),
      ),
    );
    await _markCategoryUsed(updated.categoryId);
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
      projectId: item.projectId,
      itemType: item.itemType,
      amount: item.amount,
      amountType: item.amountType,
      dueTime: nextDue,
      remindTime: item.remindTime != null
          ? rule.nextDate(item.remindTime!)
          : null,
      repeatRule: item.repeatRule,
      status: 'pending',
    );
  }

  Future<int> countCompletedInMonth(DateTime month) =>
      _db.lifeItemDao.countCompletedInMonth(month);
  Stream<int> watchCompletedCountInMonth(DateTime month) =>
      _db.lifeItemDao.watchCompletedCountInMonth(month);

  Future<void> _markCategoryUsed(int? categoryId) async {
    if (categoryId == null) return;
    await _db.categoryDao.markUsed(categoryId);
  }
}
