import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record_everything/data/database/app_database.dart';
import 'package:record_everything/data/repositories/category_repository.dart';
import 'package:record_everything/data/repositories/life_item_repository.dart';

void main() {
  group('CategoryRepository', () {
    late AppDatabase db;
    late CategoryRepository repository;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repository = CategoryRepository(db);
    });

    tearDown(() => db.close());

    test('creates and renames a custom category', () async {
      final created = await repository.create(
        name: '咖啡',
        type: 'expense',
        icon: 'coffee',
      );

      expect(created.name, '咖啡');
      expect(created.type, 'expense');
      expect(created.icon, 'coffee');
      expect(created.isDefault, isFalse);

      final renamed = await repository.updateCategory(
        created.copyWith(name: '咖啡豆', icon: 'local_cafe'),
      );

      expect(renamed.name, '咖啡豆');
      expect(renamed.icon, 'local_cafe');
    });

    test('hides default categories instead of deleting them', () async {
      final defaults = await repository.getByType('expense');
      final defaultCategory = defaults.firstWhere(
        (category) => category.isDefault,
      );

      await repository.deleteCategory(defaultCategory.id);

      final hidden = await db.categoryDao.getById(defaultCategory.id);
      final visible = await repository.getByType('expense');

      expect(hidden.isHidden, isTrue);
      expect(
        visible.any((category) => category.id == defaultCategory.id),
        isFalse,
      );
    });

    test('prevents deleting categories used by life items', () async {
      final category = await repository.create(
        name: '证件',
        type: 'item',
        icon: 'badge',
      );
      await LifeItemRepository(db).create(
        title: '护照到期',
        categoryId: category.id,
        dueTime: DateTime(2026, 6, 6),
      );

      expect(
        () => repository.deleteCategory(category.id),
        throwsA(
          isA<CategoryDeleteException>().having(
            (error) => error.reason,
            'reason',
            CategoryDeleteReason.inUse,
          ),
        ),
      );
    });

    test('pins recent categories before lower priority categories', () async {
      final first = await repository.create(
        name: '低频',
        type: 'item',
        icon: 'category',
      );
      final pinned = await repository.create(
        name: '常用',
        type: 'item',
        icon: 'category',
      );

      await repository.setPinned(pinned.id, true);
      await LifeItemRepository(db).create(
        title: '低频事项',
        categoryId: first.id,
        dueTime: DateTime(2026, 6, 6),
      );

      final rows = await repository.getByType('item');
      expect(rows.first.id, pinned.id);
    });

    test('merges category references and hides the source category', () async {
      final source = await repository.create(
        name: '低频分类',
        type: 'item',
        icon: 'category',
      );
      final target = await repository.create(
        name: '目标分类',
        type: 'item',
        icon: 'category',
      );
      final item = await LifeItemRepository(db).create(
        title: '护照到期',
        categoryId: source.id,
        dueTime: DateTime(2026, 6, 6),
      );

      await repository.mergeCategory(sourceId: source.id, targetId: target.id);

      final updatedItem = await db.lifeItemDao.getById(item.id);
      final updatedSource = await db.categoryDao.getById(source.id);

      expect(updatedItem.categoryId, target.id);
      expect(updatedSource.isHidden, isTrue);
    });
  });
}
