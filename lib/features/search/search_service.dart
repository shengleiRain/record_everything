import '../../data/database/app_database.dart';

enum SearchResultKind { lifeItem, billRecord, project }

class SearchResult {
  const SearchResult({
    required this.kind,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.date,
    this.projectId,
  });

  final SearchResultKind kind;
  final int id;
  final String title;
  final String subtitle;
  final DateTime date;
  final int? projectId;
}

class SearchService {
  const SearchService._();

  static List<SearchResult> search({
    required String query,
    required List<LifeItem> lifeItems,
    required List<BillRecord> billRecords,
    List<Project> projects = const [],
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
            projectId: item.projectId,
          ),
      for (final bill in billRecords)
        if (_matches([bill.title, bill.note, bill.amountType], normalized))
          SearchResult(
            kind: SearchResultKind.billRecord,
            id: bill.id,
            title: bill.title,
            subtitle: bill.note?.isNotEmpty == true ? bill.note! : '账单',
            date: bill.billTime,
            projectId: bill.projectId,
          ),
      for (final project in projects)
        if (_matches([
          project.title,
          project.participant,
          project.note,
        ], normalized))
          SearchResult(
            kind: SearchResultKind.project,
            id: project.id,
            title: project.title,
            subtitle: project.participant?.isNotEmpty == true
                ? '${project.participant!} · 项目'
                : '项目',
            date: project.startDate ?? project.createdAt,
          ),
    ]..sort((a, b) => b.date.compareTo(a.date));

    return results;
  }

  static bool _matches(List<String?> fields, String query) {
    return fields.any((field) => field?.toLowerCase().contains(query) == true);
  }
}
