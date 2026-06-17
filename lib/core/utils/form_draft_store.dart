import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persists a single in-progress form draft per form type, so the user doesn't
/// lose work if they leave a "new" form unsaved.
///
/// One draft per [formType] (e.g. 'project', 'template', 'life_item', 'bill').
/// Drafts auto-expire after [ttl] (24h). Only "new" forms read/write drafts —
/// edit forms load their data from the database, so they don't touch this.
///
/// The store is async (SharedPreferences has no sync API). Call [hasFreshDraft]
/// after a [load] to get the cached freshness check without awaiting.
class FormDraftStore {
  FormDraftStore({this.ttl = const Duration(hours: 24)});

  static const String _keyPrefix = 'form_draft.';
  static const String _savedAtKey = '_savedAt';

  final Duration ttl;

  /// Saves [json] as the draft for [formType], stamped with the current time.
  Future<void> save(String formType, Map<String, dynamic> json) async {
    final prefs = await SharedPreferences.getInstance();
    final stamped = Map<String, dynamic>.from(json)
      ..[_savedAtKey] = DateTime.now().toIso8601String();
    await prefs.setString('$_keyPrefix$formType', jsonEncode(stamped));
    _cache[formType] = stamped;
  }

  /// Loads the draft for [formType], or null if none exists or it has expired
  /// (expired drafts are deleted). Caches the result for [hasFreshDraft].
  Future<Map<String, dynamic>?> load(String formType) async {
    final cached = _cache[formType];
    if (cached != null) {
      return _freshOrClean(formType, cached);
    }
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_keyPrefix$formType');
    if (raw == null) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return null;
    _cache[formType] = decoded;
    return _freshOrClean(formType, decoded);
  }

  Map<String, dynamic>? _freshOrClean(
    String formType,
    Map<String, dynamic> json,
  ) {
    final savedAtStr = json[_savedAtKey];
    if (savedAtStr is! String) {
      clear(formType);
      return null;
    }
    final savedAt = DateTime.tryParse(savedAtStr);
    if (savedAt == null || DateTime.now().difference(savedAt) > ttl) {
      clear(formType);
      return null;
    }
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
  /// cache for [formType]. Returns false otherwise.
  bool hasFreshDraft(String formType) {
    final cached = _cache[formType];
    if (cached == null) return false;
    final savedAtStr = cached[_savedAtKey];
    if (savedAtStr is! String) return false;
    final savedAt = DateTime.tryParse(savedAtStr);
    return savedAt != null && DateTime.now().difference(savedAt) <= ttl;
  }
}
