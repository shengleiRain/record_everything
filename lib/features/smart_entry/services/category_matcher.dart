import '../../../data/database/daos/category_dao.dart';
import '../models/draft_item.dart';

/// 把 categoryGuess 文本匹配到本地分类表 id。
/// 按 draft 的 kind/amountType 决定查 expense/income/item 分类。spec §5.4。
class CategoryMatcher {
  CategoryMatcher(this._dao);

  final CategoryDao _dao;

  Future<int?> matchId(
    String? guess,
    DraftKind kind,
    DraftAmountType amountType,
  ) async {
    if (guess == null || guess.trim().isEmpty) return null;
    final type = _typeFor(kind, amountType);
    final list = type == null ? await _dao.getAll() : await _dao.getByType(type);
    for (final c in list) {
      if (c.name == guess) return c.id;
    }
    return null;
  }

  /// 按 kind/amountType 决定查哪个分类类型。
  /// 账单按支出/收入；事项按金额类型走 expense/income，无金额的事项用 'item'。
  String? _typeFor(DraftKind kind, DraftAmountType amountType) {
    if (kind == DraftKind.bill) {
      return amountType == DraftAmountType.income ? 'income' : 'expense';
    }
    switch (amountType) {
      case DraftAmountType.income:
        return 'income';
      case DraftAmountType.expense:
        return 'expense';
      case DraftAmountType.none:
        return 'item'; // 无金额事项（如"开会"）用 item 分类
    }
  }
}
