# 深色模式与多语言（中/英）设计文档

- **状态**：已确认
- **日期**：2026-06-21
- **范围**：主题切换（浅色/深色/跟随系统）+ 多语言（简体中文、English）
- **目标平台**：Android（纯 Dart 层跨平台），保持现有架构分层
- **核心承诺**：深色模式下所有页面文字清晰可读，不出现"白底白字/黑底黑字/图标不可见"等修改不完整问题

## 1. 背景与目标

当前 App 仅有一套固定浅色主题（`AppColors` 全为 `static const`，`AppTheme.lightTheme()` 单一 ThemeData），且全部 UI 文案为硬编码中文（6856 个中文字符分布在 148 个 dart 文件中），无任何 i18n 基建。

本设计解决两个问题：
1. **深色模式**：让整套 UI 在浅色/深色下都清晰可读，并提供用户可控的切换入口。
2. **多语言**：支持简体中文与 English 两种语言，运行时切换，覆盖所有面向用户的文案。

### 1.1 已确认的关键决策

| 编号 | 决策点 | 选择 | 理由 |
|------|--------|------|------|
| D1 | 默认分类名多语言 | 显示层翻译（内置分类走稳定 key 翻译，用户自建分类原样显示） | 切换语言后历史数据立即变；无数据漂移；符合"数据即 key、显示即翻译"原则 |
| D2 | 智能解析关键词 | 中英文各一套关键词表，按当前 Locale 选择 | 贴近各语言真实输入习惯，保证识别率；与现有"本地优先 + AI 兜底"架构一致 |
| D3 | 主题切换粒度 | 三选一（跟随系统/浅色/深色）+ 持久化 | 主流 App 习惯，用户控制力强；默认跟随系统 |
| D4 | i18n 方案 | 官方 `flutter_localizations` + `gen-l10n` | `intl 0.19.0` 已在 pubspec，零新增依赖；强类型生成类；与现有代码生成基建一致 |
| D5 | 代码注释/日志字符串 | 不翻译，保留中文 | 开发者面向内容，不影响用户；翻译纯属浪费 |
| D6 | Android configChanges | 补 `locale` 标志 | 切换语言时 Activity 不重建，表单草稿/页面状态保留 |

## 2. 颜色令牌（Color Token）系统

这是兑现"深色模式看得清"承诺的核心机制。

### 2.1 令牌化设计

把现有 `AppColors` 中写死的 `static const` 颜色值，重构为**主题感知的语义令牌**：UI 代码只引用语义名（如"正文文字色"），实际取值由当前亮/暗主题决定。

UI 调用方式从 `AppColors.textPrimary`（无参 const）改为 `AppColors.textPrimary(context)`（传 BuildContext）。

**新 `lib/core/theme/app_colors.dart`（重写）**：

```dart
import 'package:flutter/material.dart';
import 'app_palette.dart';

/// 语义颜色令牌。所有 UI 代码通过本类取色，禁止直接用 Color(0xFF...) / Colors.black / Colors.white。
abstract class AppColors {
  static Color primary(BuildContext c) => paletteOf(c).primary;
  static Color income(BuildContext c) => paletteOf(c).income;
  static Color expense(BuildContext c) => paletteOf(c).expense;
  static Color overdue(BuildContext c) => paletteOf(c).overdue;
  static Color upcoming(BuildContext c) => paletteOf(c).upcoming;
  static Color completed(BuildContext c) => paletteOf(c).completed;
  static Color error(BuildContext c) => paletteOf(c).error;
  static Color textPrimary(BuildContext c) => paletteOf(c).textPrimary;
  static Color textSecondary(BuildContext c) => paletteOf(c).textSecondary;
  static Color textHint(BuildContext c) => paletteOf(c).textHint;
  static Color background(BuildContext c) => paletteOf(c).background;
  static Color surface(BuildContext c) => paletteOf(c).surface;
  static Color border(BuildContext c) => paletteOf(c).border;
  static Color borderLight(BuildContext c) => paletteOf(c).borderLight;

  /// 从 Theme 中取出 _AppPalette extension（封装在 app_palette.dart）。
  static AppPalette paletteOf(BuildContext c) =>
      Theme.of(c).extension<AppPalette>()!;

  // 纯尺寸常量保持不变（与颜色无关，无需主题感知）。
  static const cardRadiusLarge = 16.0;
  static const cardRadiusSmall = 8.0;
}
```

