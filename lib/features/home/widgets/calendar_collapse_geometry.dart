class CalendarCollapseGeometry {
  const CalendarCollapseGeometry({
    required this.viewportTop,
    required this.visibleHeight,
  });

  final double viewportTop;
  final double visibleHeight;

  static CalendarCollapseGeometry resolve({
    required int totalRows,
    required int selectedRow,
    required double rowHeight,
    required double rowSpacing,
    required double collapseProgress,
  }) {
    final rows = totalRows < 1 ? 1 : totalRows;
    final row = selectedRow.clamp(0, rows - 1);
    final progress = collapseProgress.clamp(0.0, 1.0);

    final stride = rowHeight + rowSpacing;
    final expandedTop = 0.0;
    final expandedBottom = rows * rowHeight + (rows - 1) * rowSpacing;
    final collapsedTop = row * stride;
    final collapsedBottom = collapsedTop + rowHeight;

    final top = _lerp(expandedTop, collapsedTop, progress);
    final bottom = _lerp(expandedBottom, collapsedBottom, progress);

    return CalendarCollapseGeometry(
      viewportTop: top,
      visibleHeight: bottom - top,
    );
  }

  static double _lerp(double start, double end, double progress) {
    return start + (end - start) * progress;
  }
}
