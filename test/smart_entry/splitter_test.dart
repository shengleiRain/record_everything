import 'package:flutter_test/flutter_test.dart';
import 'package:record_everything/features/smart_entry/parser/splitter.dart';

void main() {
  const s = Splitter();

  test('按逗号分句', () {
    expect(s.split('明天3点开会,午餐花了25'), ['明天3点开会', '午餐花了25']);
  });

  test('多种分隔符混合', () {
    expect(s.split('开会；下班买水果。回家'), ['开会', '下班买水果', '回家']);
  });

  test('换行分句', () {
    expect(s.split('明天开会\n买咖啡'), ['明天开会', '买咖啡']);
  });

  test('连续分隔符合并空段', () {
    expect(s.split('开会，，买咖啡'), ['开会', '买咖啡']);
  });

  test('空输入返回空列表', () {
    expect(s.split(''), isEmpty);
    expect(s.split('   '), isEmpty);
  });

  test('去每段首尾空白', () {
    expect(s.split(' 开会 , 买咖啡 '), ['开会', '买咖啡']);
  });
}
