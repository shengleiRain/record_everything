import 'package:drift/drift.dart';

import '../database/app_database.dart';

class AccountRepository {
  const AccountRepository(this._db);

  final AppDatabase _db;

  Future<List<Account>> getAll() => _db.select(_db.accounts).get();

  Future<Account> ensureDefaultAccount() async {
    final existing = await (_db.select(
      _db.accounts,
    )..where((t) => t.isDefault.equals(true))).get();
    if (existing.isNotEmpty) return existing.first;
    return _db
        .into(_db.accounts)
        .insertReturning(
          AccountsCompanion.insert(name: '默认账户', isDefault: const Value(true)),
        );
  }
}
