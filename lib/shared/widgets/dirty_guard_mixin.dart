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
///   attachDraft(_draftStore, 'bill:new', collect: _collectDraft, noun: '账单');
///   if (!_isEdit) maybeRestoreDraft(_applyDraft, noun: '账单');
///   _loaded = true;
/// }
///
/// void _onFieldChanged() => markDirtyAndPersist(_collectDraft);
/// ```
///
/// The dirty flag is both the back-guard trigger and the draft trigger: a
/// form that the user never touched (e.g. template pre-fill) is neither
/// guarded nor persisted. Drafts are debounced (500ms), but confirming exit
/// saves the latest snapshot immediately.
mixin DirtyGuardMixin<T extends StatefulWidget> on State<T> {
  bool _dirty = false;

  Timer? _draftDebounce;
  FormDraftStore? _draftStore;
  String? _draftType;
  Map<String, dynamic> Function()? _draftCollect;
  String? _draftNoun;

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

  /// Binds a [FormDraftStore] + [draftType] so this form can persist, restore,
  /// and immediately save an in-progress draft before exiting.
  ///
  /// Call once after the route knows whether this is a new form or an edit form.
  void attachDraft(
    FormDraftStore store,
    String draftType, {
    Map<String, dynamic> Function()? collect,
    String? noun,
  }) {
    _draftStore = store;
    _draftType = draftType;
    _draftCollect = collect;
    _draftNoun = noun;
  }

  /// Marks the form dirty *and* schedules a debounced (500ms) persist of the
  /// current field values via [collect]. Use this in every field's
  /// onChanged/onSelected so the draft tracks user input without hammering
  /// SharedPreferences on every keystroke.
  void markDirtyAndPersist(Map<String, dynamic> Function() collect) {
    markDirty();
    _draftCollect = collect;
    final store = _draftStore;
    final type = _draftType;
    if (store == null || type == null) return;
    _draftDebounce?.cancel();
    _draftDebounce = Timer(const Duration(milliseconds: 500), () {
      store.save(type, collect());
    });
  }

  /// Offers to restore a previously persisted draft for this form. If a fresh
  /// draft exists, shows a restore dialog. Choosing **恢复草稿** calls [apply]
  /// with the draft map; choosing **不恢复并删除草稿** clears it. Does nothing
  /// when there is no draft.
  Future<void> maybeRestoreDraft(
    void Function(Map<String, dynamic>) apply, {
    String? noun,
  }) async {
    final store = _draftStore;
    final type = _draftType;
    if (store == null || type == null || !mounted) return;
    final draft = await store.load(type);
    if (draft == null || !mounted) return;

    final label = noun ?? _draftNoun ?? '表单';
    final savedAt = DateTime.tryParse(draft['_savedAt'] as String? ?? '');
    final ageLabel = savedAt == null
        ? ''
        : '（${savedAt.month}/${savedAt.day} ${savedAt.hour.toString().padLeft(2, '0')}:${savedAt.minute.toString().padLeft(2, '0')}）';
    final restore = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text('恢复$label草稿？'),
        content: Text('发现一份未保存的$label草稿$ageLabel。恢复草稿会覆盖当前页面内容；不恢复会删除这份草稿。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('不恢复并删除草稿'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('恢复草稿'),
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

  /// Immediately persists the latest draft snapshot. Use before leaving a dirty
  /// page so the final input is not lost while a debounce is still pending.
  Future<void> saveDraftNow() async {
    final store = _draftStore;
    final type = _draftType;
    final collect = _draftCollect;
    if (store == null || type == null || collect == null) return;
    _draftDebounce?.cancel();
    await store.save(type, collect());
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
    final canSaveDraft =
        _draftStore != null && _draftType != null && _draftCollect != null;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(canSaveDraft ? '保存草稿并离开？' : '放弃未保存的修改？'),
        content: Text(
          canSaveDraft
              ? '当前页面有未保存的修改。离开前会保存为${_draftNoun ?? '表单'}草稿，并覆盖当前作用域已有草稿。'
              : '当前页面有未保存的修改，离开后将丢失。确定要离开吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('继续编辑'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(canSaveDraft ? '保存草稿并离开' : '放弃修改'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      if (canSaveDraft) {
        await saveDraftNow();
        if (!mounted) return;
      }
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
