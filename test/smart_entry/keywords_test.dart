import 'package:flutter_test/flutter_test.dart';
import 'package:record_everything/features/smart_entry/constants/smart_entry_keywords.dart';

void main() {
  group('chineseNumberToArabic', () {
    test('单字', () {
      expect(chineseNumberToArabic('五'), 5);
      expect(chineseNumberToArabic('十'), 10);
    });
    test('十位', () {
      expect(chineseNumberToArabic('二十五'), 25);
      expect(chineseNumberToArabic('三十'), 30);
      expect(chineseNumberToArabic('十八'), 18);
    });
    test('百位', () {
      expect(chineseNumberToArabic('一百二十'), 120);
      expect(chineseNumberToArabic('两百'), 200);
    });
    test('万位', () {
      expect(chineseNumberToArabic('两万三'), 23000);
      expect(chineseNumberToArabic('一万'), 10000);
    });
    test('无法解析返回 null', () {
      expect(chineseNumberToArabic('abc'), isNull);
    });
  });

  group('动词词表', () {
    test('消费动词命中', () {
      expect(expenseVerbs.any((w) => '花了'.contains(w)), isTrue);
    });
    test('任务动词命中', () {
      expect(taskVerbs.any((w) => '明天开会'.contains(w)), isTrue);
    });
  });
}
