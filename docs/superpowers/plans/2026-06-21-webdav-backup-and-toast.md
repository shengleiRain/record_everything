# WebDAV 备份增强 + Toast 工具类 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 升级备份格式到 v7（含 Accounts/MonthlyBudgets），集成 WebDAV 作为手动导入导出通道，自建 Toast 工具类替换全项目 SnackBar。

**Architecture:** 扩展现有 `BackupFileGateway` 接口，新增 `WebDavBackupFileGateway` 实现。`webdav_client` 包提供 WebDAV 操作。配置存 SharedPreferences + flutter_secure_storage。Toast 基于 Flutter Overlay 自建。

**Tech Stack:** Flutter 3.41, Dart 3.11, Drift (SQLite), Riverpod, `webdav_client` 包, `flutter_secure_storage`, `shared_preferences`

---

## File Structure

### New Files

| Path | Responsibility |
|------|---------------|
| `lib/core/utils/toast.dart` | Toast 工具类 + `_ToastWidget` overlay 组件 |
| `lib/features/settings/models/backup_file_entry.dart` | `BackupFileEntry` 数据模型 |
| `lib/features/settings/models/webdav_config.dart` | `WebDavConfig` 数据模型 |
| `lib/features/settings/services/webdav_config_store.dart` | WebDAV 配置读写（SP + secure_storage） |
| `lib/features/settings/services/webdav_backup_file_gateway.dart` | `WebDavBackupFileGateway` 实现 |
| `lib/features/settings/pages/webdav_settings_page.dart` | WebDAV 配置页面 UI |
| `test/toast_test.dart` | Toast 工具类 widget 测试 |
| `test/backup_service_v7_test.dart` | 备份 v7 单元测试 |
| `test/webdav_config_store_test.dart` | WebDAV 配置存储测试 |
| `test/webdav_backup_file_gateway_test.dart` | WebDAV 网关单元测试 |

### Modified Files

| Path | Change |
|------|--------|
| `pubspec.yaml` | 新增 `webdav_client` 依赖 |
| `lib/features/settings/services/backup_service.dart` | v7 导出/导入 accounts+monthlyBudgets |
| `lib/features/settings/services/backup_file_gateway.dart` | 接口新增 3 个方法 |
| `lib/features/settings/services/file_picker_backup_file_gateway.dart` | 新方法抛 UnimplementedError |
| `lib/features/settings/providers/settings_providers.dart` | 新增 webdav 相关 provider + SettingsNotifier 扩展 |
| `lib/features/settings/pages/data_safety_page.dart` | 通道选择 UI + Toast 替换 |
| `lib/features/settings/pages/settings_page.dart` | 新增 WebDAV 入口 + Toast 替换 |
| `lib/core/router/app_router.dart` | 新增 `/settings/webdav` 路由 |
| 15 个 UI 文件 | SnackBar → Toast 全局替换 |

---

## Task 1: Toast 工具类

**Files:**
- Create: `lib/core/utils/toast.dart`
- Create: `test/toast_test.dart`

- [ ] **Step 1: 添加 `oktoast` 依赖到 pubspec.yaml**

实际上我们决定自建 Toast。先确认不需要额外依赖。

- [ ] **Step 2: 创建 Toast 工具类**

```dart
// lib/core/utils/toast.dart
import 'package:flutter/material.dart';

enum ToastType { success, error, info }

class Toast {
  static void show(
    BuildContext context,
    String message, {
    ToastType type = ToastType.info,
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ToastWidget(
        message: message,
        type: type,
        onDismiss: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 2), () {
      if (entry.mounted) entry.remove();
    });
  }

  static void success(BuildContext context, String msg) =>
      show(context, msg, type: ToastType.success);

  static void error(BuildContext context, String msg) =>
      show(context, msg, type: ToastType.error);

  static void info(BuildContext context, String msg) =>
      show(context, msg, type: ToastType.info);
}

class _ToastWidget extends StatefulWidget {
  const _ToastWidget({
    required this.message,
    required this.type,
    required this.onDismiss,
  });

  final String message;
  final ToastType type;
  final VoidCallback onDismiss;

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  IconData get _icon => switch (widget.type) {
        ToastType.success => Icons.check_circle_outline,
        ToastType.error => Icons.error_outline,
        ToastType.info => Icons.info_outline,
      };

  Color get _color => switch (widget.type) {
        ToastType.success => const Color(0xFF4CAF50),
        ToastType.error => const Color(0xFFE53935),
        ToastType.info => const Color(0xFF1E88E5),
      };

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: MediaQuery.of(context).size.height * 0.15,
      left: 40,
      right: 40,
      child: FadeTransition(
        opacity: _opacity,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF323232),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget._icon, color: _color, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: 创建 Toast widget 测试**

```dart
// test/toast_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record_everything/core/utils/toast.dart';

