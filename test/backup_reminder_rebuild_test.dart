import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record_everything/core/notifications/reminder_scheduler.dart';
import 'package:record_everything/data/database/app_database.dart';
import 'package:record_everything/data/database/database_provider.dart';
import 'package:record_everything/features/life_item/providers/life_item_providers.dart';
import 'package:record_everything/features/settings/providers/settings_providers.dart';

void main() {
  test('backup import rebuilds future pending reminders only', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final scheduler = FakeReminderScheduler(now: DateTime(2026, 6, 6, 8));
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        reminderSchedulerProvider.overrideWithValue(scheduler),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await db.close();
    });

    await container
        .read(settingsNotifierProvider.notifier)
        .importFromJson(
          jsonEncode({
            'version': 1,
            'categories': [],
            'lifeItems': [
              {
                'id': 1,
                'title': '未来提醒',
                'dueTime': '2026-06-06T18:00:00.000',
                'remindTime': '2026-06-06T09:00:00.000',
                'status': 'pending',
              },
              {
                'id': 2,
                'title': '过期提醒',
                'dueTime': '2026-06-06T18:00:00.000',
                'remindTime': '2026-06-06T07:00:00.000',
                'status': 'pending',
              },
              {
                'id': 3,
                'title': '已完成提醒',
                'dueTime': '2026-06-06T18:00:00.000',
                'remindTime': '2026-06-06T09:30:00.000',
                'status': 'completed',
              },
            ],
            'billRecords': [],
          }),
        );

    expect(scheduler.scheduled.map((call) => call.title), ['未来提醒']);
    expect(scheduler.cancelled, isEmpty);
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
}
