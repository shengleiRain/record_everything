import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:record_everything/core/utils/form_draft_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FormDraftStore store;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = FormDraftStore();
  });

  test('builds stable new and edit draft keys', () {
    expect(FormDraftStore.newDraftKey('bill'), 'bill:new');
    expect(FormDraftStore.editDraftKey('project', 42), 'project:edit:42');
  });

  test('save then load returns the draft stamped with _savedAt', () async {
    await store.save('bill', {'title': '咖啡', 'amount': '12.50'});
    final draft = await store.load('bill');
    expect(draft, isNotNull);
    expect(draft!['title'], '咖啡');
    expect(draft['amount'], '12.50');
    expect(draft.containsKey('_savedAt'), isTrue);
    expect(store.hasFreshDraft('bill'), isTrue);
  });

  test('load returns null when no draft exists', () async {
    expect(await store.load('bill'), isNull);
    expect(store.hasFreshDraft('bill'), isFalse);
  });

  test('clear removes the draft', () async {
    await store.save('bill', {'title': 'x'});
    await store.clear('bill');
    expect(await store.load('bill'), isNull);
  });

  test('old draft remains available until explicitly cleared', () async {
    SharedPreferences.setMockInitialValues({
      'form_draft.bill': jsonEncode({
        'title': 'old',
        '_savedAt': DateTime(2020).toIso8601String(),
      }),
    });
    final oldStore = FormDraftStore();

    final draft = await oldStore.load('bill');

    expect(draft, isNotNull);
    expect(draft!['title'], 'old');
    expect(oldStore.hasFreshDraft('bill'), isTrue);
  });

  test('drafts are independent per formType', () async {
    await store.save('bill', {'title': 'b'});
    await store.save('project', {'title': 'p'});
    expect((await store.load('bill'))!['title'], 'b');
    expect((await store.load('project'))!['title'], 'p');
  });
}
