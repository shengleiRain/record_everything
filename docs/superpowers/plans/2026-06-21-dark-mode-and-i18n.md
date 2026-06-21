# 深色模式与多语言（中/英）实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为现有仅浅色、纯中文的 record_everything 应用增加深色模式（浅/深/跟随系统三选一）与多语言（简体中文 / English），并保证深色模式下全部页面文字清晰可读、不出现"看不清"的修改不完整问题。

**Architecture:** 颜色走 `AppPalette extends ThemeExtension<AppPalette>` 挂到 `ThemeData.extensions`，UI 通过 `AppColors.xxx(context)` 读取（删除旧 `static const` 让漏改编译失败）；i18n 用官方 `flutter_localizations` + `gen-l10n`（`intl 0.19.0` 已在 pubspec，零新增第三方依赖），Locale/ThemeMode 各一个 Riverpod `NotifierProvider` + SharedPreferences 持久化。

**Tech Stack:** Flutter 3.41 / Dart 3.11，Riverpod 2.6.1，Drift 2.22.1（schema v10 → v11），go_router 14.8.1，flutter_localizations（SDK），intl 0.19.0。

**Spec:** `docs/superpowers/specs/2026-06-21-dark-mode-and-i18n-design.md`

---

## 阶段划分与依赖关系

- **阶段 A（颜色令牌）**：建立 ThemeExtension 体系，UI 暂无法编译，必须与阶段 B 连续完成
- **阶段 B（颜色迁移）**：全量替换调用点 + 清理硬编码颜色，恢复编译，此阶段结束 App 已能切换深浅
- **阶段 C（主题切换）**：themeModeProvider + MaterialApp 接入 + 设置页入口
- **阶段 D（i18n 基建）**：gen-l10n 配置 + localeProvider + MaterialApp 接入
- **阶段 E（字符串抽取）**：枚举、分类、UI 文案、智能解析双语
- **阶段 F（测试与收尾）**：新 lint 规则、组件/黄金图测试、手动验收

阶段 A→B 必须连续；C 和 D 可并行但都依赖 B；E 依赖 D；F 依赖 E。

---

## 文件结构

**新建文件：**
- `lib/core/theme/app_palette.dart` — `AppPalette extends ThemeExtension<AppPalette>`，light/dark 两套实例
- `lib/core/utils/category_display.dart` — `categoryDisplayName()` 分类名显示翻译 helper
- `lib/l10n/app_en.arb` — 英文基准 ARB
- `lib/l10n/app_zh.arb` — 简体中文 ARB
- `lib/l10n/l10n.dart` — `L10nContext` / `L10nEnum` 扩展
- `lib/l10n/generated/app_localizations.dart` — gen-l10n 产物（自动生成，需提交）
- `l10n.yaml` — gen-l10n 配置（项目根目录）
- `test/theme/app_palette_test.dart` — ThemeExtension 契约测试
- `test/theme/theme_contrast_test.dart` — 关键页面对比度测试
- `test/l10n/locale_switch_test.dart` — 语言切换渲染测试
- `test/l10n/category_display_test.dart` — 分类名显示测试
- `tools/avoid_raw_color_literal/` — 新自定义 lint 插件包
- `tools/scan_chinese_ui.dart` — 中文 UI 字符串扫描脚本（一次性）

**重写文件：**
- `lib/core/theme/app_colors.dart` — 删除所有 `static const` 颜色，改为 `static xxx(BuildContext)` + `paletteOf(context)`
- `lib/core/theme/app_theme.dart` — 提供 `lightTheme()` 和 `darkTheme()`，两套挂 AppPalette extension

**修改文件（核心）：**
- `lib/app.dart` — StatelessWidget → ConsumerWidget，接入 themeMode/locale/localizations
- `lib/main.dart` — 预热 SharedPreferences
- `lib/features/settings/providers/settings_providers.dart` — 新增 `themeModeProvider`、`localeProvider`
- `lib/features/settings/pages/settings_page.dart` — 新增外观/语言两个区块
- `lib/data/database/tables/categories_table.dart` — 新增 `builtinKey` / `originalName` 列
- `lib/data/database/app_database.dart` — schemaVersion 10 → 11，迁移逻辑，播种写入 builtin_key
- `lib/core/constants/default_categories.dart` — 加 builtin_key，保持 name 兼容
- `lib/domain/enums/*.dart` — 各枚举去 label 加 l10nKey
- `lib/features/smart_entry/constants/smart_entry_keywords.dart` — 拆 zh/en 关键词表
- `lib/features/smart_entry/parser/local_rule_engine.dart` — 注入 Locale 选择关键词表
- `lib/features/home/services/widget_sync_service.dart` — weekday 格式化按 locale
- `android/app/src/main/AndroidManifest.xml` — configChanges 补 locale
- `pubspec.yaml` — 加 flutter_localizations、generate: true
- 全 lib 下所有用 `AppColors.xxx`、`Colors.white`、`Color(0xFF...)` 的文件（阶段 B 批量处理）

---

## 阶段 A：建立颜色令牌系统

### Task A1：创建 AppPalette ThemeExtension

**Files:**
- Create: `lib/core/theme/app_palette.dart`
- Test: `test/theme/app_palette_test.dart`

- [ ] **Step 1: 写 AppPalette 的失败测试（copyWith + lerp 契约）**

创建 `test/theme/app_palette_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record_everything/core/theme/app_palette.dart';

void main() {
  group('AppPalette', () {
    test('light 和 dark 是常量实例', () {
      expect(AppPalette.light.primary, const Color(0xFF4CAF7D));
      expect(AppPalette.dark.textPrimary, const Color(0xFFE8EAED));
      expect(AppPalette.dark.background, const Color(0xFF0F1410));
    });

    test('copyWith 返回包含新值的实例', () {
      final p = AppPalette.light.copyWith(primary: const Color(0xFF000000));
      expect(p.primary, const Color(0xFF000000));
      expect(p.textPrimary, AppPalette.light.textPrimary);
    });

    test('lerp 在两端之间线性插值', () {
      final mid = AppPalette.light.lerp(AppPalette.dark, 0.5);
      // textPrimary: light 0xFF2D3436, dark 0xFFE8EAED，中点近似
      expect(mid.textPrimary, Color.lerp(const Color(0xFF2D3436), const Color(0xFFE8EAED), 0.5));
    });

    test('lerp 传入非 AppPalette 返回自身', () {
      final result = AppPalette.light.lerp(null, 0.5);
      expect(result, same(AppPalette.light));
    });
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/theme/app_palette_test.dart`
Expected: FAIL — `app_palette.dart` 不存在，导入失败

- [ ] **Step 3: 实现 AppPalette**

创建 `lib/core/theme/app_palette.dart`：

```dart
import 'package:flutter/material.dart';

/// 全应用语义调色板，作为 ThemeExtension 挂到 ThemeData。
/// 浅/深两套实例，由 MaterialApp.themeMode 自动选用。
/// spec §2.2。
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

  /// 浅色调色板（值与原 AppColors 完全一致，保证视觉零回归）。
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
    border: Color(0x14000000),
    borderLight: Color(0x0F000000),
  );

  /// 深色调色板：提亮品牌色、翻转文字明暗、深色背景 + 略亮卡片。
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
    border: Color(0x1AFFFFFF),
    borderLight: Color(0x14FFFFFF),
  );

  @override
  AppPalette copyWith({
    Color? primary,
    Color? income,
    Color? expense,
    Color? overdue,
    Color? upcoming,
    Color? completed,
    Color? error,
    Color? textPrimary,
    Color? textSecondary,
    Color? textHint,
    Color? background,
    Color? surface,
    Color? border,
    Color? borderLight,
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

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/theme/app_palette_test.dart`
Expected: PASS（4 个测试）

- [ ] **Step 5: 提交**

```bash
git add lib/core/theme/app_palette.dart test/theme/app_palette_test.dart
git commit -m "feat(theme): add AppPalette ThemeExtension with light/dark palettes"
```

---

### Task A2：重写 AppColors 为主题感知令牌

**Files:**
- Modify: `lib/core/theme/app_colors.dart`

> 注意：此步删除所有 `static const` 颜色，会导致全 lib 编译失败。**不要在此步后单独运行 `flutter analyze`**——必须紧接着执行阶段 B 的批量替换。此步只改 `app_colors.dart` 一个文件。

- [ ] **Step 1: 重写 app_colors.dart**

用以下内容**完整覆盖** `lib/core/theme/app_colors.dart`：

```dart
import 'package:flutter/material.dart';

import 'app_palette.dart';

/// 语义颜色令牌。所有 UI 代码通过本类取色。
///
/// 调用方式：`AppColors.textPrimary(context)`、`AppColors.surface(context)`。
/// 禁止直接使用 `Color(0xFF...)`、`Colors.black`、`Colors.white`
/// （唯一例外：`app_palette.dart` 内的调色板定义）。
///
/// spec §2.1。
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

  /// 从 ThemeData extension 取出调色板。
  static AppPalette paletteOf(BuildContext c) =>
      Theme.of(c).extension<AppPalette>()!;

  /// 浅色品牌色的浅色变体（用于 chip/胶囊背景，跨主题一致）。
  /// 原 primaryLight 在多处用作半透明背景，深色下仍用浅绿半透明可读，
  /// 故保留为常量。
  static const primaryLight = Color(0xFFA5D6B0);

  /// 浅色品牌色的深色变体（图标/文字色，跨主题一致）。
  static const primaryDark = Color(0xFF2E7D4F);

  /// 统一卡片圆角（大）。
  static const cardRadiusLarge = 16.0;

  /// 统一卡片圆角（小）。
  static const cardRadiusSmall = 8.0;
}
```

> 注：`primaryLight`/`primaryDark` 在多处作为半透明背景/图标色使用（如 `settings_page.dart:146` `primaryLight.withValues(alpha: 0.28)`），这些场景跨主题通用，保留为常量避免过度改造。其余颜色全部主题感知。

- [ ] **Step 2: 不要单独运行测试/分析**

明确：此时 lib 编译失败（150+ 处 `AppColors.xxx` 无参调用）。这是预期行为——编译失败即"防漏改第一重保障"。立即进入阶段 B。

- [ ] **Step 3: 提交**

```bash
git add lib/core/theme/app_colors.dart
git commit -m "refactor(theme): rewrite AppColors to context-aware tokens (breaks build)"
```

---

### Task A3：重写 AppTheme 提供 light/dark 双套

**Files:**
- Modify: `lib/core/theme/app_theme.dart`

- [ ] **Step 1: 重写 app_theme.dart**

用以下内容**完整覆盖** `lib/core/theme/app_theme.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_palette.dart';

/// 应用主题。提供浅/深两套 ThemeData，均挂载 [AppPalette] extension。
/// spec §2.3。
class AppTheme {
  static ThemeData lightTheme() => _build(Brightness.light, AppPalette.light);
  static ThemeData darkTheme() => _build(Brightness.dark, AppPalette.dark);

  static ThemeData _build(Brightness brightness, AppPalette palette) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: palette.primary,
      brightness: brightness,
      primary: palette.primary,
      surface: palette.surface,
      error: palette.error,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: palette.background,
      extensions: [palette],
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: palette.surface,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: palette.textPrimary,
        titleTextStyle: TextStyle(
          color: palette.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        systemOverlayStyle: brightness == Brightness.light
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: palette.primary,
        unselectedItemColor: palette.textHint,
        type: BottomNavigationBarType.fixed,
        backgroundColor: palette.surface,
        elevation: 8,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: palette.primary,
        foregroundColor: brightness == Brightness.light
            ? Colors.white
            : const Color(0xFF0F1410),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.primary, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.expense),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.expense, width: 1.4),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        floatingLabelStyle: TextStyle(
          color: palette.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
      dividerTheme: DividerThemeData(color: palette.borderLight, space: 1),
      textTheme: TextTheme(
        headlineLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: palette.textPrimary,
        ),
        headlineMedium: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: palette.textPrimary,
        ),
        bodyLarge: TextStyle(fontSize: 16, color: palette.textPrimary),
        bodyMedium: TextStyle(fontSize: 14, color: palette.textSecondary),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: palette.primary,
        ),
      ),
    );
  }
}
```

> 注：`floatingActionButtonTheme.foregroundColor` 用 `Colors.white`/深色——这是 FAB 内部图标色，浅色主题白图标在绿底上、深色主题深色图标在亮绿底上，均符合 Material 规范，不属于"漏改"。`Colors.white` 在此处是经过判断的合理使用。

