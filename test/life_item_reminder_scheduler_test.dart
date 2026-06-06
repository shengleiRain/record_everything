import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record_everything/core/notifications/reminder_scheduler.dart';
import 'package:record_everything/data/database/app_database.dart';
import 'package:record_everything/data/database/database_provider.dart';
import 'package:record_everything/features/life_item/providers/life_item_providers.dart';

void main() {
  group('LifeItem reminder scheduling', () {
    late AppDatabase db;
    late FakeReminderScheduler scheduler;
    late ProviderContainer container;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      scheduler = FakeReminderScheduler(now: DateTime(2026, 6, 6, 8));
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          reminderSchedulerProvider.overrideWithValue(scheduler),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('schedules a future reminder after creating an item', () async {
      final remindTime = DateTime(2026, 6, 6, 9);

      final item = await container
          .read(lifeItemNotifierProvider.notifier)
          .create({
            'title': '交房租',
            'dueTime': DateTime(2026, 6, 6, 18),
            'remindTime': remindTime,
          });

      expect(scheduler.scheduled, [
        ScheduledReminderCall(
          id: item.id,
          title: '交房租',
          body: '事项即将到期',
          scheduledTime: remindTime,
        ),
      ]);
      expect(scheduler.cancelled, isEmpty);
    });

    test('does not schedule missing or past reminder times', () async {
      await container.read(lifeItemNotifierProvider.notifier).create({
        'title': '无提醒',
        'dueTime': DateTime(2026, 6, 6, 18),
      });
      await container.read(lifeItemNotifierProvider.notifier).create({
        'title': '过期提醒',
        'dueTime': DateTime(2026, 6, 6, 18),
        'remindTime': DateTime(2026, 6, 6, 7),
      });

      expect(scheduler.scheduled, isEmpty);
      expect(scheduler.cancelled, isEmpty);
    });

    test('rebuilds reminder when updating an item', () async {
      final item = await container
          .read(lifeItemNotifierProvider.notifier)
          .create({
            'title': '交水费',
            'dueTime': DateTime(2026, 6, 6, 18),
            'remindTime': DateTime(2026, 6, 6, 9),
          });
      scheduler.clear();

      await container
          .read(lifeItemNotifierProvider.notifier)
          .update(
            item.copyWith(
              title: '交水电费',
              remindTime: Value(DateTime(2026, 6, 6, 10)),
            ),
          );

      expect(scheduler.cancelled, [item.id]);
      expect(scheduler.scheduled.single.title, '交水电费');
      expect(
        scheduler.scheduled.single.scheduledTime,
        DateTime(2026, 6, 6, 10),
      );
    });

    test('cancels reminders when completing or deleting items', () async {
      final first = await container
          .read(lifeItemNotifierProvider.notifier)
          .create({
            'title': '完成事项',
            'dueTime': DateTime(2026, 6, 6, 18),
            'remindTime': DateTime(2026, 6, 6, 9),
          });
      final second = await container
          .read(lifeItemNotifierProvider.notifier)
          .create({
            'title': '删除事项',
            'dueTime': DateTime(2026, 6, 6, 18),
            'remindTime': DateTime(2026, 6, 6, 10),
          });
      scheduler.clear();

      await container
          .read(lifeItemNotifierProvider.notifier)
          .complete(first.id);
      await container.read(lifeItemNotifierProvider.notifier).delete(second.id);

      expect(scheduler.cancelled, [first.id, second.id]);
      expect(scheduler.scheduled, isEmpty);
    });
  });
}

class FakeReminderScheduler implements ReminderScheduler {
  FakeReminderScheduler({required this.now});

  final DateTime now;
  final scheduled = <ScheduledReminderCall>[];
  final cancelled = <int>[];

  @override
  DateTime get currentTime => now;

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    scheduled.add(
      ScheduledReminderCall(
        id: id,
        title: title,
        body: body,
        scheduledTime: scheduledTime,
      ),
    );
  }

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
  }

  void clear() {
    scheduled.clear();
    cancelled.clear();
  }
}

class ScheduledReminderCall {
  const ScheduledReminderCall({
    required this.id,
    required this.title,
    required this.body,
    required this.scheduledTime,
  });

  final int id;
  final String title;
  final String body;
  final DateTime scheduledTime;

  @override
  bool operator ==(Object other) {
    return other is ScheduledReminderCall &&
        other.id == id &&
        other.title == title &&
        other.body == body &&
        other.scheduledTime == scheduledTime;
  }

  @override
  int get hashCode => Object.hash(id, title, body, scheduledTime);

  @override
  String toString() {
    return 'ScheduledReminderCall($id, $title, $body, $scheduledTime)';
  }
}
