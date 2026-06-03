import 'package:drift/drift.dart';

class BillRecords extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get lifeItemId => integer().nullable()();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  IntColumn get categoryId => integer().nullable()();
  IntColumn get amount => integer()();
  TextColumn get amountType => text().withDefault(const Constant('expense'))();
  DateTimeColumn get billTime => dateTime()();
  TextColumn get note => text().nullable().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
