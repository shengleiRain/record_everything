import 'package:flutter/animation.dart';

class CalendarSnapBehavior {
  const CalendarSnapBehavior._();

  static const Duration snapDuration = Duration(milliseconds: 260);
  static const Curve snapCurve = Curves.easeOutCubic;

  // Progress is 0.0 when fully expanded and 1.0 when fully collapsed.
  static const double _collapseCommitProgress = 0.28;
  static const double _collapsedRetentionProgress = 0.72;

  static bool shouldSnapToCollapsed({
    required double collapseProgress,
    required bool currentlyCollapsed,
  }) {
    final progress = collapseProgress.clamp(0.0, 1.0);
    if (currentlyCollapsed) {
      return progress >= _collapsedRetentionProgress;
    }
    return progress >= _collapseCommitProgress;
  }
}