### 2.2 `AppPalette` ThemeExtension

**新 `lib/core/theme/app_palette.dart`**：

```dart
import 'package:flutter/material.dart';

/// 全应用语义调色板，作为 ThemeExtension 挂到 ThemeData。
/// 浅/深两套实例，由 MaterialApp.themeMode 自动选用。
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  final Color primary;
  final Color income;
  final Color expense;
  final Color overdue;
  final Color upcoming;
  final Color completed;
  final Color error;
  final Color textPrimary;
  final Color textSecondary;
  final Color textHint;
  final Color background;
  final Color surface;
  final Color border;
  final Color borderLight;

  const AppPalette({
    required this.primary,
    required this.income,
    required this.expense,
    required this.overdue,
    required this.upcoming,
    required this.completed,
    required this.error,
    required this.textPrimary,
    required this.textSecondary,
    required this.textHint,
    required this.background,
    required this.surface,
    required this.border,
    required this.borderLight,
  });

  /// 浅色调色板（值与现 AppColors 完全一致，保证视觉零回归）。
  static const light = AppPalette(
    primary: Color(0xFF4CAF7D),
    income: Color(0xFF4CAF7D),
    expense: Color(0xFFEF6C6C),
    overdue: Color(0xFFEF6C6C),
    upcoming: Color(0xFFFFA726),
    completed: Color(0xFF81C784),
    error: Color(0xFFEF6C6C),
    textPrimary: Color(0xFF2D3436),
    textSecondary: Color(0xFF636E72),
    textHint: Color(0xFFB2BEC3),
    background: Color(0xFFF8FAF9),
    surface: Color(0xFFFFFFFF),
    border: Color(0x14000000),   // black 8%
    borderLight: Color(0x0F000000), // black 6%
  );

  /// 深色调色板：提亮品牌色、翻转文字明暗、深色背景+略亮卡片。
  static const dark = AppPalette(
    primary: Color(0xFF66C99B),
    income: Color(0xFF66C99B),
    expense: Color(0xFFEF8B8B),
    overdue: Color(0xFFEF8B8B),
    upcoming: Color(0xFFFFB851),
    completed: Color(0xFF9BD9A0),
    error: Color(0xFFEF8B8B),
    textPrimary: Color(0xFFE8EAED),
    textSecondary: Color(0xFFB0B6BC),
    textHint: Color(0xFF6B7178),
    background: Color(0xFF0F1410),
    surface: Color(0xFF1A201C),
    border: Color(0x1AFFFFFF),     // white 10%
    borderLight: Color(0x14FFFFFF), // white 8%
  );

  @override
  AppPalette copyWith({
    Color? primary, Color? income, Color? expense, Color? overdue,
    Color? upcoming, Color? completed, Color? error, Color? textPrimary,
    Color? textSecondary, Color? textHint, Color? background, Color? surface,
    Color? border, Color? borderLight,
  }) => AppPalette(
    primary: primary ?? this.primary,
    income: income ?? this.income,
    expense: expense ?? this.expense,
    overdue: overdue ?? this.overdue,
    upcoming: upcoming ?? this.upcoming,
    completed: completed ?? this.completed,
    error: error ?? this.error,
    textPrimary: textPrimary ?? this.textPrimary,
    textSecondary: textSecondary ?? this.textSecondary,
    textHint: textHint ?? this.textHint,
    background: background ?? this.background,
    surface: surface ?? this.surface,
    border: border ?? this.border,
    borderLight: borderLight ?? this.borderLight,
  );

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      primary: Color.lerp(primary, other.primary, t)!,
      income: Color.lerp(income, other.income, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
      overdue: Color.lerp(overdue, other.overdue, t)!,
      upcoming: Color.lerp(upcoming, other.upcoming, t)!,
      completed: Color.lerp(completed, other.completed, t)!,
      error: Color.lerp(error, other.error, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textHint: Color.lerp(textHint, other.textHint, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderLight: Color.lerp(borderLight, other.borderLight, t)!,
    );
  }
}
```

### 2.3 `AppTheme` 提供 light/dark 双套

**重写 `lib/core/theme/app_theme.dart`**：`lightTheme()` 与新增 `darkTheme()`，两套都挂 `extensions: [AppPalette.light / .dark]`。

