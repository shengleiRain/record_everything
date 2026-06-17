import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF4CAF7D);
  static const primaryLight = Color(0xFFA5D6B0);
  static const primaryDark = Color(0xFF2E7D4F);
  static const background = Color(0xFFF8FAF9);
  static const surface = Colors.white;
  static const income = Color(0xFF4CAF7D);
  static const expense = Color(0xFFEF6C6C);
  static const overdue = Color(0xFFEF6C6C);
  static const upcoming = Color(0xFFFFA726);
  static const completed = Color(0xFF81C784);
  static const textPrimary = Color(0xFF2D3436);
  static const textSecondary = Color(0xFF636E72);
  static const textHint = Color(0xFFB2BEC3);
  static const error = Color(0xFFEF6C6C);

  /// Unified card radius for large cards (edit/detail pages).
  static const cardRadiusLarge = 16.0;

  /// Unified card radius for small cards (list items, timeline entries).
  static const cardRadiusSmall = 8.0;

  /// Standard border color for cards and containers.
  static final border = Colors.black.withValues(alpha: 0.08);

  /// Lighter border color for subtle separators.
  static final borderLight = Colors.black.withValues(alpha: 0.06);
}
