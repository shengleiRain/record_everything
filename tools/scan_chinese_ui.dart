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
    'smart_entry_keywords.dart',
    'default_categories.dart',
    'app_palette.dart',
    'app_colors.dart',
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
      (w) => entity.path.endsWith(w),
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
      final isUiContext = RegExp(
        r"(Text\(|title:|label:|hintText:|tooltip:|message:|content:.*'|Toast\.\w+\()",
      ).hasMatch(line);
      if (isUiContext || _isPlainChineseString(line)) {
        violations.add('$relativePath:${i + 1}: ${line.trim()}');
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
