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

  /// 根据背景色 [background] 的亮度返回高对比度的前景色。
  /// 用于彩色徽章/按钮上的文字/图标色：浅底返回深色文字，深底返回白色文字。
  /// 跨主题自适应，避免深色主题下亮色背景配白字对比度不足。
  static Color onColored(BuildContext context, Color background) {
    final isLightBg = ThemeData.estimateBrightnessForColor(background) ==
        Brightness.light;
    if (isLightBg) {
      // 亮背景：浅色主题用 textPrimary（深灰），深色主题也用深色保证对比。
      return Theme.of(context).brightness == Brightness.light
          ? paletteOf(context).textPrimary
          : const Color(0xFF0F1410);
    }
    // 深背景：用白色文字。
    return const Color(0xFFFFFFFF);
  }

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
