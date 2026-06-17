import 'package:flutter/widgets.dart';

import 'step_draft.dart';
import 'step_tab_strip.dart';

/// Owns the step-list state shared by the project edit page and the project
/// template edit page: the ordered [List] of drafts, the swiping [PageController],
/// the horizontal tab [ScrollController], and the currently selected index.
///
/// It encapsulates the 7 operations that were previously duplicated verbatim
/// across both pages: add / delete / select / reorder / syncPage /
/// syncTabScroll / handlePageChanged. The controller is framework-aware: it
/// schedules post-frame callbacks and expects to be driven from a [State] that
/// calls [notifyListeners] (typically via `setState`).
///
/// Lifecycle: create it in the host [State]'s field initializer or
/// [State.initState], and call [dispose] from [State.dispose] (this disposes
/// both inner controllers but NOT the drafts themselves — the host page is
/// responsible for disposing its drafts).
class StepEditorController<T extends StepDraft> {
  StepEditorController();

  /// The editable, ordered list of step drafts. The host page mutates this
  /// directly (e.g. when loading from an existing project/template) and then
  /// calls [notifyListeners] / rebuilds.
  final List<T> steps = <T>[];

  // Owned disposables — created as field initializers (not in a function body)
  // so they're tied to this controller's lifecycle, which itself is owned by
  // the host page's State.
  final PageController pageController = PageController();
  final ScrollController tabScrollController = ScrollController();

  int selectedIndex = 0;

  /// Index clamped to the current list bounds (0 when empty).
  int get currentIndex {
    if (steps.isEmpty) return 0;
    return selectedIndex.clamp(0, steps.length - 1).toInt();
  }

  /// Appends [draft], selects it, and animates to its page.
  ///
  /// [notifyListeners] is called *before* the page sync so that the rebuild
  /// with the new step is committed first; the sync itself is scheduled in a
  /// post-frame callback.
  void addStep(T draft, {required VoidCallback notifyListeners}) {
    steps.add(draft);
    selectedIndex = steps.length - 1;
    notifyListeners();
    syncStepPage(notifyListeners: notifyListeners);
  }

  /// Removes the currently selected draft (disposing it) and re-clamps the
  /// selection. Pass the draft's [StepDraft.dispose] so the controller stays
  /// decoupled from concrete controller ownership.
  void deleteCurrent({
    required VoidCallback notifyListeners,
    required void Function(T removed) disposeRemoved,
  }) {
    if (steps.isEmpty) return;
    final removed = steps.removeAt(currentIndex);
    disposeRemoved(removed);
    selectedIndex = steps.isEmpty
        ? 0
        : selectedIndex.clamp(0, steps.length - 1).toInt();
    notifyListeners();
    syncStepPage(notifyListeners: notifyListeners, animate: false);
  }

  /// Selects [index] (clamped) and animates to it.
  void selectStep(int index, {required VoidCallback notifyListeners}) {
    if (steps.isEmpty) return;
    final next = index.clamp(0, steps.length - 1).toInt();
    if (next == selectedIndex) return;
    selectedIndex = next;
    notifyListeners();
    syncStepPage(notifyListeners: notifyListeners);
  }

  /// Reorders drafts to match a [ReorderableListView] drag, keeping the
  /// currently selected draft selected.
  void reorderStep(
    int oldIndex,
    int newIndex, {
    required VoidCallback notifyListeners,
  }) {
    if (oldIndex == newIndex) return;
    final selectedStep = steps[currentIndex];
    if (oldIndex < newIndex) newIndex -= 1;
    final moved = steps.removeAt(oldIndex);
    steps.insert(newIndex, moved);
    selectedIndex = steps.indexOf(selectedStep);
    notifyListeners();
    syncStepPage(notifyListeners: notifyListeners, animate: false);
  }

  /// Keeps the [PageController] in sync with [currentIndex]. Schedules a
  /// post-frame callback so it runs after the host rebuilds.
  void syncStepPage({
    bool animate = true,
    required VoidCallback notifyListeners,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (steps.isEmpty) return;
      final index = currentIndex;
      if (pageController.hasClients) {
        if (animate) {
          pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
          );
        } else {
          pageController.jumpToPage(index);
        }
      }
      syncStepTabScroll(index: index, animate: animate);
    });
  }

  /// Scrolls the tab strip so the tab at [index] is fully visible.
  void syncStepTabScroll({required int index, required bool animate}) {
    if (!tabScrollController.hasClients) return;
    final position = tabScrollController.position;
    const itemExtent = StepTabStrip.itemExtent;
    const leadingPadding = 0.0;
    final itemStart = leadingPadding + index * itemExtent;
    final itemEnd = itemStart + itemExtent;
    final visibleStart = position.pixels;
    final visibleEnd = visibleStart + position.viewportDimension;

    double? targetOffset;
    if (itemStart < visibleStart) {
      targetOffset = itemStart;
    } else if (itemEnd > visibleEnd) {
      targetOffset = itemEnd - position.viewportDimension;
    }
    if (targetOffset == null) return;

    final clampedOffset = targetOffset.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((clampedOffset - position.pixels).abs() < 0.5) return;

    if (animate) {
      tabScrollController.animateTo(
        clampedOffset,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    } else {
      tabScrollController.jumpTo(clampedOffset);
    }
  }

  /// Handler for [PageController.onPageChanged]: updates the selection and
  /// keeps the tab strip scrolled into view.
  void handlePageChanged(int index, {required VoidCallback notifyListeners}) {
    if (index == selectedIndex) return;
    selectedIndex = index;
    notifyListeners();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      syncStepTabScroll(index: currentIndex, animate: true);
    });
  }

  /// Disposes the inner controllers. Does NOT dispose the drafts.
  void dispose() {
    pageController.dispose();
    tabScrollController.dispose();
  }
}
