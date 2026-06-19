# 阶段二：桌面与快捷触达 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 record_everything 添加 App Shortcuts（长按图标快捷菜单）和桌面 App Widget（今日待办 + 收支概览），让用户无需打开 App 即可获取关键信息和快速操作。

**Architecture:** App Shortcuts 用 Android 静态 `shortcuts.xml` + Deep Link URI scheme（`lifeitems://`）。App Widget 用 `home_widget` Flutter 包桥接数据（SharedPreferences），Android 原生 `AppWidgetProvider` 渲染 RemoteViews 布局。Flutter 侧通过 `WidgetsBindingObserver` 和 CRUD 回调触发数据同步。

**Tech Stack:** Flutter（现有），`home_widget` 0.9.3（新增），Kotlin（Android 原生 Widget Provider），go_router（现有，加 redirect）

**对应 Spec:** `docs/superpowers/specs/2026-06-19-phase2-desktop-reach-design.md`

---

## 文件结构总览

新建文件：
```
android/app/src/main/res/xml/shortcuts.xml           ← Task 1
android/app/src/main/res/xml/home_widget_info.xml     ← Task 3
android/app/src/main/res/layout/widget_home.xml       ← Task 3
android/app/src/main/kotlin/.../HomeWidgetProvider.kt ← Task 3
lib/features/home/services/widget_sync_service.dart   ← Task 2
test/home/widget_sync_service_test.dart               ← Task 2
```

修改文件：
```
android/app/src/main/AndroidManifest.xml              ← Task 1 (shortcuts + widget + URI scheme)
pubspec.yaml                                          ← Task 3 (home_widget 依赖)
lib/core/router/app_router.dart                       ← Task 1 (URI scheme redirect)
lib/app.dart                                          ← Task 4 (WidgetsBindingObserver)
lib/features/life_item/providers/life_item_providers.dart ← Task 4 (CRUD 后触发刷新)
lib/features/bill/providers/bill_providers.dart        ← Task 4 (CRUD 后触发刷新)
```

复用的现有接入点：
- `home_providers.dart`：`homeSelectedDayAgendaProvider`、`homeMonthlyIncomeProvider`、`homeMonthlyExpenseProvider`
- `MoneyFormatter.format(int? cents)`：格式化金额
- `go_router`：`appRouter` 配置 redirect

---

## Task 1: App Shortcuts + Deep Link URI Scheme

**Files:**
- Create: `android/app/src/main/res/xml/shortcuts.xml`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `lib/core/router/app_router.dart`

- [ ] **Step 1: 创建 shortcuts.xml**

`android/app/src/main/res/xml/shortcuts.xml`:
```xml
<?xml version="1.0" encoding="utf-8"?>
<shortcuts xmlns:android="http://schemas.android.com/apk/res/android">
    <shortcut
        android:shortcutId="smart_entry"
        android:enabled="true"
        android:icon="@android:drawable/ic_menu_edit"
        android:shortcutShortLabel="@string/shortcut_smart_entry"
        android:shortcutLongLabel="@string/shortcut_smart_entry">
        <intent
            android:action="android.intent.action.VIEW"
            android:data="lifeitems://smart-entry/input" />
    </shortcut>
    <shortcut
        android:shortcutId="quick_bill"
        android:enabled="true"
        android:icon="@android:drawable/ic_menu_agenda"
        android:shortcutShortLabel="@string/shortcut_quick_bill"
        android:shortcutLongLabel="@string/shortcut_quick_bill">
        <intent
            android:action="android.intent.action.VIEW"
            android:data="lifeitems://bills/new" />
    </shortcut>
    <shortcut
        android:shortcutId="today_items"
        android:enabled="true"
        android:icon="@android:drawable/ic_menu_today"
        android:shortcutShortLabel="@string/shortcut_today_items"
        android:shortcutLongLabel="@string/shortcut_today_items">
        <intent
            android:action="android.intent.action.VIEW"
            android:data="lifeitems://items" />
    </shortcut>
</shortcuts>
```

- [ ] **Step 2: 添加字符串资源**

在 `android/app/src/main/res/values/strings.xml`（如不存在则创建）中添加：
```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">生活事项</string>
    <string name="shortcut_smart_entry">智能输入</string>
    <string name="shortcut_quick_bill">快速记账</string>
    <string name="shortcut_today_items">今日待办</string>
</resources>
```

- [ ] **Step 3: 修改 AndroidManifest.xml**

