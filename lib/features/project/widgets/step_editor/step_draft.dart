import 'package:flutter/material.dart';

import '../../../../domain/enums/amount_type.dart';

/// Common interface for an editable "step" (project node / template node)
/// row inside the step editor.
///
/// The step editor owns a [List] of these drafts and renders them through
/// [StepDraftCard]. Concrete implementations live on each page and add their
/// own page-specific fields — e.g. the project page adds an absolute
/// [DateTime] due date, the template page adds a relative `offsetDays`.
///
/// Implementations must own their [TextEditingController]s and dispose them
/// in [dispose].
abstract base class StepDraft {
  /// Subclasses pass their owned controllers here so the base getters can
  /// expose them uniformly to the step editor widgets.
  StepDraft.internal({
    required this.titleController,
    required this.amountController,
  });

  /// Stable local-only id used for ValueKeys across rebuilds/reorders.
  int get localId;

  final TextEditingController titleController;
  final TextEditingController amountController;

  AmountType get amountType;
  set amountType(AmountType value);

  /// Trimmed title text (may be empty).
  String get title => titleController.text.trim();

  /// Parsed amount in cents, or `null` when empty/unparseable.
  int? get amount;

  /// Dispose any controllers/owned resources.
  void dispose();
}

/// Mixin shared by concrete [StepDraft] implementations to provide a
/// monotonically increasing [localId] generator.
mixin StepDraftIdGenerator {
  static int _counter = 0;

  static int nextId() => _counter++;
}
