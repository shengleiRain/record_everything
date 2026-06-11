import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record_everything/core/constants/item_template_keys.dart';
import 'package:record_everything/data/database/app_database.dart';
import 'package:record_everything/data/repositories/life_item_repository.dart';

void main() {
  group('Item templates', () {
    late AppDatabase db;
    late LifeItemRepository repository;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repository = LifeItemRepository(db);
    });

    tearDown(() => db.close());

    test('seeds common templates as editable preset data', () async {
      final templates = await repository.getTemplates();
      final keys = templates.map((template) => template.templateKey).toSet();

      expect(
        keys,
        containsAll({
          ItemTemplateKeys.membershipRenewal,
          ItemTemplateKeys.documentExpiry,
          ItemTemplateKeys.medicineRestock,
          ItemTemplateKeys.householdBill,
          ItemTemplateKeys.warranty,
          ItemTemplateKeys.consumableReplacement,
        }),
      );
      expect(templates.where((template) => template.isPinned), isNotEmpty);
    });

    test('recommends templates from title keywords', () async {
      final subscription = await repository.recommendTemplates('Netflix 会员续费');
      final passport = await repository.recommendTemplates('护照快到期');

      expect(
        subscription.map((template) => template.templateKey),
        contains(ItemTemplateKeys.membershipRenewal),
      );
      expect(
        passport.map((template) => template.templateKey),
        contains(ItemTemplateKeys.documentExpiry),
      );
    });
  });
}
