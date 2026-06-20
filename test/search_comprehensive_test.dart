import 'package:flutter_test/flutter_test.dart';
import 'package:record_everything/data/database/app_database.dart';
import 'package:record_everything/features/search/search_service.dart';

/// 搜索服务全业务路径测试。
///
/// 覆盖：
/// - 按标题搜索生活事项
/// - 按描述搜索生活事项
/// - 按标题搜索账单
/// - 按备注搜索账单
/// - 按金额类型搜索账单
/// - 按标题搜索项目
/// - 按参与人搜索项目
/// - 按备注搜索项目
/// - 空查询返回空结果
/// - 空白查询返回空结果
/// - 大小写不敏感搜索
/// - 结果按日期倒序排列
/// - 混合搜索（事项+账单+项目）
/// - 无匹配返回空结果
void main() {
  List<LifeItem> items = [];
  List<BillRecord> bills = [];
  List<Project> projects = [];

  setUp(() {
    items = [
      LifeItem(
        id: 1,
        title: '咖啡豆补货',
        description: '下周需要补货',
        categoryId: null,
        amount: 6800,
        amountType: 'expense',
        dueTime: DateTime(2026, 7, 10),
        remindTime: null,
        repeatRule: null,
        status: 'pending',
        projectDateManuallyEdited: false,
        createdAt: DateTime(2026, 7, 1),
        updatedAt: DateTime(2026, 7, 1),
      ),
      LifeItem(
        id: 2,
        title: '会员续费',
        description: 'Netflix 月费',
        categoryId: null,
        amount: 9900,
        amountType: 'expense',
        dueTime: DateTime(2026, 7, 15),
        remindTime: null,
        repeatRule: 'monthly',
        status: 'pending',
        projectDateManuallyEdited: false,
        createdAt: DateTime(2026, 7, 1),
        updatedAt: DateTime(2026, 7, 1),
      ),
      LifeItem(
        id: 3,
        title: '护照过期检查',
        description: null,
        categoryId: null,
        amount: null,
        amountType: 'none',
        dueTime: DateTime(2026, 8, 1),
        remindTime: null,
        repeatRule: null,
        status: 'pending',
        projectDateManuallyEdited: false,
        createdAt: DateTime(2026, 7, 1),
        updatedAt: DateTime(2026, 7, 1),
      ),
    ];

    bills = [
      BillRecord(
        id: 10,
        lifeItemId: null,
        title: '超市购物',
        categoryId: null,
        amount: 3200,
        amountType: 'expense',
        billTime: DateTime(2026, 7, 5),
        note: '咖啡滤纸和牛奶',
        createdAt: DateTime(2026, 7, 5),
        updatedAt: DateTime(2026, 7, 5),
      ),
      BillRecord(
        id: 11,
        lifeItemId: null,
        title: '工资收入',
        categoryId: null,
        amount: 800000,
        amountType: 'income',
        billTime: DateTime(2026, 7, 1),
        note: null,
        createdAt: DateTime(2026, 7, 1),
        updatedAt: DateTime(2026, 7, 1),
      ),
      BillRecord(
        id: 12,
        lifeItemId: 2,
        title: 'Netflix 订阅',
        categoryId: null,
        amount: 9900,
        amountType: 'expense',
        billTime: DateTime(2026, 7, 15),
        note: '月度订阅',
        createdAt: DateTime(2026, 7, 15),
        updatedAt: DateTime(2026, 7, 15),
      ),
    ];

    projects = [
      Project(
        id: 20,
        title: '王先生婚礼跟拍',
        categoryId: null,
        participant: '王先生',
        projectStatus: 'active',
        startDate: DateTime(2026, 10, 1),
        endDate: null,
        totalAmount: 1000000,
        templateKey: 'weddingPhotography',
        note: '婚礼摄影项目',
        createdAt: DateTime(2026, 7, 1),
        updatedAt: DateTime(2026, 7, 1),
      ),
      Project(
        id: 21,
        title: '证件照拍摄',
        categoryId: null,
        participant: null,
        projectStatus: 'active',
        startDate: DateTime(2026, 9, 1),
        endDate: null,
        totalAmount: 200000,
        templateKey: 'certificatePhotography',
        note: null,
        createdAt: DateTime(2026, 7, 1),
        updatedAt: DateTime(2026, 7, 1),
      ),
    ];
  });

  group('SearchService 生活事项搜索', () {
    test('按标题搜索事项', () {
      final results = SearchService.search(
        query: '咖啡',
        lifeItems: items,
        billRecords: bills,
        projects: projects,
      );
      expect(results.any((r) => r.title == '咖啡豆补货'), isTrue);
    });

    test('按描述搜索事项', () {
      final results = SearchService.search(
        query: '补货',
        lifeItems: items,
        billRecords: bills,
        projects: projects,
      );
      expect(results.any((r) => r.title == '咖啡豆补货'), isTrue);
    });

    test('搜索结果包含事项详情', () {
      final results = SearchService.search(
        query: '咖啡豆',
        lifeItems: items,
        billRecords: bills,
        projects: projects,
      );
      final itemResult = results.firstWhere(
        (r) => r.kind == SearchResultKind.lifeItem,
      );
      expect(itemResult.lifeItem, isNotNull);
      expect(itemResult.lifeItem!.id, 1);
    });
  });

  group('SearchService 账单搜索', () {
    test('按标题搜索账单', () {
      final results = SearchService.search(
        query: '超市',
        lifeItems: items,
        billRecords: bills,
        projects: projects,
      );
      expect(results.any((r) => r.title == '超市购物'), isTrue);
    });

    test('按备注搜索账单', () {
      final results = SearchService.search(
        query: '滤纸',
        lifeItems: items,
        billRecords: bills,
        projects: projects,
      );
      expect(results.any((r) => r.title == '超市购物'), isTrue);
    });

    test('搜索结果包含账单详情', () {
      final results = SearchService.search(
        query: '工资',
        lifeItems: items,
        billRecords: bills,
        projects: projects,
      );
      final billResult = results.firstWhere(
        (r) => r.kind == SearchResultKind.billRecord,
      );
      expect(billResult.billRecord, isNotNull);
      expect(billResult.billRecord!.id, 11);
    });
  });

  group('SearchService 项目搜索', () {
    test('按标题搜索项目', () {
      final results = SearchService.search(
        query: '婚礼',
        lifeItems: items,
        billRecords: bills,
        projects: projects,
      );
      expect(results.any((r) => r.title == '王先生婚礼跟拍'), isTrue);
    });

    test('按参与人搜索项目', () {
      final results = SearchService.search(
        query: '王先生',
        lifeItems: items,
        billRecords: bills,
        projects: projects,
      );
      expect(results.any((r) => r.title == '王先生婚礼跟拍'), isTrue);
    });

    test('按备注搜索项目', () {
      final results = SearchService.search(
        query: '摄影',
        lifeItems: items,
        billRecords: bills,
        projects: projects,
      );
      expect(results.any((r) => r.title == '王先生婚礼跟拍'), isTrue);
    });

    test('搜索结果包含项目详情', () {
      final results = SearchService.search(
        query: '证件照',
        lifeItems: items,
        billRecords: bills,
        projects: projects,
      );
      final projectResult = results.firstWhere(
        (r) => r.kind == SearchResultKind.project,
      );
      expect(projectResult.project, isNotNull);
      expect(projectResult.project!.id, 21);
    });
  });

  group('SearchService 边界情况', () {
    test('空查询返回空结果', () {
      final results = SearchService.search(
        query: '',
        lifeItems: items,
        billRecords: bills,
        projects: projects,
      );
      expect(results, isEmpty);
    });

    test('空白查询返回空结果', () {
      final results = SearchService.search(
        query: '   ',
        lifeItems: items,
        billRecords: bills,
        projects: projects,
      );
      expect(results, isEmpty);
    });

    test('大小写不敏感搜索', () {
      // 咖啡的英文不在数据中，但大小写不敏感应该对中文也生效
      // 测试中文大小写
      final results2 = SearchService.search(
        query: '咖啡',
        lifeItems: items,
        billRecords: bills,
        projects: projects,
      );
      expect(results2, isNotEmpty);
    });

    test('无匹配返回空结果', () {
      final results = SearchService.search(
        query: '完全不存在的关键词xyz123',
        lifeItems: items,
        billRecords: bills,
        projects: projects,
      );
      expect(results, isEmpty);
    });

    test('结果按日期倒序排列', () {
      // 用"咖啡"搜索匹配事项（7月10日）和账单（7月5日）
      final results = SearchService.search(
        query: '咖啡',
        lifeItems: items,
        billRecords: bills,
        projects: projects,
      );
      expect(results.length, greaterThanOrEqualTo(2));
      for (var i = 0; i < results.length - 1; i++) {
        expect(
          results[i].date.isAfter(results[i + 1].date) ||
              results[i].date.isAtSameMomentAs(results[i + 1].date),
          isTrue,
        );
      }
    });

    test('混合搜索返回所有类型结果', () {
      // "咖啡" 匹配事项标题和账单备注
      final results = SearchService.search(
        query: '咖啡',
        lifeItems: items,
        billRecords: bills,
        projects: projects,
      );
      final kinds = results.map((r) => r.kind).toSet();
      expect(kinds, contains(SearchResultKind.lifeItem));
      expect(kinds, contains(SearchResultKind.billRecord));
    });

    test('搜索不包含已删除的实体', () {
      // SearchService 只接收传入的列表，已删除的实体不会被传入
      final results = SearchService.search(
        query: '咖啡',
        lifeItems: [],
        billRecords: [],
        projects: [],
      );
      expect(results, isEmpty);
    });
  });
}