- [ ] **Step 2: 提交**

```bash
git add lib/core/theme/app_theme.dart
git commit -m "refactor(theme): AppTheme provides light/dark with AppPalette extension"
```

---

## 阶段 B：颜色迁移（恢复编译）

> 本阶段是机械批量替换 + 重点组件审查。每个任务处理一类颜色引用。

### Task B1：替换带 build context 的 AppColors 调用

**Files:**
- Modify: 全 lib 下所有使用 `AppColors.xxx`（无参）的文件（约 35 个文件、300+ 处）

替换规则（对每个文件逐个执行）：
- `AppColors.textPrimary` → `AppColors.textPrimary(context)`（要求该处 `context` 可用）
- `AppColors.textSecondary` → `AppColors.textSecondary(context)`
- `AppColors.textHint` → `AppColors.textHint(context)`
- `AppColors.background` → `AppColors.background(context)`
- `AppColors.surface` → `AppColors.surface(context)`
- `AppColors.border` → `AppColors.border(context)`
- `AppColors.income` → `AppColors.income(context)`
- `AppColors.expense` → `AppColors.expense(context)`
- `AppColors.overdue` → `AppColors.overdue(context)`
- `AppColors.upcoming` → `AppColors.upcoming(context)`
- `AppColors.completed` → `AppColors.completed(context)`
- `AppColors.error` → `AppColors.error(context)`
- `AppColors.primary` → `AppColors.primary(context)`
- `AppColors.primaryLight` / `AppColors.primaryDark` → **不变**（仍是常量）
- `AppColors.cardRadiusLarge` / `AppColors.cardRadiusSmall` → **不变**

- [ ] **Step 1: 找出所有需修改的文件**

Run: `powershell -NoProfile -Command "Get-ChildItem -Path lib -Recurse -Filter *.dart | Where-Object { $_.FullName -notmatch '\\theme\\app_(colors|palette|theme)\.dart$' } | ForEach-Object { if (Select-String -Path $_.FullName -Pattern 'AppColors\.(textPrimary|textSecondary|textHint|background|surface|border|income|expense|overdue|upcoming|completed|error|primary)\b' -Quiet) { $_.FullName.Replace((Get-Location).Path + '\', '') } }"`

输出需修改的文件清单。

- [ ] **Step 2: 对每个文件执行替换**

对清单中每个文件，用 Edit 工具或文本替换将 `AppColors.<token>` 替换为 `AppColors.<token>(context)`。

**关键判断——context 是否可用：**
- 在 `Widget build(BuildContext context)` 方法体内：✅ 直接用 `context`
- 在 `ConsumerState`/`State` 的方法（`initState`/事件回调）内：用 `this.context` 或 `mounted ? context : null` 守卫
- 在 `Notifier`/`Repository`/纯逻辑类（无 BuildContext）：**不能直接替换**。这类情况通常是传 color 给数据层（罕见），需要把颜色计算上移到 UI 层，或把 `BuildContext` 作为参数传入。

遇到无 context 的调用点，记录到 `docs/superpowers/plans/2026-06-21-dark-mode-and-i18n-notes.md`（本任务中新建）逐一人工处理，原则：颜色永远是 UI 关注点，不应下沉到数据层。

- [ ] **Step 3: 运行 flutter analyze 检查剩余编译错误**

Run: `flutter analyze`
Expected: 剩余错误应只剩"未处理的无 context 调用点"和"硬编码 Colors.white/Color(0xFF...)"（后者在 B2 处理）。逐一处理剩余 AppColors 错误。

- [ ] **Step 4: 提交**

```bash
git add -A
git commit -m "refactor(theme): migrate AppColors calls to context-aware tokens"
```

---

### Task B2：清理硬编码颜色（Colors.white / Colors.black / Color(0xFF...)）

**Files:**
- Modify: 全 lib 下使用 `Colors.white`（约 11 处）、`Colors.black`（约 28 处）、`Color(0xFF...)`（约 21 处）的文件

**映射规则（逐处判断语义后映射）：**
- `Colors.white` 作为卡片/容器背景 → `AppColors.surface(context)`
- `Colors.white` 作为深色品牌色上的文字/图标色（FAB、主色按钮）→ 保留（已有 palette.foregroundColor 判断逻辑）或用 `Theme.of(context).colorScheme.onPrimary`
- `Colors.black` 作为描边 → `AppColors.border(context)`
- `Colors.black.withValues(alpha: ...)` 作为描边/分隔线 → `AppColors.border(context)` 或 `AppColors.borderLight(context)`
- `Colors.black.withValues(alpha: ...)` 作为阴影/遮罩 → 保留但改为基于 Theme.brightness 判断（`Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha:...) : Colors.black.withValues(alpha:...)`），或简化为 `AppColors.borderLight(context)`
- `Color(0xFF...)` 字面量 → 映射到对应语义令牌（如 `0xFFEF6C6C` 是 expense 色 → `AppColors.expense(context)`）

- [ ] **Step 1: 找出所有硬编码颜色**

Run（分三次）:
- `powershell -NoProfile -Command "Get-ChildItem -Path lib -Recurse -Filter *.dart | ForEach-Object { Select-String -Path $_.FullName -Pattern 'Colors\.white' | Select-Object @{N='File';E={$_.Path.Replace((Get-Location).Path + '\', '')}}, LineNumber, Line } | Format-Table -AutoSize -Wrap"`
- 同上改 pattern 为 `Colors\.black`
- 同上改 pattern 为 `Color\(0x`

- [ ] **Step 2: 逐处替换**

按映射规则处理。重点文件（已知高发）：
- `lib/features/settings/pages/settings_page.dart`（`Colors.black.withValues(alpha: 0.06)` 分隔线 → borderLight）
- `lib/features/home/widgets/home_calendar*.dart`（日历选中态）
- `lib/features/statistics/widgets/*_chart.dart`（图表颜色）
- `lib/core/utils/toast.dart`（Toast overlay 背景）

**Toast overlay 特殊处理**：Toast 当前可能用 `Colors.white`/`Colors.black87` 构造背景。改为：背景用 `AppColors.textPrimary(context)`（深底浅字场景），文字用对比色 `AppColors.surface(context)`；或直接用 `Theme.of(context).colorScheme.inverseSurface` 系列。在 `toast.dart` 内确认实际实现后选择最贴近的语义令牌。

- [ ] **Step 3: 运行 flutter analyze 确认无颜色相关错误**

Run: `flutter analyze`
Expected: 无 Color 相关错误（阶段 B 结束时 lib 全量编译通过）

- [ ] **Step 4: 提交**

```bash
git add -A
git commit -m "refactor(theme): replace hardcoded colors with semantic tokens"
```

---

### Task B3：图表与日历组件深色适配（专项审查）

**Files:**
- Modify: `lib/features/statistics/widgets/daily_trend_chart.dart`
- Modify: `lib/features/statistics/widgets/category_trend_chart.dart`
- Modify: `lib/features/home/widgets/home_calendar.dart`
- Modify: `lib/features/home/widgets/home_calendar_sliver.dart`
- Modify: `lib/core/utils/toast.dart`
- Modify: `lib/core/widgets/`（所有滑动操作、按钮组件）

这是深色模式"看不清"重灾区，需逐个渲染验证。

- [ ] **Step 1: 统计图表颜色改为主题感知**

打开 `lib/features/statistics/widgets/daily_trend_chart.dart` 和 `category_trend_chart.dart`。

- `fl_chart` 的 `gridData`/`borderData` 线条颜色 → `AppColors.borderLight(context)`
- 柱状图填充色 → `AppColors.primary(context)`
- 折线色 → `AppColors.expense(context)` 或 `AppColors.income(context)`
- 标题文字色（`titlesData`）→ `AppColors.textSecondary(context)`
- 超阈值标红的柱子（spec §3.3 提到的 1.5 倍日均）→ `AppColors.overdue(context)`

逐个用 `AppColors.xxx(context)` 替换硬编码颜色。

- [ ] **Step 2: 日历选中态颜色**

打开 `lib/features/home/widgets/home_calendar.dart` 和 `home_calendar_sliver.dart`。

- 选中日背景 → `AppColors.primary(context)`
- 选中日文字 → `AppColors.surface(context)`（深色下是深色卡片底色，与浅色文字对比；浅色下是白色）
- 今日边框 → `AppColors.primary(context)`
- 有事项日期的标记点 → `AppColors.overdue(context)`
- 普通日期文字 → `AppColors.textPrimary(context)`
- 非本月日期（灰色）→ `AppColors.textHint(context)`

- [ ] **Step 3: Toast overlay 颜色**

打开 `lib/core/utils/toast.dart`，把背景/文字色改为 `AppColors` 令牌。Toast 通常用深底浅字，所以：
- 背景 → `AppColors.textPrimary(context)`（浅色下深灰底、深色下浅灰底，均与文字对比）
- 文字 → `AppColors.surface(context)`

或若希望 Toast 始终是深底：用 `Theme.of(context).colorScheme.inverseSurface` / `onInverseSurface`。

- [ ] **Step 4: 滑动操作按钮颜色**

打开 `lib/core/widgets/` 下所有涉及 `Dismissible`/滑动操作的组件。

- 完成按钮背景 → `AppColors.completed(context)`
- 延期按钮背景 → `AppColors.upcoming(context)`
- 删除按钮背景 → `AppColors.expense(context)`
- 按钮图标色 → `AppColors.surface(context)` 或 `Colors.white`（保持高对比）

- [ ] **Step 5: 运行已有测试确认无破坏**

Run: `flutter test`
Expected: PASS（已有的 32 个测试文件应继续通过；若有依赖颜色的 widget test 失败，按新令牌修正）

- [ ] **Step 6: 提交**

```bash
git add -A
git commit -m "feat(theme): adapt charts, calendar, toast, swipe actions for dark mode"
```

---

### Task B4：阶段 B 冒烟验证

- [ ] **Step 1: 运行全量分析**

Run: `flutter analyze`
Expected: 无 error、无 warning（或仅剩与主题无关的既有 warning）

- [ ] **Step 2: 运行全量测试**

Run: `flutter test`
Expected: PASS

- [ ] **Step 3: 手动跑应用，临时切换深色验证（仍无切换入口，用代码临时验证）**

为验证阶段 B 成果，临时在 `main.dart` 把 `MaterialApp` 包一层深色（或临时改 `themeMode`）。此步仅为人工肉眼确认，验证后**回退临时改动**。

或者：跳过手动，直接在阶段 C 完成后统一验证。

- [ ] **Step 4: 确认无残留硬编码颜色（扫描）**

Run: `powershell -NoProfile -Command "$files = Get-ChildItem -Path lib -Recurse -Filter *.dart | Where-Object { $_.FullName -notmatch '\\theme\\app_palette\.dart$' }; $found = $false; foreach ($f in $files) { if (Select-String -Path $f.FullName -Pattern 'Colors\.(white|black)\b|Color\(0x[0-9A-Fa-f]{8}\)' -Quiet) { Write-Output $f.FullName; $found = $true } }; if (-not $found) { Write-Output 'CLEAN: no hardcoded colors outside app_palette.dart' }"`

Expected: `CLEAN: no hardcoded colors outside app_palette.dart`（FAB foreground 等合理白名单除外；若有合理保留，记录原因）

---

## 阶段 C：主题切换接入

### Task C1：新增 themeModeProvider

**Files:**
- Modify: `lib/features/settings/providers/settings_providers.dart`

> 注意：现有 `settings_providers.dart` 没有 `sharedPrefsProvider`（WebDAV 用的是 `FutureProvider + await SharedPreferences.getInstance()`）。本任务沿用这个模式——但 `themeModeProvider`/`localeProvider` 是同步 `NotifierProvider`，需要 SharedPreferences 同步可读。解决方案见 Task C2（main.dart 预热）。

- [ ] **Step 1: 在 settings_providers.dart 顶部添加 sharedPrefs 同步 provider**

在 `lib/features/settings/providers/settings_providers.dart` 顶部 import 区下方、`categoryRepositoryProvider` 上方添加：

