import 'package:drift/drift.dart';

class LifeItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get description => text().nullable().withDefault(const Constant(''))();
  IntColumn get categoryId => integer().nullable()();
  TextColumn get itemType => text().withDefault(const Constant('todo'))();
  IntColumn get amount => integer().nullable()();
  TextColumn get amountType => text().withDefault(const Constant('none'))();
  DateTimeColumn get dueTime => dateTime()();
  DateTimeColumn get remindTime => dateTime().nullable()();
  TextColumn get repeatRule => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
