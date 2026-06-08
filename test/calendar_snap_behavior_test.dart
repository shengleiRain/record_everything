import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record_everything/features/home/widgets/calendar_snap_behavior.dart';

void main() {
  test('calendar snap uses video-matched timing and easing', () {
    expect(
      CalendarSnapBehavior.snapDuration,
      const Duration(milliseconds: 320),
    );
    expect(CalendarSnapBehavior.snapCurve, Curves.easeOutCubic);
  });

  test('calendar snap commits after a short pull from either end state', () {
    expect(
      CalendarSnapBehavior.shouldSnapToCollapsed(
        collapseProgress: 0.73,
        currentlyCollapsed: true,
      ),
      isTrue,
    );
    expect(
      CalendarSnapBehavior.shouldSnapToCollapsed(
        collapseProgress: 0.71,
        currentlyCollapsed: true,
      ),
      isFalse,
    );
    expect(
      CalendarSnapBehavior.shouldSnapToCollapsed(
        collapseProgress: 0.27,
        currentlyCollapsed: false,
      ),
      isFalse,
    );
    expect(
      CalendarSnapBehavior.shouldSnapToCollapsed(
        collapseProgress: 0.29,
        currentlyCollapsed: false,
      ),
      isTrue,
    );
  });
}
