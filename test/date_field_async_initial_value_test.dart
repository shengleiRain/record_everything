import 'package:record_everything/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record_everything/core/utils/date_formatter.dart';
import 'package:record_everything/core/widgets/date_field.dart';

void main() {
  // Reproduces the bug where DateField captured its initialValue on first build
  // and never reflected an async-loaded value the parent supplied afterwards.
  //
  // Edit pages call an async DB load that completes *after* the first build,
  // so the DateField is first built with initialValue == null and then the
  // parent rebuilds with the real date. The field must reflect that date,
  // otherwise the saved value is missing on the edit screen.
  //
  // The field is wrapped in a Form (matching the real edit pages) to also guard
  // against a setState-during-build regression: FormField.didChange marks the
  // Form dirty, so the value must be applied after the build frame.
  testWidgets(
    'DateField reflects initialValue supplied after first build (async load)',
    (tester) async {
      await tester.pumpWidget(
        _DateFieldHost(initialValue: null, onPick: () async => null),
      );

      // First build with no date: shows the empty hint.
      expect(find.text('未设置'), findsOneWidget);

      // Parent finishes loading and rebuilds with the real date.
      await tester.pumpWidget(
        _DateFieldHost(
          initialValue: DateTime(2026, 7, 1),
          onPick: () async => null,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // The field must now show the loaded date, not the empty hint.
      expect(find.text('未设置'), findsNothing);
      expect(find.text(DateFormatter.formatDate(DateTime(2026, 7, 1))), findsOneWidget);
    },
  );

  // Once the user picks a date the field owns its value (per the widget's
  // contract). A subsequent parent rebuild that passes the *same* value must
  // not clobber a user's choice, and a different initialValue must not reset
  // an already-touched field.
  testWidgets(
    'DateField keeps a user-picked value across parent rebuilds',
    (tester) async {
      DateTime? picked;
      await tester.pumpWidget(
        _DateFieldHost(
          initialValue: null,
          onPick: () async {
            picked = DateTime(2026, 8, 8);
            return picked;
          },
        ),
      );

      await tester.tap(find.text('未设置'));
      await tester.pump();
      expect(
        find.text(DateFormatter.formatDate(DateTime(2026, 8, 8))),
        findsOneWidget,
      );

      // Parent rebuilds with a different initialValue (e.g. the async load
      // finally resolves to the DB value). The user's pick must win.
      await tester.pumpWidget(
        _DateFieldHost(
          initialValue: DateTime(2026, 7, 1),
          onPick: () async => null,
        ),
      );
      await tester.pump();

      expect(
        find.text(DateFormatter.formatDate(DateTime(2026, 8, 8))),
        findsOneWidget,
      );
      expect(find.text(DateFormatter.formatDate(DateTime(2026, 7, 1))), findsNothing);
    },
  );
}

/// Minimal host that renders a single [DateField] with a configurable
/// [initialValue], mirroring how an edit page rebuilds after an async load.
class _DateFieldHost extends StatelessWidget {
  const _DateFieldHost({required this.initialValue, required this.onPick});

  final DateTime? initialValue;
  final Future<DateTime?> Function() onPick;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        theme: AppTheme.lightTheme(),
        home: Scaffold(
        body: Form(
          child: DateField(
            key: const ValueKey('host-date-field'),
            label: '日期',
            initialValue: initialValue,
            onPick: onPick,
          ),
        ),
      ),
    );
  }
}
