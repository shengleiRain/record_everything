import 'package:drift/drift.dart';

class ItemTemplates extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  TextColumn get templateKey => text().nullable()();
  IntColumn get categoryId => integer().nullable()();
  TextColumn get itemType => text().withDefault(const Constant('todo'))();
  TextColumn get amountType => text().withDefault(const Constant('none'))();
  IntColumn get amount => integer().nullable()();
  IntColumn get dueOffsetDays => integer().withDefault(const Constant(1))();
  IntColumn get reminderOffsetDays => integer().nullable()();
  TextColumn get repeatRule => text().nullable()();
  TextColumn get keywords => text().withDefault(const Constant(''))();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}
