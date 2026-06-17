import 'package:flutter/material.dart';

/// Tracks whether a form has unsaved changes and guards the back gesture
/// with a confirmation dialog.
///
/// Mix into a [State] and call [markDirty] whenever a field changes. Wrap the
/// page body (or the [Scaffold]) with [popScope] to intercept system back /
/// AppBar back. The first back attempt while dirty shows a confirmation
/// dialog; confirming clears the dirty flag and pops again.
///
/// ```dart
/// class _MyPageState extends State<MyPage> with DirtyGuardMixin<MyPage> {
///   @override
///   Widget build(BuildContext context) {
///     return PopScope(canPop: !isDirty, onPopInvokedWithResult: onPopInvoked);
///   }
/// }
/// ```
mixin DirtyGuardMixin<T extends StatefulWidget> on State<T> {
  bool _dirty = false;

  /// Whether the form currently has unsaved changes.
  bool get isDirty => _dirty;

  /// Mark the form as having unsaved changes (call from field onChanged).
  void markDirty() {
    if (_dirty) return;
    setState(() => _dirty = true);
  }

  /// Mark the form as clean (call after a successful save).
  void markClean() {
    _dirty = false;
  }

  /// Handler for [PopScope.onPopInvokedWithResult]. When the pop was blocked
  /// (because the form is dirty), prompt the user to confirm discarding
  /// changes; if they confirm, clear the dirty flag and pop again.
  bool onPopInvoked(bool didPop) {
    if (didPop) return true;
    if (!isDirty) return false;
    _confirmExit();
    return false;
  }

  Future<void> _confirmExit() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('放弃未保存的修改？'),
        content: const Text('当前页面有未保存的修改，离开后将丢失。确定要离开吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('继续编辑'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('放弃修改'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      markClean();
      Navigator.of(context).maybePop();
    }
  }
}
