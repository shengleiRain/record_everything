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

  /// Initial date shown before the user interacts. Changes from the parent
  /// are NOT reactively reflected once the field has been interacted with —
  /// like any [FormField], the field owns its value. To reset programmatically,
  /// bump the [key].
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

  Future<void> _handleTap() async {
    final picked = await widget.onPick();
    if (picked != null && mounted) {
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
