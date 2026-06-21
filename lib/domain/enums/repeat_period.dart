/// i18n：标签通过 [l10nKey] 在显示层翻译。spec §5.1。
/// defaultDays 与 label 无关，保留为构造参数。
enum RepeatPeriod {
  daily('daily', 1),
  weekly('weekly', 7),
  monthly('monthly', 30),
  yearly('yearly', 365),
  custom('custom', 0);

  const RepeatPeriod(this.value, this.defaultDays);
  final String value;
  final int defaultDays;

  String get l10nKey => 'enum_repeatPeriod_$value';

  static RepeatPeriod fromString(String v) => RepeatPeriod.values.firstWhere(
    (e) => e.value == v,
    orElse: () => RepeatPeriod.custom,
  );
}
