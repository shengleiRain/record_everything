# 阶段二：桌面与快捷触达 设计文档

- **状态**：已确认
- **日期**：2026-06-19
- **范围**：App Shortcuts + 桌面 App Widget
- **目标平台**：仅 Android
- **前置依赖**：阶段一（智能录入）已合并到 main

## 1. 背景与目标

阶段一解决了"录入麻烦"的痛点。阶段二解决"忘记看"的问题——把待办事项和账单推到用户眼前（桌面、长按图标），减少打开 App 的次数。

本次只实现 **App Shortcuts**（长按图标快捷菜单）和 **桌面 App Widget**（今日待办 + 收支概览）。Live Updates 和 Quick Settings Tile 不在本次范围内，留后续单独立项。

## 2. 关键决策

| 决策点 | 选择 | 理由 |
|--------|------|------|
| Widget 框架 | `home_widget` Flutter 包 | 成熟、广泛使用，SharedPreferences 桥接省去手写 MethodChannel |
| Widget 尺寸 | 4×2（固定） | 能展示今日待办列表 + 收支概览 + 操作按钮，信息密度合适 |
| 数据同步 | App 生命周期触发 + 数据变更主动触发 | 不依赖 WorkManager（减少复杂度），覆盖绝大多数场景 |
| Shortcuts 实现 | 静态 `shortcuts.xml` | 3 个固定入口，不需要动态增删 |
| 点击导航 | Deep link URI scheme | Shortcuts 和 Widget 共用同一套 URI→路由映射 |

## 3. App Shortcuts

### 3.1 快捷入口（3 个）

| 图标 | 标签 | 目标路由 | URI |
|------|------|---------|-----|
| 📝 | 智能输入 | `/smart-entry/input` | `lifeitems://smart-entry/input` |
| 💰 | 快速记账 | `/bills/new` | `lifeitems://bills/new` |
| 📋 | 今日待办 | `/items` | `lifeitems://items` |

### 3.2 实现

- `android/app/src/main/res/xml/shortcuts.xml`：定义 3 个 `<shortcut>`
- `AndroidManifest.xml`：`<activity>` 内加 `<meta-data android:name="android.app.shortcuts" android:resource="@xml/shortcuts" />`
- 每个 shortcut 的 `<intent>` 用 `android:data` 指定 URI
- App 内通过 go_router 处理 URI scheme（在 `GoRouter` 配置 `redirect` 或 `onException`）

### 3.3 Deep Link 注册

在 `AndroidManifest.xml` 的 `<activity>` 中新增一个 intent-filter 接收自定义 scheme：

```xml
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="lifeitems" />
</intent-filter>
```

在 `app_router.dart` 中，GoRouter 配置 `redirect` 拦截 `lifeitems://` URI 并映射到对应路由。

## 4. 桌面 App Widget

### 4.1 Widget 布局（4×2）

```
┌─────────────────────────────────┐
│ 📅 6月19日 周五        生活事项  │
│─────────────────────────────────│
│ 今日待办 3 项    已逾期 1 项     │
│  · 续费会员（今天）              │
│  · 交房租（今天）                │
│  · ⚠️ 补办证件（逾期2天）        │
│─────────────────────────────────│
│ 本月：收入 ¥8,500  支出 ¥3,200  │
│                          [+记账] │
└─────────────────────────────────┘
```

**元素说明**：
- 顶部栏：日期 + App 名称
- 待办区域：今日待办数量 + 逾期数量 + 最多 3 条待办标题（带逾期警告图标）
- 底部栏：本月收入/支出 + [+记账] 按钮
- 整个 Widget 可点击打开首页，[+记账] 按钮打开智能输入页

### 4.2 数据流

```
Flutter (Drift/SQLite)
  │
  │  WidgetSyncService.sync()
  │  写入 SharedPreferences (home_widget 包)
  │
  ▼
Android AppWidgetProvider
  │
  │  读取 SharedPreferences
  │  渲染 RemoteViews
  │
  ▼
桌面 Widget 显示
```

### 4.3 数据格式（SharedPreferences key）

