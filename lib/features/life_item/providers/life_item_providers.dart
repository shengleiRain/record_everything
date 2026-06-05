import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/database_provider.dart';
import '../../../data/repositories/life_item_repository.dart';

final lifeItemRepoProvider = Provider<LifeItemRepository>((ref) {
  return LifeItemRepository(ref.watch(databaseProvider));
});

final lifeItemsProvider = StreamProvider<List<LifeItem>>((ref) {
  return ref.watch(lifeItemRepoProvider).watchAll();
});

final todayPendingProvider = StreamProvider<List<LifeItem>>((ref) {
  return ref.watch(lifeItemRepoProvider).watchTodayPending();
});

final upcomingItemsProvider = StreamProvider<List<LifeItem>>((ref) {
  return ref.watch(lifeItemRepoProvider).watchUpcoming(7);
});

final overdueItemsProvider = StreamProvider<List<LifeItem>>((ref) {
  return ref.watch(lifeItemRepoProvider).watchOverdue();
});

final forecastExpensesProvider = StreamProvider<List<LifeItem>>((ref) {
  return ref.watch(lifeItemRepoProvider).watchForecastExpenses(30);
});

final lifeItemByIdProvider = StreamProvider.family<LifeItem, int>((ref, id) {
  return ref.watch(lifeItemRepoProvider).watchById(id);
});

class LifeItemNotifier extends Notifier<void> {
  @override
  void build() {}

  LifeItemRepository get _repo => ref.read(lifeItemRepoProvider);

  Future<LifeItem> create(Map<String, dynamic> data) => _repo.create(
    title: data['title'] as String,
    description: data['description'] as String?,
    categoryId: data['categoryId'] as int?,
    itemType: data['itemType'] as String? ?? 'todo',
    amount: data['amount'] as int?,
    amountType: data['amountType'] as String? ?? 'none',
    dueTime: data['dueTime'] as DateTime,
    remindTime: data['remindTime'] as DateTime?,
    repeatRule: data['repeatRule'] as String?,
  );

  Future<LifeItem> update(LifeItem item) => _repo.updateItem(item);

  Future<void> delete(int id) => _repo.deleteItem(id);

  Future<LifeItem> complete(int id) => _repo.complete(id);

  Future<LifeItem> defer(int id, DateTime newDate) => _repo.defer(id, newDate);

  Future<LifeItem> completeAndGenerateNext(int id) =>
      _repo.completeAndGenerateNext(id);
}

final lifeItemNotifierProvider = NotifierProvider<LifeItemNotifier, void>(
  LifeItemNotifier.new,
);
