import 'package:drift/drift.dart';

class ProjectTemplateSteps extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get templateId => integer()();
  TextColumn get title => text().withLength(min: 1, max: 120)();
  TextColumn get amountType => text().withDefault(const Constant('none'))();
  IntColumn get amount => integer().nullable()();
  IntColumn get offsetDays => integer().withDefault(const Constant(0))();
  IntColumn get keyDateOffsetDays => integer().nullable()();
  IntColumn get createdDateOffsetDays => integer().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
