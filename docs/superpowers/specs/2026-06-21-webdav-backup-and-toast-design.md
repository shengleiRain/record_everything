# WebDAV 备份增强 + Toast 工具类 设计文档

> 日期: 2026-06-21  
> 范围: 备份格式升级、WebDAV 导入导出通道、Toast 工具类及全局替换

---

## 1. 目标

1. **备份格式升级 v6 → v7**：将 Accounts（账户）和 MonthlyBudgets（月度预算）纳入备份范围，保持向后兼容
2. **WebDAV 手动导入导出**：作为现有本地文件选择器之外的第二个传输通道，支持列出/选择远端备份文件
3. **Toast 工具类**：自建轻量 Toast（基于 Overlay），替换全项目约 30 处 SnackBar 调用

## 2. 备份格式 v7

### 2.1 JSON 结构变更

在 v6 基础上新增 `accounts` 和 `monthlyBudgets` 两个顶层字段：

```json
{
  "version": 7,
  "exportedAt": "2026-06-21T10:00:00.000",
  "categories": [...],
  "itemTemplates": [...],
  "projectTemplates": [...],
  "projectTemplateSteps": [...],
  "projects": [...],
  "lifeItems": [...],
  "billRecords": [...],
  "projectEvents": [...],
  "accounts": [
    { "id": 1, "name": "默认账户", "type": "cash", "isDefault": true, "createdAt": "..." }
  ],
  "monthlyBudgets": [
    { "id": 1, "monthStart": "2026-01-01T00:00:00.000", "amount": 500000, "createdAt": "...", "updatedAt": "..." }
  ]
}
```

### 2.2 向后兼容策略

- `_decodeAndValidate` 增加 `version == 7` 到合法版本集合
- v1-v6 备份导入时 `accounts`/`monthlyBudgets` 返回空列表，不报错
- v7 导出的文件，旧版本 app 的 `_decodeAndValidate` 会忽略未知字段（只要 categories/lifeItems/billRecords 存在即可）

### 2.3 去重规则

| 实体 | 去重字段 | 理由 |
|------|---------|------|
| Account | `name + type` | 无天然唯一标识，组合匹配合理 |
| MonthlyBudget | `monthStart` | 数据库有 unique 约束 |

### 2.4 BackupImportSummary 扩展

新增 `accountsImported` 和 `monthlyBudgetsImported` 字段（默认值 0，向后兼容）。

## 3. WebDAV 集成

### 3.1 架构方案：扩展 BackupFileGateway

在现有 `BackupFileGateway` 接口上新增方法，创建 `WebDavBackupFileGateway` 实现。

### 3.2 接口扩展

```dart
abstract class BackupFileGateway {
  // 现有
  Future<String?> pickBackupJson();
  Future<String?> saveBackupJson({required String fileName, required String content});

  // 新增（WebDAV 需要，本地实现抛 UnimplementedError）
  Future<List<BackupFileEntry>> listBackupFiles();
  Future<String?> fetchBackupJson(String fileName);
  Future<void> deleteBackupFile(String fileName);
}
```

### 3.3 数据模型

```dart
/// 备份文件列表项
class BackupFileEntry {
  final String fileName;
  final int sizeBytes;
  final DateTime modifiedAt;
}

/// WebDAV 配置
class WebDavConfig {
  final String serverUrl;
  final String username;
  final String password;
  final String remotePath;
}
```

### 3.4 WebDAV 客户端

使用 `webdav_client` 包（pub.dev，63 likes，12.4k 下载）。

核心操作映射：
- 列出文件 → `client.readDir(remotePath)`
- 上传文件 → `client.writeFromFile(tempPath, remotePath/fileName)`
- 下载文件 → `client.read(remotePath/fileName)` 返回 bytes
- 删除文件 → `client.remove(remotePath/fileName)`
- 创建目录 → `client.mkdirAll(remotePath)`

### 3.5 配置存储

| 字段 | 存储位置 | 理由 |
|------|---------|------|
| serverUrl | SharedPreferences | 非敏感 |
| username | SharedPreferences | 非敏感 |
| password | flutter_secure_storage | 敏感，与 AI API Key 同策略 |
| remotePath | SharedPreferences | 非敏感 |

### 3.6 SettingsNotifier 扩展

新增 WebDAV 专用方法，不复用现有 file picker 方法：

