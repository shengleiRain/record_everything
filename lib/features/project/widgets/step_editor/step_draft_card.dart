import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../domain/enums/amount_type.dart';
import '../../../../shared/widgets/app_dropdown_field.dart';
import 'step_draft.dart';

/// A card that edits a single [StepDraft].
///
/// Renders the shared fields common to every step editor — node title,
/// amount type, amount — plus a delete button, and exposes an
/// [extraSlot] builder for the page-specific field (absolute due date on the
/// project page, relative offset days on the template page).
class StepDraftCard<T extends StepDraft> extends StatelessWidget {
  const StepDraftCard({
    super.key,
    required this.draft,
    required this.onChanged,
    this.onDelete,
    required this.amountLabel,
    this.titleFieldKey,
    this.amountFieldKey,
    this.deleteButtonKey,
    this.extraSlot,
  });

  /// The draft being edited.
  final T draft;

  /// Called whenever any field on the card changes (title, amount type,
  /// amount, or anything emitted by [extraSlot]).
  final VoidCallback onChanged;

  /// When non-null, renders a delete affordance in the top-right corner.
  final VoidCallback? onDelete;

  /// Label for the amount field — e.g. `'金额'` on the project page,
  /// `'默认金额'` on the template page.
  final String amountLabel;

  /// Optional stable keys so widget tests can target the title/amount fields.
  /// Use [Key] (not `ValueKey`) so the caller's `const ValueKey<String>(...)`
  /// keeps its generic type — `ValueKey<String>('x')` and `ValueKey<dynamic>('x')`
  /// are not considered equal by [WidgetTester.find.byKey].
  final Key? titleFieldKey;
  final Key? amountFieldKey;
  final Key? deleteButtonKey;

  /// Page-specific field rendered below the shared fields. Receives the draft
  /// so the slot can read/write page-specific state (e.g. due date).
  final Widget Function(T draft)? extraSlot;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 48),
              child: Column(
                children: [
                  TextFormField(
                    key: titleFieldKey,
                    controller: draft.titleController,
                    decoration: const InputDecoration(labelText: '节点标题 *'),
                    onChanged: (_) => onChanged(),
                    validator: (value) =>
                        value == null || value.trim().isEmpty
                        ? '请输入节点标题'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  AppDropdownField<AmountType>(
                    label: '金额类型',
                    value: draft.amountType,
                    options: AmountType.values
                        .map(
                          (type) =>
                              AppDropdownOption(value: type, label: type.label),
                        )
                        .toList(),
                    onSelected: (value) {
                      draft.amountType = value ?? draft.amountType;
                      onChanged();
                    },
                  ),
                  if (draft.amountType != AmountType.none) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      key: amountFieldKey,
                      controller: draft.amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: amountLabel,
                        prefixText: '¥',
                      ),
                    ),
                  ],
                  if (extraSlot != null) ...[
                    const SizedBox(height: 12),
                    extraSlot!(draft),
                  ],
                ],
              ),
            ),
            if (onDelete != null)
              Positioned(
                top: 0,
                right: 0,
                child: SizedBox.square(
                  dimension: 48,
                  child: IconButton(
                    key: deleteButtonKey,
                    tooltip: '删除节点',
                    onPressed: onDelete,
                    icon: const Icon(Icons.close),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
