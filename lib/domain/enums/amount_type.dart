enum AmountType {
  none('none', '无金额'),
  income('income', '收入'),
  expense('expense', '支出');

  const AmountType(this.value, this.label);
  final String value;
  final String label;

  static AmountType fromString(String v) => AmountType.values.firstWhere(
    (e) => e.value == v,
    orElse: () => AmountType.none,
  );
}
