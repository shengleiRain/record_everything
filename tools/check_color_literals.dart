// 检查 lib/ 下硬编码的颜色字面量。spec §3.2。
//
// 运行：dart run tools/check_color_literals.dart
// 白名单：app_palette.dart、app_colors.dart、app_theme.dart、*_test.dart。
//
// 退出码 0 = 干净，非 0 = 发现违规。
import 'dart:io';

void main() {
  final libDir = Directory('lib');
  final whitelistPaths = <String>[
    'app_palette.dart',
    'app_colors.dart',
    'app_theme.dart',
  ];
  final violations = <String>[];
  int fileCount = 0;

  for (final entity in libDir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    if (entity.path.endsWith('.g.dart') || entity.path.endsWith('.gr.dart')) {
      continue;
    }
    final isWhitelisted = whitelistPaths.any(
      (w) => entity.path.endsWith(w),
    );
    if (isWhitelisted) continue;

    final relativePath = entity.path.replaceFirst(
      Directory.current.path + Platform.pathSeparator,
      '',
    );

    final lines = entity.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      // 跳过注释
      final trimmed = line.trim();
      if (trimmed.startsWith('//') ||
          trimmed.startsWith('*') ||
          trimmed.startsWith('/*')) {
        continue;
      }

      // 检查 Color(0xFF...) 字面量
      if (RegExp(r'Color\(0x[0-9A-Fa-f]{8}\)').hasMatch(line)) {
        violations.add(
          '$relativePath:${i + 1}: hardcoded Color literal: ${line.trim()}',
        );
      }
      // 检查 Colors.black / Colors.white（排除 FAB foreground 等合理用法）
      if (RegExp(r'Colors\.(black|white)\b').hasMatch(line)) {
        // 排除 colorScheme 相关的合理用法
        if (!line.contains('colorScheme') && !line.contains('onPrimary')) {
          violations.add(
            '$relativePath:${i + 1}: Colors.black/white usage: ${line.trim()}',
          );
        }
      }
    }
    fileCount++;
  }

  print('Scanned $fileCount files.');
  if (violations.isEmpty) {
    print('CLEAN: no hardcoded color literals found.');
    exit(0);
  } else {
    print('FOUND ${violations.length} violations:');
    for (final v in violations) {
      print('  $v');
    }
    exit(1);
  }
}
