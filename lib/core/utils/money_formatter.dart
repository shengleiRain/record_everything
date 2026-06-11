class MoneyFormatter {
  static String format(int? cents) {
    if (cents == null) return '¥0.00';
    final prefix = cents < 0 ? '-¥' : '¥';
    final abs = cents.abs();
    final yuan = abs ~/ 100;
    final fen = abs % 100;
    return '$prefix$yuan.${fen.toString().padLeft(2, '0')}';
  }

  static int? parse(String s) {
    s = s.replaceAll(RegExp(r'[^\d.-]'), '');
    final d = double.tryParse(s);
    if (d == null) return null;
    return (d * 100).round();
  }

  static String formatIncome(int cents) => '+${format(cents)}';

  static String formatExpense(int cents) => '-${format(cents.abs())}';

  static String formatInt(int cents) => format(cents);
}
