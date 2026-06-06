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

    test('prevents deleting default categories', () async {
      final defaults = await repository.getByType('expense');
      final defaultCategory = defaults.firstWhere(
        (category) => category.isDefault,
      );

      expect(
        () => repository.deleteCategory(defaultCategory.id),
        throwsA(isA<CategoryDeleteException>()),
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
  });
}
