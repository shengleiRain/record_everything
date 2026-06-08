import 'package:flutter/material.dart';
import 'home_summary_strip.dart';

class SummarySliver extends SliverPersistentHeaderDelegate {
  SummarySliver({required this.summaryStrip});

  final HomeSummaryStrip summaryStrip;

  @override
  double get maxExtent => extent;

  @override
  double get minExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return summaryStrip;
  }

  @override
  bool shouldRebuild(covariant SummarySliver oldDelegate) =>
      summaryStrip.monthlyExpense != oldDelegate.summaryStrip.monthlyExpense ||
      summaryStrip.monthlyIncome != oldDelegate.summaryStrip.monthlyIncome ||
      summaryStrip.pendingCount != oldDelegate.summaryStrip.pendingCount ||
      summaryStrip.overdueCount != oldDelegate.summaryStrip.overdueCount;

  // margin: (12 top + 8 bottom) + padding: (12 * 2 vertical)
  // + content: bodySmall line (~16) + gap(4) + titleSmall line (~18)
  static const double extent = 86;
}