```dart
class SettingsNotifier extends Notifier<void> {
  // 现有方法保持不变
  Future<String?> exportWithFilePicker() async { ... }
  Future<BackupImportSummary?> importWithFilePicker() async { ... }

  // 新增 WebDAV 方法
  Future<void> exportToWebDav() async {
    final config = ref.read(webdavConfigProvider).value;
    if (config == null) throw StateError('WebDAV 未配置');
    final json = await ref.read(backupServiceProvider).exportToJson();
    final gateway = ref.read(backupFileGatewayProvider) as WebDavBackupFileGateway;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    await gateway.saveBackupJson(
      fileName: 'life_items_backup_$timestamp.json',
      content: json,
    );
  }

  Future<BackupImportSummary?> importFromWebDav(String fileName) async {
    final gateway = ref.read(backupFileGatewayProvider) as WebDavBackupFileGateway;
    final json = await gateway.fetchBackupJson(fileName);
    if (json == null) return null;
    final summary = await ref.read(backupServiceProvider).importFromJson(json);
    await _rebuildFutureReminders();
    return summary;
  }

  Future<List<BackupFileEntry>> listWebDavBackups() async {
    final gateway = ref.read(backupFileGatewayProvider) as WebDavBackupFileGateway;
    return gateway.listBackupFiles();
  }
}
```

### 3.7 Provider 层

```
backupFileGatewayProvider (已有，运行时动态注入)
  ├─ UnconfiguredBackupFileGateway (默认占位)
  ├─ FilePickerBackupFileGateway (本地文件选择器)
  └─ WebDavBackupFileGateway (WebDAV，通过配置创建)

webdavConfigProvider (新增 StreamProvider<WebDavConfig?>)
  └─ 监听配置变化，null = 未配置

webdavConfigStoreProvider (新增 Provider<WebDavConfigStore>)
  └─ 提供配置读写能力
```

### 3.8 错误处理

| 场景 | 处理方式 |
|------|---------|
| WebDAV 连接失败 | Toast.error 提示 "连接失败: {原因}" |
| WebDAV 认证失败 | Toast.error 提示 "认证失败，请检查用户名和密码" |
| 上传/下载超时 | Toast.error 提示 "操作超时，请检查网络" |
| 远程目录不存在 | 自动 mkdirAll 创建 |
| 下载内容非 JSON | BackupFormatException 处理 |
| WebDAV 未配置 | 自动跳转配置页面 |
| 文件列表为空 | 显示 "暂无备份文件" 空状态 |

### 3.9 数据一致性保障

- 导入在现有 `transaction()` 中执行，新增实体也在同一事务
- 上传前先在内存中完成 JSON 序列化
- 下载后先校验 JSON 格式，再执行导入
- Accounts/MonthlyBudgets 去重规则与数据库约束一致

## 4. Toast 工具类

### 4.1 实现方式

自建轻量 Toast，基于 Flutter `Overlay`，不引入额外依赖。

```dart
// lib/core/utils/toast.dart
enum ToastType { success, error, info }

class Toast {
  static void show(BuildContext context, String message, {ToastType type = ToastType.info});
  static void success(BuildContext context, String msg);
  static void error(BuildContext context, String msg);
  static void info(BuildContext context, String msg);
}
```

Toast Widget 样式：
- 成功：绿色图标 + 文字
- 错误：红色图标 + 文字
- 信息：蓝色图标 + 文字
- 自动 2 秒后消失，支持手动关闭
- 从底部弹出，位于屏幕下方 1/3 处

### 4.2 全局 SnackBar → Toast 替换

替换范围：15 个文件，约 30 处调用。

| 文件 | 替换策略 |
|------|---------|
| `data_safety_page.dart` | Toast.success / Toast.error / Toast.info |
| `recycle_bin_page.dart` | Toast.success |
| `category_management_page.dart` | Toast.info / Toast.error |
| `settings_page.dart` | Toast.info |
| `bill_edit_page.dart` | Toast.error |
| `life_item_edit_page.dart` | Toast.error |
| `life_item_list_page.dart` | Toast.info |
| `life_item_detail_sheet.dart` | Toast.info |
| `selected_day_agenda.dart` | Toast.info |
| `project_detail_page.dart` | Toast.info |
| `project_edit_page.dart` | Toast.error |
| `project_list_page.dart` | Toast.info |
| `project_template_edit_page.dart` | Toast.info |
| `ai_assistant_settings_page.dart` | Toast.success |
| `smart_entry_confirm_page.dart` | Toast.success / Toast.error |
| `smart_entry_input_page.dart` | Toast.error |
| `form_save_mixin.dart` | Toast.error |

