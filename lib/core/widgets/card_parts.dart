import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The 3px-wide colored accent stripe placed on the left edge of every card,
/// matching the project detail page's `_ProjectFlowCard`.
///
/// Place inside a `Stack` with `Positioned(left: 0, top: 0, bottom: 0)`.
class CardLeftStripe extends StatelessWidget {
  const CardLeftStripe({super.key, required this.color, this.width = 3});

  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      top: 0,
      bottom: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
        ),
        child: SizedBox(width: width),
      ),
    );
  }
}

/// A small 14×14 folded triangle in the top-right corner used to mark a row
/// as a bill record (and to distinguish bills from life items on a timeline).
class BillFoldCorner extends StatelessWidget {
  const BillFoldCorner({super.key});

  @override
  Widget build(BuildContext context) {
    return const Positioned(right: 0, top: 0, child: _BillFoldShape());
  }
}

class _BillFoldShape extends StatelessWidget {
  const _BillFoldShape();

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _BillFoldClipper(),
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.08),
        child: const SizedBox.square(dimension: 14),
      ),
    );
  }
}

class _BillFoldClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// A bottom-right ribbon showing a status label (e.g. 已完成 / 逾期 M/D).
///
/// Identical to the project detail page's `_StatusCornerBadge`.
class StatusCornerBadge extends StatelessWidget {
  const StatusCornerBadge({
    super.key,
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 0,
      bottom: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(8),
            bottomRight: Radius.circular(8),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
          child: Text(
            label,
            maxLines: 1,
            textHeightBehavior: const TextHeightBehavior(
              applyHeightToFirstAscent: false,
              applyHeightToLastDescent: false,
            ),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

/// A rounded tinted icon tile used as the leading element of a card row.
///
/// Matches the project detail page's `_EntryIcon`: a square box with a 12%
/// tinted background and a centered icon in [color].
class CardEntryIcon extends StatelessWidget {
  const CardEntryIcon({
    super.key,
    required this.icon,
    required this.color,
    this.size = 28,
    this.iconSize = 17,
    this.radius = 8,
  });

  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(icon, color: color, size: iconSize),
    );
  }
}

/// Standard border color for a card, derived from its state.
Color cardBorderColor({required bool isOverdue, required bool isCompleted}) {
  if (isOverdue) return AppColors.overdue.withValues(alpha: 0.28);
  if (isCompleted) return AppColors.completed.withValues(alpha: 0.24);
  return Colors.black.withValues(alpha: 0.08);
}

/// The trailing amount/status value on the right edge of a card row.
///
/// Matches the project detail page's `_TrailingValue`: a right-aligned,
/// vertically-centered value constrained to a 52-96px width band and scaled
/// down to fit. The fixed width band keeps the text clear of a
/// [StatusCornerBadge] anchored in the bottom-right corner, preventing the
/// "已完成" / "逾期 M/D" badge from overlapping the amount.
class CardTrailingValue extends StatelessWidget {
  const CardTrailingValue({
    super.key,
    required this.text,
    required this.color,
    this.minWidth = 52,
    this.maxWidth = 96,
    this.fontSize,
    this.fontWeight = FontWeight.w900,
  });

  final String text;
  final Color color;
  final double minWidth;
  final double maxWidth;

  /// Optional explicit font size; defaults to `labelLarge` from the theme.
  final double? fontSize;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: minWidth, maxWidth: maxWidth),
      child: Align(
        alignment: Alignment.centerRight,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Text(
            text,
            maxLines: 1,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: fontWeight,
              fontSize: fontSize,
            ),
          ),
        ),
      ),
    );
  }
}
