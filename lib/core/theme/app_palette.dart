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
