enum BillAmountType {
  income('income', '收入'),
  expense('expense', '支出');

  const BillAmountType(this.value, this.label);
  final String value;
  final String label;

  static BillAmountType fromString(String v) =>
      BillAmountType.values.firstWhere((e) => e.value == v, orElse: () => BillAmountType.expense);
}
