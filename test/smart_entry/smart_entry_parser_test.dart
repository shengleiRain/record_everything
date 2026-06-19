import 'package:flutter_test/flutter_test.dart';
import 'package:record_everything/features/smart_entry/models/draft_item.dart';
import 'package:record_everything/features/smart_entry/parser/smart_entry_parser.dart';

void main() {
  final parser = SmartEntryParser.forTest(now: DateTime(2026, 6, 19, 10));

  test('一句话拆出事项+账单', () async {
    final draft = await parser.parse('明天3点开会,午餐花了25');
    expect(draft.items, hasLength(2));
    expect(draft.items.any((i) => i.kind == DraftKind.lifeItem), isTrue);
    expect(draft.items.any((i) => i.kind == DraftKind.bill), isTrue);
    expect(draft.source, DraftSource.nl);
    expect(draft.rawInput, '明天3点开会,午餐花了25');
  });

  test('空输入 → 空 draft', () async {
    final draft = await parser.parse('');
    expect(draft.isEmpty, isTrue);
  });

  test('保留 ocrFullText', () async {
    final draft = await parser.parse(
      '合计 25.00',
      source: DraftSource.ocr,
      ocrFullText: '商店\n合计 25.00',
    );
    expect(draft.ocrFullText, '商店\n合计 25.00');
    expect(draft.source, DraftSource.ocr);
  });
}