在 `<activity>` 标签内、现有 intent-filter 之后追加：
```xml
<!-- App Shortcuts -->
<meta-data
    android:name="android.app.shortcuts"
    android:resource="@xml/shortcuts" />
<!-- Deep Link URI scheme -->
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="lifeitems" />
</intent-filter>
```

- [ ] **Step 4: go_router 添加 URI scheme redirect**

修改 `lib/core/router/app_router.dart`，在 `GoRouter` 构造函数中添加 `redirect`：

```dart
final appRouter = GoRouter(
  initialLocation: '/home',
  redirect: (context, state) {
    // 处理 lifeitems:// URI scheme（来自 App Shortcuts / Widget）。
    final uri = state.uri;
    if (uri.scheme == 'lifeitems') {
      // lifeitems://smart-entry/input → /smart-entry/input
      // lifeitems://bills/new → /bills/new
      // lifeitems://items → /items
      final path = '/${uri.host}${uri.path}';
      return path;
    }
    return null; // 不重定向
  },
  routes: [ ... ],
);
```

> 注意：`state.uri` 在 go_router 中是 `Uri` 类型。`lifeitems://smart-entry/input` 解析为 `scheme=lifeitems, host=smart-entry, path=/input`，所以 `/${uri.host}${uri.path}` = `/smart-entry/input`。对于 `lifeitems://bills/new`，`host=bills, path=/new` → `/bills/new`。对于 `lifeitems://items`，`host=items, path=` → `/items`。验证每种 URI 的解析结果。

- [ ] **Step 5: 静态检查**

Run: `flutter analyze lib/core/router/app_router.dart`
Expected: No issues

- [ ] **Step 6: 提交**

```bash
git add android/app/src/main/res/xml/shortcuts.xml android/app/src/main/res/values/strings.xml android/app/src/main/AndroidManifest.xml lib/core/router/app_router.dart
git commit -m "feat(phase2): add app shortcuts and deep link URI scheme"
```

---

## Task 2: Widget 数据同步服务 WidgetSyncService

**Files:**
- Create: `lib/features/home/services/widget_sync_service.dart`
- Test: `test/home/widget_sync_service_test.dart`

- [ ] **Step 1: 添加 home_widget 依赖**

Run: `flutter pub add home_widget`
Expected: 成功

- [ ] **Step 2: 写失败测试**

`test/home/widget_sync_service_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:home_widget/home_widget.dart';
import 'package:record_everything/features/home/services/widget_sync_service.dart';

void main() {
  test('formatWidgetItem 格式化待办条目 JSON', () {
    final json = WidgetSyncService.formatWidgetItems([
      WidgetItemData(title: '续费会员', isOverdue: false),
      WidgetItemData(title: '补办证件', isOverdue: true),
    ]);
    expect(json, contains('续费会员'));
    expect(json, contains('补办证件'));
    expect(json, contains('"isOverdue":true'));
  });

  test('formatWidgetItem 空列表返回空 JSON 数组', () {
    expect(WidgetSyncService.formatWidgetItems([]), '[]');
  });
}
```

- [ ] **Step 3: 写实现**

`lib/features/home/services/widget_sync_service.dart`:
```dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

/// Widget 数据同步服务。spec §4.2。
/// 把今日待办 + 月度收支写入 SharedPreferences，供 Android Widget 读取。
class WidgetSyncService {
  /// 同步数据到 Widget。调用时机：App 进入后台 / 数据变更。
  static Future<void> sync({
    required String dateLabel,
    required int todayCount,
    required int overdueCount,
    required List<WidgetItemData> items,
    required String monthlyIncome,
    required String monthlyExpense,
  }) async {
    await Future.wait([
      HomeWidget.saveWidgetData<String>('widget_date', dateLabel),
      HomeWidget.saveWidgetData<int>('widget_today_count', todayCount),
      HomeWidget.saveWidgetData<int>('widget_overdue_count', overdueCount),
      HomeWidget.saveWidgetData<String>('widget_items', formatWidgetItems(items)),
      HomeWidget.saveWidgetData<String>('widget_monthly_income', monthlyIncome),
      HomeWidget.saveWidgetData<String>('widget_monthly_expense', monthlyExpense),
    ]);
    await HomeWidget.updateWidget(
      qualifiedAndroidName: 'com.lifeitems.record_everything.HomeWidgetProvider',
    );
  }

  /// 将待办列表格式化为 JSON 字符串（最多 3 条）。
  static String formatWidgetItems(List<WidgetItemData> items) {
    final list = items.take(3).map((e) => {
      'title': e.title,
      'isOverdue': e.isOverdue,
    }).toList();
    return jsonEncode(list);
  }
}

/// 单条待办数据（用于 Widget 显示）。
@immutable
class WidgetItemData {
  const WidgetItemData({required this.title, required this.isOverdue});
  final String title;
  final bool isOverdue;
}
```

