/// i18n：标签通过 [l10nKey] 在显示层翻译。spec §5.1。
enum ProjectEventType {
  note('note'),
  statusChange('status_change'),
  communication('communication'),
  milestone('milestone'),
  delivery('delivery'),
  other('other');

  const ProjectEventType(this.value);
  final String value;

  String get l10nKey => 'enum_projectEventType_$value';

  static ProjectEventType fromString(String v) =>
      ProjectEventType.values.firstWhere(
        (e) => e.value == v,
        orElse: () => ProjectEventType.note,
      );
}