- `scaffoldBackgroundColor`、`cardTheme.color`、`inputDecorationTheme.fillColor`、`appBarTheme.backgroundColor`、`bottomNavigationBarTheme.backgroundColor`、`textTheme` 颜色——全部改用 `ColorScheme` 派生值（`colorScheme.surface`/`onSurface`/`primary` 等），不再写死 `AppColors.xxx`。
- `colorScheme` 用 `ColorScheme.fromSeed(seedColor: ..., brightness: Brightness.light/dark)` 生成，再覆盖关键槽位。
- `appBarTheme` 的 `systemOverlayStyle` 按 brightness 配置（浅色主题 `SystemUiOverlayStyle.dark`，深色主题 `SystemUiOverlayStyle.light`），保证状态栏图标色清晰。

## 3. 颜色迁移与防漏改策略

### 3.1 四批次迁移

**批次 1：建立令牌系统（破坏性，与批次 2 连续完成）**
- 新建 `app_palette.dart`，重写 `app_colors.dart`、`app_theme.dart`（见第 2 节）。
- 删除 `AppColors` 所有 `static const` 颜色，改为 `static xxx(BuildContext)`。
- 此批完成后代码无法编译（150+ 调用点签名变了），必须与批次 2 连续完成。

**批次 2：全量替换调用点**
- 按以下数量机械替换 + 手工核对：
  | 令牌 | 出现次数 |
  |---|---|
  | `AppColors.primary` | 75 |
  | `AppColors.textSecondary` | 61 |
  | `AppColors.surface` | 31 |
  | `AppColors.expense` | 22 |
  | `AppColors.overdue` | 22 |
  | `AppColors.income` | 20 |
  | `AppColors.textHint` | 19 |
  | `AppColors.textPrimary` | 15 |
  | `AppColors.background` | 15 |
  | `AppColors.upcoming` | 15 |
  | `AppColors.completed` | 12 |
  | `AppColors.border` | 5 |
- 替换规则：
  - 在 `build()` / `State` 方法能拿到 `context` → 直接传 `AppColors.xxx(context)`。
  - 在 `Theme`/`TextStyle` 无 context 场景（主要在 `app_theme.dart` 的 `textTheme`）→ 改用 `ColorScheme` 派生值。
- `app_theme.dart` 的 `textTheme` 不再写死颜色，改用 `colorScheme.onSurface`/`onSurfaceVariant`/`primary`。

**批次 3：清理硬编码颜色**
- `Colors.white`（11 处）：逐个判断语义，映射到 `surface`/`textPrimary`/`primary` 前景色等。
- `Colors.black` / `Color(0xFF...)`（约 49 处）：同上，多为描边/阴影/文字色。
- `withValues(alpha:)`（66 处）：基于 black 的描边翻转为 `border` 令牌；基于 white 的遮罩按需翻转。

**批次 4：特殊组件审查**
这些是深色模式"看不清"重灾区，逐个验证：
- 图表（`lib/features/statistics/widgets/*_chart.dart`）：`fl_chart` 网格线、柱状图填充、折线颜色——深色背景上调对比度。
- 日历（`lib/features/home/widgets/home_calendar*.dart`）：选中日、今日、有事项日期的背景/文字色组合。
- 滑动操作按钮、FAB、Toast overlay（`lib/core/utils/toast.dart`）、对话框。
- OCR/AI 设置页（`lib/features/smart_entry/pages/ai_assistant_settings_page.dart`）的代码块/Key 输入框。
- 所有 `Material(color:)`、`Card(color:)`、`Container(color:)` 直接赋色的位置。

### 3.2 三重防漏改保障

1. **令牌 API 编译期强制**：删除 `static const textPrimary` 后，旧调用 `AppColors.textPrimary`（无参）编译失败 → 所有遗漏点在 `flutter analyze` 暴露，无法漏网。

2. **新增 `avoid_raw_color_literal` lint 规则**：在现有 `tools/disposable_resource_lint` 旁新增 `tools/avoid_raw_color_literal`，禁止 `lib/` 下出现：
   - `Color(0xFF...)` 字面量
   - `Colors.black` / `Colors.white` 直接引用
   - 白名单：`lib/core/theme/app_palette.dart`、`*_test.dart`、`test/**`。
   从源头防止未来再硬编码。