- [ ] **Step 4: 运行测试**

Run: `flutter test test/home/widget_sync_service_test.dart`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add lib/features/home/services/widget_sync_service.dart test/home/widget_sync_service_test.dart pubspec.yaml pubspec.lock
git commit -m "feat(phase2): add WidgetSyncService and home_widget dependency"
```

---

## Task 3: Widget 原生实现（Kotlin + XML 布局）

**Files:**
- Create: `android/app/src/main/res/xml/home_widget_info.xml`
- Create: `android/app/src/main/res/layout/widget_home.xml`
- Create: `android/app/src/main/kotlin/com/lifeitems/record_everything/HomeWidgetProvider.kt`
- Modify: `android/app/src/main/AndroidManifest.xml`

- [ ] **Step 1: Widget 元数据**

`android/app/src/main/res/xml/home_widget_info.xml`:
```xml
<?xml version="1.0" encoding="utf-8"?>
<appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"
    android:minWidth="250dp"
    android:minHeight="110dp"
    android:targetCellWidth="4"
    android:targetCellHeight="2"
    android:updatePeriodMillis="1800000"
    android:initialLayout="@layout/widget_home"
    android:resizeMode="horizontal|vertical"
    android:widgetCategory="home_screen"
    android:description="@string/widget_description" />
```

在 `strings.xml` 中添加：
```xml
<string name="widget_description">今日待办与收支概览</string>
```

- [ ] **Step 2: Widget 布局**

`android/app/src/main/res/layout/widget_home.xml`:
```xml
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:orientation="vertical"
    android:background="@android:color/white"
    android:padding="12dp">

    <!-- 顶部：日期 + 标题 -->
    <LinearLayout
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:orientation="horizontal"
        android:gravity="center_vertical">
        <TextView
            android:id="@+id/widget_date"
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_weight="1"
            android:text="📅 --"
            android:textSize="13sp"
            android:textColor="#333333" />
        <TextView
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:text="生活事项"
            android:textSize="12sp"
            android:textColor="#888888" />
    </LinearLayout>

    <View
        android:layout_width="match_parent"
        android:layout_height="1dp"
        android:background="#EEEEEE"
        android:layout_marginTop="6dp"
        android:layout_marginBottom="6dp" />

    <!-- 待办区域 -->
    <LinearLayout
        android:layout_width="match_parent"
        android:layout_height="0dp"
        android:layout_weight="1"
        android:orientation="vertical">
        <TextView
            android:id="@+id/widget_summary"
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:text="今日待办 -- 项"
            android:textSize="12sp"
            android:textColor="#666666"
            android:layout_marginBottom="4dp" />
        <TextView
            android:id="@+id/widget_item_1"
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:textSize="13sp"
            android:textColor="#333333"
            android:visibility="gone" />
        <TextView
            android:id="@+id/widget_item_2"
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:textSize="13sp"
            android:textColor="#333333"
            android:visibility="gone" />
        <TextView
            android:id="@+id/widget_item_3"
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:textSize="13sp"
            android:textColor="#333333"
            android:visibility="gone" />
    </LinearLayout>

    <View
        android:layout_width="match_parent"
        android:layout_height="1dp"
        android:background="#EEEEEE"
        android:layout_marginTop="6dp"
        android:layout_marginBottom="6dp" />

    <!-- 底部：收支 + 记账按钮 -->
    <LinearLayout
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:orientation="horizontal"
        android:gravity="center_vertical">
        <TextView
            android:id="@+id/widget_finance"
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_weight="1"
            android:text="本月：--"
            android:textSize="12sp"
            android:textColor="#666666" />
        <TextView
            android:id="@+id/widget_add_btn"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:text="+记账"
            android:textSize="13sp"
            android:textColor="#4CAF7D"
            android:paddingStart="8dp"
            android:paddingEnd="8dp"
            android:paddingTop="4dp"
            android:paddingBottom="4dp" />
    </LinearLayout>
