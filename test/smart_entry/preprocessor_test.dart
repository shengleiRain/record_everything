import 'package:flutter_test/flutter_test.dart';
import 'package:record_everything/features/smart_entry/parser/preprocessor.dart';

void main() {
  const p = Preprocessor();

  test('全角转半角', () {
    expect(p.normalize('花了２５元，。'), '花了25元,.');
  });

  test('中文数字转阿拉伯（基础）', () {
    expect(p.normalize('花了二十五'), '花了25');
    expect(p.normalize('一百二十'), '120');
    expect(p.normalize('两万三'), '23000');
  });

  test('单位词 1k/1w 等转数字', () {
    expect(p.normalize('花了1k'), '花了1000');
    expect(p.normalize('花了2w'), '花了20000');
  });

  test('去除首尾空白', () {
    expect(p.normalize('  明天开会  '), '明天开会');
  });

  test('保留中文标点用于分句（被 Splitter 处理）', () {
    // 全角逗号/分号/句号已转半角，但感叹号等保留
    expect(p.normalize('开会！'), '开会!');
  });
}
