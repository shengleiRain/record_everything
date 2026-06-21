import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record_everything/core/theme/app_theme.dart';
import 'dart:math' as math;

/// 计算 WCAG 2.0 对比度（1.0 ~ 21.0）。spec §7.1。
double contrastRatio(Color a, Color b) {
  double luminance(Color c) {
    final r = c.red / 255;
    final g = c.green / 255;
    final bl = c.blue / 255;
    double channel(double v) =>
        v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(bl);
  }

  final l1 = luminance(a);
  final l2 = luminance(b);
  final lighter = l1 > l2 ? l1 : l2;
  final darker = l1 > l2 ? l2 : l1;
  return (lighter + 0.05) / (darker + 0.05);
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
