/// 智能录入解析产出的草稿项。不可变值对象，确认前只存在内存里。
///
/// 设计与现有实体分离（不复用 LifeItem/BillRecord），保持
/// "未落库草稿"与"已落库实体"的清晰边界。详见 spec §4。
library;

import 'package:flutter/foundation.dart';

enum DraftKind { lifeItem, bill }

enum DraftSource { nl, ocr, share, voice }

/// 草稿里的金额类型。账单无 none；事项可为 none（无金额的待办）。
enum DraftAmountType { none, income, expense }

extension DraftAmountTypeX on DraftAmountType {
  String get value => name;
  static DraftAmountType fromString(String v) =>
      DraftAmountType.values.firstWhere(
        (e) => e.value == v,
        orElse: () => DraftAmountType.none,
      );
}

@immutable
class DraftItem {
  final DraftKind kind;
  final String title;
  final int? amountCents;
  final DraftAmountType amountType;
  final DateTime time; // 事项=dueTime，账单=billTime
  final DateTime? remindTime; // 仅事项
  final String? repeatRule; // 仅事项，复用现有 RepeatRule 字符串格式
  final int? categoryId; // 已匹配到本地分类 id；为空时用 categoryGuess
  final String? categoryGuess; // 文本（如"餐饮"），供确认页下拉选择
  final double confidence; // 0.0~1.0
  final List<String> parseNotes;
  final DraftSource source;

  const DraftItem({
    required this.kind,
    required this.title,
    required this.amountCents,
    required this.amountType,
    required this.time,
    this.remindTime,
    this.repeatRule,
    this.categoryId,
    this.categoryGuess,
    required this.confidence,
    this.parseNotes = const [],
    required this.source,
  });

  static const double _lowConfidenceThreshold = 0.6;

  bool get isLowConfidence => confidence < _lowConfidenceThreshold;

  DraftItem copyWith({
    DraftKind? kind,
    String? title,
    Object? amountCents = _sentinel,
    DraftAmountType? amountType,
    DateTime? time,
    Object? remindTime = _sentinel,
    Object? repeatRule = _sentinel,
    Object? categoryId = _sentinel,
    Object? categoryGuess = _sentinel,
    double? confidence,
    List<String>? parseNotes,
    DraftSource? source,
  }) {
    return DraftItem(
      kind: kind ?? this.kind,
      title: title ?? this.title,
      amountCents: amountCents == _sentinel
          ? this.amountCents
          : amountCents as int?,
      amountType: amountType ?? this.amountType,
      time: time ?? this.time,
      remindTime: remindTime == _sentinel
          ? this.remindTime
          : remindTime as DateTime?,
      repeatRule: repeatRule == _sentinel
          ? this.repeatRule
          : repeatRule as String?,
      categoryId: categoryId == _sentinel
          ? this.categoryId
          : categoryId as int?,
      categoryGuess: categoryGuess == _sentinel
          ? this.categoryGuess
          : categoryGuess as String?,
      confidence: confidence ?? this.confidence,
      parseNotes: parseNotes ?? this.parseNotes,
      source: source ?? this.source,
    );
  }

  static const Object _sentinel = Object();
}

@immutable
class EntryDraft {
  final List<DraftItem> items;
  final DraftSource source;
  final String rawInput;
  final String? ocrFullText; // 仅 OCR 来源保留

  const EntryDraft({
    required this.items,
    required this.source,
    required this.rawInput,
    this.ocrFullText,
  });

  factory EntryDraft.empty(DraftSource source, {required String rawInput}) {
    return EntryDraft(
      items: const [],
      source: source,
      rawInput: rawInput,
    );
  }

  bool get isEmpty => items.isEmpty;
}
