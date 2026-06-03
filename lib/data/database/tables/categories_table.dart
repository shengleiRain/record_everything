import 'package:drift/drift.dart';

class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  TextColumn get type => text()();
  TextColumn get icon => text().withDefault(const Constant('category'))();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
}
