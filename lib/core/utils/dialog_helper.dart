import 'package:flutter/material.dart';

/// Extension for safe dialog/sheet dismissal.
///
/// Use [safePop] instead of [Navigator.pop] when dismissing dialogs or
/// bottom sheets, especially after async operations or when the calling
/// context may have been deactivated.
///
/// Common scenarios that require safePop:
/// - Dismissing after an async gap (await) where the widget may be disposed
/// - Dismissing a dialog/bottom sheet from a callback that fires after
///   the parent widget has been removed from the tree
extension SafeDismiss on BuildContext {
  /// Pop the current route/dialog only if this context is still mounted.
  void safePop([dynamic result]) {
    if (mounted) Navigator.pop(this, result);
  }
}
