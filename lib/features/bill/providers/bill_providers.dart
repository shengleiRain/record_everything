import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/database_provider.dart';
import '../../../data/repositories/account_repository.dart';
import '../../../data/repositories/bill_record_repository.dart';
import '../../../data/repositories/budget_repository.dart';

final billRepoProvider = Provider<BillRecordRepository>((ref) {
  return BillRecordRepository(ref.watch(databaseProvider));
});

final accountRepoProvider = Provider<AccountRepository>((ref) {
  return AccountRepository(ref.watch(databaseProvider));
});

final budgetRepoProvider = Provider<BudgetRepository>((ref) {
  return BudgetRepository(ref.watch(databaseProvider));
});

final currentMonthProvider = StateProvider<DateTime>((ref) => DateTime.now());

final billsByMonthProvider = StreamProvider<List<BillRecord>>((ref) {
  final month = ref.watch(currentMonthProvider);
  return ref.watch(billRepoProvider).watchByMonth(month);
});

final monthlyIncomeProvider = StreamProvider<int>((ref) {
  final month = ref.watch(currentMonthProvider);
  return ref.watch(billRepoProvider).watchIncomeForMonth(month);
});

final monthlyExpenseProvider = StreamProvider<int>((ref) {
  final month = ref.watch(currentMonthProvider);
  return ref.watch(billRepoProvider).watchExpenseForMonth(month);
});

final monthlyBudgetProvider = StreamProvider<int>((ref) {
  final month = ref.watch(currentMonthProvider);
  return ref.watch(budgetRepoProvider).watchMonthlyBudget(month);
});

class BillNotifier extends Notifier<void> {
  @override
  void build() {}

  BillRecordRepository get _repo => ref.read(billRepoProvider);

  Future<BillRecord> create({
    required String title,
    required int amount,
    String amountType = 'expense',
    int? categoryId,
    int? accountId,
    int? projectId,
    DateTime? billTime,
    String? note,
    int? lifeItemId,
  }) async {
    final resolvedAccountId =
        accountId ??
        (await ref.read(accountRepoProvider).ensureDefaultAccount()).id;
    return _repo.create(
      title: title,
      amount: amount,
      amountType: amountType,
      categoryId: categoryId,
      accountId: resolvedAccountId,
      projectId: projectId,
      billTime: billTime ?? DateTime.now(),
      note: note,
      lifeItemId: lifeItemId,
    );
  }

  Future<BillRecord> createFromLifeItem(
    LifeItem item,
    int? customAmount,
    int? customCategoryId,
    String? note,
  ) => _repo.create(
    title: item.title,
    amount: customAmount ?? item.amount ?? 0,
    amountType: item.amountType,
    categoryId: customCategoryId ?? item.categoryId,
    projectId: item.projectId,
    billTime: DateTime.now(),
    note: note,
    lifeItemId: item.id,
  );

  Future<void> delete(int id) => _repo.deleteRecord(id);
}

final billNotifierProvider = NotifierProvider<BillNotifier, void>(
  BillNotifier.new,
);
