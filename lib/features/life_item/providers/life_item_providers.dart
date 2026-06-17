import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/calendar/calendar_event_service.dart';
import '../../../core/notifications/reminder_scheduler.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/database_provider.dart';
import '../../../data/repositories/life_item_repository.dart';

final lifeItemRepoProvider = Provider<LifeItemRepository>((ref) {
  return LifeItemRepository(ref.watch(databaseProvider));
});

final reminderSchedulerProvider = Provider<ReminderScheduler>((ref) {
  return const NoopReminderScheduler();
});

final calendarEventGatewayProvider = Provider<CalendarEventGateway>((ref) {
  return const NoopCalendarEventGateway();
});

final calendarEventServiceProvider = Provider<CalendarEventService>((ref) {
  return CalendarEventService(ref.watch(calendarEventGatewayProvider));
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

final itemTemplatesProvider = StreamProvider<List<ItemTemplate>>((ref) {
  return ref.watch(lifeItemRepoProvider).watchTemplates();
});

final itemTemplateRecommendationsProvider = FutureProvider.autoDispose
    .family<List<ItemTemplate>, String>((ref, title) {
      return ref.watch(lifeItemRepoProvider).recommendTemplates(title);
    });

class LifeItemNotifier extends Notifier<void> {
  @override
  void build() {}

  LifeItemRepository get _repo => ref.read(lifeItemRepoProvider);
  ReminderScheduler get _scheduler => ref.read(reminderSchedulerProvider);
  CalendarEventService get _calendarEventService =>
      ref.read(calendarEventServiceProvider);

  Future<LifeItem> create(Map<String, dynamic> data) async {
    final item = await _repo.create(
      title: data['title'] as String,
      description: data['description'] as String?,
      categoryId: data['categoryId'] as int?,
      projectId: data['projectId'] as int?,
      itemType: data['itemType'] as String? ?? 'todo',
      amount: data['amount'] as int?,
      amountType: data['amountType'] as String? ?? 'none',
      dueTime: data['dueTime'] as DateTime,
      remindTime: data['remindTime'] as DateTime?,
      repeatRule: data['repeatRule'] as String?,
    );
    await _scheduleIfNeeded(item);
    return item;
  }

  Future<LifeItem> update(LifeItem item) async {
    final updated = await _repo.updateItem(item);
    await _rebuildReminder(updated);
    return updated;
  }

  Future<void> delete(int id) async {
    await _repo.deleteItem(id);
    await _scheduler.cancel(id);
  }

  Future<LifeItem> complete(int id) async {
    final updated = await _repo.complete(id);
    await _scheduler.cancel(id);
    return updated;
  }

  Future<LifeItem> cancel(int id) async {
    final updated = await _repo.cancel(id);
    await _scheduler.cancel(id);
    return updated;
  }

  Future<LifeItem> reopen(int id) async {
    final updated = await _repo.reopen(id);
    // 重新打开后，若仍有未来的提醒时间，需要重新排提醒。
    await _rebuildReminder(updated);
    return updated;
  }

  Future<LifeItem> defer(int id, DateTime newDate) async {
    final updated = await _repo.defer(id, newDate);
    await _rebuildReminder(updated);
    return updated;
  }

  Future<LifeItem> completeAndGenerateNext(int id) async {
    final next = await _repo.completeAndGenerateNext(id);
    await _scheduler.cancel(id);
    await _scheduleIfNeeded(next);
    return next;
  }

  Future<void> requestCreateCalendarEvent(LifeItem item) {
    return _calendarEventService.requestCreateEvent(item);
  }

  Future<void> _rebuildReminder(LifeItem item) async {
    await _scheduler.cancel(item.id);
    await _scheduleIfNeeded(item);
  }

  Future<void> _scheduleIfNeeded(LifeItem item) async {
    final remindTime = item.remindTime;
    if (remindTime == null) return;
    if (item.status != 'pending') return;
    if (!remindTime.isAfter(_scheduler.currentTime)) return;
    await _scheduler.schedule(
      id: item.id,
      title: item.title,
      body: '事项即将到期',
      scheduledTime: remindTime,
    );
  }
}

final lifeItemNotifierProvider = NotifierProvider<LifeItemNotifier, void>(
  LifeItemNotifier.new,
);
