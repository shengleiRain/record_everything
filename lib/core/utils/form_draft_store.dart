import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persists a single in-progress form draft per form type, so the user doesn't
/// lose work if they leave a "new" form unsaved.
///
/// One draft per [formType] key. New-form keys should use [newDraftKey], while
/// edit-form keys should use [editDraftKey] so each edited instance owns its
/// own recoverable draft.
///
/// Drafts never expire automatically. They remain until the user discards the
/// draft or the form is successfully saved.
class FormDraftStore {
  /// [ttl] is accepted for compatibility with older call sites. Drafts no
  /// longer expire automatically, so the value is ignored.
  FormDraftStore({Duration? ttl});

  static const String _keyPrefix = 'form_draft.';
  static const String _savedAtKey = '_savedAt';

  static String newDraftKey(String formType) => '$formType:new';

  static String editDraftKey(String formType, int id) => '$formType:edit:$id';

  /// Saves [json] as the draft for [formType], stamped with the current time.
  Future<void> save(String formType, Map<String, dynamic> json) async {
    final prefs = await SharedPreferences.getInstance();
    final stamped = Map<String, dynamic>.from(json)
      ..[_savedAtKey] = DateTime.now().toIso8601String();
    await prefs.setString('$_keyPrefix$formType', jsonEncode(stamped));
    _cache[formType] = stamped;
  }

  /// Loads the draft for [formType], or null if none exists or the stored JSON is
  /// malformed. Caches the result for [hasFreshDraft].
  Future<Map<String, dynamic>?> load(String formType) async {
    final cached = _cache[formType];
    if (cached != null) {
      return cached;
    }
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_keyPrefix$formType');
    if (raw == null) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      clear(formType);
      return null;
    }
    final json = Map<String, dynamic>.from(decoded);
    if (json[_savedAtKey] is! String) {
      clear(formType);
      return null;
    }
    _cache[formType] = json;
    return json;
  }

  /// Deletes the draft for [formType]. Call after a successful save.
  Future<void> clear(String formType) async {
    _cache.remove(formType);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_keyPrefix$formType');
  }

  /// In-memory cache so [hasFreshDraft] is synchronous after a [load].
  final Map<String, Map<String, dynamic>> _cache = {};

  /// Synchronous freshness check, valid only after [load] has populated the
  /// cache for [formType]. Returns false otherwise. "Fresh" now means the draft
  /// exists and has not been explicitly cleared.
  bool hasFreshDraft(String formType) {
    final cached = _cache[formType];
    if (cached == null) return false;
    return cached[_savedAtKey] is String;
  }
}