3. **深色模式专项测试**：见第 6 节。

### 3.3 不改的边界

- 不引入动态取色（Material You / 动态壁纸取色），仅静态浅/深两套。
- 不为图标/插画资源做反色版本（当前无彩色 PNG 资源）。
- 状态栏/导航栏图标色交给 `SystemUiOverlayStyle` 自动适配。

## 4. 多语言（i18n）基建

### 4.1 目录结构

```
lib/l10n/
  app_en.arb          # 英文（基准 ARB，gen-l10n template）
  app_zh.arb          # 简体中文
  l10n.dart           # AppLocalizations 上下文便捷扩展
l10n.yaml             # 根目录，gen-l10n 配置
```

### 4.2 gen-l10n 配置（`l10n.yaml`）

```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
output-class: AppLocalizations
output-dir: lib/l10n/generated
synthetic-package: false   # 生成到 lib/ 而非合成包，便于 lint 检查
nullable-getter: false
```

### 4.3 key 命名约定（按 feature 前缀，保证单文件可检索）

| 前缀 | 范围 | 示例 |
|---|---|---|
| `common_*` | 通用：保存/取消/删除/确认/重试 | `common_save`, `common_cancel` |
| `enum_*` | 枚举标签 | `enum_projectStatus_active` |
| `cat_*` | 内置分类显示名（D1） | `cat_food`, `cat_salary` |
| `home_*` | 首页 | `home_todayTodos` |
| `item_*` | 生活事项 | `item_completeAction_generateBill` |
| `bill_*` | 账单 | `bill_filter_subscription` |
| `project_*` | 项目 | `project_status_advanceLabel` |
| `stats_*` | 统计 | `stats_budgetNotSet` |
| `settings_*` | 设置 | `settings_themeMode_dark` |
| `smart_*` | 智能录入 | `smart_confirmTitle` |
| `search_*` | 搜索 | `search_hint` |

带参数的字符串用 ICU 占位符：
```json
"item_overdueDays": "{count} 天逾期",
"@item_overdueDays": { "placeholders": { "count": { "type": "int" } } }
```

### 4.4 Locale 状态管理

复用现有 `lib/features/settings/providers/settings_providers.dart` 的 `sharedPrefsProvider`，新增：

```dart
final localeProvider = NotifierProvider<LocaleNotifier, Locale>(LocaleNotifier.new);

class LocaleNotifier extends Notifier<Locale> {
  static const _key = 'app_locale';  // 'zh' / 'en' / null(跟随系统)

  @override
  Locale build() {
    final prefs = ref.read(sharedPrefsProvider);
    final saved = prefs.getString(_key);
    if (saved == 'en') return const Locale('en');
    if (saved == 'zh') return const Locale('zh');
    return _systemLocale();  // null → 跟随系统
  }

  Future<void> set(Locale locale) async {
    state = locale;
    await ref.read(sharedPrefsProvider).setString(_key, locale.languageCode);
  }

  Future<void> followSystem() async {
    await ref.read(sharedPrefsProvider).remove(_key);
    state = _systemLocale();
  }

  /// null 表示跟随系统，用于 UI 显示"跟随系统"选中态。
  bool get isFollowingSystem =>
      ref.read(sharedPrefsProvider).getString(_key) == null;

  Locale _systemLocale() {
    final platform = WidgetsBinding.instance.platformDispatcher.locale;
    // 系统是 en 用 en，否则默认 zh（兜底）。
    return platform.languageCode == 'en' ? const Locale('en') : const Locale('zh');
  }
}
```

> 注：实现阶段需确认 `sharedPrefsProvider` 是同步可读。若为异步，则 `localeProvider`/`themeModeProvider` 改用预热机制（见 5.3）。

### 4.5 UI 访问便捷扩展（`lib/l10n/l10n.dart`）

```dart
import 'package:flutter/material.dart';
import 'generated/app_localizations.dart';

extension L10nContext on BuildContext {
  AppLocalizations get l => AppLocalizations.of(this);
}
```

UI 中使用：`Text(context.l.common_save)`。

`AppLocalizations.localizationsDelegates` 已自动包含 `GlobalMaterialLocalizations/CupertinoLocalizations/WidgetsLocalizations`，切换语言后系统组件（iOS 日期选择器、Cupertino 控件）也跟随。

