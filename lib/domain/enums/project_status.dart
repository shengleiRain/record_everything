enum ProjectStatus {
  planned('planned', '计划中'),
  active('active', '进行中'),
  waiting('waiting', '等待中'),
  completed('completed', '已完成'),
  cancelled('cancelled', '已取消'),
  archived('archived', '已归档');

  const ProjectStatus(this.value, this.label);
  final String value;
  final String label;

  static ProjectStatus fromString(String v) => ProjectStatus.values.firstWhere(
    (e) => e.value == v,
    orElse: () => ProjectStatus.planned,
  );
}
