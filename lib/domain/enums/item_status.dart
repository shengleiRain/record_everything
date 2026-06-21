/// 事项状态。
///
/// 流转：
///   pending → completed（完成）
///   pending → cancelled（取消）
///   completed / cancelled → pending（重新打开）
///   archived 为终态。
///
/// i18n：标签通过 [l10nKey] 在显示层翻译。spec §5.1。
enum ItemStatus {
  pending('pending'),
  completed('completed'),
  cancelled('cancelled'),
  archived('archived');

  const ItemStatus(this.value);
  final String value;

  String get l10nKey => 'enum_itemStatus_$value';

  static ItemStatus fromString(String v) => ItemStatus.values.firstWhere(
    (e) => e.value == v,
    orElse: () => ItemStatus.pending,
  );

  /// 是否为终态：终态事项在编辑页整页只读，状态只能通过「重新打开」回退。
  bool get isFinal =>
      this == ItemStatus.completed ||
      this == ItemStatus.cancelled ||
      this == ItemStatus.archived;

  bool canTransitionTo(ItemStatus next) {
    if (this == next) return false;
    return switch (this) {
      ItemStatus.pending =>
        next == ItemStatus.completed || next == ItemStatus.cancelled,
      ItemStatus.completed ||
      ItemStatus.cancelled => next == ItemStatus.pending,
      ItemStatus.archived => false,
    };
  }
}
