import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/calendar/add2calendar_event_gateway.dart';
import 'core/notifications/notification_service.dart';
import 'core/notifications/reminder_scheduler.dart';
import 'features/life_item/providers/life_item_providers.dart';
import 'features/settings/providers/settings_providers.dart';
import 'features/settings/services/file_picker_backup_file_gateway.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ProviderScope(
      overrides: [
        backupFileGatewayProvider.overrideWithValue(
          FilePickerBackupFileGateway(),
        ),
        reminderSchedulerProvider.overrideWithValue(
          const NotificationReminderScheduler(),
        ),
        calendarEventGatewayProvider.overrideWithValue(
          const Add2CalendarEventGateway(),
        ),
      ],
      child: const App(),
    ),
  );
  unawaited(NotificationService.init());
}
