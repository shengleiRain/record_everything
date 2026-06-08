import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class HomeAgendaScrollFill extends StatelessWidget {
  const HomeAgendaScrollFill({
    super.key,
    required this.minHeight,
    required this.child,
  });

  static const double fixedBottomGap = 24;

  final double minHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: ColoredBox(
        color: AppColors.background,
        child: ConstrainedBox(
          key: const ValueKey('home-agenda-scroll-fill-section'),
          constraints: BoxConstraints(minHeight: minHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              child,
              const SizedBox(
                key: ValueKey('home-agenda-scroll-fill'),
                height: fixedBottomGap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