| Key | 类型 | 说明 |
|-----|------|------|
| `widget_date` | String | 今天日期（"6月19日 周五"） |
| `widget_today_count` | int | 今日待办数量 |
| `widget_overdue_count` | int | 逾期数量 |
| `widget_items` | String | JSON 数组，最多 3 条 `[{title, isOverdue}]` |
| `widget_monthly_income` | String | 本月收入（格式化后如 "¥8,500"） |
| `widget_monthly_expense` | String | 本月支出（格式化后如 "¥3,200"） |

### 4.4 更新时机

| 触发点 | 时机 | 实现方式 |
|--------|------|---------|
| App 进入后台 | 用户切走或按 Home | `WidgetsBindingObserver.didChangeAppLifecycleState` → `AppLifecycleState.inactive` |
| 数据变更 | 事项/账单 CRUD 后 | 在 `lifeItemNotifierProvider` / `billNotifierProvider` 的 create/update/delete 后触发 |
| Widget 首次添加 | 用户把 Widget 拖到桌面 | `home_widget` 包的 `initiallyTriggered` 回调 |
| 定时刷新 | 每 30 分钟 | `home_widget` 的 `updatePeriodically` 或 Android `AppWidgetManager.updateAppWidget` |

### 4.5 点击行为

- **点击整个 Widget**：打开 App 首页（`/home`）
- **点击 [+记账]**：打开智能输入页（`/smart-entry/input`）
- 实现方式：Widget 布局中用 `PendingIntent` 指定不同 target，`home_widget` 包通过 `Uri` scheme 区分

### 4.6 新增依赖

| 包 | 用途 |
|----|------|
| `home_widget` | Flutter↔Android Widget 数据桥接 |

## 5. 文件结构

### Android 原生新增

```
android/app/src/main/
  res/
    xml/
      shortcuts.xml                    ← App Shortcuts 定义
      home_widget_info.xml             ← Widget 元数据（尺寸、刷新周期、预览图）
    layout/
      widget_home.xml                  ← Widget 布局（RemoteViews）
  kotlin/.../
    HomeWidgetProvider.kt              ← AppWidgetProvider 子类（渲染+点击处理）
```

### Android 原生修改

```
android/app/src/main/
  AndroidManifest.xml                  ← 注册 Widget Provider + Shortcuts meta-data + URI scheme
```

### Flutter 新增

```
lib/features/home/
  services/
    widget_sync_service.dart           ← 数据同步到 SharedPreferences
```

### Flutter 修改

```
lib/app.dart                           ← 添加 WidgetsBindingObserver 触发 Widget 刷新
lib/core/router/app_router.dart        ← 添加 Deep link URI scheme 处理
lib/features/life_item/providers/      ← CRUD 后触发 Widget 刷新
lib/features/bill/providers/           ← CRUD 后触发 Widget 刷新
```

## 6. 实施切片

按依赖顺序：

1. **切片 1：App Shortcuts**（shortcuts.xml + Manifest + URI scheme + go_router redirect）——纯配置，零 Dart 业务逻辑改动
2. **切片 2：Widget 数据同步服务**（WidgetSyncService + SharedPreferences 写入）——纯 Dart，可单测
3. **切片 3：Widget 原生实现**（home_widget_info.xml + widget_home.xml + HomeWidgetProvider.kt + Manifest 注册）——Android 原生
4. **切片 4：Widget 生命周期集成**（WidgetsBindingObserver + CRUD 触发刷新）——Dart 层
5. **切片 5：端到端验证**（手动测试：添加 Widget 到桌面 → 显示数据 → 点击导航）

## 7. 测试策略

| 层次 | 覆盖 |
|------|------|
| 单元测试 | `WidgetSyncService`：验证写入 SharedPreferences 的 key/value 格式正确 |
| 手动测试 | Widget 添加到桌面 → 数据显示正确 → 点击打开首页/智能输入 → CRUD 后 Widget 刷新 |
| App Shortcuts | 长按图标 → 3 个快捷入口 → 点击正确跳转 |

## 8. 已知局限

- Widget 布局用 RemoteViews（Android 原生 XML），不支持 Flutter 渲染，样式需单独维护
- Widget 数据刷新不是实时的（依赖 App 生命周期或定时器），极端情况下可能有几秒延迟
- 4×2 固定尺寸，不支持用户调整（后续可加 2×1 紧凑版）
