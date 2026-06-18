import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/utils/form_draft_store.dart';

/// Tracks whether a form has unsaved changes and guards the back gesture
/// with a confirmation dialog, while also persisting a draft to disk so the
/// user doesn't lose work on a "new" form.
///
/// Mix into a [State] and call [markDirty] (or [markDirtyAndPersist]) whenever
/// a field changes. Wrap the page body (or the [Scaffold]) with a [PopScope]:
///
/// ```dart
/// return PopScope(canPop: !isDirty, onPopInvokedWithResult: (d, _) => onPopInvoked(d));
/// ```
///
/// For "new" forms that should keep a recoverable draft:
///
/// ```dart
/// @override
/// void didChangeDependencies() {
///   super.didChangeDependencies();
///   if (_loaded) return;
///   attachDraft(_draftStore, 'bill'); // once
///   if (!_isEdit) maybeRestoreDraft(_applyDraft, noun: '账单');
///   _loaded = true;
/// }
///
/// void _onFieldChanged() => markDirtyAndPersist(_collectDraft);
/// ```
///
/// The dirty flag is both the back-guard trigger and the draft trigger: a
/// form that the user never touched (e.g. template pre-fill) is neither
/// guarded nor persisted. Drafts are debounced (500ms) and auto-expire after
/// 24h — see [FormDraftStore].
mixin DirtyGuardMixin<T extends StatefulWidget> on State<T> {
  bool _dirty = false;

  Timer? _draftDebounce;
  FormDraftStore? _draftStore;
  String? _draftType;

  /// Whether the form currently has unsaved changes.
  bool get isDirty => _dirty;

  /// Mark the form as having unsaved changes (call from field onChanged).
  void markDirty() {
    if (_dirty) return;
    setState(() => _dirty = true);
  }

  /// Mark the form as clean (call after a successful save or after the user
  /// confirms discarding changes). Rebuilds so that [PopScope.canPop] picks up
  /// the new value — without this the route stays locked even when the flag is
  /// cleared, leaving the user stuck on the page.
  void markClean() {
    if (!_dirty) return;
    setState(() => _dirty = false);
  }

  /// Binds a [FormDraftStore] + [draftType] so this form can persist and
  /// restore an in-progress draft. Call once during initialization (typically
  /// in [State.didChangeDependencies]). Only meaningful for "new" forms.
  void attachDraft(FormDraftStore store, String draftType) {
    _draftStore = store;
    _draftType = draftType;
  }

  /// Marks the form dirty *and* schedules a debounced (500ms) persist of the
  /// current field values via [collect]. Use this in every field's
  /// onChanged/onSelected so the draft tracks user input without hammering
  /// SharedPreferences on every keystroke.
  void markDirtyAndPersist(Map<String, dynamic> Function() collect) {
    markDirty();
    final store = _draftStore;
    final type = _draftType;
    if (store == null || type == null) return;
    _draftDebounce?.cancel();
    _draftDebounce = Timer(const Duration(milliseconds: 500), () {
      store.save(type, collect());
    });
  }

  /// Offers to restore a previously persisted draft for this form. If a fresh
  /// (non-expired) draft exists, shows a "恢复未完成的{noun}？" dialog:
  /// choosing **恢复** calls [apply] with the draft map, choosing **丢弃**
  /// clears it. Does nothing when there is no draft. Call this during "new"
  /// form initialization, after [attachDraft]. [noun] defaults to '草稿'.
  Future<void> maybeRestoreDraft(
    void Function(Map<String, dynamic>) apply, {
    String? noun,
  }) async {
    final store = _draftStore;
    final type = _draftType;
    if (store == null || type == null || !mounted) return;
    final draft = await store.load(type);
    if (draft == null || !mounted) return;

    final label = noun ?? '草稿';
    final savedAt = DateTime.tryParse(draft['_savedAt'] as String? ?? '');
    final ageLabel = savedAt == null
        ? ''
        : '（${savedAt.month}/${savedAt.day} ${savedAt.hour.toString().padLeft(2, '0')}:${savedAt.minute.toString().padLeft(2, '0')}）';
    final restore = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('恢复未完成的$label？'),
        content: Text('发现一条未提交的草稿$ageLabel，是否恢复？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('丢弃'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('恢复'),
          ),
        ],
      ),
    );
    if (restore != true) {
      await store.clear(type);
      return;
    }
    if (!mounted) return;
    apply(draft);
    markDirty();
  }

  /// Clears the persisted draft. Call after a successful save so a submitted
  /// record doesn't resurface as a stale draft next time.
  Future<void> clearDraft() async {
    final store = _draftStore;
    final type = _draftType;
    if (store == null || type == null) return;
    _draftDebounce?.cancel();
    await store.clear(type);
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
      // markClean rebuilds so PopScope.canPop flips to true, then we force the
      // pop. We intentionally use pop() (not maybePop()) so the route exits
      // even if the canPop rebuild hasn't settled yet — this matches the
      // save path, which also pops unconditionally.
      markClean();
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _draftDebounce?.cancel();
    super.dispose();
  }
}
