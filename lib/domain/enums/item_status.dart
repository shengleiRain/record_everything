/// 事项状态。
///
/// 流转：
///   pending → completed（完成）
///   pending → cancelled（取消）
///   completed / cancelled → pending（重新打开）
///   archived 为终态。
enum ItemStatus {
  pending('pending', '待处理'),
  completed('completed', '已完成'),
  cancelled('cancelled', '已取消'),
  archived('archived', '已归档');

  const ItemStatus(this.value, this.label);
  final String value;
  final String label;

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
