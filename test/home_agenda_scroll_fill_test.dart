import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record_everything/features/home/widgets/home_agenda_scroll_fill.dart';

void main() {
  testWidgets('agenda scroll section expands to collapsed-week remainder', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CustomScrollView(
          slivers: [
            HomeAgendaScrollFill(minHeight: 300, child: SizedBox(height: 100)),
          ],
        ),
      ),
    );

    final section = tester.renderObject<RenderBox>(
      find.byKey(const ValueKey('home-agenda-scroll-fill-section')),
    );
    final fixedGap = tester.widget<SizedBox>(
      find.byKey(const ValueKey('home-agenda-scroll-fill')),
    );

    expect(section.size.height, 300);
    expect(fixedGap.height, 24);
  });

  testWidgets(
    'agenda scroll section keeps natural height when content is tall',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CustomScrollView(
            slivers: [
              HomeAgendaScrollFill(
                minHeight: 300,
                child: SizedBox(height: 400),
              ),
            ],
          ),
        ),
      );

      final section = tester.renderObject<RenderBox>(
        find.byKey(const ValueKey('home-agenda-scroll-fill-section')),
      );

      expect(section.size.height, 424);
    },
  );
}
