import 'package:flutter/material.dart';

import '../utils/date_formatter.dart';

/// A read-only date field that opens a picker on tap and participates in a
/// [Form]'s validation as a [FormField<DateTime>].
///
/// Previously this widget was a plain [StatelessWidget] that only displayed a
/// formatted string and fired `onTap`, which meant date validation (e.g.
/// "please pick a key date") had to be done with an ad-hoc SnackBar alongside
/// `_formKey.validate()`. By being a [FormField], the same `_formKey` now
/// covers date fields: a [validator] failure turns the field red.
///
/// The pick interaction is delegated to [onPick] (typically a `showDatePicker`
/// call), which returns the chosen date (or null if cancelled). This widget
/// owns the [FormField] state and calls `didChange` with the result.
class DateField extends StatefulWidget {
  const DateField({
    super.key,
    required this.label,
    this.initialValue,
    required this.onPick,
    this.validator,
    this.emptyHint = '未设置',
    this.suffixIcon = Icons.calendar_today,
    this.enabled = true,
    this.formatter,
  });

  final String label;

  /// Initial date shown before the user interacts.
  ///
  /// Before the user picks a date, this value is reactive: a parent that
  /// rebuilds with a different value (e.g. after an async DB load completes)
  /// will see it reflected in the field. Once the user picks a date the field
  /// owns its value, like any [FormField], and subsequent parent changes are
  /// ignored — to reset programmatically, bump the [key].
  final DateTime? initialValue;

  /// Opens the date picker and returns the chosen date, or null if cancelled.
  final Future<DateTime?> Function() onPick;

  final FormFieldValidator<DateTime>? validator;

  /// Placeholder text shown when no date is selected.
  final String emptyHint;

  final IconData suffixIcon;

  final bool enabled;

  /// Custom formatter for the selected value. Defaults to [DateFormatter.formatDate]
  /// (a day-precision string). Pass a time formatter (e.g. `HH:mm`) for
  /// time-of-day fields that reuse this widget.
  final String Function(DateTime)? formatter;

  @override
  State<DateField> createState() => _DateFieldState();
}

class _DateFieldState extends State<DateField> {
  late final GlobalKey<FormFieldState<DateTime>> _formFieldKey =
      GlobalKey<FormFieldState<DateTime>>();

  /// Whether the user has interacted with the field (picked a date). Once set
  /// the field owns its value, matching the [FormField] contract, and parent
  /// changes to [DateField.initialValue] are ignored. Before that, an async
  /// load that supplies the real value after the first build must still reach
  /// the field.
  bool _touched = false;

  @override
  void didUpdateWidget(covariant DateField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_touched) return;
    final field = _formFieldKey.currentState;
    if (field == null) return;
    // Reflect an async-loaded value the parent supplies after first build.
    // Only push when it actually differs from what the field currently shows
    // (avoids resetting validation state on no-op rebuilds).
    final next = widget.initialValue;
    final shouldUpdate = (next != field.value && next != null) ||
        (next == null && field.value != null);
    if (!shouldUpdate) return;
    // didUpdateWidget runs during the build phase, but FormField.didChange
    // marks the Form dirty (setState/markNeedsBuild). Schedule it for after the
    // current frame to avoid "setState called during build". Coalesce rapid
    // rebuilds onto the latest value so only one deferred update lands.
    _pendingValue = next;
    if (_pendingScheduled) return;
    _pendingScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pendingScheduled = false;
      if (!mounted || _touched) return;
      final f = _formFieldKey.currentState;
      if (f == null) return;
      if (f.value != _pendingValue) {
        f.didChange(_pendingValue);
      }
    });
  }

  DateTime? _pendingValue;
  bool _pendingScheduled = false;

  Future<void> _handleTap() async {
    final picked = await widget.onPick();
    if (picked != null && mounted) {
      _touched = true;
      _formFieldKey.currentState?.didChange(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormField<DateTime>(
      key: _formFieldKey,
      initialValue: widget.initialValue,
      validator: widget.validator,
      builder: (field) {
        final date = field.value;
        final isEmpty = date == null;
        final text = isEmpty
            ? widget.emptyHint
            : (widget.formatter?.call(date) ?? DateFormatter.formatDate(date));
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: widget.enabled ? _handleTap : null,
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: widget.label,
              suffixIcon: Icon(widget.suffixIcon),
              errorText: field.errorText,
            ),
            child: Text(
              text,
              style: isEmpty
                  ? Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).hintColor,
                      )
                  : Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        );
      },
    );
  }
}
