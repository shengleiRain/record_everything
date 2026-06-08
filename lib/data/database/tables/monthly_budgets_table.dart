import 'package:drift/drift.dart';

class MonthlyBudgets extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get monthStart => dateTime().unique()();
  IntColumn get amount => integer()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
