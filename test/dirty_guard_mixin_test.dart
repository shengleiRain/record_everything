import 'package:record_everything/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record_everything/core/utils/form_draft_store.dart';
import 'package:record_everything/shared/widgets/dirty_guard_mixin.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Minimal host exercising [DirtyGuardMixin] inside a real [Navigator], so we
/// can assert that confirming "放弃修改" actually pops the route instead of
/// leaving the page stuck (regression for the canPop/maybePop deadlock).
class _GuardedPage extends StatefulWidget {
  const _GuardedPage();

  @override
  State<_GuardedPage> createState() => _GuardedPageState();
}

class _GuardedPageState extends State<_GuardedPage>
    with DirtyGuardMixin<_GuardedPage> {
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !isDirty,
      onPopInvokedWithResult: (didPop, _) => onPopInvoked(didPop),
      child: Scaffold(
        body: Center(
          child: TextButton(
            onPressed: markDirty,
            child: const Text('make dirty'),
          ),
        ),
      ),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const _GuardedPage())),
          child: const Text('open'),
        ),
      ),
    ),
  );
}

/// Host that wires a real [FormDraftStore] into the mixin, so we can exercise
/// the debounce-persist / restore / clear flow.
class _DraftPage extends StatefulWidget {
  const _DraftPage({required this.store});

  final FormDraftStore store;

  @override
  State<_DraftPage> createState() => _DraftPageState();
}

class _DraftPageState extends State<_DraftPage>
    with DirtyGuardMixin<_DraftPage> {
  String _value = '';

  @override
  void initState() {
    super.initState();
    attachDraft(widget.store, 'thing', collect: _collect);
  }

  void _change(String v) {
    setState(() => _value = v);
    markDirtyAndPersist(_collect);
  }

  Map<String, dynamic> _collect() => {'value': _value};

  void _apply(Map<String, dynamic> draft) {
    setState(() => _value = draft['value'] as String? ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !isDirty,
      onPopInvokedWithResult: (didPop, _) => onPopInvoked(didPop),
      child: Scaffold(
        body: Column(
          children: [
            Text('value: $_value'),
            TextButton(
              onPressed: () => _change('hello'),
              child: const Text('type'),
            ),
            TextButton(onPressed: clearDraft, child: const Text('clear')),
            TextButton(
              onPressed: () => maybeRestoreDraft(_apply, noun: '事项'),
              child: const Text('restore'),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _wrapDraft(_DraftPage page) => MaterialApp(theme: AppTheme.lightTheme(), home: page);

class _DraftRoot extends StatelessWidget {
  const _DraftRoot({required this.store});

  final FormDraftStore store;

  @override
  Widget build(BuildContext context) => MaterialApp(
        theme: AppTheme.lightTheme(),
        home: Scaffold(
      body: Center(
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => _DraftPage(store: store))),
            child: const Text('open draft'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('confirming discard clears dirty and pops the route', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme(), home: _Root()));

    // Push the guarded page so there's a real route to pop.
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(_GuardedPage), findsOneWidget);

    final state = tester.state(find.byType(_GuardedPage)) as _GuardedPageState;

    // Mark the form dirty so the back gesture is guarded.
    await tester.tap(find.text('make dirty'));
    await tester.pump();
    expect(state.isDirty, isTrue);

    // System back while dirty: PopScope blocks the pop (didPop == false) and
    // the guard shows the confirmation dialog.
    await tester.state<NavigatorState>(find.byType(Navigator).first).maybePop();
    await tester.pumpAndSettle();

    expect(find.text('放弃未保存的修改？'), findsOneWidget);

    // Confirm discard.
    await tester.tap(find.text('放弃修改'));
    await tester.pumpAndSettle();

    // The dialog must be dismissed and the page must actually be gone.
    expect(find.text('放弃未保存的修改？'), findsNothing);
    expect(
      find.byType(_GuardedPage),
      findsNothing,
      reason: '确认放弃后必须真正退出当前页，否则用户被卡死',
    );
    // We should be back at the root.
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('markDirtyAndPersist debounces and persists after 500ms', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = FormDraftStore();
    await tester.pumpWidget(_wrapDraft(_DraftPage(store: store)));

    // Typing schedules a debounce; before it fires there is no draft.
    await tester.tap(find.text('type'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(await store.load('thing'), isNull);

    // After the debounce window the draft is on disk.
    await tester.pump(const Duration(milliseconds: 500));
    final draft = await store.load('thing');
    expect(draft, isNotNull);
    expect(draft!['value'], 'hello');
  });

  testWidgets('maybeRestoreDraft restores when a fresh draft exists', (
    tester,
  ) async {
    // Pre-seed a draft.
    SharedPreferences.setMockInitialValues({});
    final store = FormDraftStore();
    await store.save('thing', {'value': 'persisted'});

    await tester.pumpWidget(_wrapDraft(_DraftPage(store: store)));

    // Trigger restore; the dialog appears.
    await tester.tap(find.text('restore'));
    await tester.pumpAndSettle();
    expect(find.text('恢复事项草稿？'), findsOneWidget);

    // Confirm restore -> the field value is applied.
    await tester.tap(find.text('恢复草稿'));
    await tester.pumpAndSettle();
    expect(find.text('value: persisted'), findsOneWidget);
  });

  testWidgets('maybeRestoreDraft discarding clears the draft', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = FormDraftStore();
    await store.save('thing', {'value': 'persisted'});

    await tester.pumpWidget(_wrapDraft(_DraftPage(store: store)));

    await tester.tap(find.text('restore'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('不恢复并删除草稿'));
    await tester.pumpAndSettle();

    // Discard cleared the stored draft.
    expect(await store.load('thing'), isNull);
    // And did not apply anything.
    expect(find.text('value: persisted'), findsNothing);
  });

  testWidgets('clearDraft removes the persisted draft after save', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = FormDraftStore();

    await tester.pumpWidget(_wrapDraft(_DraftPage(store: store)));

    // Type and let the debounce persist.
    await tester.tap(find.text('type'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(await store.load('thing'), isNotNull);

    // Clearing (as after a successful save) wipes it.
    await tester.tap(find.text('clear'));
    await tester.pump();
    expect(await store.load('thing'), isNull);
  });

  testWidgets(
    'confirming exit saves the latest draft immediately before the debounce fires',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final store = FormDraftStore();
      await tester.pumpWidget(_DraftRoot(store: store));

      await tester.tap(find.text('open draft'));
      await tester.pumpAndSettle();
      expect(find.byType(_DraftPage), findsOneWidget);

      await tester.tap(find.text('type'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(await store.load('thing'), isNull);

      await tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .maybePop();
      await tester.pumpAndSettle();

      expect(find.text('保存草稿并离开？'), findsOneWidget);
      await tester.tap(find.text('保存草稿并离开'));
      await tester.pumpAndSettle();

      final draft = await store.load('thing');
      expect(draft, isNotNull);
      expect(draft!['value'], 'hello');
      expect(find.byType(_DraftPage), findsNothing);
    },
  );
}
