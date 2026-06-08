import 'package:flutter_test/flutter_test.dart';
import 'package:record_everything/features/home/widgets/calendar_collapse_geometry.dart';

void main() {
  test('collapses month bounds toward the selected week bounds', () {
    final expanded = CalendarCollapseGeometry.resolve(
      totalRows: 5,
      selectedRow: 1,
      rowHeight: 50,
      rowSpacing: 10,
      collapseProgress: 0,
    );
    final midway = CalendarCollapseGeometry.resolve(
      totalRows: 5,
      selectedRow: 1,
      rowHeight: 50,
      rowSpacing: 10,
      collapseProgress: 0.5,
    );
    final collapsed = CalendarCollapseGeometry.resolve(
      totalRows: 5,
      selectedRow: 1,
      rowHeight: 50,
      rowSpacing: 10,
      collapseProgress: 1,
    );

    expect(expanded.viewportTop, 0);
    expect(expanded.visibleHeight, 290);

    expect(midway.viewportTop, 30);
    expect(midway.visibleHeight, 170);

    expect(collapsed.viewportTop, 60);
    expect(collapsed.visibleHeight, 50);
  });

  test('clamps invalid progress and selected rows', () {
    final beforeStart = CalendarCollapseGeometry.resolve(
      totalRows: 5,
      selectedRow: -4,
      rowHeight: 50,
      rowSpacing: 10,
      collapseProgress: -1,
    );
    final afterEnd = CalendarCollapseGeometry.resolve(
      totalRows: 5,
      selectedRow: 9,
      rowHeight: 50,
      rowSpacing: 10,
      collapseProgress: 2,
    );

    expect(beforeStart.viewportTop, 0);
    expect(beforeStart.visibleHeight, 290);
    expect(afterEnd.viewportTop, 240);
    expect(afterEnd.visibleHeight, 50);
  });
}
