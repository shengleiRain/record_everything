import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import 'step_draft.dart';

// Shared layout constants between the page and the editor widgets.
const double _stepContentHorizontalInset = 16;
const double _stepTabAddButtonGap = 8;

/// A pinned sliver header that hosts the horizontal reorderable step tabs and
/// the "add node" button. Generic over the concrete [StepDraft] type so it can
/// be shared by the project edit page and the project template edit page.
class StepTabHeader<T extends StepDraft> extends SliverPersistentHeaderDelegate {
  const StepTabHeader({
    required this.scrollController,
    required this.steps,
    required this.selectedIndex,
    required this.onReorder,
    required this.onSelected,
    required this.onAdd,
    required this.keyPrefix,
  });

  final ScrollController scrollController;
  final List<T> steps;
  final int selectedIndex;
  final ReorderCallback onReorder;
  final ValueChanged<int> onSelected;
  final VoidCallback onAdd;

  /// Prefix used for all [ValueKey]s rendered by this header and its
  /// descendants (e.g. `'project-edit'` / `'project-template'`). Keeps test
  /// lookups stable and avoids key collisions when both editors coexist.
  final String keyPrefix;

  static const double extent = 60;

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
    return Material(
      key: ValueKey('$keyPrefix-step-tab-header'),
      color: AppColors.background(context),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          _stepContentHorizontalInset,
          6,
          _stepContentHorizontalInset,
          6,
        ),
        child: SizedBox(
          height: 48,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final hasSteps = steps.isNotEmpty;
              final buttonWidth = hasSteps
                  ? StepAddButton.collapsedExtent
                  : StepAddButton.expandedWidth;
              final tabLimit =
                  constraints.maxWidth -
                  buttonWidth -
                  (hasSteps ? _stepTabAddButtonGap : 0);
              final tabWidth = hasSteps
                  ? StepTabStrip.widthForCount(
                      steps.length,
                    ).clamp(0.0, tabLimit < 0 ? 0.0 : tabLimit).toDouble()
                  : 0.0;

              return Row(
                children: [
                  if (hasSteps)
                    AnimatedContainer(
                      duration: StepAddButton.duration,
                      curve: StepAddButton.curve,
                      width: tabWidth,
                      child: StepTabStrip<T>(
                        scrollController: scrollController,
                        steps: steps,
                        selectedIndex: selectedIndex,
                        onReorder: onReorder,
                        onSelected: onSelected,
                        keyPrefix: keyPrefix,
                      ),
                    ),
                  if (hasSteps) const SizedBox(width: _stepTabAddButtonGap),
                  StepAddButton(
                    key: ValueKey('$keyPrefix-add-step'),
                    isEmpty: !hasSteps,
                    onPressed: onAdd,
                  ),
                  const Spacer(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant StepTabHeader<T> oldDelegate) => true;
}

/// Horizontal, reorderable list of step tabs.
class StepTabStrip<T extends StepDraft> extends StatelessWidget {
  const StepTabStrip({
    super.key,
    required this.scrollController,
    required this.steps,
    required this.selectedIndex,
    required this.onReorder,
    required this.onSelected,
    required this.keyPrefix,
  });

  static const double itemExtent = 112;

  static double widthForCount(int count) {
    if (count <= 0) return 0;
    return itemExtent * count;
  }

  final ScrollController scrollController;
  final List<T> steps;
  final int selectedIndex;
  final ReorderCallback onReorder;
  final ValueChanged<int> onSelected;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) return const SizedBox.shrink();

    return ReorderableListView.builder(
      key: ValueKey('$keyPrefix-step-tabs'),
      scrollController: scrollController,
      scrollDirection: Axis.horizontal,
      buildDefaultDragHandles: false,
      itemExtent: itemExtent,
      padding: EdgeInsets.zero,
      proxyDecorator: (child, index, animation) {
        return Material(
          color: Colors.transparent,
          child: ScaleTransition(
            scale: Tween<double>(begin: 1, end: 1.04).animate(animation),
            child: child,
          ),
        );
      },
      itemCount: steps.length,
      onReorder: onReorder,
      itemBuilder: (context, index) {
        final trailingGap = index == steps.length - 1 ? 0.0 : 6.0;
        return Padding(
          key: ValueKey('$keyPrefix-step-tab-${steps[index].localId}'),
          padding: EdgeInsets.only(right: trailingGap),
          child: ReorderableDelayedDragStartListener(
            key: ValueKey('$keyPrefix-step-tab-drag-$index'),
            index: index,
            child: _StepTab(
              keyPrefix: keyPrefix,
              index: index,
              title: steps[index].title,
              selected: index == selectedIndex,
              onSelected: () => onSelected(index),
            ),
          ),
        );
      },
    );
  }
}

/// A single step tab chip with an ordinal badge.
class _StepTab extends StatelessWidget {
  const _StepTab({
    required this.keyPrefix,
    required this.index,
    required this.title,
    required this.selected,
    required this.onSelected,
  });

