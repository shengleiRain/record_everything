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
      expect(
        mid.textPrimary,
        Color.lerp(const Color(0xFF2D3436), const Color(0xFFE8EAED), 0.5),
      );
    });

    test('lerp 传入非 AppPalette 返回自身', () {
      final result = AppPalette.light.lerp(null, 0.5);
      expect(result, same(AppPalette.light));
    });
  });
}
