enum ProjectEventType {
  note('note', '备注'),
  statusChange('status_change', '状态变更'),
  communication('communication', '沟通记录'),
  milestone('milestone', '里程碑'),
  delivery('delivery', '交付记录'),
  other('other', '其他');

  const ProjectEventType(this.value, this.label);
  final String value;
  final String label;

  static ProjectEventType fromString(String v) =>
      ProjectEventType.values.firstWhere(
        (e) => e.value == v,
        orElse: () => ProjectEventType.note,
      );
}
