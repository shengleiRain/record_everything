import '../../data/database/app_database.dart';

enum SearchResultKind { lifeItem, billRecord }

class SearchResult {
  const SearchResult({
    required this.kind,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.date,
  });

  final SearchResultKind kind;
  final int id;
  final String title;
  final String subtitle;
  final DateTime date;
}

class SearchService {
  const SearchService._();

  static List<SearchResult> search({
    required String query,
    required List<LifeItem> lifeItems,
    required List<BillRecord> billRecords,
  }) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return const [];

    final results = <SearchResult>[
      for (final item in lifeItems)
        if (_matches([item.title, item.description, item.itemType], normalized))
          SearchResult(
            kind: SearchResultKind.lifeItem,
            id: item.id,
            title: item.title,
            subtitle: item.description?.isNotEmpty == true
                ? item.description!
                : '事项',
            date: item.dueTime,
          ),
      for (final bill in billRecords)
        if (_matches([bill.title, bill.note, bill.amountType], normalized))
          SearchResult(
            kind: SearchResultKind.billRecord,
            id: bill.id,
            title: bill.title,
            subtitle: bill.note?.isNotEmpty == true ? bill.note! : '账单',
            date: bill.billTime,
          ),
    ]..sort((a, b) => b.date.compareTo(a.date));

    return results;
  }

  static bool _matches(List<String?> fields, String query) {
    return fields.any((field) => field?.toLowerCase().contains(query) == true);
  }
}