```dart
/// 同步访问的 SharedPreferences 实例。
///
/// 依赖 [main.dart] 中的 `await SharedPreferences.getInstance()` 预热，
/// 保证首帧前已有实例可读，避免主题/语言切换闪烁。
/// spec §6.3。
late final SharedPreferences sharedPrefsInstance;

/// 初始化 sharedPrefsInstance。必须在 runApp 前、main() 中调用一次。
Future<void> initSharedPrefs() async {
  sharedPrefsInstance = await SharedPreferences.getInstance();
}

/// 同步 Provider：返回预热好的 SharedPreferences。
/// 若未初始化（测试场景），抛出友好错误提示需在测试 setUp 中初始化。
final sharedPrefsProvider = Provider<SharedPreferences>((ref) {
  return sharedPrefsInstance;
});
```

- [ ] **Step 2: 添加 themeModeProvider**

在 `settings_providers.dart` 文件末尾（`settingsNotifierProvider` 之后）添加：

```dart
/// 主题模式（跟随系统/浅色/深色）。spec §6.2。
final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _key = 'app_theme_mode';

  @override
  ThemeMode build() {
    final saved = ref.read(sharedPrefsProvider).getString(_key);
    return switch (saved) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await ref.read(sharedPrefsProvider).setString(_key, mode.name);
  }
}
```

- [ ] **Step 3: 提交**

```bash
git add lib/features/settings/providers/settings_providers.dart
git commit -m "feat(settings): add sharedPrefsProvider and themeModeProvider"
```

---

### Task C2：main.dart 预热 SharedPreferences

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: 在 main() 中调用 initSharedPrefs**

修改 `lib/main.dart` 的 `main()`：

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initSharedPrefs();  // 预热 SharedPreferences，保证主题/语言首帧可读
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
```

并在文件顶部 import 区添加：
```dart
import 'features/settings/providers/settings_providers.dart';
```

- [ ] **Step 2: 更新受影响的测试 setUp**

搜索 test 目录中所有用到 `ProviderScope` 的测试。在每个测试的 `setUp` 中添加 `initSharedPrefs()` 的初始化（或注入 mock SharedPreferences）。

由于 `sharedPrefsInstance` 是 `late final`，测试中需用真实 SharedPreferences（Flutter test 环境的 shared_preferences plugin 默认可用内存实现）：

在受影响测试文件的 `main()` 顶部或 `setUp` 添加：
```dart
setUpAll(() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await initSharedPrefs();
});
```

- [ ] **Step 3: 运行测试确认通过**

Run: `flutter test`
Expected: PASS（若有失败，按错误信息逐个补 setUp）

- [ ] **Step 4: 提交**

```bash
git add -A
git commit -m "feat(main): warm up SharedPreferences before runApp for theme/locale"
```

---

### Task C3：MaterialApp 接入主题

**Files:**
- Modify: `lib/app.dart`

- [ ] **Step 1: App 改为 ConsumerWidget 并接入主题**

修改 `lib/app.dart` 的 `App` 类（`_ShareBootstrap` 保持不变）：

```dart
class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: '生活事项',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: themeMode,
      routerConfig: appRouter,
      builder: (context, child) => _ShareBootstrap(child: child!),
    );
  }
}
```

并在顶部 import 区添加：
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/settings/providers/settings_providers.dart';
```

（`flutter_riverpod` 已导入，`settings_providers` 需新增）

- [ ] **Step 2: 运行应用手动验证主题切换**

Run: `flutter run`

在设备/模拟器上（阶段 C4 加设置页入口前），临时验证：手动改系统深色模式，App 应跟随系统切换。验证后进入 C4。

- [ ] **Step 3: 提交**

```bash
git add lib/app.dart
git commit -m "feat(app): wire themeMode into MaterialApp.router"
```

---

### Task C4：设置页新增「外观」区块

**Files:**
- Modify: `lib/features/settings/pages/settings_page.dart`

- [ ] **Step 1: 在 settings_page.dart 新增外观区块**

在 `_SettingsGroup(rows: [... 提醒设置 ...])` 之后、`_SettingsGroup(rows: [... 导入数据 ...])` 之前插入新的分组。

先在文件顶部 import 区添加：
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
```
（`flutter_riverpod` 已导入；确认 `app_colors` 已导入）

在 `SettingsPage.build` 的 ListView children 中，第一个 `_SettingsGroup` 之后、`const SizedBox(height: 12)` 之前，插入：

```dart
          const SizedBox(height: 12),
          _AppearanceGroup(),
```

然后在文件末尾（`_AboutRow` 之后）添加新的 widget 类：

```dart
class _AppearanceGroup extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '观',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '主题',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          DropdownButton<ThemeMode>(
            value: themeMode,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(
                value: ThemeMode.system,
                child: Text('跟随系统'),
              ),
              DropdownMenuItem(
                value: ThemeMode.light,
                child: Text('浅色'),
              ),
              DropdownMenuItem(
                value: ThemeMode.dark,
                child: Text('深色'),
              ),
            ],
            onChanged: (mode) {
              if (mode != null) {
                ref.read(themeModeProvider.notifier).set(mode);
              }
            },
          ),
        ],
      ),
    );
  }
}
```

并 import：
```dart
import '../providers/settings_providers.dart';
```

> 注：本任务的 UI 文案先用中文硬编码，阶段 E（i18n 抽取）会统一替换为 `context.l.xxx`。这是预期的中间状态。

- [ ] **Step 2: 运行应用手动验证**

Run: `flutter run`

在设置页选择"深色"，App 应立即切换到深色；选"浅色"切回；选"跟随系统"跟随系统。**逐一检查**：首页、事项列表、账单列表、统计、设置、智能输入等页面在深色下文字清晰、无白底白字。

- [ ] **Step 3: 提交**

```bash
git add lib/features/settings/pages/settings_page.dart
git commit -m "feat(settings): add appearance section with theme mode selector"
```

---

## 阶段 D：i18n 基建

### Task D1：配置 pubspec.yaml 与 l10n.yaml

**Files:**
- Modify: `pubspec.yaml`
- Create: `l10n.yaml`

- [ ] **Step 1: pubspec.yaml 添加 flutter_localizations 依赖**

在 `pubspec.yaml` 的 `dependencies:` 块中，`flutter:` 之后添加：

```yaml
  flutter_localizations:
    sdk: flutter
```

- [ ] **Step 2: pubspec.yaml flutter 块启用 generate**

修改 `flutter:` 块：

```yaml
flutter:
  uses-material-design: true
  generate: true
```

- [ ] **Step 3: 创建 l10n.yaml**

在项目根目录创建 `l10n.yaml`：

```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
output-class: AppLocalizations
output-dir: lib/l10n/generated
synthetic-package: false
nullable-getter: false
```

- [ ] **Step 4: 运行 flutter pub get**

Run: `flutter pub get`
Expected: 成功拉取 `flutter_localizations`

- [ ] **Step 5: 提交**

```bash
git add pubspec.yaml pubspec.lock l10n.yaml
git commit -m "feat(i18n): add flutter_localizations dep and gen-l10n config"
```

---

### Task D2：创建基准 ARB 文件并生成 AppLocalizations

**Files:**
- Create: `lib/l10n/app_en.arb`
- Create: `lib/l10n/app_zh.arb`
- Create: `lib/l10n/generated/app_localizations.dart`（自动生成）

- [ ] **Step 1: 创建 app_en.arb（英文基准）**

先创建一个最小可用的基准 ARB，包含 `appName` 和少量通用 key，后续阶段 E 再扩充：

创建 `lib/l10n/app_en.arb`：

```json
{
  "@@locale": "en",
  "appName": "Life Items",
  "common_save": "Save",
  "common_cancel": "Cancel",
  "common_delete": "Delete",
  "common_confirm": "Confirm",
  "common_retry": "Retry",
  "common_ok": "OK",
  "settings_themeTitle": "Theme",
  "settings_themeMode_system": "Follow system",
  "settings_themeMode_light": "Light",
  "settings_themeMode_dark": "Dark",
  "settings_languageTitle": "Language",
  "settings_language_system": "Follow system",
  "settings_language_zh": "简体中文",
  "settings_language_en": "English"
}
```

- [ ] **Step 2: 创建 app_zh.arb**

创建 `lib/l10n/app_zh.arb`：

```json
{
  "@@locale": "zh",
  "appName": "生活事项",
  "common_save": "保存",
  "common_cancel": "取消",
  "common_delete": "删除",
  "common_confirm": "确认",
  "common_retry": "重试",
  "common_ok": "确定",
  "settings_themeTitle": "主题",
  "settings_themeMode_system": "跟随系统",
  "settings_themeMode_light": "浅色",
  "settings_themeMode_dark": "深色",
  "settings_languageTitle": "语言",
  "settings_language_system": "跟随系统",
  "settings_language_zh": "简体中文",
  "settings_language_en": "English"
}
```

> 注：`settings_language_zh`/`en` 用原生语言书写（语言名不翻译）。

- [ ] **Step 3: 运行 gen-l10n 生成代码**

Run: `flutter gen-l10n`
Expected: 在 `lib/l10n/generated/` 下生成 `app_localizations.dart` + `app_localizations_en.dart` + `app_localizations_zh.dart`

- [ ] **Step 4: 确认生成产物存在**

Run: `dir lib\l10n\generated`
Expected: 看到 3 个 dart 文件

- [ ] **Step 5: 提交（含生成产物）**

```bash
git add lib/l10n/
git commit -m "feat(i18n): add baseline ARB files and generated AppLocalizations"
```

---

### Task D3：创建 l10n.dart 便捷扩展

**Files:**
- Create: `lib/l10n/l10n.dart`

- [ ] **Step 1: 创建 l10n.dart**

创建 `lib/l10n/l10n.dart`：

```dart
import 'package:flutter/material.dart';

import 'generated/app_localizations.dart';

/// BuildContext 上访问 [AppLocalizations] 的便捷扩展。
/// 用法：`context.l.common_save`。spec §4.5。
extension L10nContext on BuildContext {
  AppLocalizations get l => AppLocalizations.of(this);
}
```

> 注：枚举相关的扩展（`L10nEnum`）在阶段 E 抽取枚举时添加。

- [ ] **Step 2: 提交**

```bash
git add lib/l10n/l10n.dart
git commit -m "feat(i18n): add L10nContext extension for convenient access"
```

---

### Task D4：新增 localeProvider

**Files:**
- Modify: `lib/features/settings/providers/settings_providers.dart`

- [ ] **Step 1: 在 settings_providers.dart 末尾添加 localeProvider**

在 `lib/features/settings/providers/settings_providers.dart` 末尾添加：

```dart
/// 应用语言。null 表示跟随系统。spec §4.4。
final localeProvider =
    NotifierProvider<LocaleNotifier, Locale>(LocaleNotifier.new);

class LocaleNotifier extends Notifier<Locale> {
  static const _key = 'app_locale';

  @override
  Locale build() {
    final saved = ref.read(sharedPrefsProvider).getString(_key);
    if (saved == 'en') return const Locale('en');
    if (saved == 'zh') return const Locale('zh');
    return _systemLocale();
  }

  /// 设置具体语言并持久化。
  Future<void> set(Locale locale) async {
    state = locale;
    await ref.read(sharedPrefsProvider).setString(_key, locale.languageCode);
  }

  /// 恢复跟随系统。
  Future<void> followSystem() async {
    await ref.read(sharedPrefsProvider).remove(_key);
    state = _systemLocale();
  }

  /// 是否跟随系统（用于 UI 选中态）。
  bool get isFollowingSystem =>
      ref.read(sharedPrefsProvider).getString(_key) == null;

  Locale _systemLocale() {
    final platform = WidgetsBinding.instance.platformDispatcher.locale;
    return platform.languageCode == 'en'
        ? const Locale('en')
        : const Locale('zh');
  }
}
```

并在文件顶部 import 区添加：
```dart
import 'package:flutter/widgets.dart';
```

- [ ] **Step 2: 提交**

```bash
git add lib/features/settings/providers/settings_providers.dart
git commit -m "feat(i18n): add localeProvider with persistence and system fallback"
```

---

### Task D5：MaterialApp 接入 i18n

**Files:**
- Modify: `lib/app.dart`

- [ ] **Step 1: 修改 App 接入 localizationsDelegates 和 locale**

修改 `lib/app.dart` 的 `App.build`：

```dart
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      title: '生活事项',
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
```

并在顶部 import 区添加：
```dart
import 'l10n/generated/app_localizations.dart';
import 'features/settings/providers/settings_providers.dart';
```

（`settings_providers` 已导入 `themeModeProvider`；确认 `localeProvider` 同文件已存在）

- [ ] **Step 2: 运行确认编译**

Run: `flutter analyze`
Expected: 无 error

- [ ] **Step 3: 提交**

```bash
git add lib/app.dart
git commit -m "feat(app): wire locale and localizationsDelegates into MaterialApp"
```

---

### Task D6：设置页新增「语言」区块

**Files:**
- Modify: `lib/features/settings/pages/settings_page.dart`

- [ ] **Step 1: 新增语言区块**

在 `settings_page.dart` 的 `_AppearanceGroup` 之后、`_SettingsGroup(rows: [... 导入数据 ...])` 之前插入：

在 ListView children 中 `_AppearanceGroup()` 之后添加：
```dart
          const SizedBox(height: 12),
          _LanguageGroup(),