void main() {
  group('Toast', () {
    testWidgets('shows success toast with message', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Toast.success(context, '操作成功'),
                child: const Text('show'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('show'));
      await tester.pump();
      expect(find.text('操作成功'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets('shows error toast with message', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Toast.error(context, '操作失败'),
                child: const Text('show'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('show'));
      await tester.pump();
      expect(find.text('操作失败'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('shows info toast with message', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Toast.info(context, '提示信息'),
                child: const Text('show'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('show'));
      await tester.pump();
      expect(find.text('提示信息'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });

    testWidgets('auto-dismisses after 2 seconds', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Toast.info(context, '将消失'),
                child: const Text('show'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('show'));
      await tester.pump();
      expect(find.text('将消失'), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(find.text('将消失'), findsNothing);
    });
  });
}
```

- [ ] **Step 4: 运行测试验证通过**

Run: `flutter test test/toast_test.dart`
Expected: All 4 tests PASS

- [ ] **Step 5: Commit**

```bash
git add lib/core/utils/toast.dart test/toast_test.dart
git commit -m "feat: add Toast utility class based on Overlay"
```

---

## Task 2: 备份数据模型

**Files:**
- Create: `lib/features/settings/models/backup_file_entry.dart`
- Create: `lib/features/settings/models/webdav_config.dart`

- [ ] **Step 1: 创建 BackupFileEntry 模型**

```dart
// lib/features/settings/models/backup_file_entry.dart
class BackupFileEntry {
  const BackupFileEntry({
    required this.fileName,
    required this.sizeBytes,
    required this.modifiedAt,
  });

  final String fileName;
  final int sizeBytes;
  final DateTime modifiedAt;

  String get displaySize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
```

- [ ] **Step 2: 创建 WebDavConfig 模型**

```dart
// lib/features/settings/models/webdav_config.dart
class WebDavConfig {
  const WebDavConfig({
    required this.serverUrl,
    required this.username,
    required this.password,
    required this.remotePath,
  });

  final String serverUrl;
  final String username;
  final String password;
  final String remotePath;

  /// Returns [serverUrl] without trailing slash.
  String get baseUrl => serverUrl.endsWith('/')
      ? serverUrl.substring(0, serverUrl.length - 1)
      : serverUrl;

  /// Returns [remotePath] with leading slash, without trailing slash.
  String get normalizedPath {
    var p = remotePath;
    if (!p.startsWith('/')) p = '/$p';
    if (p.endsWith('/') && p.length > 1) {
      p = p.substring(0, p.length - 1);
    }
    return p;
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/features/settings/models/
git commit -m "feat: add BackupFileEntry and WebDavConfig models"
```

---

## Task 3: 备份格式升级 v7

**Files:**
- Modify: `lib/features/settings/services/backup_service.dart`
- Create: `test/backup_service_v7_test.dart`

- [ ] **Step 1: 编写 v7 备份测试**

```dart
// test/backup_service_v7_test.dart
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record_everything/data/database/app_database.dart';
import 'package:record_everything/data/repositories/account_repository.dart';
import 'package:record_everything/data/repositories/budget_repository.dart';
import 'package:record_everything/data/repositories/category_repository.dart';
import 'package:record_everything/data/repositories/life_item_repository.dart';
import 'package:record_everything/features/settings/services/backup_service.dart';

void main() {
  group('BackupService v7', () {
    late AppDatabase db;
    late BackupService service;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      service = BackupService(db);
    });

    tearDown(() => db.close());

    test('exports accounts and monthlyBudgets in v7 format', () async {
      await AccountRepository(db).ensureDefaultAccount();
      await BudgetRepository(db).setMonthlyBudget(DateTime(2026, 6, 1), 500000);

      final jsonText = await service.exportToJson();
      final data = jsonDecode(jsonText) as Map<String, Object?>;

      expect(data['version'], 7);
      expect(data['accounts'], isA<List>());
      expect((data['accounts'] as List).length, 1);
      expect(data['monthlyBudgets'], isA<List>());
      expect((data['monthlyBudgets'] as List).length, 1);
    });

    test('imports accounts and monthlyBudgets from v7 backup', () async {
      final jsonText = jsonEncode({
        'version': 7,
        'categories': [],
        'lifeItems': [],
        'billRecords': [],
        'projects': [],
        'projectEvents': [],
        'projectTemplates': [],
        'projectTemplateSteps': [],
        'itemTemplates': [],
        'accounts': [
          {
            'id': 1,
            'name': '微信钱包',
            'type': 'wechat',
            'isDefault': false,
            'createdAt': '2026-01-01T00:00:00.000',
          },
        ],
        'monthlyBudgets': [
          {
            'id': 1,
            'monthStart': '2026-06-01T00:00:00.000',
            'amount': 800000,
            'createdAt': '2026-06-01T00:00:00.000',
            'updatedAt': '2026-06-01T00:00:00.000',
          },
        ],
      });

      final summary = await service.importFromJson(jsonText);

      expect(summary.accountsImported, 1);
      expect(summary.monthlyBudgetsImported, 1);

      final accounts = await AccountRepository(db).getAll();
      expect(accounts.any((a) => a.name == '微信钱包'), isTrue);

      final budget = await BudgetRepository(db).getMonthlyBudget(
        DateTime(2026, 6, 1),
      );
      expect(budget, 800000);
    });

    test('v6 backup imports without accounts and budgets', () async {
      final jsonText = jsonEncode({
        'version': 6,
        'categories': [],
        'lifeItems': [],
        'billRecords': [],
        'projects': [],
        'projectEvents': [],
        'projectTemplates': [],
        'projectTemplateSteps': [],
        'itemTemplates': [],
      });

      final summary = await service.importFromJson(jsonText);

      expect(summary.accountsImported, 0);
      expect(summary.monthlyBudgetsImported, 0);
    });

    test('skips duplicate accounts by name+type', () async {
      final jsonText = jsonEncode({
        'version': 7,
        'categories': [],
        'lifeItems': [],
        'billRecords': [],
        'projects': [],
        'projectEvents': [],
        'projectTemplates': [],
        'projectTemplateSteps': [],
        'itemTemplates': [],
        'accounts': [
          {
            'id': 1,
            'name': '默认账户',
            'type': 'cash',
            'isDefault': true,
            'createdAt': '2026-01-01T00:00:00.000',
          },
        ],
        'monthlyBudgets': [],
      });

      // 确保默认账户已存在
      await AccountRepository(db).ensureDefaultAccount();

      final summary = await service.importFromJson(jsonText);
      expect(summary.accountsImported, 0);
    });

    test('skips duplicate monthlyBudgets by monthStart', () async {
      final jsonText = jsonEncode({
        'version': 7,
        'categories': [],
        'lifeItems': [],
        'billRecords': [],
        'projects': [],
        'projectEvents': [],
        'projectTemplates': [],
        'projectTemplateSteps': [],
        'itemTemplates': [],
        'accounts': [],
        'monthlyBudgets': [
          {
            'id': 1,
            'monthStart': '2026-06-01T00:00:00.000',
            'amount': 500000,
            'createdAt': '2026-06-01T00:00:00.000',
            'updatedAt': '2026-06-01T00:00:00.000',
          },
        ],
      });

      await BudgetRepository(db).setMonthlyBudget(DateTime(2026, 6, 1), 500000);

      final summary = await service.importFromJson(jsonText);
      expect(summary.monthlyBudgetsImported, 0);
    });
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `flutter test test/backup_service_v7_test.dart`
Expected: FAIL — `version 7` 不在合法版本集合中，`BackupImportSummary` 缺少 `accountsImported`/`monthlyBudgetsImported`

- [ ] **Step 3: 升级 BackupImportSummary**

在 `backup_service.dart` 的 `BackupImportSummary` 类中添加两个新字段：

```dart
class BackupImportSummary {
  const BackupImportSummary({
    required this.categoriesImported,
    required this.projectsImported,
    required this.lifeItemsImported,
    required this.billRecordsImported,
    required this.projectEventsImported,
    this.projectTemplatesImported = 0,
    this.projectTemplateStepsImported = 0,
    this.itemTemplatesImported = 0,
    this.accountsImported = 0,          // 新增
    this.monthlyBudgetsImported = 0,    // 新增
  });

  // ... 现有字段 ...
  final int accountsImported;
  final int monthlyBudgetsImported;
}
```

- [ ] **Step 4: 升级 exportToJson 导出 accounts + monthlyBudgets**

在 `exportToJson()` 方法中，在 `final data = {` 之前添加查询，在 data map 中添加两个新字段：

```dart
// 在 exportToJson() 中，现有 projectTemplateSteps 查询之后添加：
final accounts = await _db.select(_db.accounts).get();
final monthlyBudgets = await _db.select(_db.monthlyBudgets).get();

// 在 data map 中，'projectEvents' 之后添加：
'accounts': accounts.map(_accountToMap).toList(),
'monthlyBudgets': monthlyBudgets.map(_monthlyBudgetToMap).toList(),
```

在文件末尾添加两个新的序列化方法：

```dart
Map<String, Object?> _accountToMap(Account account) => {
  'id': account.id,
  'name': account.name,
  'type': account.type,
  'isDefault': account.isDefault,
  'createdAt': account.createdAt.toIso8601String(),
};

Map<String, Object?> _monthlyBudgetToMap(MonthlyBudget budget) => {
  'id': budget.id,
  'monthStart': budget.monthStart.toIso8601String(),
  'amount': budget.amount,
  'createdAt': budget.createdAt.toIso8601String(),
  'updatedAt': budget.updatedAt.toIso8601String(),
};
```

- [ ] **Step 5: 升级 _decodeAndValidate 支持 v7**

在 `_decodeAndValidate` 方法中：

```dart
// 修改版本验证（第 435-440 行附近）：
if (rawVersion is! int ||
    (rawVersion != 1 &&
        rawVersion != 2 &&
        rawVersion != 3 &&
        rawVersion != 4 &&
        rawVersion != 5 &&
        rawVersion != 6 &&
        rawVersion != 7)) {                    // 新增 v7
  throw const BackupFormatException('备份版本不受支持');
}

// 在 version >= 5 的 itemTemplates 处理之后添加：
if (version >= 7) {
  result['accounts'] = _optionalMapList(decoded, 'accounts');
  result['monthlyBudgets'] = _optionalMapList(decoded, 'monthlyBudgets');
} else {
  result['accounts'] = <Map<String, Object?>>[];
  result['monthlyBudgets'] = <Map<String, Object?>>[];
}
```

- [ ] **Step 6: 升级 importFromJson 导入 accounts + monthlyBudgets**

在 `importFromJson` 方法中，在 `final itemTemplates = version >= 5 ...` 之后添加：

```dart
final accounts = version >= 7
    ? data['accounts'] as List<Map<String, Object?>>
    : <Map<String, Object?>>[];
final monthlyBudgets = version >= 7
    ? data['monthlyBudgets'] as List<Map<String, Object?>>
    : <Map<String, Object?>>[];
```

在 transaction 内部，projectEvents 导入之后、return 之前添加 accounts 和 monthlyBudgets 导入逻辑：

```dart
// Import accounts
var accountsImported = 0;
for (final map in accounts) {
  final name = _requiredString(map, 'name');
  final type = _optionalString(map, 'type') ?? 'cash';
  final isDefault = _optionalBool(map, 'isDefault') ?? false;
  final createdAt = _optionalDate(map, 'createdAt') ?? DateTime.now();

  final existingAccounts = await _db.select(_db.accounts).get();
  final existing = existingAccounts.where(
    (a) => a.name == name && a.type == type,
  ).firstOrNull;
  if (existing != null) continue;

  await _db.into(_db.accounts).insert(
    AccountsCompanion.insert(
      name: name,
      type: Value(type),
      isDefault: Value(isDefault),
      createdAt: Value(createdAt),
    ),
  );
  accountsImported++;
}

// Import monthly budgets
var monthlyBudgetsImported = 0;
for (final map in monthlyBudgets) {
  final monthStart = _requiredDate(map, 'monthStart');
  final amount = _requiredInt(map, 'amount');
  final createdAt = _optionalDate(map, 'createdAt') ?? DateTime.now();
  final updatedAt = _optionalDate(map, 'updatedAt') ?? createdAt;

  final existing = await (_db.select(_db.monthlyBudgets)
    ..where((t) => t.monthStart.equals(monthStart))
  ).getSingleOrNull();
  if (existing != null) continue;

  await _db.into(_db.monthlyBudgets).insert(
    MonthlyBudgetsCompanion.insert(
      monthStart: monthStart,
      amount: amount,
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    ),
  );
  monthlyBudgetsImported++;
}
```

更新 return 语句：

```dart
return BackupImportSummary(
  // ... 现有字段 ...
  accountsImported: accountsImported,
  monthlyBudgetsImported: monthlyBudgetsImported,
);
```

- [ ] **Step 7: 运行测试验证通过**

Run: `flutter test test/backup_service_v7_test.dart`
Expected: All 5 tests PASS

- [ ] **Step 8: 运行现有备份测试确保不回归**

Run: `flutter test test/backup_service_test.dart`
Expected: All 3 existing tests PASS

- [ ] **Step 9: Commit**

```bash
git add lib/features/settings/services/backup_service.dart test/backup_service_v7_test.dart
git commit -m "feat: upgrade backup format to v7 with accounts and monthly budgets"
```

---

## Task 4: WebDAV 配置存储

**Files:**
- Create: `lib/features/settings/services/webdav_config_store.dart`
- Create: `test/webdav_config_store_test.dart`

- [ ] **Step 1: 编写配置存储测试**

```dart
// test/webdav_config_store_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:record_everything/features/settings/models/webdav_config.dart';

void main() {
  group('WebDavConfig', () {
    test('baseUrl removes trailing slash', () {
      const config = WebDavConfig(
        serverUrl: 'https://dav.example.com/',
        username: 'user',
        password: 'pass',
        remotePath: '/backups/',
      );
      expect(config.baseUrl, 'https://dav.example.com');
    });

    test('normalizedPath adds leading slash and removes trailing slash', () {
      const config = WebDavConfig(
        serverUrl: 'https://dav.example.com',
        username: 'user',
        password: 'pass',
        remotePath: 'backups/life-items/',
      );
      expect(config.normalizedPath, '/backups/life-items');
    });

    test('normalizedPath preserves single slash', () {
      const config = WebDavConfig(
        serverUrl: 'https://dav.example.com',
        username: 'user',
        password: 'pass',
        remotePath: '/',
      );
      expect(config.normalizedPath, '/');
    });
  });
}
```

- [ ] **Step 2: 运行测试验证通过**

Run: `flutter test test/webdav_config_store_test.dart`
Expected: All 3 tests PASS（模型方法已在 Task 2 创建）

- [ ] **Step 3: 创建 WebDavConfigStore**

```dart
// lib/features/settings/services/webdav_config_store.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/webdav_config.dart';

class WebDavConfigStore {
  WebDavConfigStore({
    required SharedPreferences prefs,
    required FlutterSecureStorage secureStorage,
  })  : _prefs = prefs,
        _secureStorage = secureStorage;

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secureStorage;

  static const _keyServerUrl = 'webdav.server_url';
  static const _keyUsername = 'webdav.username';
  static const _keyPassword = 'webdav.password';
  static const _keyRemotePath = 'webdav.remote_path';

  Future<WebDavConfig?> load() async {
    final serverUrl = _prefs.getString(_keyServerUrl);
    final username = _prefs.getString(_keyUsername);
    final remotePath = _prefs.getString(_keyRemotePath);
    final password = await _secureStorage.read(key: _keyPassword);

    if (serverUrl == null ||
        serverUrl.isEmpty ||
        username == null ||
        password == null) {
      return null;
    }

    return WebDavConfig(
      serverUrl: serverUrl,
      username: username,
      password: password,
      remotePath: remotePath ?? '/backups/life-items/',
    );
  }

  Future<void> save(WebDavConfig config) async {
    await _prefs.setString(_keyServerUrl, config.serverUrl);
    await _prefs.setString(_keyUsername, config.username);
    await _prefs.setString(_keyRemotePath, config.remotePath);
    await _secureStorage.write(key: _keyPassword, value: config.password);
  }

  Future<void> clear() async {
    await _prefs.remove(_keyServerUrl);
    await _prefs.remove(_keyUsername);
    await _prefs.remove(_keyRemotePath);
    await _secureStorage.delete(key: _keyPassword);
  }
}
```

- [ ] **Step 4: Commit**

```bash
git add lib/features/settings/services/webdav_config_store.dart test/webdav_config_store_test.dart
git commit -m "feat: add WebDavConfigStore for persistent WebDAV configuration"
```

---

## Task 5: BackupFileGateway 接口扩展

**Files:**
- Modify: `lib/features/settings/services/backup_file_gateway.dart`
- Modify: `lib/features/settings/services/file_picker_backup_file_gateway.dart`

- [ ] **Step 1: 扩展 BackupFileGateway 接口**

```dart
// lib/features/settings/services/backup_file_gateway.dart
import '../models/backup_file_entry.dart';

abstract class BackupFileGateway {
  Future<String?> pickBackupJson();
  Future<String?> saveBackupJson({
    required String fileName,
    required String content,
  });

  /// Lists backup files in the remote directory (WebDAV only).
  Future<List<BackupFileEntry>> listBackupFiles() async =>
      throw UnimplementedError('listBackupFiles not supported');

  /// Fetches a specific backup file's content by name (WebDAV only).
  Future<String?> fetchBackupJson(String fileName) async =>
      throw UnimplementedError('fetchBackupJson not supported');

  /// Deletes a specific backup file by name (WebDAV only).
  Future<void> deleteBackupFile(String fileName) async =>
      throw UnimplementedError('deleteBackupFile not supported');
}

class UnconfiguredBackupFileGateway implements BackupFileGateway {
  const UnconfiguredBackupFileGateway();

  @override
  Future<String?> pickBackupJson() async {
    throw StateError('BackupFileGateway is not configured');
  }

  @override
  Future<String?> saveBackupJson({
    required String fileName,
    required String content,
  }) async {
    throw StateError('BackupFileGateway is not configured');
  }
}
```

- [ ] **Step 2: FilePickerBackupFileGateway 无需修改**

新方法使用默认实现（throw UnimplementedError），FilePickerBackupFileGateway 自动继承。

- [ ] **Step 3: 运行现有测试确保不回归**

Run: `flutter test test/backup_service_test.dart test/backup_reminder_rebuild_test.dart`
Expected: All tests PASS

- [ ] **Step 4: Commit**

```bash
git add lib/features/settings/services/backup_file_gateway.dart
git commit -m "feat: extend BackupFileGateway with list/fetch/delete methods"
```

---

## Task 6: WebDavBackupFileGateway

**Files:**
- Create: `lib/features/settings/services/webdav_backup_file_gateway.dart`
- Create: `test/webdav_backup_file_gateway_test.dart`

- [ ] **Step 1: 添加 webdav_client 依赖**

在 `pubspec.yaml` 的 `dependencies` 中添加：

```yaml
  webdav_client: ^1.2.2
```

Run: `flutter pub get`

- [ ] **Step 2: 编写 WebDAV 网关测试**

```dart
// test/webdav_backup_file_gateway_test.dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:record_everything/features/settings/models/backup_file_entry.dart';
import 'package:record_everything/features/settings/models/webdav_config.dart';
import 'package:record_everything/features/settings/services/webdav_backup_file_gateway.dart';

void main() {
  group('WebDavBackupFileGateway', () {
    test('generates correct fileName with timestamp', () {
      final timestamp = DateTime(2026, 6, 21, 10, 30, 0);
      final fileName =
          'life_items_backup_${timestamp.millisecondsSinceEpoch}.json';
      expect(fileName, 'life_items_backup_1750487400000.json');
    });

    test('parses file size display correctly', () {
      const entry = BackupFileEntry(
        fileName: 'test.json',
        sizeBytes: 1536,
        modifiedAt: const DateTime(2026, 6, 21),
      );
      expect(entry.displaySize, '1.5 KB');
    });
  });
}
```

- [ ] **Step 3: 运行测试验证通过**

Run: `flutter test test/webdav_backup_file_gateway_test.dart`
Expected: All tests PASS

- [ ] **Step 4: 创建 WebDavBackupFileGateway**

```dart
// lib/features/settings/services/webdav_backup_file_gateway.dart
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;

import '../models/backup_file_entry.dart';
import '../models/webdav_config.dart';
import 'backup_file_gateway.dart';

class WebDavBackupFileGateway implements BackupFileGateway {
  WebDavBackupFileGateway(this._config) : _client = _createClient(_config);

  final WebDavConfig _config;
  final webdav.Client _client;

  static webdav.Client _createClient(WebDavConfig config) {
    return webdav.newClient(
      config.baseUrl,
      user: config.username,
      password: config.password,
    );
  }

  @override
  Future<String?> pickBackupJson() async {
    // WebDAV 不使用 pickBackupJson，通过 listBackupFiles + fetchBackupJson 替代
    throw UnimplementedError('Use listBackupFiles + fetchBackupJson instead');
  }

  @override
  Future<String?> saveBackupJson({
    required String fileName,
    required String content,
  }) async {
    await _ensureRemoteDir();

    // 写入临时文件后上传
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/$fileName');
    await tempFile.writeAsString(content, encoding: utf8);

    try {
      final remotePath = '${_config.normalizedPath}/$fileName';
      await _client.writeFromFile(tempFile.path, remotePath);
      return remotePath;
    } finally {
      if (await tempFile.exists()) await tempFile.delete();
    }
  }

  @override
  Future<List<BackupFileEntry>> listBackupFiles() async {
    try {
      await _ensureRemoteDir();
      final files = await _client.readDir(_config.normalizedPath);
      return files
          .where((f) => f.name != null && f.name!.endsWith('.json'))
          .map(
            (f) => BackupFileEntry(
              fileName: f.name ?? '',
              sizeBytes: f.size ?? 0,
              modifiedAt: f.mTime ?? DateTime.now(),
            ),
          )
          .toList()
        ..sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    } catch (e) {
      throw Exception('无法列出备份文件: $e');
    }
  }

  @override
  Future<String?> fetchBackupJson(String fileName) async {
    try {
      final remotePath = '${_config.normalizedPath}/$fileName';
      final bytes = await _client.read(remotePath);
      return utf8.decode(bytes);
    } catch (e) {
      throw Exception('无法下载备份文件: $e');
    }
  }

  @override
  Future<void> deleteBackupFile(String fileName) async {
    try {
      final remotePath = '${_config.normalizedPath}/$fileName';
      await _client.remove(remotePath);
    } catch (e) {
      throw Exception('无法删除备份文件: $e');
    }
  }

  /// Ensures the remote directory exists, creating it recursively if needed.
  Future<void> _ensureRemoteDir() async {
    try {
      await _client.readDir(_config.normalizedPath);
    } catch (_) {
      await _client.mkdirAll(_config.normalizedPath);
    }
  }
}
```

- [ ] **Step 5: Commit**

```bash
git add lib/features/settings/services/webdav_backup_file_gateway.dart pubspec.yaml pubspec.lock test/webdav_backup_file_gateway_test.dart
git commit -m "feat: add WebDavBackupFileGateway with webdav_client package"
```

---

## Task 7: Settings Provider 层扩展

**Files:**
- Modify: `lib/features/settings/providers/settings_providers.dart`

- [ ] **Step 1: 添加新的 Provider 和 SettingsNotifier 方法**

```dart
// 在 settings_providers.dart 中添加：

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/backup_file_entry.dart';
import '../models/webdav_config.dart';
import '../services/webdav_backup_file_gateway.dart';
import '../services/webdav_config_store.dart';

// WebDAV 配置存储 Provider
final webdavConfigStoreProvider = FutureProvider<WebDavConfigStore>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return WebDavConfigStore(
    prefs: prefs,
    secureStorage: const FlutterSecureStorage(),
  );
});

// WebDAV 配置 Provider（null = 未配置）
final webdavConfigProvider = FutureProvider<WebDavConfig?>((ref) async {
  final store = await ref.watch(webdavConfigStoreProvider.future);
  return store.load();
});

// 在 SettingsNotifier 中添加 WebDAV 方法：

class SettingsNotifier extends Notifier<void> {
  // ... 现有方法 ...

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
```

- [ ] **Step 2: 运行现有测试确保不回归**

Run: `flutter test`
Expected: All existing tests PASS

- [ ] **Step 3: Commit**

```bash
git add lib/features/settings/providers/settings_providers.dart
git commit -m "feat: add WebDAV providers and SettingsNotifier methods"
```

---

## Task 8: WebDAV 配置页面

**Files:**
- Create: `lib/features/settings/pages/webdav_settings_page.dart`
- Modify: `lib/core/router/app_router.dart`

- [ ] **Step 1: 创建 WebDAV 配置页面**

```dart
// lib/features/settings/pages/webdav_settings_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/toast.dart';
import '../models/webdav_config.dart';
import '../providers/settings_providers.dart';

class WebDavSettingsPage extends ConsumerStatefulWidget {
  const WebDavSettingsPage({super.key});

  @override
  ConsumerState<WebDavSettingsPage> createState() => _WebDavSettingsPageState();
}

class _WebDavSettingsPageState extends ConsumerState<WebDavSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _serverController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _pathController = TextEditingController(text: '/backups/life-items/');
  bool _isLoading = false;
  bool _isTesting = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _loadExistingConfig();
  }

  Future<void> _loadExistingConfig() async {
    final config = await ref.read(webdavConfigProvider.future);
    if (config != null && mounted) {
      _serverController.text = config.serverUrl;
      _usernameController.text = config.username;
      _passwordController.text = config.password;
      _pathController.text = config.remotePath;
    }
  }

  @override
  void dispose() {
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _pathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('WebDAV 同步配置')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _buildTextField(
              controller: _serverController,
              label: '服务器地址',
              hint: 'https://dav.example.com',
              keyboardType: TextInputType.url,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return '请输入服务器地址';
                final uri = Uri.tryParse(v.trim());
                if (uri == null || !uri.hasScheme) return '请输入有效的 URL';
                return null;
              },
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _usernameController,
              label: '用户名',
              validator: (v) =>
                  v == null || v.trim().isEmpty ? '请输入用户名' : null,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _passwordController,
              label: '密码',
              obscureText: _obscurePassword,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? '请输入密码' : null,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _pathController,
              label: '远程路径',
              hint: '/backups/life-items/',
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _isTesting ? null : _testConnection,
              icon: _isTesting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.wifi_find),
              label: Text(_isTesting ? '测试中...' : '测试连接'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _isLoading ? null : _save,
              child: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('保存配置'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: AppColors.surface,
      ),
      validator: validator,
    );
  }

  WebDavConfig _buildConfig() => WebDavConfig(
        serverUrl: _serverController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        remotePath: _pathController.text.trim().isEmpty
            ? '/backups/life-items/'
            : _pathController.text.trim(),
      );

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isTesting = true);
    try {
      final config = _buildConfig();
      await ref.read(settingsNotifierProvider.notifier).saveWebDavConfig(config);
      final ok =
          await ref.read(settingsNotifierProvider.notifier).testWebDavConnection();
      if (mounted) {
        Toast.success(context, ok ? '连接成功' : '连接失败，请检查配置');
      }
    } catch (e) {
      if (mounted) Toast.error(context, '连接失败: $e');
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final config = _buildConfig();
      await ref.read(settingsNotifierProvider.notifier).saveWebDavConfig(config);
      if (mounted) {
        Toast.success(context, '配置已保存');
        context.pop();
      }
    } catch (e) {
      if (mounted) Toast.error(context, '保存失败: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
```

- [ ] **Step 2: 添加路由**

在 `app_router.dart` 的 settings routes 中添加：

```dart
GoRoute(
  path: 'webdav',
  builder: (context, state) => const WebDavSettingsPage(),
),
```

- [ ] **Step 3: 运行测试确保不回归**

Run: `flutter test test/settings_navigation_widget_test.dart`
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add lib/features/settings/pages/webdav_settings_page.dart lib/core/router/app_router.dart
git commit -m "feat: add WebDAV settings page with connection test"
```

---

## Task 9: DataSafetyPage 通道选择改造

**Files:**
- Modify: `lib/features/settings/pages/data_safety_page.dart`

- [ ] **Step 1: 改造 DataSafetyPage 为通道选择 UI**

```dart
// lib/features/settings/pages/data_safety_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/toast.dart';
import '../providers/settings_providers.dart';

class DataSafetyPage extends ConsumerWidget {
  const DataSafetyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('数据安全')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _ActionGroup(
            rows: [
              _ActionRowData(
                icon: Icons.file_upload_outlined,
                title: '导出备份',
                subtitle: '保存到本地文件',
                onTap: () => _exportLocal(context, ref),
              ),
              _ActionRowData(
                icon: Icons.cloud_upload_outlined,
                title: '上传到 WebDAV',
                subtitle: '备份到云端服务器',
                onTap: () => _exportWebDav(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ActionGroup(
            rows: [
              _ActionRowData(
                icon: Icons.file_download_outlined,
                title: '导入备份',
                subtitle: '从本地文件恢复数据',
                onTap: () => _importLocal(context, ref),
              ),
              _ActionRowData(
                icon: Icons.cloud_download_outlined,
                title: '从 WebDAV 导入',
                subtitle: '从云端服务器恢复',
                onTap: () => _importWebDav(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.black.withValues(alpha: 0.07)),
            ),
            child: Text(
              '导入会追加有效记录，并自动复用同名同类型分类。导入前会校验备份版本、字段结构、日期和金额格式。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportLocal(BuildContext context, WidgetRef ref) async {
    try {
      final path = await ref
          .read(settingsNotifierProvider.notifier)
          .exportWithFilePicker();
      if (context.mounted) {
        Toast.info(context, path == null ? '已取消导出' : '备份已导出: $path');
      }
    } catch (error) {
      if (context.mounted) Toast.error(context, '导出失败: $error');
    }
  }

  Future<void> _exportWebDav(BuildContext context, WidgetRef ref) async {
    final config = await ref.read(webdavConfigProvider.future);
    if (config == null) {
      if (context.mounted) {
        Toast.info(context, '请先配置 WebDAV');
        context.push('/settings/webdav');
      }
      return;
    }
    try {
      await ref.read(settingsNotifierProvider.notifier).exportToWebDav();
      if (context.mounted) Toast.success(context, '备份已上传到 WebDAV');
    } catch (error) {
      if (context.mounted) Toast.error(context, '上传失败: $error');
    }
  }

  Future<void> _importLocal(BuildContext context, WidgetRef ref) async {
    try {
      final summary = await ref
          .read(settingsNotifierProvider.notifier)
          .importWithFilePicker();
      if (context.mounted) {
        final message = summary == null
            ? '已取消导入'
            : '导入成功: 分类 ${summary.categoriesImported}，'
                '模板 ${summary.projectTemplatesImported}，'
                '项目 ${summary.projectsImported}，'
                '事项 ${summary.lifeItemsImported}，'
                '账单 ${summary.billRecordsImported}';
        Toast.success(context, message);
      }
    } catch (error) {
      if (context.mounted) Toast.error(context, '导入失败: $error');
    }
  }

  Future<void> _importWebDav(BuildContext context, WidgetRef ref) async {
    final config = await ref.read(webdavConfigProvider.future);
    if (config == null) {
      if (context.mounted) {
        Toast.info(context, '请先配置 WebDAV');
        context.push('/settings/webdav');
      }
      return;
    }

    if (!context.mounted) return;

    // 显示文件列表 BottomSheet
    try {
      final files =
          await ref.read(settingsNotifierProvider.notifier).listWebDavBackups();
      if (!context.mounted) return;

      if (files.isEmpty) {
        Toast.info(context, '暂无备份文件');
        return;
      }

      final selected = await showModalBottomSheet<String>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  '选择备份文件',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: files.length,
                  itemBuilder: (ctx, index) {
                    final file = files[index];
                    return ListTile(
                      title: Text(file.fileName),
                      subtitle: Text(
                        '${file.displaySize}  ·  '
                        '${file.modifiedAt.month}/${file.modifiedAt.day} '
                        '${file.modifiedAt.hour}:${file.modifiedAt.minute.toString().padLeft(2, '0')}',
                      ),
                      onTap: () => Navigator.of(ctx).pop(file.fileName),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );

      if (selected == null || !context.mounted) return;

      final summary = await ref
          .read(settingsNotifierProvider.notifier)
          .importFromWebDav(selected);
      if (context.mounted) {
        if (summary == null) {
          Toast.info(context, '已取消导入');
        } else {
          Toast.success(
            context,
            '导入成功: 分类 ${summary.categoriesImported}，'
                '项目 ${summary.projectsImported}，'
                '事项 ${summary.lifeItemsImported}，'
                '账单 ${summary.billRecordsImported}',
          );
        }
      }
    } catch (error) {
      if (context.mounted) Toast.error(context, '导入失败: $error');
    }
  }
}

class _ActionGroup extends StatelessWidget {
  const _ActionGroup({required this.rows});

  final List<_ActionRowData> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black.withValues(alpha: 0.07)),
      ),
      child: Column(
        children: [
          for (var index = 0; index < rows.length; index++) ...[
            _ActionRow(data: rows[index]),
            if (index != rows.length - 1)
              Divider(
                height: 1,
                indent: 56,
                color: Colors.black.withValues(alpha: 0.06),
              ),
          ],
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.data});

  final _ActionRowData data;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minLeadingWidth: 28,
      leading: Icon(data.icon, color: AppColors.primaryDark),
      title: Text(data.title),
      subtitle: Text(data.subtitle),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textHint),
      onTap: data.onTap,
    );
  }
}

class _ActionRowData {
  const _ActionRowData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}
```

- [ ] **Step 2: 运行测试确保不回归**

Run: `flutter test test/settings_navigation_widget_test.dart`
Expected: PASS（测试验证的是 '导出备份' 和 '导入备份' 文字存在，仍然匹配）

- [ ] **Step 3: Commit**

```bash
git add lib/features/settings/pages/data_safety_page.dart
git commit -m "feat: add WebDAV import/export channel to DataSafetyPage"
```

---

## Task 10: SettingsPage 新增 WebDAV 入口

**Files:**
- Modify: `lib/features/settings/pages/settings_page.dart`

- [ ] **Step 1: 在 settings_page.dart 中添加 WebDAV 入口**

在 "数据安全" 入口之后添加一个新的 `_SettingsRowData`：

```dart
_SettingsRowData(
  icon: Icons.cloud_sync_outlined,
  title: 'WebDAV 同步',
  subtitle: '配置云端备份服务器',
  onTap: () => context.push('/settings/webdav'),
),
```

同时将 settings_page.dart 中的 `SnackBar` 调用替换为 `Toast`：

```dart
// 之前
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(content: Text('$title 后续开放')),
);

// 之后
Toast.info(context, '$title 后续开放');
```

- [ ] **Step 2: 运行测试确保不回归**

Run: `flutter test test/settings_navigation_widget_test.dart`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add lib/features/settings/pages/settings_page.dart
git commit -m "feat: add WebDAV sync entry to SettingsPage"
```

---

## Task 11: 全局 SnackBar → Toast 替换

**Files:**
- Modify: 15 个 UI 文件（见下方清单）

- [ ] **Step 1: 替换 `form_save_mixin.dart`**

在 `shared/widgets/form_save_mixin.dart` 中：
- 添加 `import '../../../core/utils/toast.dart';`
- 将 `ScaffoldMessenger.of(context).showSnackBar(...)` 替换为 `Toast.error(context, '保存失败：$error')`

- [ ] **Step 2: 替换 `bill_edit_page.dart`**

- 添加 Toast import
- 将 SnackBar 调用替换为 `Toast.error(context, '账单已删除，不可编辑')`

- [ ] **Step 3: 替换 `life_item_edit_page.dart`**

- 将 SnackBar 替换为 `Toast.error(context, '事项已完结，不可编辑')`

- [ ] **Step 4: 替换 `life_item_list_page.dart`**

- 2 处 SnackBar 替换为 `Toast.info(context, '已取消事项')` 和 `Toast.info(context, '已重新打开事项')`

- [ ] **Step 5: 替换 `life_item_detail_sheet.dart`**

- 3 处替换为 `Toast.info(context, ...)`

- [ ] **Step 6: 替换 `selected_day_agenda.dart`**

- 1 处替换为 `Toast.info(context, '已取消事项')`

- [ ] **Step 7: 替换 `project_detail_page.dart`**

- 3 处替换为 `Toast.info(context, ...)`

- [ ] **Step 8: 替换 `project_edit_page.dart`**

- 1 处替换为 `Toast.error(context, '项目已完结，不可编辑')`

- [ ] **Step 9: 替换 `project_list_page.dart`**

- 1 处替换为 `Toast.info(context, '已归档项目')`

- [ ] **Step 10: 替换 `project_template_edit_page.dart`**

- 1 处替换为 `Toast.info(context, '至少保留一个模板节点')`

- [ ] **Step 11: 替换 `category_management_page.dart`**

- 3 处替换为 `Toast.info` / `Toast.error`

- [ ] **Step 12: 替换 `recycle_bin_page.dart`**

- 6 处替换为 `Toast.success(context, ...)`

- [ ] **Step 13: 替换 `ai_assistant_settings_page.dart`**

- 1 处替换为 `Toast.success(context, '已保存')`

- [ ] **Step 14: 替换 `smart_entry_confirm_page.dart`**

- 2 处替换为 `Toast.success` / `Toast.error`

- [ ] **Step 15: 替换 `smart_entry_input_page.dart`**

- 2 处替换为 `Toast.error(context, ...)`

- [ ] **Step 16: 运行全量测试**

Run: `flutter test`
Expected: All tests PASS

- [ ] **Step 17: Commit**

```bash
git add -A
git commit -m "refactor: replace all SnackBar calls with Toast utility across 15 files"
```

---

## Final Verification

- [ ] **Step 1: 运行完整测试套件**

Run: `flutter test`
Expected: All tests PASS

- [ ] **Step 2: 静态分析**

Run: `flutter analyze`
Expected: No errors or warnings

- [ ] **Step 3: 验证构建**

Run: `flutter build apk --debug`
Expected: Build succeeds
