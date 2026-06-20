import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record_everything/data/database/app_database.dart';
import 'package:record_everything/data/repositories/account_repository.dart';
import 'package:record_everything/data/repositories/budget_repository.dart';
import 'package:record_everything/features/settings/services/backup_service.dart';

void main() {
  group('BackupService v7', () {
    late AppDatabase db;
    late BackupService service;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      service = BackupService(db);
    });

    tearDown(() => db.close());

    test('exports accounts and monthlyBudgets in v7 format', () async {
      await AccountRepository(db).ensureDefaultAccount();
      await BudgetRepository(db).setMonthlyBudget(DateTime(2026, 6, 1), 500000);

      final jsonText = await service.exportToJson();
      final data = jsonDecode(jsonText) as Map<String, Object?>;

      expect(data['version'], 7);
      expect(data['accounts'], isA<List>());
      expect((data['accounts'] as List).length, 1);
      expect(data['monthlyBudgets'], isA<List>());
      expect((data['monthlyBudgets'] as List).length, 1);
    });

    test('imports accounts and monthlyBudgets from v7 backup', () async {
      final jsonText = jsonEncode({
        'version': 7,
        'categories': [],
        'lifeItems': [],
        'billRecords': [],
        'projects': [],
        'projectEvents': [],
        'projectTemplates': [],
        'projectTemplateSteps': [],
        'itemTemplates': [],
        'accounts': [
          {
            'id': 1,
            'name': '微信钱包',
            'type': 'wechat',
            'isDefault': false,
            'createdAt': '2026-01-01T00:00:00.000',
          },
        ],
        'monthlyBudgets': [
          {
            'id': 1,
            'monthStart': '2026-06-01T00:00:00.000',
            'amount': 800000,
            'createdAt': '2026-06-01T00:00:00.000',
            'updatedAt': '2026-06-01T00:00:00.000',
          },
        ],
      });

      final summary = await service.importFromJson(jsonText);

      expect(summary.accountsImported, 1);
      expect(summary.monthlyBudgetsImported, 1);

      final accounts = await AccountRepository(db).getAll();
      expect(accounts.any((a) => a.name == '微信钱包'), isTrue);

      final budget = await BudgetRepository(db).getMonthlyBudget(
        DateTime(2026, 6, 1),
      );
      expect(budget, 800000);
    });

    test('v6 backup imports without accounts and budgets', () async {
      final jsonText = jsonEncode({
        'version': 6,
        'categories': [],
        'lifeItems': [],
        'billRecords': [],
        'projects': [],
        'projectEvents': [],
        'projectTemplates': [],
        'projectTemplateSteps': [],
        'itemTemplates': [],
      });

      final summary = await service.importFromJson(jsonText);

      expect(summary.accountsImported, 0);
      expect(summary.monthlyBudgetsImported, 0);
    });

    test('skips duplicate accounts by name+type', () async {
      final jsonText = jsonEncode({
        'version': 7,
        'categories': [],
        'lifeItems': [],
        'billRecords': [],
        'projects': [],
        'projectEvents': [],
        'projectTemplates': [],
        'projectTemplateSteps': [],
        'itemTemplates': [],
        'accounts': [
          {
            'id': 1,
            'name': '默认账户',
            'type': 'cash',
            'isDefault': true,
            'createdAt': '2026-01-01T00:00:00.000',
          },
        ],
        'monthlyBudgets': [],
      });

      // Ensure default account already exists
      await AccountRepository(db).ensureDefaultAccount();

      final summary = await service.importFromJson(jsonText);
      expect(summary.accountsImported, 0);
    });

    test('skips duplicate monthlyBudgets by monthStart', () async {
      final jsonText = jsonEncode({
        'version': 7,
        'categories': [],
        'lifeItems': [],
        'billRecords': [],
        'projects': [],
        'projectEvents': [],
        'projectTemplates': [],
        'projectTemplateSteps': [],
        'itemTemplates': [],
        'accounts': [],
        'monthlyBudgets': [
          {
            'id': 1,
            'monthStart': '2026-06-01T00:00:00.000',
            'amount': 500000,
            'createdAt': '2026-06-01T00:00:00.000',
            'updatedAt': '2026-06-01T00:00:00.000',
          },
        ],
      });

      await BudgetRepository(db).setMonthlyBudget(DateTime(2026, 6, 1), 500000);

      final summary = await service.importFromJson(jsonText);
      expect(summary.monthlyBudgetsImported, 0);
    });
  });
}
