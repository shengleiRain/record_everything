import 'package:flutter/material.dart';

class SheetActionLayout extends StatelessWidget {
  const SheetActionLayout({super.key, required this.children});

  final List<Widget> children;

  static const double gap = 10;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final fullWidth = constraints.maxWidth;
        final halfWidth = (fullWidth - gap) / 2;
        final rows = <Widget>[];

        if (children.length == 1) {
          rows.add(SizedBox(width: fullWidth, child: children.single));
        } else if (children.length == 2) {
          rows.add(_twoColumnRow(children[0], children[1], halfWidth));
        } else if (children.length == 3) {
          rows
            ..add(SizedBox(width: fullWidth, child: children[0]))
            ..add(_twoColumnRow(children[1], children[2], halfWidth));
        } else {
          for (var index = 0; index < children.length; index += 2) {
            final left = children[index];
            final right = index + 1 < children.length
                ? children[index + 1]
                : null;
            rows.add(
              right == null
                  ? SizedBox(width: fullWidth, child: left)
                  : _twoColumnRow(left, right, halfWidth),
            );
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < rows.length; index++) ...[
              rows[index],
              if (index != rows.length - 1) const SizedBox(height: gap),
            ],
          ],
        );
      },
    );
  }

  Widget _twoColumnRow(Widget left, Widget right, double width) {
    return Row(
      children: [
        SizedBox(width: width, child: left),
        const SizedBox(width: gap),
        SizedBox(width: width, child: right),
      ],
    );
  }
}
