// Regression tests for the disposable-resource lint.
//
// These prove the rule flags the exact pattern that caused the
// "A TextEditingController was used after being disposed" crash — a
// controller created as a local inside a function body (e.g. right before
// `await showDialog(...)`) — while allowing the legitimate ownership points
// (field initializers, initState, constructor initializer lists).
//
// Note: snippets use an explicit `new` before constructor calls because these
// tests parse without type resolution. Without resolution the parser can't
// tell `Foo()` (constructor) from `foo()` (function call), so we anchor on
// `new` to force an InstanceCreationExpression. In the real analyzer (which
// resolves types) no `new` is needed — as confirmed by `dart run custom_lint`.

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:disposable_resource_lint/src/avoid_local_disposable_in_function.dart';
import 'package:test/test.dart';

void main() {
  test('flags TextEditingController created as a local in a function body',
      () {
    final hits = _findHits(r'''
import 'package:flutter/widgets.dart';
Future<void> showBillDialog() async {
  final amountController = new TextEditingController(text: '1.00');
  final noteController = new TextEditingController();
  await showDialog(builder: (ctx) => new TextField(controller: noteController));
  amountController.dispose();
  noteController.dispose();
}
''');
    expect(hits, hasLength(2));
    expect(hits, containsAll(['TextEditingController', 'TextEditingController']));
  });

  test('flags controller created inside a showDialog builder closure', () {
    final hits = _findHits(r'''
import 'package:flutter/widgets.dart';
void open() {
  showDialog(builder: (ctx) {
    final c = new TextEditingController();
    return new TextField(controller: c);
  });
}
''');
    expect(hits, hasLength(1));
    expect(hits.single, 'TextEditingController');
  });

  test('flags ScrollController and FocusNode locals', () {
    final hits = _findHits(r'''
import 'package:flutter/widgets.dart';
void build() {
  final sc = new ScrollController();
  final fn = new FocusNode();
  print(sc);
  print(fn);
}
''');
    expect(hits, hasLength(2));
    expect(hits, containsAll(['ScrollController', 'FocusNode']));
  });

  test('allows field initializers', () {
    final hits = _findHits(r'''
import 'package:flutter/widgets.dart';
class Foo {
  final _c = new TextEditingController();
  final _s = new ScrollController();
}
''');
    expect(hits, isEmpty);
  });

  test('allows State.initState', () {
    final hits = _findHits(r'''
import 'package:flutter/widgets.dart';
class FooState extends State {
  @override
  void initState() {
    super.initState();
    _c = new TextEditingController();
    _s = new ScrollController();
  }
  late TextEditingController _c;
  late ScrollController _s;
}
''');
    expect(hits, isEmpty);
  });

  test('allows constructor initializer lists (draft-style ownership)', () {
    final hits = _findHits(r'''
import 'package:flutter/widgets.dart';
class Draft {
  Draft(String t)
      : titleController = new TextEditingController(text: t),
        amountController = new TextEditingController(text: '0');
  final TextEditingController titleController;
  final TextEditingController amountController;
}
''');
    expect(hits, isEmpty);
  });

  test('ignores StreamController (provider pattern is legitimate)', () {
    final hits = _findHits(r'''
Stream<int> provider() {
  final controller = StreamController<int>();
  return controller.stream;
}
''');
    expect(hits, isEmpty);
  });

  test('does not flag unrelated locals', () {
    final hits = _findHits(r'''
import 'package:flutter/widgets.dart';
void foo() {
  final controller = 'not a controller';
  final list = <String>[];
  print(controller);
  print(list);
}
''');
    expect(hits, isEmpty);
  });
}

/// Parses [source], runs [classifyCreation] over every
/// `InstanceCreationExpression`, and returns the simple names of the tracked
/// types that the rule flags. The constructed type name is taken from the
/// constructor's type name (the identifier), which is enough for these
/// structural checks.
List<String> _findHits(String source) {
  final result = parseString(content: source, throwIfDiagnostics: false);
  final hits = <String>[];
  result.unit.accept(_Collector(onHit: hits.add));
  return hits;
}

class _Collector extends RecursiveAstVisitor<void> {
  _Collector({required this.onHit});

  final void Function(String) onHit;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final name = node.constructorName.type.name2.lexeme;
    final hit = classifyCreation(node: node, createdTypeName: name);
    if (hit != null) onHit(hit);
    super.visitInstanceCreationExpression(node);
  }
}
