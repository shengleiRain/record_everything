import 'package:flutter/material.dart';

/// A [FilledButton] that shows a loading indicator and disables itself
/// while a save action is in flight.
///
/// Used together with [FormSaveMixin] to give every form a consistent
/// "saving" affordance: the button cannot be tapped twice and the user
/// gets immediate visual feedback while the async work runs.
class SavingButton extends StatelessWidget {
  const SavingButton({
    super.key,
    required this.onPressed,
    required this.isSaving,
    this.label = '保存',
    this.savingLabel,
    this.autofocus = false,
  });

  /// Invoked when the button is tapped. [FormSaveMixin.runSave] wraps the
  /// real work, so this usually just calls `() => _save()`.
  final VoidCallback onPressed;

  /// Whether the surrounding form is currently saving. While true the button
  /// is disabled and shows a spinner in place of [label].
  final bool isSaving;

  /// Button label in the idle state.
  final String label;

  /// Optional label shown while saving. When null, only the spinner is shown.
  final String? savingLabel;

  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      autofocus: autofocus,
      onPressed: isSaving ? null : onPressed,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SizeTransition(
              sizeFactor: animation,
              axisAlignment: 0,
              child: child,
            ),
          );
        },
        child: isSaving
            ? Row(
                key: const ValueKey('saving-button-indicator'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  if (savingLabel != null) ...[
                    const SizedBox(width: 8),
                    Text(savingLabel!),
                  ],
                ],
              )
            : Text(
                label,
                key: ValueKey('saving-button-label-$label'),
              ),
      ),
    );
  }
}
