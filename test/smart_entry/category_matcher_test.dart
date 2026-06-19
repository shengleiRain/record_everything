import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:record_everything/data/database/app_database.dart';
import 'package:record_everything/data/repositories/category_repository.dart';
import 'package:record_everything/features/smart_entry/models/draft_item.dart';
import 'package:record_everything/features/smart_entry/services/category_matcher.dart';

void main() {
  late AppDatabase db;
  late CategoryMatcher matcher;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    // 内存库首次查询触发 onCreate，播种默认分类（含餐饮/交通等 expense、工资等 income）。
    await db.categoryDao.getAll();
    // 补充一个自定义 expense 分类用于稳定测试。
    await CategoryRepository(db).create(name: '咖啡', type: 'expense', icon: 'coffee');
    matcher = CategoryMatcher(db.categoryDao);
  });

  tearDown(() async => db.close());

  test('按文本精确匹配默认 expense 分类（餐饮）', () async {
    final id = await matcher.matchId('餐饮', DraftKind.bill, DraftAmountType.expense);
    expect(id, isNotNull);
  });

  test('匹配自定义 expense 分类（咖啡）', () async {
    final id = await matcher.matchId('咖啡', DraftKind.bill, DraftAmountType.expense);
    expect(id, isNotNull);
  });

  test('不匹配返回 null', () async {
    final id = await matcher.matchId('不存在的分类XYZ', DraftKind.bill, DraftAmountType.expense);
    expect(id, isNull);
  });

  test('收入类型只在 income 分类里找', () async {
    await CategoryRepository(db).create(name: '兼职', type: 'income', icon: 'wallet');
    final id = await matcher.matchId('兼职', DraftKind.bill, DraftAmountType.income);
    expect(id, isNotNull);
    final id2 = await matcher.matchId('咖啡', DraftKind.bill, DraftAmountType.income);
    expect(id2, isNull); // “咖啡”是 expense，不应在 income 里命中
  });
}
