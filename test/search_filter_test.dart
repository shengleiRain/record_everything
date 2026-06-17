import 'package:flutter_test/flutter_test.dart';
import 'package:record_everything/data/database/app_database.dart';
import 'package:record_everything/features/search/search_service.dart';

void main() {
  test('search service matches life items and bills by title and note', () {
    final results = SearchService.search(
      query: '咖啡',
      lifeItems: [
        LifeItem(
          id: 1,
          title: '咖啡豆补货',
          description: '下周用',
          categoryId: null,
          amount: null,
          amountType: 'none',
          dueTime: DateTime(2026, 6, 6),
          remindTime: null,
          repeatRule: null,
          status: 'pending',
          createdAt: DateTime(2026, 6, 1),
          updatedAt: DateTime(2026, 6, 1),
        ),
      ],
      billRecords: [
        BillRecord(
          id: 2,
          lifeItemId: null,
          title: '超市',
          categoryId: null,
          amount: 3200,
          amountType: 'expense',
          billTime: DateTime(2026, 6, 6),
          note: '咖啡滤纸',
          createdAt: DateTime(2026, 6, 1),
          updatedAt: DateTime(2026, 6, 1),
        ),
      ],
    );

    expect(results.map((result) => result.title), ['咖啡豆补货', '超市']);
  });
}
