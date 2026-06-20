import 'package:flutter/material.dart';

import '../../core/utils/toast.dart';

/// Manages the "saving" lifecycle for a form [State].
///
/// Every edit/create form in the app follows the same pattern:
/// validate, run an async save, show a spinner on the save button while it
/// runs, and surface any failure through a [SnackBar]. This mixin encodes
/// that pattern once so individual pages no longer each reimplement the
/// `_saving` flag, the re-entry guard, the try/catch, and the SnackBar.
///
/// Usage:
/// ```dart
/// class _MyPageState extends ConsumerState<MyPage> with FormSaveMixin {
///   Future<void> _save() async {
///     if (!_formKey.currentState!.validate()) return;
///     final ok = await runSave(() async {
///       await ref.read(myNotifierProvider.notifier).create(...);
///       if (mounted) context.pop();
///     });
///     if (ok) {
///       // optional: clear draft, mark clean, etc.
///     }
///   }
/// }
/// ```
///
/// Pair with [SavingButton] in [build]:
/// ```dart
/// SavingButton(onPressed: _save, isSaving: isSaving)
/// ```
mixin FormSaveMixin<T extends StatefulWidget> on State<T> {
  bool _saving = false;

  /// Whether a save is currently in flight. Bind this to [SavingButton.isSaving].
  bool get isSaving => _saving;

  /// Runs [action] with consistent save UX:
  /// - Returns `false` immediately and does nothing if a save is already
  ///   running (re-entry guard against double-taps).
  /// - Sets [isSaving] for the duration of [action].
  /// - On success returns `true`.
  /// - On any thrown object shows a [SnackBar] with [errorMessage] (default
  ///   `'保存失败：$error'`) and returns `false`. The original exception is
  ///   not rethrown — the caller normally just checks the boolean result.
  Future<bool> runSave(
    Future<void> Function() action, {
    String? errorMessage,
  }) async {
    if (_saving) return false;
    setState(() => _saving = true);
    try {
      await action();
      return true;
    } on Object catch (error) {
      if (mounted) {
        Toast.error(context, errorMessage ?? '保存失败：$error');
      }
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
