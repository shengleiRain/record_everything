import 'package:flutter/material.dart';

/// A quick action revealed when the user swipes a card.
///
/// This is the public counterpart of the original private `_FlowQuickAction`
/// used by the project detail page. It is intentionally tiny so that every
/// card in the app can describe its own swipe actions.
class SwipeAction {
  const SwipeAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

/// Wraps [child] in a swipeable layer that reveals [actions] on the right.
///
/// Extracted from `project_detail_page.dart` so that every list/card in the
/// app can share the exact same swipe-to-reveal behaviour:
/// * up to [maxOffset] px of drag,
/// * opens past half-width or on a fast flick,
/// * only one card open at a time (see [SwipeRevealController]),
/// * pages should call [SwipeRevealController.closeIfOutside] from a
///   `Listener.onPointerDown` on their scrollable so tapping outside closes
///   the currently-open card.
class SwipeActionReveal extends StatefulWidget {
  const SwipeActionReveal({
    super.key,
    required this.actions,
    required this.child,
    this.maxOffset = 148,
  });

  final List<SwipeAction> actions;
  final Widget child;

  /// Maximum horizontal offset the card can travel. Defaults to 148 to match
  /// the project detail page.
  final double maxOffset;

  @override
  State<SwipeActionReveal> createState() => SwipeActionRevealState();
}

class SwipeActionRevealState extends State<SwipeActionReveal> {
  final _rootKey = GlobalKey();
  double _offset = 0;

  @override
  void dispose() {
    SwipeRevealController.unregister(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.actions.isEmpty) return widget.child;
    return ClipRect(
      child: KeyedSubtree(
        key: _rootKey,
        child: Stack(
          children: [
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: widget.maxOffset,
                  child: Row(
                    children: [
                      for (
                        var index = 0;
                        index < widget.actions.length;
                        index++
                      )
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              left: index == 0 ? 6 : 0,
                              right: 6,
                            ),
                            child: SwipeActionButton(
                              action: widget.actions[index],
                              onClose: _close,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              transform: Matrix4.translationValues(-_offset, 0, 0),
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragUpdate: (details) {
                  setState(() {
                    _offset = (_offset - details.delta.dx).clamp(
                      0,
                      widget.maxOffset,
                    );
                  });
                },
                onHorizontalDragEnd: (details) {
                  final velocity = details.primaryVelocity ?? 0;
                  if (_offset > widget.maxOffset / 2 || velocity < -280) {
                    _open();
                  } else {
                    _close();
                  }
                },
                child: widget.child,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool containsGlobalPosition(Offset position) {
    final context = _rootKey.currentContext;
    if (context == null) return false;
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return false;
    final local = renderObject.globalToLocal(position);
    return (Offset.zero & renderObject.size).contains(local);
  }

  void _open() {
    SwipeRevealController.open(this);
    if (!mounted) return;
    setState(() => _offset = widget.maxOffset);
  }

  void _close() {
    SwipeRevealController.unregister(this);
    if (!mounted) return;
    setState(() => _offset = 0);
  }
}

/// Coordinates the single-open policy across every [SwipeActionReveal].
///
/// Use [closeIfOutside] from a page-level `Listener.onPointerDown` so that
/// tapping outside an opened card collapses it.
class SwipeRevealController {
  SwipeRevealController._();

  static SwipeActionRevealState? _openState;

  static void open(SwipeActionRevealState state) {
    if (_openState != state) {
      _openState?._close();
    }
    _openState = state;
  }

  static void unregister(SwipeActionRevealState state) {
    if (_openState == state) {
      _openState = null;
    }
  }

  static void closeIfOutside(Offset position) {
    final state = _openState;
    if (state == null) return;
    if (state.containsGlobalPosition(position)) return;
    state._close();
  }
}

/// A single filled action button revealed by [SwipeActionReveal].
class SwipeActionButton extends StatelessWidget {
  const SwipeActionButton({
    super.key,
    required this.action,
    required this.onClose,
  });

  final SwipeAction action;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: action.color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: () {
        onClose();
        action.onTap();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(action.icon, size: 18),
          const SizedBox(height: 3),
          Text(
            action.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}
