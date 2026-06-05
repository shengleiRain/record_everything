import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record_everything/features/home/widgets/quick_create_sheet.dart';

void main() {
  testWidgets('QuickCreateSheet renders all mobile quick actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: QuickCreateSheet())),
    );

    expect(find.text('快速新增'), findsOneWidget);
    expect(find.text('记一笔'), findsOneWidget);
    expect(find.text('建事项'), findsOneWidget);
    expect(find.text('账单到期'), findsOneWidget);
    expect(find.text('周期模板'), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-create-bill')), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-create-item')), findsOneWidget);
  });
}
