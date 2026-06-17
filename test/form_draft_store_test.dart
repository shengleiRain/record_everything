import 'package:flutter_test/flutter_test.dart';
import 'package:record_everything/core/utils/form_draft_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FormDraftStore store;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = FormDraftStore(ttl: const Duration(hours: 24));
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

  test('expired draft is treated as missing and cleaned up', () async {
    final expiredStore = FormDraftStore(ttl: const Duration(milliseconds: 1));
    await expiredStore.save('bill', {'title': 'old'});
    // Wait past the TTL.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(await expiredStore.load('bill'), isNull);
    expect(expiredStore.hasFreshDraft('bill'), isFalse);
  });

  test('drafts are independent per formType', () async {
    await store.save('bill', {'title': 'b'});
    await store.save('project', {'title': 'p'});
    expect((await store.load('bill'))!['title'], 'b');
    expect((await store.load('project'))!['title'], 'p');
  });
}
