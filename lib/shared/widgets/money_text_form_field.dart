import 'package:flutter/material.dart';

import '../../core/utils/money_formatter.dart';

/// A [FormField] for entering a money amount (stored internally as cents),
/// with consistent formatting and validation across all forms.
///
/// Wraps a [TextField] whose text is parsed via [MoneyFormatter.parse]. The
/// [FormField] value is `null` when empty (or unparseable); pass [isRequired]
/// or a custom [validator] to enforce non-empty.
///
/// The host page owns the [controller] (creating it as a State field and
/// disposing it) so the typed text survives rebuilds; this widget reads from
/// it but the [FormField] value is derived via [MoneyFormatter.parse].
class MoneyTextFormField extends FormField<int> {
  MoneyTextFormField({
    super.key,
    required TextEditingController controller,
    String label = '金额',
    String? hintText,
    bool isRequired = false,
    bool allowNegative = false,
    FormFieldValidator<int>? validator,
    super.enabled,
  }) : super(
          initialValue: MoneyFormatter.parse(controller.text),
          validator: validator ?? (isRequired ? _requiredValidator : null),
          builder: (field) {
            return TextField(
              controller: controller,
              keyboardType: TextInputType.numberWithOptions(
                decimal: true,
                signed: allowNegative,
              ),
              decoration: InputDecoration(
                labelText: isRequired ? '$label *' : label,
                hintText: hintText ?? '0.00',
                prefixText: '¥',
                errorText: field.errorText,
              ),
              onChanged: (text) {
                field.didChange(MoneyFormatter.parse(text));
              },
            );
          },
        );

  static String? _requiredValidator(int? value) =>
      value == null ? '请输入金额' : null;
}
