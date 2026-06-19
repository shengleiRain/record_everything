import 'package:flutter_test/flutter_test.dart';
import 'package:record_everything/features/smart_entry/models/draft_item.dart';
import 'package:record_everything/features/smart_entry/parser/smart_entry_parser.dart';

void main() {
  // 不测真实 OCR（需真机 ML Kit）。这里验 OCR 文本喂给解析管道的正确性。
  final parser = SmartEntryParser.forTest(now: DateTime(2026, 6, 19));

  test('标准小票文本（合计 25.00）解析出金额', () async {
    const ocrText = '便利店\n合计 25.00\n2026-06-19';
    final draft = await parser.parse(
      ocrText,
      source: DraftSource.ocr,
      ocrFullText: ocrText,
    );
    expect(draft.ocrFullText, ocrText);
    expect(draft.source, DraftSource.ocr);
    final bill = draft.items.where((i) => i.kind == DraftKind.bill).toList();
    expect(bill, isNotEmpty);
    expect(bill.first.amountCents, 2500);
  });

  test('实付关键字金额被正确提取', () async {
    // 多行小票经 Splitter 拆成多段。"商品 5 件" 这类行内数字可能被误判为
    // 金额（本地引擎已知局限，复杂场景留给云端增强），但 "实付 88.00"
    // 必须能被正确解析为 88 元。
    const ocrText = '商品 5 件\n实付 88.00';
    final draft = await parser.parse(ocrText, source: DraftSource.ocr);
    final bills = draft.items
        .where((i) => i.kind == DraftKind.bill && i.amountCents != null)
        .toList();
    expect(bills.map((b) => b.amountCents), contains(8800));
  });

  test('OCR 空文本 → 空 draft', () async {
    final draft = await parser.parse('', source: DraftSource.ocr, ocrFullText: '');
    expect(draft.isEmpty, isTrue);
  });
}
