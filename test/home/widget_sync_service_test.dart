import 'package:flutter_test/flutter_test.dart';
import 'package:record_everything/features/home/services/widget_sync_service.dart';

void main() {
  test('formatWidgetItems 格式化待办条目 JSON', () {
    final json = WidgetSyncService.formatWidgetItems([
      const WidgetItemData(title: '续费会员', isOverdue: false),
      const WidgetItemData(title: '补办证件', isOverdue: true),
    ]);
    expect(json, contains('续费会员'));
    expect(json, contains('补办证件'));
    expect(json, contains('"isOverdue":true'));
    expect(json, contains('"isOverdue":false'));
  });

  test('formatWidgetItems 空列表返回空 JSON 数组', () {
    expect(WidgetSyncService.formatWidgetItems([]), '[]');
  });

  test('formatWidgetItems 最多取 3 条', () {
    final items = List.generate(
      5,
      (i) => WidgetItemData(title: 'item$i', isOverdue: false),
    );
    final json = WidgetSyncService.formatWidgetItems(items);
    expect(json, contains('item0'));
    expect(json, contains('item1'));
    expect(json, contains('item2'));
    expect(json, isNot(contains('item3')));
  });
}
