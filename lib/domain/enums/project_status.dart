/// 项目状态。
///
/// 项目一旦创建即处于「进行中」，可在进行中 / 已完成 / 已取消 / 已归档
/// 四个状态间流转。状态机逻辑（终态判定、单向推进、推进按钮文案/图标）
/// 全部集中在本枚举上，作为整个 app 的唯一权威来源，避免在各 UI 入口
/// 重复 switch 导致不一致。
///
/// 状态流转：
///   active → completed（标记完成）
///   active → cancelled（取消项目）
///   completed → archived（归档）
///   cancelled / archived → active（重新激活）
enum ProjectStatus {
  active('active', '进行中'),
  completed('completed', '已完成'),
  cancelled('cancelled', '已取消'),
  archived('archived', '已归档');

  const ProjectStatus(this.value, this.label);
  final String value;
  final String label;

  /// 新建项目的默认状态。
  static ProjectStatus get defaultStatus => ProjectStatus.active;

  /// 从存储字符串解析状态。未知值或已废弃的旧值（'planned'/'waiting'）
  /// 兜底为 [defaultStatus]，兼容旧版本数据库行与旧备份导入。
  static ProjectStatus fromString(String v) {
    switch (v) {
      case 'active':
        return ProjectStatus.active;
      case 'completed':
        return ProjectStatus.completed;
      case 'cancelled':
        return ProjectStatus.cancelled;
      case 'archived':
        return ProjectStatus.archived;
      // 已废弃的旧状态：计划中/等待中，统一归并到「进行中」。
      case 'planned':
      case 'waiting':
        return ProjectStatus.active;
      default:
        return ProjectStatus.defaultStatus;
    }
  }

  /// 是否为终态：终态项目在编辑页中整页只读，状态只能通过详情页的
  /// 「重新激活」等显式动作回退。
  bool get isFinal =>
      this == ProjectStatus.completed ||
      this == ProjectStatus.cancelled ||
      this == ProjectStatus.archived;

  /// 单向推进的下一状态（详情页「推进状态」按钮使用）。终态返回 null，
  /// 表示该按钮不再出现。
  ProjectStatus? get nextStatus => switch (this) {
        ProjectStatus.active => ProjectStatus.completed,
        _ => null,
      };

  /// 推进状态按钮的文案。
  String get advanceLabel => switch (this) {
        ProjectStatus.active => '标记完成',
        _ => '推进状态',
      };
}
