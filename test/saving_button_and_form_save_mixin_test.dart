import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record_everything/shared/widgets/form_save_mixin.dart';
import 'package:record_everything/shared/widgets/saving_button.dart';

/// A minimal host widget that mixes in [FormSaveMixin] so we can exercise
/// `runSave` in isolation. It must live *under* a MaterialApp so that
/// `ScaffoldMessenger.of(context)` (called by runSave on error) resolves.
class _Host extends StatefulWidget {
  const _Host({required this.action, this.onSuccess});

  final Future<void> Function() action;
  final VoidCallback? onSuccess;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> with FormSaveMixin<_Host> {
  int callCount = 0;

  Future<void> _save() async {
    final ok = await runSave(() async {
      callCount += 1;
      await widget.action();
    });
    if (ok) widget.onSuccess?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SavingButton(
          onPressed: _save,
          isSaving: isSaving,
          label: '保存',
        ),
      ),
    );
  }
}

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  testWidgets(
    'SavingButton shows label when idle and spinner when saving',
    (tester) async {
      final completer = Completer<void>();
      await tester.pumpWidget(_wrap(_Host(action: () => completer.future)));

      // Idle: label visible, no spinner.
      expect(find.text('保存'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // Tap -> saving.
      await tester.tap(find.text('保存'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Complete -> back to idle.
      completer.complete();
      await tester.pumpAndSettle();

      expect(find.text('保存'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets('runSave guards against re-entry while in flight',
      (tester) async {
    final completer = Completer<void>();
    await tester.pumpWidget(_wrap(_Host(action: () => completer.future)));

    await tester.tap(find.text('保存'));
    await tester.pump();

    final state = tester.state(find.byType(_Host)) as _HostState;
    // The action runs exactly once; while saving the button is disabled.
    expect(state.callCount, 1);

    completer.complete();
    await tester.pumpAndSettle();
    expect(state.callCount, 1);
  });

  testWidgets(
      'runSave swallows errors, shows a SnackBar, and returns false '
      '(onSuccess not called)', (tester) async {
    var succeeded = false;

    await tester.pumpWidget(
      _wrap(
        _Host(
          action: () async => throw StateError('boom'),
          onSuccess: () => succeeded = true,
        ),
      ),
    );

    await tester.tap(find.text('保存'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('保存失败'), findsOneWidget);
    expect(succeeded, isFalse);
  });

  testWidgets('runSave returns true and calls onSuccess on success',
      (tester) async {
    var succeeded = false;
    await tester.pumpWidget(
      _wrap(
        _Host(
          action: () async {},
          onSuccess: () => succeeded = true,
        ),
      ),
    );

    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(succeeded, isTrue);
    expect(find.byType(SnackBar), findsNothing);
  });
}