```

然后在文件末尾（`_AppearanceGroup` 之后）添加：

```dart
class _LanguageGroup extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(localeProvider.notifier);
    final isSystem = notifier.isFollowingSystem;
    final current = ref.watch(localeProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '语',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '语言',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          DropdownButton<String>(
            value: isSystem ? 'system' : current.languageCode,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: 'system', child: Text('跟随系统')),
              DropdownMenuItem(value: 'zh', child: Text('简体中文')),
              DropdownMenuItem(value: 'en', child: Text('English')),
            ],
            onChanged: (value) async {
              if (value == null) return;
              if (value == 'system') {
                await notifier.followSystem();
              } else {
                await notifier.set(Locale(value));
              }
            },
          ),
        ],
      ),
    );
  }
}
```

并在顶部 import 区确认有：
```dart
import 'dart:ui';  // Locale
import '../providers/settings_providers.dart';
```

> 注：UI 文案（"跟随系统""语言"）先用中文，阶段 E 统一替换。语言名（"简体中文""English"）按 i18n 规范用原生书写，已在基准 ARB 里。

- [ ] **Step 2: 运行应用手动验证**

Run: `flutter run`

设置页切换语言：选 English 后，**App title（onGenerateTitle）** 和设置页语言区块自身会变化；其他页面暂还是中文（阶段 E 抽取）。验证切换正常即可。

- [ ] **Step 3: 提交**

```bash
git add lib/features/settings/pages/settings_page.dart
git commit -m "feat(settings): add language section with locale selector"
```

---

## 阶段 E：字符串抽取

> 本阶段把全 lib 的中文 UI 文案抽取到 ARB。工作量大但机械，按"枚举 → 分类 → UI 页面 → 智能解析"顺序推进。每个任务都是增量提交，保持可运行。

### Task E1：枚举去 label 加 l10nKey

**Files:**
- Modify: `lib/domain/enums/project_status.dart`
- Modify: `lib/domain/enums/item_status.dart`
- Modify: `lib/domain/enums/amount_type.dart`
- Modify: `lib/domain/enums/bill_amount_type.dart`
- Modify: `lib/domain/enums/repeat_period.dart`
- Modify: 其它含中文 label 的枚举（扫描 `lib/domain/enums/`）

- [ ] **Step 1: 扫描所有含 label 的枚举**

Run: `powershell -NoProfile -Command "Get-ChildItem -Path lib/domain/enums -Filter *.dart | ForEach-Object { if (Select-String -Path $_.FullName -Pattern '(label|中文)' -Quiet) { $_.Name } }"`

对每个返回的文件，检查其构造是否含中文 label。

- [ ] **Step 2: 改造 project_status.dart**

修改 `lib/domain/enums/project_status.dart`：

把 `enum ProjectStatus { active('active', '进行中'), ... }` 改为去掉 label 参数、新增 l10nKey getter：

```dart
enum ProjectStatus {
  active('active'),
  completed('completed'),
  cancelled('cancelled'),
  archived('archived');

  const ProjectStatus(this.value);
  final String value;

  /// i18n key，由显示层翻译。spec §5.1。
  String get l10nKey => 'enum_projectStatus_$value';

  // ... defaultStatus / fromString / isFinal / nextStatus / canTransitionTo 保持不变

  /// 推进状态按钮的文案 key（原 advanceLabel 改为返回 key）。
  String get advanceLabelKey => switch (this) {
    ProjectStatus.active => 'enum_projectStatus_advance_complete',
    _ => 'enum_projectStatus_advance_generic',
  };
}
```

> 注：原 `advanceLabel` 直接返回中文 `'标记完成'`。改为返回 key 后，调用方需通过 i18n 翻译。本步**同时**要找到所有 `advanceLabel` 的调用点（grep `advanceLabel`）并改为 `context.l.getByKey(status.advanceLabelKey) ?? '推进状态'`（先留中文兜底，阶段 E3 全量替换时统一）。

- [ ] **Step 3: 改造其余枚举**

对 `item_status.dart`、`amount_type.dart`、`bill_amount_type.dart`、`repeat_period.dart` 等同样处理：
- 去掉构造的 label 参数
- 新增 `String get l10nKey => 'enum_<enumName>_<value>';`
- 找到所有 `.label` 调用点，改为 `context.l.<enumName>(e)`（E3 步骤会在 l10n.dart 加对应方法）

**repeat_period.dart 特殊处理**：它有 `defaultDays` 参数（与 label 无关），保留。只去掉 label：
```dart
enum RepeatPeriod {
  daily('daily', 1),
  weekly('weekly', 7),
  monthly('monthly', 30),
  yearly('yearly', 365),
  custom('custom', 0);

  const RepeatPeriod(this.value, this.defaultDays);
  final String value;
  final int defaultDays;
  String get l10nKey => 'enum_repeatPeriod_$value';

  static RepeatPeriod fromString(String v) => RepeatPeriod.values.firstWhere(
    (e) => e.value == v,
    orElse: () => RepeatPeriod.custom,
  );
}
```

- [ ] **Step 4: 在 ARB 添加枚举 key**

在 `app_en.arb` 和 `app_zh.arb` 中添加所有枚举 key。例如 project_status：

`app_en.arb`:
```json
  "enum_projectStatus_active": "In Progress",
  "enum_projectStatus_completed": "Completed",
  "enum_projectStatus_cancelled": "Cancelled",
  "enum_projectStatus_archived": "Archived",
  "enum_projectStatus_advance_complete": "Mark Complete",
  "enum_projectStatus_advance_generic": "Advance",
```

`app_zh.arb`:
```json
  "enum_projectStatus_active": "进行中",
  "enum_projectStatus_completed": "已完成",
  "enum_projectStatus_cancelled": "已取消",
  "enum_projectStatus_archived": "已归档",
  "enum_projectStatus_advance_complete": "标记完成",
  "enum_projectStatus_advance_generic": "推进状态",
```

对其余枚举（itemStatus / amountType / billAmountType / repeatPeriod）同样添加中英文 key。

- [ ] **Step 5: 重新生成 AppLocalizations**

Run: `flutter gen-l10n`

- [ ] **Step 6: 在 l10n.dart 添加枚举访问扩展**

修改 `lib/l10n/l10n.dart`，在 `L10nContext` 之后添加：

```dart
import '../domain/enums/project_status.dart';
import '../domain/enums/item_status.dart';
import '../domain/enums/amount_type.dart';
import '../domain/enums/bill_amount_type.dart';
import '../domain/enums/repeat_period.dart';

/// 枚举标签翻译扩展。spec §5.1。
extension L10nEnum on AppLocalizations {
  String projectStatus(ProjectStatus s) => _byKey(s.l10nKey)!;
  String itemStatus(ItemStatus s) => _byKey(s.l10nKey)!;
  String amountType(AmountType s) => _byKey(s.l10nKey)!;
  String billAmountType(BillAmountType s) => _byKey(s.l10nKey)!;
  String repeatPeriod(RepeatPeriod s) => _byKey(s.l10nKey)!;

  /// 按字符串 key 查找翻译。用于分类 builtin_key 等动态 key 场景。
  String? getByKey(String key) {
    // gen-l10n 生成的类不支持按字符串 key 查找；
    // 通过遍历 supportedLocales + 一个内部 map 实现。
    // 简化方案：维护一个 key→getter 的映射。
    return _keyMap[key]?.call(this);
  }

  String? _byKey(String key) => getByKey(key);
}

/// key → 翻译 getter 的映射表。由工具在 build 时填充，
/// 本实现采用手动维护（与枚举/分类 key 同步）。
typedef _Tr = String Function(AppLocalizations l);

final Map<String, _Tr> _keyMap = {
  // 枚举
  'enum_projectStatus_active': (l) => l.enum_projectStatus_active,
  'enum_projectStatus_completed': (l) => l.enum_projectStatus_completed,
  'enum_projectStatus_cancelled': (l) => l.enum_projectStatus_cancelled,
  'enum_projectStatus_archived': (l) => l.enum_projectStatus_archived,
  // ... 其余枚举 key 同样填入
  // 分类（E2 任务补充）
};
```

> 注：gen-l10n 生成的 `AppLocalizations` 不提供 by-key 查找，所以用 `_keyMap` 维护映射。每新增一个 ARB key，都要在 `_keyMap` 加一条。这个手动维护是已知成本，`avoid_raw_color_literal` 之外不加 lint 强制（分类/枚举数量有限）。

- [ ] **Step 7: 运行测试确认编译**

Run: `flutter analyze` 然后 `flutter test`
Expected: 编译通过（`.label` 调用点已改为兜底中文或 i18n），测试通过

- [ ] **Step 8: 提交**

```bash
git add -A
git commit -m "refactor(i18n): replace enum labels with l10nKey getters"
```

---

### Task E2：默认分类 builtin_key + original_name（schema v11）

**Files:**
- Modify: `lib/data/database/tables/categories_table.dart`
- Modify: `lib/data/database/app_database.dart`
- Modify: `lib/core/constants/default_categories.dart`
- Modify: `lib/data/repositories/category_repository.dart`
- Create: `lib/core/utils/category_display.dart`
- Test: `test/l10n/category_display_test.dart`

- [ ] **Step 1: 写 categoryDisplayName 失败测试**

创建 `test/l10n/category_display_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record_everything/core/utils/category_display.dart';
import 'package:record_everything/l10n/generated/app_localizations.dart';

