import 'package:flutter_test/flutter_test.dart';
import 'package:record_everything/features/smart_entry/models/draft_item.dart';

void main() {
  group('DraftItem', () {
    test('copyWith 更新单个字段保留其余', () {
      final item = DraftItem(
        kind: DraftKind.bill,
        title: '午餐',
        amountCents: 2500,
        amountType: DraftAmountType.expense,
        time: DateTime(2026, 6, 19, 12),
        source: DraftSource.nl,
        confidence: 0.9,
      );
      final updated = item.copyWith(title: '晚餐', amountCents: 5000);
      expect(updated.title, '晚餐');
      expect(updated.amountCents, 5000);
      expect(updated.kind, DraftKind.bill); // 其余字段保留
    });

    test('isLowConfidence 阈值 0.6', () {
      final low = DraftItem(
        kind: DraftKind.bill,
        title: 'x',
        amountCents: 0,
        amountType: DraftAmountType.expense,
        time: DateTime(2026, 6, 19),
        source: DraftSource.ocr,
        confidence: 0.55,
      );
      final high = low.copyWith(confidence: 0.8);
      expect(low.isLowConfidence, isTrue);
      expect(high.isLowConfidence, isFalse);
    });
  });

  group('EntryDraft', () {
    test('空态工厂', () {
      final empty = EntryDraft.empty(DraftSource.nl, rawInput: '?');
      expect(empty.items, isEmpty);
      expect(empty.rawInput, '?');
    });
  });
}