### 4.6 pubspec.yaml 依赖

新增 `flutter_localizations` SDK 依赖（不引入第三方）：

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:   # 新增
    sdk: flutter
  intl: ^0.19.0            # 已存在
```

`flutter` 配置块新增：
```yaml
flutter:
  uses-material-design: true
  generate: true           # 启用 gen-l10n
```

## 5. 字符串抽取的三个难点

### 5.1 难点一：枚举标签

现状：`ProjectStatus.active('active', '进行中')`、`ItemStatus`、`BillAmountType`、`RepeatPeriod` 等枚举把中文 label 写在构造里，UI 各处 `status.label` 直接显示。

**问题**：枚举位于 `domain/enums/`（纯数据层），不能依赖 `BuildContext`/`AppLocalizations`，否则破坏分层。

**方案：枚举只保留稳定 key，显示层翻译。**

- 枚举去掉 `label` 字段，新增 `l10nKey` getter：
  ```dart
  enum ProjectStatus {
    active('active'), completed('completed'), cancelled('cancelled'), archived('archived');
    const ProjectStatus(this.value);
    final String value;
    String get l10nKey => 'enum_projectStatus_$value';
    // 其余状态机逻辑（isFinal / nextStatus / canTransitionTo / fromString）不变。
  }
  ```
- ARB 加对应 key（中英文）。
- `lib/l10n/l10n.dart` 提供类型安全的访问扩展：
  ```dart
  extension L10nEnum on AppLocalizations {
    String projectStatus(ProjectStatus s) => _byKey(s.l10nKey);
    String itemStatus(ItemStatus s) => _byKey(s.l10nKey);
    // ... 每个枚举一个方法
  }
  ```
- UI 调用：`context.l.projectStatus(item.status)`。
- 涉及枚举（按 `domain/enums/` 扫描确认）：`ProjectStatus`、`ItemStatus`、`AmountType`、`BillAmountType`、`RepeatPeriod`，以及 `ReminderPreset`（若含 label）。

### 5.2 难点二：默认分类名（D1 已定）

现状：`DefaultCategories.income = [{'name': '工资', 'icon': 'work'}, ...]`，`name` 直接写库。

**方案：分类用稳定 key 标识，显示层翻译；用户自建分类无 key。**

- **数据库迁移（schema v11）**：`Categories` 表新增两列：`builtin_key TEXT NULL` 和 `original_name TEXT NULL`。
  - 内置分类播种时填入：`builtin_key`（如 `'cat_salary'`）+ `original_name`（如 `'工资'`），`name` 列保留中文作为兜底显示（兼容旧查询逻辑）。
  - 用户自建分类 `builtin_key = NULL`、`original_name = NULL`。
  - 迁移逻辑：对所有内置分类（按现有 `name` 值匹配 `DefaultCategories` 的原始中文），回填 `builtin_key` 和 `original_name`（= 当前 name）。
- **用户改名检测**：内置分类被用户改名后，切换语言应保留用户输入而非覆盖为翻译。为可靠判定"是否改过名"，迁移时**额外存原始播种名**：
  - schema v11 同时新增 `builtin_key TEXT NULL` 和 `original_name TEXT NULL` 两列。
  - 内置分类播种时：`builtin_key = 'cat_salary'`，`original_name = '工资'`，`name = '工资'`。
  - 用户改名只改 `name`，`builtin_key`/`original_name` 不变。
- **显示翻译 helper**（优先级明确，自上而下）：
  ```dart
  // lib/core/utils/category_display.dart
  String categoryDisplayName(BuildContext context, Category c) {
    // 1. 用户自建分类（无 builtin_key）：原样显示。
    if (c.builtinKey == null) return c.name;

    // 2. 内置分类被用户改过名（name != 原始播种名）：显示用户改的名。
    //    切换语言不覆盖用户的主动编辑。
    if (c.originalName != null && c.name != c.originalName) return c.name;

    // 3. 内置分类未改名：按 builtin_key 走翻译；翻译缺失兜底 name。
    final localized = context.l.getByKey(c.builtinKey!);
    return localized ?? c.name;
  }
  ```
- ARB 加 `cat_salary` / `cat_food` / ... 中英文（约 40 个内置分类）。
- 所有显示分类名的地方（账单列表、事项卡片、统计饼图图例、分类管理页、筛选器等）改用 `categoryDisplayName()`。
- **分类管理页编辑语义**（明确）：内置分类的 `name` 字段可被用户改名，但 `builtin_key`/`original_name` 不变；用户改的名优先于语言翻译显示。

### 5.3 难点三：智能解析关键词（D2 已定）

现状：`lib/features/smart_entry/constants/smart_entry_keywords.dart` 是纯中文表。

**方案：拆为中/英两套，按当前 Locale 选择。**

- 重构 `smart_entry_keywords.dart`：
  ```dart
  abstract class SmartEntryKeywords {
    static const zh = <KeywordRule>[ /* 现有中文表原样保留 */ ];
    static const en = <KeywordRule>[ /* 新建英文表 */ ];

    static List<KeywordRule> forLocale(Locale l) =>
        l.languageCode == 'en' ? en : zh;
  }
  ```
- `local_rule_engine.dart` 通过 Provider 注入 Locale，匹配时用 `SmartEntryKeywords.forLocale(locale)`。
- **英文表内容**：基于英文记账/待办场景设计，覆盖与中文表对应的语义：
  - 餐饮：`lunch`, `dinner`, `breakfast`, `coffee`, `pizza`, `takeout`...
  - 交通：`uber`, `taxi`, `gas`, `parking`, `subway`...
  - 收入：`salary`, `paycheck`, `bonus`, `refund`...
  - 日期词：`today`, `tomorrow`, `yesterday`, `next week`, `next monday`...
  - 金额：`$25`, `$25.50`, `25 bucks`...
- **`preprocessor.dart`（日期/金额预处理）**：增加英文分支（当前仅识别"明天""下周""3点""25元"），按 Locale 选择预处理规则。
- **`ocr_service.dart`（币种识别）**：英文版识别 `$`，中文版识别 `¥`，按 Locale 切换。

## 6. 设置页入口与初始化流程

### 6.1 设置页新增两个区块

在 `lib/features/settings/pages/settings_page.dart` 的 ListView 中，提醒权限区块下方、数据导入导出区块上方，插入：

**区块 1：外观（Appearance）**
- `DropdownButtonFormField`（复用 `app_dropdown_field.dart`），绑定 `themeModeProvider`。
- 三选项：`跟随系统 / Follow system`、`浅色 / Light`、`深色 / Dark`（标签随当前语言）。

**区块 2：语言（Language）**
- `DropdownButtonFormField`，绑定 `localeProvider`。
- 三选项：`跟随系统`、`简体中文`、`English`。
- **语言名用原生书写**（标准做法）：中文用户看到的"English"、英文用户看到的"简体中文"不翻译，保证用户能识别自己的语言。

### 6.2 `themeModeProvider` 定义

新增到 `settings_providers.dart`：

```dart
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _key = 'app_theme_mode';  // 'system' / 'light' / 'dark'

  @override
  ThemeMode build() {
    final saved = ref.read(sharedPrefsProvider).getString(_key);
    return switch (saved) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,  // 默认跟随系统
    };
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await ref.read(sharedPrefsProvider).setString(_key, mode.name);
  }
}
```

### 6.3 App 启动初始化顺序

当前 `main.dart`：
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(ProviderScope(overrides: [...], child: const App()));
  unawaited(NotificationService.init());
}
```

