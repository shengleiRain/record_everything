import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/notifications/reminder_scheduler.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/database_provider.dart';
import '../../../data/repositories/category_repository.dart';
import '../../life_item/providers/life_item_providers.dart';
import '../models/backup_file_entry.dart';
import '../models/webdav_config.dart';
import '../services/backup_file_gateway.dart';
import '../services/backup_service.dart';
import '../services/webdav_backup_file_gateway.dart';
import '../services/webdav_config_store.dart';

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository(ref.watch(databaseProvider));
});

final categoriesProvider = StreamProvider<List<Category>>((ref) {
  return ref.watch(categoryRepositoryProvider).watchAll();
});

/// Categories filtered by [type] (e.g. 'income', 'expense', 'item', 'project').
///
/// Uses a [FutureProvider] (one-shot) rather than a [StreamProvider] because
/// the form pages read the category list once on open — they don't need to
/// react to live changes, and a stream would prevent widget-test
/// `pumpAndSettle` from ever completing. Callers that need fresh data after a
/// category edit can `ref.invalidate` this provider.
final categoriesByTypeProvider =
    FutureProvider.family<List<Category>, String>((ref, type) {
      return ref.watch(categoryRepositoryProvider).getByType(type);
    });

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(ref.watch(databaseProvider));
});

final backupFileGatewayProvider = Provider<BackupFileGateway>((ref) {
  return UnconfiguredBackupFileGateway();
});

// WebDAV configuration store provider
final webdavConfigStoreProvider = FutureProvider<WebDavConfigStore>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return WebDavConfigStore(
    prefs: prefs,
    secureStorage: const FlutterSecureStorage(),
  );
});

// WebDAV configuration provider (null = not configured)
final webdavConfigProvider = FutureProvider<WebDavConfig?>((ref) async {
  final store = await ref.watch(webdavConfigStoreProvider.future);
  return store.load();
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

  Future<void> setHidden(int id, bool hidden) => _repo.setHidden(id, hidden);

  Future<void> setPinned(int id, bool pinned) => _repo.setPinned(id, pinned);

  Future<void> merge({required int sourceId, required int targetId}) =>
      _repo.mergeCategory(sourceId: sourceId, targetId: targetId);
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

  // --- WebDAV methods ---

  Future<void> exportToWebDav() async {
    final config = await ref.read(webdavConfigProvider.future);
    if (config == null) throw StateError('WebDAV 未配置');
    final json = await ref.read(backupServiceProvider).exportToJson();
    final gateway = WebDavBackupFileGateway(config);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    await gateway.saveBackupJson(
      fileName: 'life_items_backup_$timestamp.json',
      content: json,
    );
  }

  Future<BackupImportSummary?> importFromWebDav(String fileName) async {
    final config = await ref.read(webdavConfigProvider.future);
    if (config == null) throw StateError('WebDAV 未配置');
    final gateway = WebDavBackupFileGateway(config);
    final json = await gateway.fetchBackupJson(fileName);
    if (json == null) return null;
    final summary = await ref.read(backupServiceProvider).importFromJson(json);
    await _rebuildFutureReminders();
    return summary;
  }

  Future<List<BackupFileEntry>> listWebDavBackups() async {
    final config = await ref.read(webdavConfigProvider.future);
    if (config == null) throw StateError('WebDAV 未配置');
    final gateway = WebDavBackupFileGateway(config);
    return gateway.listBackupFiles();
  }

  Future<bool> testWebDavConnection() async {
    final config = await ref.read(webdavConfigProvider.future);
    if (config == null) return false;
    try {
      final gateway = WebDavBackupFileGateway(config);
      await gateway.listBackupFiles();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> saveWebDavConfig(WebDavConfig config) async {
    final store = await ref.read(webdavConfigStoreProvider.future);
    await store.save(config);
    ref.invalidate(webdavConfigProvider);
  }

  Future<void> clearWebDavConfig() async {
    final store = await ref.read(webdavConfigStoreProvider.future);
    await store.clear();
    ref.invalidate(webdavConfigProvider);
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