</LinearLayout>
```

- [ ] **Step 3: Kotlin WidgetProvider**

`android/app/src/main/kotlin/com/lifeitems/record_everything/HomeWidgetProvider.kt`:
```kotlin
package com.lifeitems.record_everything

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class HomeWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: android.content.SharedPreferences
    ) {
        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_home).apply {
                // 日期
                setTextViewText(R.id.widget_date, widgetData.getString("widget_date", "📅 --"))

                // 待办概览
                val todayCount = widgetData.getInt("widget_today_count", 0)
                val overdueCount = widgetData.getInt("widget_overdue_count", 0)
                val summary = buildString {
                    append("今日待办 $todayCount 项")
                    if (overdueCount > 0) append("    已逾期 $overdueCount 项")
                }
                setTextViewText(R.id.widget_summary, summary)

                // 待办条目
                val itemsJson = widgetData.getString("widget_items", "[]") ?: "[]"
                try {
                    val items = org.json.JSONArray(itemsJson)
                    val itemViews = listOf(R.id.widget_item_1, R.id.widget_item_2, R.id.widget_item_3)
                    for (i in 0 until minOf(items.length(), 3)) {
                        val item = items.getJSONObject(i)
                        val title = item.getString("title")
                        val isOverdue = item.getBoolean("isOverdue")
                        val prefix = if (isOverdue) "⚠️ " else "  · "
                        setTextViewText(itemViews[i], "$prefix$title")
                        setViewVisibility(itemViews[i], View.VISIBLE)
                    }
                    // 隐藏多余的条目
                    for (i in items.length() until 3) {
                        setViewVisibility(itemViews[i], View.GONE)
                    }
                } catch (_: Exception) {}

                // 收支
                val income = widgetData.getString("widget_monthly_income", "--") ?: "--"
                val expense = widgetData.getString("widget_monthly_expense", "--") ?: "--"
                setTextViewText(R.id.widget_finance, "本月：收入 $income  支出 $expense")

                // 点击整个 Widget → 打开首页
                val homeIntent = Intent(context, MainActivity::class.java).apply {
                    data = Uri.parse("lifeitems://home")
                }
                setOnClickFillInIntent(R.id.widget_date, homeIntent)

                // 点击 [+记账] → 打开智能输入
                val addIntent = Intent(context, MainActivity::class.java).apply {
                    data = Uri.parse("lifeitems://smart-entry/input")
                }
                setOnClickFillInIntent(R.id.widget_add_btn, addIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
```

- [ ] **Step 4: 注册 Widget Provider 到 Manifest**

在 `AndroidManifest.xml` 的 `<application>` 标签内、`</application>` 之前追加：
```xml
<!-- App Widget -->
<receiver
    android:name=".HomeWidgetProvider"
    android:exported="true">
    <intent-filter>
        <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
    </intent-filter>
    <meta-data
        android:name="android.appwidget.provider"
        android:resource="@xml/home_widget_info" />
</receiver>
```

- [ ] **Step 5: 静态检查**

Run: `flutter analyze`
Expected: No issues

- [ ] **Step 6: 提交**

```bash
git add android/app/src/main/res/xml/home_widget_info.xml android/app/src/main/res/layout/widget_home.xml android/app/src/main/res/values/strings.xml android/app/src/main/kotlin/com/lifeitems/record_everything/HomeWidgetProvider.kt android/app/src/main/AndroidManifest.xml
git commit -m "feat(phase2): add Android App Widget with layout and provider"
```

---

## Task 4: Widget 生命周期集成（Flutter 侧触发刷新）

**Files:**
- Modify: `lib/app.dart`
- Modify: `lib/features/life_item/providers/life_item_providers.dart`
- Modify: `lib/features/bill/providers/bill_providers.dart`

- [ ] **Step 1: app.dart 添加 WidgetsBindingObserver**

修改 `lib/app.dart`，在 `_ShareBootstrap` 中添加 `WidgetsBindingObserver`，App 进入后台时触发 Widget 刷新：

```dart
class _ShareBootstrapState extends State<_ShareBootstrap>
    with WidgetsBindingObserver {
  // ... 现有代码 ...

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // ... 现有 postFrameCallback ...
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      // App 进入后台，同步数据到 Widget。
      _syncWidget();
    }
  }

  Future<void> _syncWidget() async {
    final container = ProviderScope.containerOf(context);
    await WidgetSyncService.syncFromProviders(container);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // ... 现有 dispose ...
    super.dispose();
  }
}
```

- [ ] **Step 2: WidgetSyncService 添加 syncFromProviders 便捷方法**

在 `widget_sync_service.dart` 中添加：

```dart
/// 从 Riverpod providers 读取数据并同步到 Widget。
static Future<void> syncFromProviders(ProviderContainer container) async {
  try {
    final now = DateTime.now();
    final weekday = ['周一','周二','周三','周四','周五','周六','周日'][now.weekday - 1];
    final dateLabel = '${now.month}月${now.day}日 $weekday';

    // 读取今日待办。
    final agenda = await container.read(homeSelectedDayAgendaProvider.future);
    final todayItems = agenda
        .where((a) => !a.isCompleted)
        .map((a) => WidgetItemData(title: a.title, isOverdue: a.isOverdue))
        .toList();
    final overdueCount = todayItems.where((i) => i.isOverdue).length;

    // 读取月度收支。
    final income = await container.read(homeMonthlyIncomeProvider.future);
    final expense = await container.read(homeMonthlyExpenseProvider.future);

    await sync(
      dateLabel: dateLabel,
      todayCount: todayItems.length,
      overdueCount: overdueCount,
      items: todayItems,
      monthlyIncome: MoneyFormatter.format(income),
      monthlyExpense: MoneyFormatter.format(expense),
    );
  } catch (_) {
    // 静默失败，不阻断 App。
  }
}
```

> 注意：需要 import `homeSelectedDayAgendaProvider`、`homeMonthlyIncomeProvider`、`homeMonthlyExpenseProvider`、`MoneyFormatter`。

- [ ] **Step 3: CRUD 后触发刷新**

在 `life_item_providers.dart` 的 `LifeItemNotifier.create()`、`complete()`、`delete()` 方法末尾添加：
```dart
// 触发 Widget 刷新（异步，不阻断主流程）。
WidgetSyncService.syncFromProviders(ref).ignore();
```

同理在 `bill_providers.dart` 的 `BillNotifier.create()`、`delete()` 方法末尾添加。

> 注意：需要 import `WidgetSyncService`。`syncFromProviders` 需要 `ProviderContainer`，在 Notifier 中通过 `ref` 获取。如果 `ref` 类型不直接暴露 `ProviderContainer`，改用 `ref.read(provider)` 逐个读取后调用 `sync()`。

- [ ] **Step 4: 运行测试**

Run: `flutter test test/home/widget_sync_service_test.dart`
Expected: PASS

Run: `flutter analyze`
Expected: No issues

- [ ] **Step 5: 提交**

```bash
git add lib/app.dart lib/features/home/services/widget_sync_service.dart lib/features/life_item/providers/life_item_providers.dart lib/features/bill/providers/bill_providers.dart
git commit -m "feat(phase2): add widget lifecycle integration and CRUD refresh triggers"
```

---

## Task 5: 端到端验证（手动测试清单）

本 Task 无代码，纯手动验证。

- [ ] **Step 1: App Shortcuts 验证**
  - 长按 App 图标 → 出现 3 个快捷入口（智能输入、快速记账、今日待办）
  - 点击"智能输入" → 打开智能输入页
  - 点击"快速记账" → 打开账单新建页
  - 点击"今日待办" → 打开事项列表页

- [ ] **Step 2: Widget 验证**
  - 长按桌面空白处 → 小组件 → 找到"生活事项" → 添加 4×2 Widget
  - Widget 显示今日日期、待办数量、待办条目（最多 3 条）、月度收支
  - 逾期事项显示 ⚠️ 图标

- [ ] **Step 3: Widget 交互验证**
  - 点击 Widget 任意位置 → 打开 App 首页
  - 点击 [+记账] → 打开智能输入页

- [ ] **Step 4: Widget 刷新验证**
  - 在 App 中新建一个事项 → 切到桌面 → Widget 数据更新
  - 在 App 中删除一个账单 → 切到桌面 → Widget 数据更新
  - 等待 30 分钟（或手动触发 `updateWidget`）→ Widget 刷新

---

## 手动测试清单（依赖真机）

- [ ] 长按 App 图标 → 3 个快捷入口正常显示
- [ ] 点击每个快捷入口 → 正确跳转到对应页面
- [ ] 桌面添加 Widget → 显示今日数据
- [ ] Widget 点击 → 打开首页
- [ ] [+记账] 点击 → 打开智能输入
- [ ] CRUD 后切到桌面 → Widget 数据刷新
- [ ] Widget 无数据时显示默认占位文本（不崩溃）
