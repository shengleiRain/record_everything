import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/reminder_scheduler.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/database_provider.dart';
import '../../../data/repositories/category_repository.dart';
import '../../life_item/providers/life_item_providers.dart';
import '../services/backup_file_gateway.dart';
import '../services/backup_service.dart';

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository(ref.watch(databaseProvider));
});

final categoriesProvider = StreamProvider<List<Category>>((ref) {
  return ref.watch(categoryRepositoryProvider).watchAll();
});

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(ref.watch(databaseProvider));
});

final backupFileGatewayProvider = Provider<BackupFileGateway>((ref) {
  return const UnconfiguredBackupFileGateway();
});

class CategoryNotifier extends Notifier<void> {
  @override
  void build() {}

  CategoryRepository get _repo => ref.read(categoryRepositoryProvider);

  Future<Category> create({
    required String name,
    required String type,
    String icon = 'category',
  }) {
    return _repo.create(name: name, type: type, icon: icon);
  }

  Future<Category> update(Category category) => _repo.updateCategory(category);

  Future<void> delete(int id) => _repo.deleteCategory(id);
}

final categoryNotifierProvider = NotifierProvider<CategoryNotifier, void>(
  CategoryNotifier.new,
);

class SettingsNotifier extends Notifier<void> {
  @override
  void build() {}

  AppDatabase get _db => ref.read(databaseProvider);

  Future<String> exportToJson() async {
    return BackupService(_db).exportToJson();
  }

  Future<BackupImportSummary> importFromJson(String jsonString) async {
    final summary = await BackupService(_db).importFromJson(jsonString);
    await _rebuildFutureReminders();
    return summary;
  }

  Future<String?> exportWithFilePicker() async {
    final json = await ref.read(backupServiceProvider).exportToJson();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return ref
        .read(backupFileGatewayProvider)
        .saveBackupJson(
          fileName: 'life_items_backup_$timestamp.json',
          content: json,
        );
  }

  Future<BackupImportSummary?> importWithFilePicker() async {
    final json = await ref.read(backupFileGatewayProvider).pickBackupJson();
    if (json == null) return null;
    final summary = await ref.read(backupServiceProvider).importFromJson(json);
    await _rebuildFutureReminders();
    return summary;
  }

  Future<void> _rebuildFutureReminders() async {
    final scheduler = ref.read(reminderSchedulerProvider);
    final items = await _db.lifeItemDao.getAll();
    for (final item in items) {
      if (_shouldScheduleReminder(item, scheduler)) {
        await scheduler.schedule(
          id: item.id,
          title: item.title,
          body: '事项即将到期',
          scheduledTime: item.remindTime!,
        );
      }
    }
  }
}

bool _shouldScheduleReminder(LifeItem item, ReminderScheduler scheduler) {
  final remindTime = item.remindTime;
  if (remindTime == null) return false;
  if (item.status != 'pending') return false;
  return remindTime.isAfter(scheduler.currentTime);
}

final settingsNotifierProvider = NotifierProvider<SettingsNotifier, void>(
  SettingsNotifier.new,
);
