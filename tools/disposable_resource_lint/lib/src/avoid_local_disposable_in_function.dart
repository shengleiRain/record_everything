// ignore_for_file: public_member_api_docs

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Lint rule that prevents disposable Flutter *widget* resources from being
/// created as locals inside ordinary functions or methods.
///
/// Resources such as [TextEditingController], [ScrollController] and
/// [FocusNode] must be owned by a [State] (created in field initializers or
/// [State.initState], disposed in [State.dispose]). When they are created as
/// locals inside a function, they are typically disposed by hand right after
/// `await showDialog(...)` / `showModalBottomSheet(...)`. Because dialog/sheet
/// dismissal runs an exit transition, the still-attached `TextField` keeps
/// touching the controller after it has been disposed, throwing:
///
///   "A TextEditingController was used after being disposed."
///
/// Allowed creation sites (not flagged):
/// - field initializers (`final _c = TextEditingController();`)
/// - [State.initState] / any method named `initState`
/// - constructor initializer lists (`Foo() : c = TextEditingController();`)
///
/// This mirrors the root-cause analysis in complete_action_sheet and
/// category_management_page, where this exact pattern caused crashes.
class AvoidLocalDisposableInFunction extends DartLintRule {
  const AvoidLocalDisposableInFunction() : super(code: _code);

  /// Lint code emitted by this rule.
  static const LintCode _code = LintCode(
    name: 'avoid_local_disposable_in_function',
    problemMessage: "Do not create disposable resources ('{0}') as locals "
        "inside a function or method. Own them from a State (field "
        "initializer or initState) instead, so their lifecycle is tied to the "
        "widget and not to a dialog/sheet exit animation.",
  );

  /// Simple names of the disposable Flutter *widget* types this rule guards
  /// against. Matched by simple name so it works regardless of import
  /// prefix/alias. StreamController is intentionally excluded: creating one
  /// inside a Riverpod provider (managed via `ref.onDispose`) is a legitimate
  /// pattern and is not the source of the "used after disposed" widget crashes
  /// this rule targets.
  static const _trackedTypes = <String>{
    'TextEditingController',
    'ScrollController',
    'FocusNode',
    'FocusScopeNode',
    'PageController',
    'TabController',
    'AnimationController',
    'TransformationController',
    'TrackingScrollController',
    'FixedExtentScrollController',
  };

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((node) {
      final createdName = _createdTypeName(node.staticType);
      if (createdName == null) return;
      if (!_trackedTypes.contains(createdName)) return;

      // Skip legitimate ownership points.
      if (_isFieldInitializer(node)) return;
      if (_isInInitializerList(node)) return;
      if (_isInInitState(node)) return;

      // Flag anything else that lives inside a function/method/closure body.
      if (_isInsideExecutableBody(node)) {
        reporter.atNode(node, _code, arguments: [createdName]);
      }
    });
  }

  static String? _createdTypeName(DartType? type) {
    if (type == null) return null;
    // `element3` is the non-deprecated accessor for the declared element. It
    // is flagged experimental by the analyzer team, but the deprecated
    // `element` is scheduled for removal; `element3` is what custom_lint /
    // riverpod_lint depend on internally, so we follow suit.
    // ignore: experimental_member_use
    final element = type.element3;
    // displayName yields the simple class name (e.g. `TextEditingController`)
    // regardless of element kind.
    return element?.displayName;
  }

  /// `final _c = TextEditingController();` as a field (member-level variable).
  static bool _isFieldInitializer(InstanceCreationExpression node) {
    return node.thisOrAncestorOfType<FieldDeclaration>() != null &&
        node.thisOrAncestorOfType<MethodDeclaration>() == null &&
        node.thisOrAncestorOfType<FunctionBody>() == null;
  }

  /// `Foo() : c = TextEditingController();` in a constructor initializer list
  /// (ConstructorFieldInitializer). Such objects' lifecycle is managed by the
  /// owning object's own dispose logic (e.g. draft objects), so it's allowed.
  static bool _isInInitializerList(InstanceCreationExpression node) {
    return node
            .thisOrAncestorOfType<ConstructorFieldInitializer>() !=
        null;
  }

  /// Inside a method literally named `initState` (the canonical [State]
  /// creation point).
  static bool _isInInitState(InstanceCreationExpression node) {
    final method = node.thisOrAncestorOfType<MethodDeclaration>();
    return method != null && method.name.lexeme == 'initState';
  }

  /// Returns true if the creation is anywhere inside a function body — a
  /// top-level function, a method, a getter, a constructor *body*, or an
  /// arbitrary closure (e.g. the builder passed to `showDialog`).
  static bool _isInsideExecutableBody(InstanceCreationExpression node) {
    return node.thisOrAncestorOfType<FunctionBody>() != null;
  }
}

/// Pure-AST decision exported for unit testing (no analyzer resolution
/// context required). Returns the name of the tracked type being constructed,
/// or `null` when the creation is at a legitimate ownership point or builds a
/// non-tracked type.
///
/// [createdTypeName] is the simple name of the constructed type (e.g.
/// `TextEditingController`), extracted from the AST's type name. In real
/// analysis this comes from resolved static types; in tests it is passed in
/// directly from the constructor name, which is sufficient for the structural
/// checks this rule performs.
String? classifyCreation({
  required InstanceCreationExpression node,
  required String? createdTypeName,
}) {
  if (createdTypeName == null) return null;
  if (!AvoidLocalDisposableInFunction._trackedTypes.contains(createdTypeName)) {
    return null;
  }
  if (AvoidLocalDisposableInFunction._isFieldInitializer(node)) return null;
  if (AvoidLocalDisposableInFunction._isInInitializerList(node)) return null;
  if (AvoidLocalDisposableInFunction._isInInitState(node)) return null;
  if (AvoidLocalDisposableInFunction._isInsideExecutableBody(node)) {
    return createdTypeName;
  }
  return null;
}
