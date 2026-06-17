/// Project-local custom_lint plugin that guards against disposable Flutter
/// resources (TextEditingController, ScrollController, FocusNode, ...) being
/// created as locals inside functions or methods.
///
/// Enable it in `analysis_options.yaml` with:
///
/// ```yaml
/// custom_lint:
///   plugins:
///     - disposable_resource_lint
/// ```
///
/// Then run `dart run custom_lint` (or `flutter analyze` once custom_lint is
/// wired into the analysis server).
library;

import 'package:custom_lint_builder/custom_lint_builder.dart';

import 'src/avoid_local_disposable_in_function.dart';

/// Entrypoint discovered by custom_lint.
PluginBase createPlugin() => _DisposableResourceLintPlugin();

class _DisposableResourceLintPlugin extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) => [
        const AvoidLocalDisposableInFunction(),
      ];
}
