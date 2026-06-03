enum RepeatPeriod {
  daily('daily', '每天', 1),
  weekly('weekly', '每周', 7),
  monthly('monthly', '每月', 30),
  yearly('yearly', '每年', 365),
  custom('custom', '自定义', 0);

  const RepeatPeriod(this.value, this.label, this.defaultDays);
  final String value;
  final String label;
  final int defaultDays;

  static RepeatPeriod fromString(String v) =>
      RepeatPeriod.values.firstWhere((e) => e.value == v, orElse: () => RepeatPeriod.custom);
}