  final String keyPrefix;
  final int index;
  final String title;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = selected ? AppColors.primaryDark : AppColors.textPrimary(context);
    final badgeBg = selected ? AppColors.primary(context) : AppColors.primaryLight;
    final badgeFg = selected ? AppColors.onColored(context, badgeBg) : AppColors.primary(context);
    final displayTitle = title.isNotEmpty ? title : '未命名节点';
    return InkWell(
      key: ValueKey('$keyPrefix-step-tab-button-$index'),
      borderRadius: BorderRadius.circular(10),
      onTap: onSelected,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: selected ? AppColors.primaryLight : colorScheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected
                      ? AppColors.primary(context)
                      : AppColors.border(context),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 6, 8, 6),
                child: Align(
                  alignment: Alignment.center,
                  child: Text(
                    displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(10),
                  bottomRight: Radius.circular(8),
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: AppColors.primary(context).withValues(alpha: 0.18),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: SizedBox(
                width: 24,
                height: 18,
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: badgeFg,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The morphing add-node button: a wide pill when there are no steps, a round
/// icon button otherwise.
class StepAddButton extends StatelessWidget {
  const StepAddButton({
    super.key,
    required this.isEmpty,
    required this.onPressed,
  });

  final bool isEmpty;
  final VoidCallback onPressed;

  static const double collapsedExtent = 44;
  static const double expandedWidth = 112;
  static const Duration duration = Duration(milliseconds: 260);
  static const Curve curve = Curves.easeOutCubic;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isEmpty ? AppColors.surface(context) : AppColors.primary(context);
    final foregroundColor = isEmpty ? AppColors.primary(context) : AppColors.onColored(context, backgroundColor);

    return Tooltip(
      message: '添加节点',
      child: AnimatedContainer(
        duration: duration,
        curve: curve,
        width: isEmpty ? expandedWidth : collapsedExtent,
        height: collapsedExtent,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(collapsedExtent / 2),
          border: Border.all(
            color: isEmpty
                ? AppColors.primary(context).withValues(alpha: 0.35)
                : AppColors.primary(context),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary(context).withValues(alpha: isEmpty ? 0.08 : 0.16),
              blurRadius: isEmpty ? 8 : 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(collapsedExtent / 2),
            onTap: onPressed,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final showLabel = isEmpty && constraints.maxWidth >= 96;
                return AnimatedPadding(
                  duration: duration,
                  curve: curve,
                  padding: EdgeInsets.symmetric(horizontal: showLabel ? 10 : 0),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_rounded,
                          size: 20,
                          color: foregroundColor,
                        ),
                        if (showLabel) ...[
                          const SizedBox(width: 4),
                          Text(
                            '添加节点',
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                            textAlign: TextAlign.center,
                            strutStyle: const StrutStyle(
                              fontSize: 14,
                              height: 1,
                              forceStrutHeight: true,
                            ),
                            textHeightBehavior: const TextHeightBehavior(
                              applyHeightToFirstAscent: false,
                              applyHeightToLastDescent: false,
                            ),
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: foregroundColor,
                                  fontWeight: FontWeight.w700,
                                  height: 1,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