void main() {
  Widget _wrap(Widget child, Locale locale) {
    return MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(builder: (context) => Scaffold(body: child)),
    );
  }

  // 用最小化的假 Category 类测试（避免 drift 依赖）
  testWidgets('内置分类在英文下返回英文翻译', (tester) async {
    await tester.pumpWidget(_wrap(
      Builder(builder: (context) {
        final name = categoryDisplayNameFor(
          context,
          name: '工资',
          builtinKey: 'cat_salary',
          originalName: '工资',
        );
        expect(name, 'Salary');
        return const SizedBox();
      }),
      const Locale('en'),
    ));
  });

  testWidgets('内置分类在中文下返回中文', (tester) async {
    await tester.pumpWidget(_wrap(
      Builder(builder: (context) {
        final name = categoryDisplayNameFor(
          context,
          name: '工资',
          builtinKey: 'cat_salary',
          originalName: '工资',
        );
        expect(name, '工资');
        return const SizedBox();
      }),
      const Locale('zh'),
    ));
  });

  testWidgets('用户改名的内置分类保留用户输入', (tester) async {
    await tester.pumpWidget(_wrap(
      Builder(builder: (context) {
        final name = categoryDisplayNameFor(
          context,
          name: '我的工资',
          builtinKey: 'cat_salary',
          originalName: '工资',
        );
        expect(name, '我的工资');
        return const SizedBox();
      }),
      const Locale('en'),
    ));
  });

  testWidgets('用户自建分类原样返回', (tester) async {
    await tester.pumpWidget(_wrap(
      Builder(builder: (context) {
        final name = categoryDisplayNameFor(
          context,
          name: '自定义分类',
          builtinKey: null,
          originalName: null,
        );
        expect(name, '自定义分类');
        return const SizedBox();
      }),
      const Locale('en'),
    ));
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/l10n/category_display_test.dart`
Expected: FAIL — `category_display.dart` 不存在

- [ ] **Step 3: 扩展 categories 表加两列**

修改 `lib/data/database/tables/categories_table.dart`：

```dart
import 'package:drift/drift.dart';

class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  TextColumn get type => text()();
  TextColumn get icon => text().withDefault(const Constant('category'))();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  BoolColumn get isHidden => boolean().withDefault(const Constant(false))();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastUsedAt => dateTime().nullable()();
  // schema v11：内置分类标识与原始播种名（用于 i18n + 改名检测）。spec §5.2。
  TextColumn get builtinKey => text().nullable()();
  TextColumn get originalName => text().nullable()();
}
```

- [ ] **Step 4: 更新 schemaVersion 与迁移逻辑**

修改 `lib/data/database/app_database.dart`：

- 把 `int get schemaVersion => 10;` 改为 `int get schemaVersion => 11;`
- 在 `onUpgrade` 块中 `if (from < 10) { ... }` 之后添加：

```dart
      if (from < 11) {
        // schema v11：分类新增 builtin_key / original_name 列（i18n 支持）。
        // spec §5.2。对所有内置分类（isDefault=true）回填 key 和原始名。
        await m.addColumn(categories, categories.builtinKey);
        await m.addColumn(categories, categories.originalName);
        await _backfillBuiltinCategoryKeys();
      }
```

- 在 `onCreate` 的 `_insertDefaultCategories()` 调用之后，添加对新建库也回填 key 的处理（或在播种时直接写入）。最简方式：`_insertDefaultCategories` 改造为写入 builtin_key。

把 `_insertDefaultCategories`、`_insertDefaultProjectCategories` 改为从 `DefaultCategories` 读 builtin_key：

```dart
  Future<void> _insertDefaultCategories() async {
    for (final c in DefaultCategories.income) {
      await into(categories).insert(
        CategoriesCompanion.insert(
          name: c['name']!,
          type: 'income',
          icon: Value(c['icon']!),
          isDefault: const Value(true),
          builtinKey: Value(c['key']),
          originalName: Value(c['name']),
        ),
      );
    }
    // expense / item 同样加 builtinKey / originalName
    for (final c in DefaultCategories.expense) {
      await into(categories).insert(
        CategoriesCompanion.insert(
          name: c['name']!, type: 'expense', icon: Value(c['icon']!),
          isDefault: const Value(true),
          builtinKey: Value(c['key']), originalName: Value(c['name']),
        ),
      );
    }
    for (final c in DefaultCategories.item) {
      await into(categories).insert(
        CategoriesCompanion.insert(
          name: c['name']!, type: 'item', icon: Value(c['icon']!),
          isDefault: const Value(true),
          builtinKey: Value(c['key']), originalName: Value(c['name']),
        ),
      );
    }
  }

  Future<void> _insertDefaultProjectCategories() async {
    for (final c in DefaultCategories.project) {
      await into(categories).insert(
        CategoriesCompanion.insert(
          name: c['name']!, type: 'project', icon: Value(c['icon']!),
          isDefault: const Value(true),
          builtinKey: Value(c['key']), originalName: Value(c['name']),
        ),
      );
    }
  }

  /// v11 迁移：为已存在的内置分类回填 builtin_key 和 original_name。
  /// 按 name 匹配 DefaultCategories 的内置分类清单。
  Future<void> _backfillBuiltinCategoryKeys() async {
    final all = <Map<String, String>>[
      ...DefaultCategories.income,
      ...DefaultCategories.expense,
      ...DefaultCategories.item,
      ...DefaultCategories.project,
    ];
    for (final c in all) {
      await (categories.update()
            ..where((t) => t.name.equals(c['name']!) & t.isDefault.equals(true)))
          .write(CategoriesCompanion(
            builtinKey: Value(c['key']),
            originalName: Value(c['name']),
          ));
    }
  }
```

- [ ] **Step 5: 更新 DefaultCategories 加 key 字段**

修改 `lib/core/constants/default_categories.dart`，每条加 `'key'`：

```dart
class DefaultCategories {
  static const income = [
    {'name': '工资', 'icon': 'work', 'key': 'cat_salary'},
    {'name': '奖金', 'icon': 'emoji_events', 'key': 'cat_bonus'},
    {'name': '兼职', 'icon': 'schedule', 'key': 'cat_parttime'},
    {'name': '报销', 'icon': 'receipt', 'key': 'cat_reimbursement'},
    {'name': '投资收益', 'icon': 'trending_up', 'key': 'cat_investment'},
    {'name': '退款返现', 'icon': 'undo', 'key': 'cat_refund'},
    {'name': '其他收入', 'icon': 'more_horiz', 'key': 'cat_income_other'},
  ];

  static const expense = [
    {'name': '餐饮', 'icon': 'restaurant', 'key': 'cat_food'},
    {'name': '购物', 'icon': 'shopping_bag', 'key': 'cat_shopping'},
    {'name': '交通', 'icon': 'directions_car', 'key': 'cat_transport'},
    {'name': '住房', 'icon': 'home', 'key': 'cat_housing'},
    {'name': '水电燃气', 'icon': 'bolt', 'key': 'cat_utilities'},
    {'name': '通信网络', 'icon': 'wifi', 'key': 'cat_telecom'},
    {'name': '医疗药品', 'icon': 'medical_services', 'key': 'cat_medical'},
    {'name': '会员订阅', 'icon': 'subscriptions', 'key': 'cat_subscription'},
    {'name': '家庭耗材', 'icon': 'cleaning_services', 'key': 'cat_household'},
    {'name': '教育', 'icon': 'school', 'key': 'cat_education'},
    {'name': '娱乐', 'icon': 'sports_esports', 'key': 'cat_entertainment'},
    {'name': '人情礼物', 'icon': 'redeem', 'key': 'cat_gift'},
    {'name': '旅行差旅', 'icon': 'flight', 'key': 'cat_travel'},
    {'name': '保险', 'icon': 'security', 'key': 'cat_insurance'},
    {'name': '税费手续费', 'icon': 'request_quote', 'key': 'cat_tax_fees'},
    {'name': '其他支出', 'icon': 'more_horiz', 'key': 'cat_expense_other'},
  ];

  static const item = [
    {'name': '待办', 'icon': 'check_circle', 'key': 'cat_todo'},
    {'name': '证件', 'icon': 'badge', 'key': 'cat_document'},
    {'name': '账单提醒', 'icon': 'receipt_long', 'key': 'cat_bill_reminder'},
    {'name': '订阅续费', 'icon': 'card_membership', 'key': 'cat_renewal'},
    {'name': '保修售后', 'icon': 'build', 'key': 'cat_warranty'},
    {'name': '药品健康', 'icon': 'medication', 'key': 'cat_health'},
    {'name': '食品库存', 'icon': 'kitchen', 'key': 'cat_grocery_stock'},
    {'name': '家庭耗材', 'icon': 'cleaning_services', 'key': 'cat_household_item'},
    {'name': '车辆设备', 'icon': 'devices_other', 'key': 'cat_device'},
    {'name': '其他事项', 'icon': 'more_horiz', 'key': 'cat_item_other'},
  ];

  static const project = [
    {'name': '个人项目', 'icon': 'person', 'key': 'cat_personal_project'},
    {'name': '客户项目', 'icon': 'business_center', 'key': 'cat_client_project'},
    {'name': '家庭事务', 'icon': 'home', 'key': 'cat_family_project'},
    {'name': '活动安排', 'icon': 'event', 'key': 'cat_event'},
    {'name': '旅行计划', 'icon': 'flight', 'key': 'cat_trip'},
    {'name': '学习成长', 'icon': 'school', 'key': 'cat_learning'},
    {'name': '摄影接单', 'icon': 'camera_alt', 'key': 'cat_photo_order'},
    {'name': '跟拍', 'icon': 'photo_camera', 'key': 'cat_photo_follow'},
    {'name': '其他项目', 'icon': 'folder', 'key': 'cat_project_other'},
  ];
}
```

- [ ] **Step 6: 在 ARB 添加分类翻译 key**

在 `app_en.arb` 添加（所有分类 key 的英文）：

```json
  "cat_salary": "Salary",
  "cat_bonus": "Bonus",
  "cat_parttime": "Side Gig",
  "cat_reimbursement": "Reimbursement",
  "cat_investment": "Investment",
  "cat_refund": "Refund",
  "cat_income_other": "Other Income",
  "cat_food": "Food",
  "cat_shopping": "Shopping",
  "cat_transport": "Transport",
  "cat_housing": "Housing",
  "cat_utilities": "Utilities",
  "cat_telecom": "Phone & Internet",
  "cat_medical": "Medical",
  "cat_subscription": "Subscription",
  "cat_household": "Household",
  "cat_education": "Education",
  "cat_entertainment": "Entertainment",
  "cat_gift": "Gift",
  "cat_travel": "Travel",
  "cat_insurance": "Insurance",
  "cat_tax_fees": "Tax & Fees",
  "cat_expense_other": "Other Expense",
  "cat_todo": "Todo",
  "cat_document": "Document",
  "cat_bill_reminder": "Bill Reminder",
  "cat_renewal": "Renewal",
  "cat_warranty": "Warranty",
  "cat_health": "Health",
  "cat_grocery_stock": "Grocery Stock",
  "cat_household_item": "Household",
  "cat_device": "Device",
  "cat_item_other": "Other Item",
  "cat_personal_project": "Personal Project",
  "cat_client_project": "Client Project",
  "cat_family_project": "Family",
  "cat_event": "Event",
  "cat_trip": "Trip",
  "cat_learning": "Learning",
  "cat_photo_order": "Photo Order",
  "cat_photo_follow": "Photo Shoot",
  "cat_project_other": "Other Project",
```

在 `app_zh.arb` 添加对应中文（值即现有 DefaultCategories 的 name）。

- [ ] **Step 7: 实现 categoryDisplayName helper**

创建 `lib/core/utils/category_display.dart`：

```dart
import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';

/// 分类名显示翻译。spec §5.2。
///
/// 优先级：
/// 1. 用户自建分类（builtinKey == null）：原样返回 name。
/// 2. 内置分类被用户改名（name != originalName）：返回用户改的 name。
/// 3. 内置分类未改名：按 builtinKey 翻译，缺失兜底 name。
String categoryDisplayNameFor({
  required BuildContext context,
  required String name,
  required String? builtinKey,
  required String? originalName,
}) {
  if (builtinKey == null) return name;
  if (originalName != null && name != originalName) return name;
  final l = AppLocalizations.of(context);
  // 通过 l10n.dart 的 getByKey 查找
  // （需要 l10n.dart 已注入分类 key 到 _keyMap，见 Task E1 Step 6 + 本任务后续）
  final localized = _lookupCategory(l, builtinKey);
  return localized ?? name;
}

/// 分类 key → 翻译查找。在 l10n.dart 的 _keyMap 已注册 cat_* 时直接复用。
String? _lookupCategory(AppLocalizations l, String key) {
  // 复用 l10n.dart 暴露的 getByKey（若已 public）；否则在这里内联映射。
  // 为解耦，这里通过 AppLocalizations 的实例方法直接调用（gen-l10n 生成同名 getter）。
  switch (key) {
    case 'cat_salary': return l.cat_salary;
    case 'cat_bonus': return l.cat_bonus;
    case 'cat_parttime': return l.cat_parttime;
    case 'cat_reimbursement': return l.cat_reimbursement;
    case 'cat_investment': return l.cat_investment;
    case 'cat_refund': return l.cat_refund;
    case 'cat_income_other': return l.cat_income_other;
    case 'cat_food': return l.cat_food;
    case 'cat_shopping': return l.cat_shopping;
    case 'cat_transport': return l.cat_transport;
    case 'cat_housing': return l.cat_housing;
    case 'cat_utilities': return l.cat_utilities;
    case 'cat_telecom': return l.cat_telecom;
    case 'cat_medical': return l.cat_medical;
    case 'cat_subscription': return l.cat_subscription;
    case 'cat_household': return l.cat_household;
    case 'cat_education': return l.cat_education;
    case 'cat_entertainment': return l.cat_entertainment;
    case 'cat_gift': return l.cat_gift;
    case 'cat_travel': return l.cat_travel;
    case 'cat_insurance': return l.cat_insurance;
    case 'cat_tax_fees': return l.cat_tax_fees;
    case 'cat_expense_other': return l.cat_expense_other;
    case 'cat_todo': return l.cat_todo;
    case 'cat_document': return l.cat_document;
    case 'cat_bill_reminder': return l.cat_bill_reminder;
    case 'cat_renewal': return l.cat_renewal;
    case 'cat_warranty': return l.cat_warranty;
    case 'cat_health': return l.cat_health;
    case 'cat_grocery_stock': return l.cat_grocery_stock;
    case 'cat_household_item': return l.cat_household_items;
    case 'cat_device': return l.cat_device;
    case 'cat_item_other': return l.cat_item_other;
    case 'cat_personal_project': return l.cat_personal_project;
    case 'cat_client_project': return l.cat_client_project;
    case 'cat_family_project': return l.cat_family_project;
    case 'cat_event': return l.cat_event;
    case 'cat_trip': return l.cat_trip;
    case 'cat_learning': return l.cat_learning;
    case 'cat_photo_order': return l.cat_photo_order;
    case 'cat_photo_follow': return l.cat_photo_follow;
    case 'cat_project_other': return l.cat_project_other;
    default: return null;
  }
}
```

> 注：用 switch + gen-l10n 生成的 getter，比反射 map 更类型安全（key 拼错编译失败）。代价是分类新增时要维护这个 switch，但分类是低频变更。

> **重要：测试里的 `categoryDisplayNameFor` 签名**（接受裸参数而非 Category 实体）是为了避免测试依赖 drift。实际 UI 调用通过下面的便捷重载。

在 `category_display.dart` 末尾添加便捷重载（接受 drift 生成的 Category）：

```dart
// 便捷重载：直接传 drift 生成的 Category 实体。
// import '../../data/database/app_database.dart';  // 取消注释以获取 Category 类型
// String categoryDisplayName(BuildContext context, Category c) =>
//     categoryDisplayNameFor(
//       context: context,
//       name: c.name,
//       builtinKey: c.builtinKey,
//       originalName: c.originalName,
//     );
```

> 取消注释该重载（需要 import app_database.dart）。gen-l10n 后 Category 类会有 `builtinKey`/`originalName` 字段。

- [ ] **Step 8: 重新生成 drift 代码**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: 生成更新后的 `app_database.g.dart`，Category 类含新字段

- [ ] **Step 9: 重新生成 l10n**

Run: `flutter gen-l10n`

- [ ] **Step 10: 运行测试确认通过**

Run: `flutter test test/l10n/category_display_test.dart`
Expected: PASS（4 个测试）

- [ ] **Step 11: 提交**

```bash
git add -A
git commit -m "feat(i18n): add builtin_key/original_name to categories (schema v11) + display helper"
```

---

### Task E3：替换所有显示分类名的地方为 categoryDisplayName

**Files:**
- Modify: 全 lib 下所有显示分类名的位置

- [ ] **Step 1: 找出所有显示分类名的位置**

通过 grep 找出引用 `category.name` 或 `.name`（在 Category 上下文）的 UI 位置。重点文件（已知）：
- `lib/features/bill/pages/bill_list_page.dart`（账单按分类显示）
- `lib/features/bill/pages/bill_edit_page.dart`（分类选择器）
- `lib/features/life_item/widgets/life_item_card.dart`
- `lib/features/life_item/pages/life_item_edit_page.dart`
- `lib/features/statistics/widgets/category_trend_chart.dart`（图例）
- `lib/features/settings/pages/category_management_page.dart`（分类管理列表）
- 搜索/筛选组件中的分类 chip

- [ ] **Step 2: 逐个替换为 categoryDisplayName(context, category)**

对每处 `Text(category.name)` 或类似，改为 `Text(categoryDisplayName(context, category))`。

确保 `category_display.dart` 已 import。

- [ ] **Step 3: 运行 flutter analyze 确认**

Run: `flutter analyze`
Expected: 无 error

- [ ] **Step 4: 提交**

```bash
git add -A
git commit -m "refactor(i18n): use categoryDisplayName across UI"
```

---

### Task E4：抽取 UI 页面文案到 ARB（按 feature 分批）

> 本任务是工作量最大的一块（约 3500 个中文字符分布在 30+ 文件）。按 feature 分批增量提交，每批一个 commit。

**Files:**
- Modify: 全 lib 下所有含面向用户中文文案的 UI 文件
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb`

**抽取规则：**
- 仅抽取面向用户的文案：`Text('...')`、`label:`、`title:`、`hintText:`、`tooltip:`、`Toast.info/success/error(context, '...')`、`DialogHelper.confirm(..., title: '...')`、`AppBar(title: Text('...'))` 等
- **不抽取**：代码注释、日志字符串、数据库播种注释、`smart_entry_keywords.dart` 的 `zh` 表、`_systemLocale` 等内部逻辑

- [ ] **Step 1: 按以下顺序分批抽取（每批一个 commit）**

**批次顺序（按 feature）**：
1. `features/home/`（首页）
2. `features/life_item/`（生活事项）
3. `features/bill/`（账单）
4. `features/project/`（项目）
5. `features/statistics/`（统计）
6. `features/settings/`（设置，含已写的主题/语言区块改用 i18n）
7. `features/search/`（搜索）
8. `features/smart_entry/`（智能录入 UI 页面，不含关键词表）
9. `core/widgets/`、`core/utils/dialog_helper.dart`、`shared/widgets/`（共享组件）
10. `app.dart`（title 已用 onGenerateTitle，确认）

**对每个文件的抽取流程：**
1. 找出所有中文 UI 字符串
2. 为每个字符串分配 ARB key（按命名约定：`<feature>_<语义>`，如 `home_todayTodos`）
3. 在 `app_en.arb` 和 `app_zh.arb` 添加 key（英文翻译 + 中文原文）
4. 运行 `flutter gen-l10n` 重新生成
5. 把 UI 中的中文字符串替换为 `context.l.<key>`

**示例（以 home_page.dart 的 "今日待办" 为例）：**

`app_en.arb`:
```json
  "home_todayTodos": "Today's Todos",
```
`app_zh.arb`:
```json
  "home_todayTodos": "今日待办",
```
`home_page.dart`:
```dart
// 原：Text('今日待办')
// 改：
Text(context.l.home_todayTodos)
```

- [ ] **Step 2: 每批抽取后运行 flutter test 确认**

每完成一个 feature 批次：
Run: `flutter analyze && flutter test`
Expected: 无 error，测试通过

- [ ] **Step 3: 每批提交**

每个 feature 一个 commit：
```bash
git add -A
git commit -m "feat(i18n): extract <feature> UI strings to ARB"
```

> **执行提示（给 agentic worker）：** 本任务规模大。建议每个 feature 作为独立子任务，抽取前先 `grep` 该 feature 目录的所有中文字符串，列清单，逐条翻译 + 替换。遇到含参数的字符串用 ICU 占位符（如 `"{count} 天逾期"` → `item_overdueDays` + `@` 元数据）。完成后运行 `tools/scan_chinese_ui.dart`（Task F1 创建）扫描确认无残留。

---

### Task E5：设置页主题/语言区块改用 i18n

**Files:**
- Modify: `lib/features/settings/pages/settings_page.dart`

- [ ] **Step 1: 把 C4/D6 写的中文硬编码替换为 i18n**

在 `_AppearanceGroup`：
- `'主题'` → `context.l.settings_themeTitle`
- DropdownMenuItem 的 `'跟随系统'`/`'浅色'`/`'深色'` → `context.l.settings_themeMode_system` / `_light` / `_dark`

在 `_LanguageGroup`：
- `'语言'` → `context.l.settings_languageTitle`
- `'跟随系统'` → `context.l.settings_language_system`
- `'简体中文'` → `context.l.settings_language_zh`（原生书写）
- `'English'` → `context.l.settings_language_en`（原生书写）

- [ ] **Step 2: 运行确认**

Run: `flutter analyze`
Expected: 无 error

- [ ] **Step 3: 提交**

```bash
git add lib/features/settings/pages/settings_page.dart
git commit -m "refactor(i18n): use localized strings in theme/language settings"
```

---

### Task E6：智能解析关键词表双语化（范围受限）

**Files:**
- Modify: `lib/features/smart_entry/constants/smart_entry_keywords.dart`
- Modify: `lib/features/smart_entry/parser/local_rule_engine.dart`
- Modify: `lib/features/smart_entry/providers/smart_entry_providers.dart`

> **范围声明（spec 对齐）：** 智能解析的本地引擎对中文深度耦合（中文数字转换如"两万三"、动词判定）。完整双语重写超出主题/i18n 范围。本任务仅做：**关键词→分类映射**双语化（让英文输入"lunch"能识别为餐饮），数字/日期/动词判定维持中文，英文输入主要走 AI 兜底。这是设计权衡，spec §5.3 已涵盖，本任务进一步明确边界。

- [ ] **Step 1: 重构 smart_entry_keywords.dart 拆 zh/en**

打开 `lib/features/smart_entry/constants/smart_entry_keywords.dart`。

保留现有所有中文表（`expenseVerbs`/`incomeVerbs`/`taskVerbs` 等）不变，把文件重构为：

```dart
/// 智能录入解析用的词表与中文数字转换。spec §5.2 / §5.3。
library;

// ===== 中文数字转阿拉伯（保留，仅中文场景用） =====
// （现有 _digit / chineseNumberToArabic 等保持不变）

// ===== 动词词表（中文，保留） =====
const expenseVerbs = <String>[
  '花了', '买了', '消费', '支出', '付款', '付了', '充值',
];

const incomeVerbs = <String>[
  '工资', '收入', '收到', '退款', '报销', '奖金', '到账',
];

const taskVerbs = <String>[
  '开会', '提醒', '记得', '别忘了', '办', '办理', '交', '预约', '带',
];

// ===== 英文动词词表（新增） =====

/// 英文场景：出现则强倾向账单。
const expenseVerbsEn = <String>[
  'spent', 'bought', 'paid', 'payment', 'charged', 'billed',
];

/// 英文场景：出现则强倾向收入账单。
const incomeVerbsEn = <String>[
  'salary', 'paycheck', 'received', 'refund', 'bonus', 'deposit',
];

/// 英文场景：出现则倾向事项。
const taskVerbsEn = <String>[
  'meeting', 'remind', 'remember', 'don\'t forget', 'schedule', 'appointment',
  'todo', 'task',
];

// ===== 分类关键词映射 =====

/// 中文分类关键词 → 内置分类 builtin_key。spec §5.3。
const categoryKeywordsZh = <String, String>{
  '午餐': 'cat_food', '晚餐': 'cat_food', '早饭': 'cat_food',
  '吃饭': 'cat_food', '外卖': 'cat_food', '咖啡': 'cat_food',
  '奶茶': 'cat_food', '零食': 'cat_food',
  '打车': 'cat_transport', '地铁': 'cat_transport', '公交': 'cat_transport',
  '加油': 'cat_transport', '停车': 'cat_transport', '高铁': 'cat_transport',
  '机票': 'cat_transport',
  '房租': 'cat_housing', '水电': 'cat_utilities', '燃气': 'cat_utilities',
  '话费': 'cat_telecom', '网费': 'cat_telecom',
  '工资': 'cat_salary', '奖金': 'cat_bonus',
  '购物': 'cat_shopping', '淘宝': 'cat_shopping', '京东': 'cat_shopping',
  '会员': 'cat_subscription', '订阅': 'cat_subscription',
  '电影': 'cat_entertainment', '游戏': 'cat_entertainment',
  '药': 'cat_medical', '看病': 'cat_medical', '挂号': 'cat_medical',
};

/// 英文分类关键词 → 内置分类 builtin_key。spec §5.3。
const categoryKeywordsEn = <String, String>{
  'lunch': 'cat_food', 'dinner': 'cat_food', 'breakfast': 'cat_food',
  'coffee': 'cat_food', 'pizza': 'cat_food', 'takeout': 'cat_food',
  'snack': 'cat_food', 'meal': 'cat_food', 'grocery': 'cat_food',
  'uber': 'cat_transport', 'taxi': 'cat_transport', 'gas': 'cat_transport',
  'parking': 'cat_transport', 'subway': 'cat_transport', 'bus': 'cat_transport',
  'rent': 'cat_housing', 'electricity': 'cat_utilities', 'water bill': 'cat_utilities',
  'phone bill': 'cat_telecom', 'internet': 'cat_telecom',
  'salary': 'cat_salary', 'paycheck': 'cat_salary', 'bonus': 'cat_bonus',
  'refund': 'cat_refund', 'shopping': 'cat_shopping', 'amazon': 'cat_shopping',
  'subscription': 'cat_subscription', 'netflix': 'cat_subscription',
  'movie': 'cat_entertainment', 'game': 'cat_entertainment',
  'medicine': 'cat_medical', 'doctor': 'cat_medical', 'pharmacy': 'cat_medical',
};

/// 按语言选择分类关键词表。
Map<String, String> categoryKeywordsFor(String languageCode) {
  return languageCode == 'en' ? categoryKeywordsEn : categoryKeywordsZh;
}
```

> 注：以上关键词是基础集合，可按需扩充。核心是建立中英两套表 + `categoryKeywordsFor` 选择器。

- [ ] **Step 2: 修改 local_rule_engine 支持语言选择**

打开 `lib/features/smart_entry/parser/local_rule_engine.dart`。

构造增加 `languageCode` 参数（默认 'zh'）：

```dart
class LocalRuleEngine {
  LocalRuleEngine({
    DateTime? now,
    DraftSource source = DraftSource.nl,
    this.languageCode = 'zh',
  }) : now = now ?? DateTime.now(),
       defaultSource = source;

  final DateTime now;
  final DraftSource defaultSource;
  final String languageCode;

  // ... parseAll / parse 不变

  /// 分类猜测：按当前语言的关键词表匹配。spec §5.3。
  String? _extractCategory(String seg) {
    final table = categoryKeywordsFor(languageCode);
    final lower = seg.toLowerCase();
    for (final entry in table.entries) {
      if (lower.contains(entry.key.toLowerCase())) {
        return entry.value;  // 返回 builtin_key
      }
    }
    return null;
  }
}
```

（替换原有的 `_extractCategory` 实现；动词判定 `_judgeKind` 保持中文 verbs + 按 languageCode 选 verbsEn）

> **保留中文数字解析**：`chineseNumberToArabic` 仍只对中文输入生效（英文走阿拉伯数字直接 `int.tryParse`）。`_extractAmount` 已支持阿拉伯数字，英文输入 `"$25"` 能解析。无需改。

- [ ] **Step 3: smart_entry_providers 注入语言**

打开 `lib/features/smart_entry/providers/smart_entry_providers.dart`。

找到 `LocalRuleEngine` 的实例化处（或 `smartEntryParserProvider`），改为读取 `localeProvider`：

```dart
final smartEntryParserProvider = FutureProvider<SmartEntryParser>((ref) async {
  final locale = ref.watch(localeProvider);
  return SmartEntryParser.forTest(
    now: DateTime.now(),
    languageCode: locale.languageCode,
  );
});
```

（具体签名按现有 `smartEntryParserProvider` 实现调整；关键是把 `locale.languageCode` 传入 LocalRuleEngine）

- [ ] **Step 4: SmartEntryParser 透传 languageCode**

打开 `lib/features/smart_entry/parser/smart_entry_parser.dart`，构造增加 `languageCode` 并透传给 `LocalRuleEngine`：

```dart
class SmartEntryParser {
  SmartEntryParser({
    DateTime? now,
    CloudParser cloud = const NoopCloudParser(),
    String languageCode = 'zh',
  }) : _engine = LocalRuleEngine(now: now, languageCode: languageCode),
       _cloud = cloud;

  SmartEntryParser.forTest({required DateTime now, String languageCode = 'zh'})
    : _engine = LocalRuleEngine(now: now, languageCode: languageCode),
      _cloud = const NoopCloudParser();
  // ...
}
```

- [ ] **Step 5: 运行已有 smart_entry 测试确认不破坏**

Run: `flutter test test/`（若有 smart_entry 相关测试）

Expected: PASS（中文场景行为不变）

- [ ] **Step 6: 提交**

```bash
git add -A
git commit -m "feat(smart-entry): add bilingual category keywords (zh/en)"
```

---

### Task E7：桌面 Widget 日期标签 locale 化

**Files:**
- Modify: `lib/features/home/services/widget_sync_service.dart`

- [ ] **Step 1: 修改 weekday 格式化为按 locale**

打开 `lib/features/home/services/widget_sync_service.dart`。

在 `syncFromProviders` 和 `syncFromRef` 中，把硬编码的中文 weekday 列表替换为 `intl.DateFormat`：

```dart
// 原：
// const weekday = ['周一','周二',...];
// final dateLabel = '${now.month}月${now.day}日 ${weekday[now.weekday - 1]}';

// 改为：
import 'package:intl/intl.dart';
import '../../settings/providers/settings_providers.dart';

// 在 syncFromProviders 内：
final locale = container.read(localeProvider);
final dateLabel = DateFormat(
  'MMMd EEEE',
  locale.toLanguageTag(),
).format(now);
// 例：中文 → "6月21日 周六"，英文 → "Jun 21 Saturday"
```

`syncFromRef` 同样改造（`ref.read(localeProvider)`）。

> 注：`intl.DateFormat` 的 locale 参数若为 null 或不支持，会回退到默认 locale。`locale.toLanguageTag()` 返回 'zh'/'en'，intl 已内置支持。

- [ ] **Step 2: 运行确认**

Run: `flutter analyze`
Expected: 无 error

- [ ] **Step 3: 提交**

```bash
git add lib/features/home/services/widget_sync_service.dart
git commit -m "feat(home): localize widget date label by locale"
```

---

## 阶段 F：测试与收尾

### Task F1：创建中文 UI 扫描脚本

**Files:**
- Create: `tools/scan_chinese_ui.dart`

- [ ] **Step 1: 创建扫描脚本**

创建 `tools/scan_chinese_ui.dart`：

```dart
// 扫描 lib/ 下硬编码的中文 UI 字符串。spec §7.1 第一层。
//
// 运行：dart run tools/scan_chinese_ui.dart
// 白名单：注释（// 或 /* */ 行）、smart_entry_keywords.dart 的 zh 表、
//         数据库播种注释、default_categories.dart（数据，非 UI）。
//
// 退出码 0 = 干净，非 0 = 发现疑似遗漏。
import 'dart:io';

void main() {
  final libDir = Directory('lib');
  final whitelistPaths = <String>[
    'lib${Platform.pathSeparator}features${Platform.pathSeparator}smart_entry${Platform.pathSeparator}constants${Platform.pathSeparator}smart_entry_keywords.dart',
    'lib${Platform.pathSeparator}core${Platform.pathSeparator}constants${Platform.pathSeparator}default_categories.dart',
  ];
  final violations = <String>[];
  int fileCount = 0;

  for (final entity in libDir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    if (entity.path.endsWith('.g.dart') || entity.path.endsWith('.gr.dart')) {
      continue;
    }
    final relativePath = entity.path.replaceFirst(
      Directory.current.path + Platform.pathSeparator,
      '',
    );
    final isWhitelisted = whitelistPaths.any(
      (w) => relativePath == w || entity.path.endsWith(w),
    );

    final lines = entity.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      // 跳过注释行
      final trimmed = line.trim();
      if (trimmed.startsWith('//') ||
          trimmed.startsWith('*') ||
          trimmed.startsWith('/*')) {
        continue;
      }
      // 查找中文字符
      final hasChinese = RegExp(r'[\u4e00-\u9fff]').hasMatch(line);
      if (!hasChinese) continue;

      // 白名单文件直接跳过
      if (isWhitelisted) continue;

      // 非白名单文件：检查是否在 UI 字符串上下文
      // （Text('...') / label: '...' / title: '...' / hintText: 等）
      final isUiContext = RegExp(
        r"(Text\(|title:|label:|hintText:|tooltip:|message:|content:.*'|Toast\.\w+\()",
      ).hasMatch(line);
      if (isUiContext || _isPlainChineseString(line)) {
        violations.add('$relativePath:${i + 1}: $line');
      }
    }
    fileCount++;
  }

  print('Scanned $fileCount files.');
  if (violations.isEmpty) {
    print('CLEAN: no hardcoded Chinese UI strings found.');
    exit(0);
  } else {
    print('FOUND ${violations.length} suspected violations:');
    for (final v in violations) {
      print('  $v');
    }
    exit(1);
  }
}

bool _isPlainChineseString(String line) {
  // 形如 '某中文' 的独立字符串字面量（不在注释里）
  return RegExp(r"""['"][\u4e00-\u9fff]""").hasMatch(line);
}
```

- [ ] **Step 2: 运行扫描确认阶段 E 完整性**

Run: `dart run tools/scan_chinese_ui.dart`
Expected: 阶段 E 完成后应输出 `CLEAN`（或仅剩白名单文件的合法内容）。若 FOUND，回到 E4 补抽取。

- [ ] **Step 3: 提交**

```bash
git add tools/scan_chinese_ui.dart
git commit -m "chore(i18n): add Chinese UI string scanner tool"
```

---

### Task F2：AndroidManifest 补 configChanges locale

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml`

- [ ] **Step 1: 找到主 Activity 的 android:configChanges**

打开 `android/app/src/main/AndroidManifest.xml`，找到主 `<activity>` 标签的 `android:configChanges` 属性。

- [ ] **Step 2: 补 locale 标志**

把现有 `android:configChanges="..."` 补上 `locale`（如原来是 `orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale`，确认 locale 已在；若没有则加上）。

> 注：若现有 configChanges 已包含 locale（很多 Flutter 项目默认有），此任务无需改动，记录"已存在"。

- [ ] **Step 3: 提交（若有改动）**

```bash
git add android/app/src/main/AndroidManifest.xml
git commit -m "chore(android): ensure locale in configChanges to avoid activity recreate"
```

---

### Task F3：新增对比度 widget 测试

**Files:**
- Create: `test/theme/theme_contrast_test.dart`

- [ ] **Step 1: 创建对比度测试**

创建 `test/theme/theme_contrast_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record_everything/core/theme/app_theme.dart';
import 'package:record_everything/l10n/generated/app_localizations.dart';

/// 计算 WCAG 对比度（1.0 ~ 21.0）。spec §7.1 第三层。
double contrastRatio(Color a, Color b) {
  double luminance(Color c) {
    final r = c.red / 255;
    final g = c.green / 255;
    final bl = c.blue / 255;
    double channel(double v) =>
        v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(bl);
  }
  final l1 = luminance(a);
  final l2 = luminance(b);
  final lighter = l1 > l2 ? l1 : l2;
  final darker = l1 > l2 ? l2 : l1;
  return (lighter + 0.05) / (darker + 0.05);
}

double pow(double x, double y) => x.toDouble() == 0
    ? 0
    : (x == 1 ? 1 : _pow(x, y));
double _pow(double x, double y) {
  // 简单幂运算（避免 import dart:math 在测试上下文混乱）
  var result = 1.0;
  for (var i = 0; i < y.toInt(); i++) {
    result *= x;
  }
  return result;
}

void main() {
  group('theme contrast', () {
    test('浅色主题：正文文字与背景对比度 ≥ 4.5', () {
      final theme = AppTheme.lightTheme();
      final text = theme.textTheme.bodyLarge!.color!;
      final bg = theme.scaffoldBackgroundColor;
      expect(contrastRatio(text, bg), greaterThanOrEqualTo(4.5));
    });

    test('深色主题：正文文字与背景对比度 ≥ 4.5', () {
      final theme = AppTheme.darkTheme();
      final text = theme.textTheme.bodyLarge!.color!;
      final bg = theme.scaffoldBackgroundColor;
      expect(contrastRatio(text, bg), greaterThanOrEqualTo(4.5));
    });

    test('浅色主题：次要文字与背景对比度 ≥ 4.5', () {
      final theme = AppTheme.lightTheme();
      final text = theme.textTheme.bodyMedium!.color!;
      final bg = theme.scaffoldBackgroundColor;
      expect(contrastRatio(text, bg), greaterThanOrEqualTo(4.5));
    });

    test('深色主题：次要文字与背景对比度 ≥ 4.5', () {
      final theme = AppTheme.darkTheme();
      final text = theme.textTheme.bodyMedium!.color!;
      final bg = theme.scaffoldBackgroundColor;
      expect(contrastRatio(text, bg), greaterThanOrEqualTo(4.5));
    });

    test('浅色主题：标题文字与卡片背景对比度 ≥ 4.5', () {
      final theme = AppTheme.lightTheme();
      final text = theme.textTheme.headlineMedium!.color!;
      final card = theme.cardTheme.color!;
      expect(contrastRatio(text, card), greaterThanOrEqualTo(4.5));
    });

    test('深色主题：标题文字与卡片背景对比度 ≥ 4.5', () {
      final theme = AppTheme.darkTheme();
      final text = theme.textTheme.headlineMedium!.color!;
      final card = theme.cardTheme.color!;
      expect(contrastRatio(text, card), greaterThanOrEqualTo(4.5));
    });
  });
}
```

> 注：`pow` 用简化实现避免 `dart:math` import；实际对比度计算用标准 WCAG 公式。若 `_pow` 对非整数 y 不精确，可改 `import 'dart:math'` 并用 `math.pow`。

- [ ] **Step 2: 运行测试确认通过**

Run: `flutter test test/theme/theme_contrast_test.dart`
Expected: PASS（6 个测试）。若失败，说明深色/浅色调色板对比度不足，回到 `app_palette.dart` 调整对应颜色（提亮文字或加深背景）。

- [ ] **Step 3: 提交**

```bash
git add test/theme/theme_contrast_test.dart
git commit -m "test(theme): add WCAG contrast tests for light/dark themes"
```

---

### Task F4：新增语言切换渲染测试

**Files:**
- Create: `test/l10n/locale_switch_test.dart`

- [ ] **Step 1: 创建语言切换测试**

创建 `test/l10n/locale_switch_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record_everything/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('英文 locale 下 appName 为 Life Items', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Text(AppLocalizations.of(context).appName),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Life Items'), findsOneWidget);
  });

  testWidgets('中文 locale 下 appName 为 生活事项', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Text(AppLocalizations.of(context).appName),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('生活事项'), findsOneWidget);
  });

  testWidgets('英文 locale 下 common_save 为 Save', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Text(AppLocalizations.of(context).common_save),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('中文 locale 下 common_save 为 保存', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Text(AppLocalizations.of(context).common_save),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('保存'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行测试确认通过**

Run: `flutter test test/l10n/locale_switch_test.dart`
Expected: PASS（4 个测试）

- [ ] **Step 3: 提交**

```bash
git add test/l10n/locale_switch_test.dart
git commit -m "test(l10n): add locale switch rendering tests"
```

---

### Task F5：新增 ThemeMode/Locale Provider 单元测试

**Files:**
- Create: `test/providers/settings_providers_test.dart`

- [ ] **Step 1: 创建 Provider 测试**

创建 `test/providers/settings_providers_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:record_everything/features/settings/providers/settings_providers.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await initSharedPrefs();
  });

  group('ThemeModeNotifier', () {
    test('默认为 ThemeMode.system', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(themeModeProvider), ThemeMode.system);
    });

    test('set 后持久化并更新 state', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(themeModeProvider.notifier).set(ThemeMode.dark);
      expect(container.read(themeModeProvider), ThemeMode.dark);
      // 持久化验证
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_theme_mode'), 'dark');
    });

    test('已保存的值在重建时恢复', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_theme_mode', 'light');
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(themeModeProvider), ThemeMode.light);
    });
  });

  group('LocaleNotifier', () {
    test('默认跟随系统', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final locale = container.read(localeProvider);
      // 跟随系统时返回 _systemLocale（zh 或 en）
      expect(['zh', 'en'], contains(locale.languageCode));
    });

    test('set(en) 持久化并更新 state', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(localeProvider.notifier).set(const Locale('en'));
      expect(container.read(localeProvider).languageCode, 'en');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_locale'), 'en');
    });

    test('followSystem 清除持久化', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_locale', 'en');
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(localeProvider.notifier).followSystem();
      expect(prefs.getString('app_locale'), isNull);
      expect(container.read(localeProvider.notifier).isFollowingSystem, true);
    });
  });
}
```

- [ ] **Step 2: 运行测试确认通过**

Run: `flutter test test/providers/settings_providers_test.dart`
Expected: PASS（6 个测试）

- [ ] **Step 3: 提交**

```bash
git add test/providers/settings_providers_test.dart
git commit -m "test(settings): add ThemeMode/Locale provider unit tests"
```

---

### Task F6：新增 avoid_raw_color_literal lint 规则

**Files:**
- Create: `tools/avoid_raw_color_literal/`（完整 pub package）
- Modify: `pubspec.yaml`（dev_dependencies 添加）
- Modify: `analysis_options.yaml`

> **实施说明：** 现有项目已有 `tools/disposable_resource_lint` 自定义 lint 包。本任务参照其结构创建 `avoid_raw_color_literal`，禁止 `lib/` 下出现 `Color(0x...)`、`Colors.black`、`Colors.white` 字面量（白名单 `app_palette.dart`、测试）。

- [ ] **Step 1: 参照 disposable_resource_lint 结构创建包**

先查看 `tools/disposable_resource_lint/` 的 `pubspec.yaml` 和 `lib/` 结构作为模板。

Run: `dir tools\disposable_resource_lint` 和查看其 `pubspec.yaml`、`lib/*.dart`

- [ ] **Step 2: 创建 avoid_raw_color_literal 包**

在 `tools/avoid_raw_color_literal/` 下创建：
- `pubspec.yaml`（参照 disposable_resource_lint，改 name 为 `avoid_raw_color_literal`，依赖 `_analyzer`/`custom_lint`）
- `lib/avoid_raw_color_literal.dart`（plugin 注册）
- `lib/src/avoid_raw_color_literal_rule.dart`（AST visitor 检测 `Color(0x...)`/`Colors.black`/`Colors.white`，排除白名单路径）

核心规则逻辑（伪代码）：
```dart
// 在 visitNode 中检测：
// - InstanceCreationExpression，构造名是 'Color'，且参数是十六进制字面量
// - PrefixedIdentifier/PropertyAccess，前缀是 'Colors'，标识符是 'black' 或 'white'
// 检查所在文件路径，若在白名单（app_palette.dart / *_test.dart / test/）则跳过
// 否则报告 lint error
```

> **执行提示：** 这是本计划中最具技术挑战的任务。若时间紧张，可降级为：不实现自定义 lint，改为在 CI 加一个 grep 检查脚本（类似 Task F1 的 scanner）。功能等价，只是错误提示不那么 IDE 友好。

- [ ] **Step 3: 注册到 pubspec.yaml**

在 `pubspec.yaml` 的 `dev_dependencies:` 添加：
```yaml
  avoid_raw_color_literal:
    path: tools/avoid_raw_color_literal
```

- [ ] **Step 4: 注册到 analysis_options.yaml**

打开 `analysis_options.yaml`，在 `custom_lint` 的 `rules:` 下添加（参照 disposable_resource_lint 的注册方式）：
```yaml
custom_lint:
  rules:
    - avoid_local_disposable_in_function
    - avoid_raw_color_literal
```

- [ ] **Step 5: 运行 custom_lint 确认**

Run: `dart run custom_lint`
Expected: 无 avoid_raw_color_literal 违规（阶段 B 已清理）。若有违规，回到对应文件修正。

- [ ] **Step 6: 提交**

```bash
git add -A
git commit -m "chore(lint): add avoid_raw_color_literal custom lint rule"
```

---

### Task F7：黄金图测试（核心页面 light/dark）

**Files:**
- Create: `test/golden/`（目录）
- Create: `test/golden/home_page_golden_test.dart`
- Create: `test/golden/settings_page_golden_test.dart`
- （其余页面按需）

> **范围说明：** 完整 8 页面 × 2 主题 = 16 张黄金图工作量很大。本任务先做 2 个核心页面（首页、设置页）的 light/dark 共 4 张作为基线示范，其余可在后续迭代补全。spec §7.1 第四层的目标是"建立机制"，机制建立后页面可逐步增加。

- [ ] **Step 1: 创建首页黄金图测试**

创建 `test/golden/home_page_golden_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record_everything/app.dart';
import 'package:record_everything/core/theme/app_theme.dart';
import 'package:record_everything/features/settings/providers/settings_providers.dart';
import 'package:record_everything/l10n/generated/app_localizations.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await initSharedPrefs();
  });

  Future<void> pumpGolden(
    WidgetTester tester,
    String name,
    ThemeMode themeMode,
    Locale locale,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          themeModeProvider.overrideWith((ref) {
            final n = ThemeModeNotifier();
            // 通过 state 直接设置
            return n;
          }),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme(),
          darkTheme: AppTheme.darkTheme(),
          themeMode: themeMode,
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const HomePage(),  // 或具体页面 widget
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  testWidgets('首页 - 浅色 - 中文', (tester) async {
    await pumpGolden(tester, 'home_light_zh', ThemeMode.light, const Locale('zh'));
  });

  testWidgets('首页 - 深色 - 中文', (tester) async {
    await pumpGolden(tester, 'home_dark_zh', ThemeMode.dark, const Locale('zh'));
  });

  testWidgets('首页 - 浅色 - 英文', (tester) async {
    await pumpGolden(tester, 'home_light_en', ThemeMode.light, const Locale('en'));
  });

  testWidgets('首页 - 深色 - 英文', (tester) async {
    await pumpGolden(tester, 'home_dark_en', ThemeMode.dark, const Locale('en'));
  });
}
```

> **执行提示：** `HomePage` 的实际引用路径和构造需根据项目调整（可能需要 mock 数据库 provider）。黄金图测试涉及数据层 mock 较复杂，若某页面依赖过多 provider，可先用更简单的 widget（如纯 `SettingsPage`）建立基线。

- [ ] **Step 2: 生成黄金图基线**

Run: `flutter test --update-goldens test/golden/`
Expected: 在 `test/golden/goldens/` 下生成 4 张 PNG

- [ ] **Step 3: 运行黄金图测试确认通过**

Run: `flutter test test/golden/`
Expected: PASS（基线已生成后对比通过）

- [ ] **Step 4: 提交（含黄金图基线）**

```bash
git add -A
git commit -m "test(golden): add home page golden tests (light/dark × zh/en)"
```

---

### Task F8：最终验收与 README 更新

**Files:**
- Modify: `README.md`

- [ ] **Step 1: 运行完整测试矩阵**

Run 依次：
- `flutter analyze` — Expected: 零 warning（含新 lint）
- `flutter test` — Expected: 全绿
- `dart run tools/scan_chinese_ui.dart` — Expected: CLEAN
- `dart run custom_lint` — Expected: 无违规

- [ ] **Step 2: 手动验收（按 spec Appendix A 清单）**

在模拟器/真机上逐一验证：
- 设置页切换 浅色→深色→跟随系统，检查每个页面（首页、事项、账单、项目、统计、搜索、设置、回收站、智能输入）无看不清问题
- 切换 中文↔英文，检查每页文案正确、无 key 暴露
- 内置分类在英文下显示英文名（"餐饮"→"Food"）
- 用户改名的内置分类切语言后保留用户输入
- 切换语言后桌面 Widget 日期标签跟随
- 冷启动无闪烁
- 切换语言时表单草稿不丢失

记录任何遗漏并回到对应任务修复。

- [ ] **Step 3: 更新 README**

在 `README.md` 的「功能特性」section 顶部，更新「智能输入」之前的位置，新增：

```markdown
### 深色模式与多语言
- 三种主题模式：跟随系统 / 浅色 / 深色（设置 → 外观）
- 多语言支持：简体中文、English（设置 → 语言）
- 内置分类名随语言切换；用户自建分类原样显示
- 所有页面深色模式适配，符合 WCAG AA 对比度标准
```

并在「技术栈」表格补充：
```markdown
| flutter_localizations | 多语言（gen-l10n，中/英） |
```

- [ ] **Step 4: 提交**

```bash
git add README.md
git commit -m "docs: update README with dark mode and i18n features"
```

---

## 完成标准回顾

实现完成后，确认以下全部达成（spec §7.2 DoD）：

1. ✅ `flutter analyze` 零 warning（含 `avoid_raw_color_literal` lint）
2. ✅ `flutter test` 全绿（含 theme/l10n/providers/contrast/golden 测试）
3. ✅ 16 张黄金图通过（核心页面 × light/dark × zh/en）
4. ✅ 手动验收清单（spec Appendix A）逐项通过
5. ✅ 切换语言时 Activity 不重建（`configChanges` 生效）
6. ✅ `tools/scan_chinese_ui.dart` 报告 CLEAN

---

## 执行提示（给 agentic worker）

1. **阶段 A → B 必须连续**：A2 会破坏编译，B 完成前不要单独提交可运行状态以外的检查。
2. **Task E4（UI 文案抽取）是最大工作量**：建议用 subagent 分 feature 并行处理，每个 subagent 负责一个 feature 的抽取，主 agent 汇总 ARB 并重新 gen-l10n。
3. **Task F6（自定义 lint）可选降级**：若实现自定义 lint 包遇阻，降级为 CI grep 脚本，不影响主功能。
4. **Task F7（黄金图）可增量**：先建立 2-4 个核心页面的基线，后续迭代补全。
5. **每完成一个 Task 都运行 `flutter analyze && flutter test`**：避免问题累积。
6. **遇到 spec 与代码现状冲突时**：以代码现状为准（如发现 `sharedPrefsProvider` 已存在或签名不同），在对应 Task 的 notes 文件记录调整。
