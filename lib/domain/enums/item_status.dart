enum ItemStatus {
  pending('pending', '待处理'),
  completed('completed', '已完成'),
  overdue('overdue', '已逾期'),
  cancelled('cancelled', '已取消'),
  archived('archived', '已归档');

  const ItemStatus(this.value, this.label);
  final String value;
  final String label;

  static ItemStatus fromString(String v) =>
      ItemStatus.values.firstWhere((e) => e.value == v, orElse: () => ItemStatus.pending);
}
