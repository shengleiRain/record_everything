import 'package:drift/drift.dart';

class ProjectEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get projectId => integer()();
  TextColumn get eventType => text()();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get description => text().nullable()();
  DateTimeColumn get eventTime => dateTime()();
  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