需调整：`SharedPreferences` 必须在 `runApp` 前初始化完成，否则 `themeModeProvider`/`localeProvider` 首帧读不到值会闪烁（先显示系统默认，再跳到用户选择）：

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SharedPreferences.getInstance();  // 预热，确保首帧可读
  runApp(ProviderScope(overrides: [...], child: const App()));
  unawaited(NotificationService.init());
}
```

实现阶段确认 `sharedPrefsProvider` 实现（同步可读 vs Future）。若为异步，预热后仍保持 `NotifierProvider` 即可（预热保证首帧前已有值）。

### 6.4 平台层联动（Android）

- **状态栏/导航栏图标色**：`AppTheme` 里按 brightness 配置 `SystemUiOverlayStyle`（浅色主题 `SystemUiOverlayStyle.dark` 深色图标，深色主题 `SystemUiOverlayStyle.light` 浅色图标），`MaterialApp.themeMode` 自动驱动。
- **Android configChanges（D6 已定）**：`AndroidManifest.xml` 主 Activity 的 `android:configChanges` 补上 `locale`（如 `...|locale|layoutDirection`），切换语言时 Activity 不重建，表单草稿/页面状态保留。
- **桌面 Widget / Shortcuts**：`lib/features/home/services/widget_sync_service.dart` 中"周一""周二"等中文 weekday，改用 `intl.DateFormat` 按当前 Locale 格式化：
  ```dart
  final locale = container.read(localeProvider);
  final dateLabel = DateFormat('MMMd EEEE', locale.toLanguageTag()).format(now);
  ```
  否则英文用户桌面看到中文星期。

### 6.5 MaterialApp 完整接入（汇总）

`lib/app.dart` 由 `StatelessWidget` 改为 `ConsumerWidget`：

```dart
class App extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    return MaterialApp.router(
      // MaterialApp 顶层 title 用于 Android 任务管理器/最近任务标题，
      // 此处无 BuildContext（build 外层），用 onGenerateTitle 在有 context 后按 locale 翻译。
      onGenerateTitle: (context) => context.l.appName,
      title: '生活事项',  // 兜底常量（onGenerateTitle 生效前的极短窗口）
      debugShowCheckedModeBanner: false,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: themeMode,
      routerConfig: appRouter,
      builder: (context, child) => _ShareBootstrap(child: child!),
    );
  }
}
```

ARB 中加 `appName` key（中：`生活事项`，英：`Life Items`）。

## 7. 测试策略与验收标准

### 7.1 四层测试

**第一层：静态检查（防漏改硬闸）**

| 检查项 | 工具 | 阻断条件 |
|---|---|---|
| 旧颜色 API 残留 | `flutter analyze` | 删 `static const` 后，`AppColors.textPrimary`（无参）编译失败 |
| 硬编码颜色字面量 | `avoid_raw_color_literal` lint | `lib/` 出现 `Color(0xFF...)`/`Colors.black`/`Colors.white`（白名单：`app_palette.dart`、`*_test.dart`） |
| 硬编码中文 UI 字符串 | 一次性扫描脚本（`tools/scan_chinese_ui.dart`，手动跑） | `lib/` 的 `Text(...)`/`label:`/`title:` 含中文（白名单：注释、`smart_entry_keywords.dart` 的 `zh` 表、数据库播种注释） |
| ARB 完整性 | gen-l10n | `app_en.arb`（基准）与 `app_zh.arb` key 集合必须一致，否则编译失败 |

中文扫描脚本放 `tools/`，CI 或本地手动跑，不进 lint（避免误伤注释）。

**第二层：单元测试**

- `AppPalette` 的 `copyWith`/`lerp`（ThemeExtension 契约）。
- `categoryDisplayName()`：内置分类返回翻译、用户自建返回原 name、用户改名的内置分类返回用户名。
- `SmartEntryKeywords.forLocale()`：zh/en 各返回正确表。
- 枚举 `l10nKey` 生成正确。
- `ThemeModeNotifier`/`LocaleNotifier`：持久化读写、默认值、`followSystem()`。

**第三层：组件测试（关键，防"看不清"）**

新增 `test/theme/` 与 `test/l10n/` 目录：
- **对比度 widget test**：对每个主要页面（home/item_list/bill_list/statistics/settings/smart_entry），分别用 `ThemeMode.light`/`ThemeMode.dark` 包裹渲染，断言：
  - 主 `Text` 的 `style.color` 与 `Scaffold` 背景色对比度 ≥ WCAG AA 4.5:1（用一个计算对比度的工具函数）。
  - 卡片内文字与卡片背景对比度达标。
- **i18n 切换 test**：同一页面分别用 `Locale('zh')`/`Locale('en')` 渲染，断言关键文案随语言变化。
- **分类名显示 test**：内置分类在 zh/en 下显示对应翻译。

**第四层：黄金图测试（Golden Test，捕捉视觉回归）**

对 8 个核心页面各生成 light + dark 两张黄金图：
- 首页（日历+今日待办）、生活事项列表、账单列表、项目详情、统计页、设置页、智能输入页、智能确认页。

共 16 张基线。首次生成后纳入版本库。后续颜色改动导致的视觉回归在 `flutter test --update-goldens` 对比时暴露。用 `Ahem` 字体（Flutter 测试默认）规避跨平台字体差异。

### 7.2 验收标准（DoD）

实现完成的硬性门槛：

1. `flutter analyze` 零 warning（含新 lint 规则）。
2. `flutter test` 全绿（含新增 theme/l10n 测试）。
3. 8 个核心页面 × 2 主题 = 16 张黄金图全部通过。
4. 手动验收清单（见 Appendix A）：
   - 设置页切换 浅色→深色→跟随系统，**每个页面逐一检查**无白底白字/黑底黑字/图标不可见。
   - 切换 中文↔英文，每个页面文案正确、无残留中文/英文、无 key 暴露（如显示 `item_completeAction`）。
   - 切换语言后，桌面 Widget 日期标签跟随语言。
   - 切换主题后，状态栏图标色（深/浅）正确。
   - 冷启动时主题/语言无闪烁。
   - 内置分类在英文下显示英文名，切回中文显示中文名；用户改过名的内置分类保留用户名。
5. 切换语言时 Activity 不重建（`configChanges` 生效），表单草稿不丢失。

### 7.3 回归风险点清单（实现时重点盯防）

| 风险点 | 文件 | 原因 |
|---|---|---|
| 图表颜色 | `lib/features/statistics/widgets/*_chart.dart` | `fl_chart` 网格线/柱体写死颜色 |
| 日历选中态 | `lib/features/home/widgets/home_calendar*.dart` | 选中日背景+文字色组合 |
| Toast overlay | `lib/core/utils/toast.dart` | 自建 overlay，背景色可能写死 |
| 滑动操作 | `lib/core/widgets/` 滑动组件 | 操作按钮背景色 |
| 数据库默认数据 | `lib/data/database/app_database.dart` 播种 | 分类 name 写库（D1 处理） |
| `Material`/`Card`/`Container` 直接 `color:` | 全局 | 绕过 theme 的卡片色 |
| `TextStyle(color: Colors.white)` | 11 处 | 深色下白字变不可见或反之 |
| 智能解析双语 | `local_rule_engine`/`preprocessor`/`ocr_service` | 英文规则分支易漏 |

## 8. 明确排除（不做的事）

- 不做 RTL 布局镜像（中英文都是 LTR）。
- 不做 Material You 动态取色。
- 不做第三方语言包加载（仅内置 zh/en）。
- 不翻译代码注释和日志字符串（D5）。
- 不引入除 `flutter_localizations`（Flutter SDK 自带）外的 i18n 依赖。
- 不为图标/插画资源做反色版本。

## Appendix A：手动验收清单

### A.1 主题切换

- [ ] 设置页选择"浅色"：全 App 浅色，状态栏图标深色。
- [ ] 设置页选择"深色"：全 App 深色，状态栏图标浅色，无白底白字/黑底黑字。
- [ ] 设置页选择"跟随系统"：随系统设置变化。
- [ ] 逐一检查页面：首页、生活事项列表/编辑/详情、账单列表/编辑、项目列表/详情/编辑/模板、统计、搜索、设置、回收站、智能输入/确认/AI 设置。
- [ ] 冷启动时直接应用用户选择，无闪烁。
- [ ] 桌面 Widget 在深色系统下显示协调（Widget 本身是原生渲染，主要验证日期标签文字正确）。

### A.2 语言切换

- [ ] 设置页选择"English"：全 App 英文，无残留中文，无 key 暴露。
- [ ] 设置页选择"简体中文"：全 App 中文。
- [ ] 设置页选择"跟随系统"：随系统语言变化。
- [ ] 逐一检查页面文案（同 A.1 页面清单）。
- [ ] 内置分类在英文下显示英文名（如"餐饮"→"Food"）。
- [ ] 用户改过名的内置分类：切换语言后仍显示用户改的名。
- [ ] 切换语言后桌面 Widget 日期标签跟随（"周一"→"Mon"）。
- [ ] 切换语言时表单草稿不丢失（`configChanges` 生效）。
- [ ] 英文下智能输入：输入"lunch $25"能识别为餐饮支出 25 美元（按 `cat_food` 关联）。

### A.3 组合场景

- [ ] 英文 + 深色：两者叠加无冲突。
- [ ] 中文 + 浅色：与现状视觉零回归。
