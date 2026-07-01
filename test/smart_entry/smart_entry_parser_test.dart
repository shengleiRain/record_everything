import 'package:flutter_test/flutter_test.dart';
import 'package:record_everything/features/smart_entry/models/ai_assistant_config.dart';
import 'package:record_everything/features/smart_entry/models/draft_item.dart';
import 'package:record_everything/features/smart_entry/parser/cloud_parser.dart';
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

  test('alwaysCloud 开启时即使本地高置信也使用云端结果', () async {
    final cloud = _FakeCloudParser([
      DraftItem(
        kind: DraftKind.bill,
        title: '云端午餐',
        amountCents: 2600,
        amountType: DraftAmountType.expense,
        time: DateTime(2026, 6, 20, 12),
        confidence: 0.9,
        source: DraftSource.nl,
      ),
    ]);
    final cloudFirstParser = SmartEntryParser(
      now: DateTime(2026, 6, 19, 10),
      cloud: cloud,
      alwaysCloud: true,
    );

    final draft = await cloudFirstParser.parse('午餐花了25');

    expect(cloud.calls, 1);
    expect(draft.items.single.title, '云端午餐');
  });

  test('解析管道使用传入的本地规则', () async {
    final parser = SmartEntryParser(
      now: DateTime(2026, 6, 19, 10),
      rules: const [
        LocalSmartEntryRule(
          id: 'parking',
          name: '停车',
          keywords: ['停车'],
          kind: DraftKind.lifeItem,
          categoryGuess: '用车',
          amountType: DraftAmountType.none,
        ),
      ],
    );

    final draft = await parser.parse('明天停车');

    expect(draft.items.single.kind, DraftKind.lifeItem);
    expect(draft.items.single.categoryGuess, '用车');
  });
}

class _FakeCloudParser implements CloudParser {
  _FakeCloudParser(this.items);

  final List<DraftItem> items;
  int calls = 0;

  @override
  Future<List<DraftItem>> parse(
    String text, {
    required DraftSource source,
  }) async {
    calls++;
    return items;
  }
}
