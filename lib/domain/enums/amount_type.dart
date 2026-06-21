/// i18n：标签通过 [l10nKey] 在显示层翻译。spec §5.1。
enum AmountType {
  none('none'),
  income('income'),
  expense('expense');

  const AmountType(this.value);
  final String value;

  String get l10nKey => 'enum_amountType_$value';

  static AmountType fromString(String v) => AmountType.values.firstWhere(
    (e) => e.value == v,
    orElse: () => AmountType.none,
  );
}