### 4.3 form_save_mixin 改造

`FormSaveMixin` 需要适配 Toast。由于 Toast 需要 `BuildContext`，mixin 的错误展示方法改为调用 `Toast.error(context, message)`。

## 5. UI 设计

### 5.1 WebDAV 配置页面

路由：`/settings/webdav`

```
┌─────────────────────────────────────┐
│ ← WebDAV 同步配置                    │
├─────────────────────────────────────┤
│ 服务器地址   [https://dav.xxx.com]   │
│ 用户名       [username]              │
│ 密码         [••••••••]              │
│ 远程路径     [/backups/life-items/]  │
├─────────────────────────────────────┤
│  [ 测试连接 ]                        │
│  连接状态: ● 已连接 / ○ 未配置       │
├─────────────────────────────────────┤
│  [ 保存配置 ]                        │
└─────────────────────────────────────┘
```

### 5.2 DataSafetyPage 改造

导入/导出按钮改为弹出通道选择：

```
┌─────────────────────────────────────┐
│ ← 数据安全                          │
├─────────────────────────────────────┤
│ 📤 导出备份                         │
│    ├─ 保存到本地文件                 │
│    └─ 上传到 WebDAV                  │
│ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─  │
│ 📥 导入备份                         │
│    ├─ 从本地文件导入                 │
│    └─ 从 WebDAV 导入                 │
├─────────────────────────────────────┤
│ 说明：导入会追加有效记录...          │
└─────────────────────────────────────┘
```

### 5.3 SettingsPage 新增入口

在 "数据安全" 下方新增 "WebDAV 同步" 入口，跳转 `/settings/webdav`。

### 5.4 WebDAV 导入流程

1. 用户点击 "从 WebDAV 导入"
2. 若未配置 WebDAV → Toast.info 提示 + 跳转配置页面
3. 弹出文件列表 BottomSheet（显示远端 .json 文件：文件名、大小、修改时间）
4. 用户选择文件 → 下载 → 导入 → Toast.success 显示摘要

### 5.5 WebDAV 导出流程

1. 用户点击 "上传到 WebDAV"
2. 若未配置 → Toast.info 提示 + 跳转配置页面
3. 自动创建远程目录（如不存在）
4. 上传文件 `life_items_backup_{timestamp}.json`
5. Toast.success 提示成功

## 6. 新增文件清单

| 文件路径 | 用途 |
|---------|------|
| `lib/core/utils/toast.dart` | Toast 工具类 + _ToastWidget |
| `lib/features/settings/models/backup_file_entry.dart` | BackupFileEntry 模型 |
| `lib/features/settings/models/webdav_config.dart` | WebDavConfig 模型 |
| `lib/features/settings/services/webdav_config_store.dart` | WebDAV 配置读写 |
| `lib/features/settings/services/webdav_backup_file_gateway.dart` | WebDAV 实现 |
| `lib/features/settings/pages/webdav_settings_page.dart` | WebDAV 配置页面 |

## 7. 修改文件清单

| 文件路径 | 修改内容 |
|---------|---------|
| `pubspec.yaml` | 新增 `webdav_client` 依赖 |
| `lib/features/settings/services/backup_service.dart` | v7 导出/导入 accounts+monthlyBudgets |
| `lib/features/settings/services/backup_file_gateway.dart` | 接口新增 3 个方法 |
| `lib/features/settings/services/file_picker_backup_file_gateway.dart` | 新方法抛 UnimplementedError |
| `lib/features/settings/providers/settings_providers.dart` | 新增 webdav 相关 provider |
| `lib/features/settings/pages/data_safety_page.dart` | 通道选择 UI + Toast 替换 |
| `lib/features/settings/pages/settings_page.dart` | 新增 WebDAV 入口 + Toast 替换 |
| `lib/core/router/app_router.dart` | 新增 `/settings/webdav` 路由 |
| 15 个文件 | SnackBar → Toast 全局替换 |
