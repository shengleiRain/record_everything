import 'notification_service.dart';

abstract class ReminderScheduler {
  DateTime get currentTime;

  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  });

  Future<void> cancel(int id);
}

class NoopReminderScheduler implements ReminderScheduler {
  const NoopReminderScheduler();

  @override
  DateTime get currentTime => DateTime.now();

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {}

  @override
  Future<void> cancel(int id) async {}
}

class NotificationReminderScheduler implements ReminderScheduler {
  const NotificationReminderScheduler();

  @override
  DateTime get currentTime => DateTime.now();

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    await NotificationService.init();
    await NotificationService.scheduleReminder(
      id: id,
      title: title,
      body: body,
      scheduledTime: scheduledTime,
    );
  }

  @override
  Future<void> cancel(int id) async {
    await NotificationService.init();
    await NotificationService.cancelReminder(id);
  }
}
