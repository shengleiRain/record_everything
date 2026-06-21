/// i18n：标签通过 [l10nKey] 在显示层翻译。spec §5.1。
enum BillAmountType {
  income('income'),
  expense('expense');

  const BillAmountType(this.value);
  final String value;

  String get l10nKey => 'enum_billAmountType_$value';

  static BillAmountType fromString(String v) => BillAmountType.values
      .firstWhere((e) => e.value == v, orElse: () => BillAmountType.expense);
}
