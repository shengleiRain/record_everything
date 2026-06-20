import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record_everything/features/smart_entry/models/draft_item.dart';
import 'package:record_everything/features/smart_entry/widgets/draft_item_card.dart';

void main() {
  testWidgets('展示标题与金额，低置信有警告标识', (tester) async {
    final item = DraftItem(
      kind: DraftKind.bill,
      title: '午餐',
      amountCents: 2500,
      amountType: DraftAmountType.expense,
      time: DateTime(2026, 6, 19, 12),
      source: DraftSource.nl,
      confidence: 0.5,
      parseNotes: const ['未识别到金额'],
    );
    DraftItem? edited;
    bool deleted = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DraftItemCard(
            item: item,
            onChanged: (i) => edited = i,
            onDeleted: () => deleted = true,
          ),
        ),
      ),
    );

    expect(find.text('午餐'), findsOneWidget);
    expect(find.text('¥25.00'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget); // 低置信
    expect(find.text('未识别到金额'), findsOneWidget);
    expect(edited, isNull);

    await tester.tap(find.byKey(const ValueKey('draft-card-delete')));
    await tester.pump();
    expect(deleted, isTrue);
  });

  testWidgets('高置信无警告', (tester) async {
    final item = DraftItem(
      kind: DraftKind.bill,
      title: '咖啡',
      amountCents: 1500,
      amountType: DraftAmountType.expense,
      time: DateTime(2026, 6, 19, 12),
      source: DraftSource.nl,
      confidence: 0.9,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DraftItemCard(item: item, onChanged: (_) {}, onDeleted: () {}),
        ),
      ),
    );
    expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
  });
}
