import 'package:flutter/material.dart';

class AppDropdownOption<T> {
  const AppDropdownOption({required this.value, required this.label});

  final T value;
  final String label;
}

class AppDropdownField<T> extends StatelessWidget {
  const AppDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onSelected,
  });

  final String label;
  final T? value;
  final List<AppDropdownOption<T>> options;
  final ValueChanged<T?> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        return DropdownMenu<T>(
          initialSelection: value,
          expandedInsets: EdgeInsets.zero,
          label: Text(label),
          trailingIcon: const Icon(Icons.keyboard_arrow_down_rounded),
          selectedTrailingIcon: const Icon(Icons.keyboard_arrow_up_rounded),
          inputDecorationTheme: theme.inputDecorationTheme,
          menuStyle: MenuStyle(
            backgroundColor: WidgetStatePropertyAll(colorScheme.surface),
            surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
            shadowColor: WidgetStatePropertyAll(
              Colors.black.withValues(alpha: 0.16),
            ),
            elevation: const WidgetStatePropertyAll(8),
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(vertical: 6),
            ),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.65),
                ),
              ),
            ),
            maximumSize: WidgetStatePropertyAll(
              Size(constraints.maxWidth, 420),
            ),
          ),
          dropdownMenuEntries: options
              .map(
                (option) => DropdownMenuEntry<T>(
                  value: option.value,
                  label: option.label,
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith((states) {
                      if (option.value == value) {
                        return colorScheme.primary.withValues(alpha: 0.10);
                      }
                      if (states.contains(WidgetState.hovered) ||
                          states.contains(WidgetState.focused)) {
                        return colorScheme.primary.withValues(alpha: 0.06);
                      }
                      return Colors.transparent;
                    }),
                    padding: const WidgetStatePropertyAll(
                      EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    foregroundColor: WidgetStatePropertyAll(
                      colorScheme.onSurface,
                    ),
                    overlayColor: WidgetStatePropertyAll(
                      colorScheme.primary.withValues(alpha: 0.08),
                    ),
                    textStyle: WidgetStatePropertyAll(
                      theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: option.value == value
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
          onSelected: onSelected,
        );
      },
    );
  }
}
