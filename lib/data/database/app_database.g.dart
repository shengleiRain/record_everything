// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $CategoriesTable extends Categories
    with TableInfo<$CategoriesTable, Category> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 50,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
    'icon',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('category'),
  );
  static const VerificationMeta _isDefaultMeta = const VerificationMeta(
    'isDefault',
  );
  @override
  late final GeneratedColumn<bool> isDefault = GeneratedColumn<bool>(
    'is_default',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_default" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, type, icon, isDefault];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<Category> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('icon')) {
      context.handle(
        _iconMeta,
        icon.isAcceptableOrUnknown(data['icon']!, _iconMeta),
      );
    }
    if (data.containsKey('is_default')) {
      context.handle(
        _isDefaultMeta,
        isDefault.isAcceptableOrUnknown(data['is_default']!, _isDefaultMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Category map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Category(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      icon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon'],
      )!,
      isDefault: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_default'],
      )!,
    );
  }

  @override
  $CategoriesTable createAlias(String alias) {
    return $CategoriesTable(attachedDatabase, alias);
  }
}

class Category extends DataClass implements Insertable<Category> {
  final int id;
  final String name;
  final String type;
  final String icon;
  final bool isDefault;
  const Category({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    required this.isDefault,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['type'] = Variable<String>(type);
    map['icon'] = Variable<String>(icon);
    map['is_default'] = Variable<bool>(isDefault);
    return map;
  }

  CategoriesCompanion toCompanion(bool nullToAbsent) {
    return CategoriesCompanion(
      id: Value(id),
      name: Value(name),
      type: Value(type),
      icon: Value(icon),
      isDefault: Value(isDefault),
    );
  }

  factory Category.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Category(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      type: serializer.fromJson<String>(json['type']),
      icon: serializer.fromJson<String>(json['icon']),
      isDefault: serializer.fromJson<bool>(json['isDefault']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<String>(type),
      'icon': serializer.toJson<String>(icon),
      'isDefault': serializer.toJson<bool>(isDefault),
    };
  }

  Category copyWith({
    int? id,
    String? name,
    String? type,
    String? icon,
    bool? isDefault,
  }) => Category(
    id: id ?? this.id,
    name: name ?? this.name,
    type: type ?? this.type,
    icon: icon ?? this.icon,
    isDefault: isDefault ?? this.isDefault,
  );
  Category copyWithCompanion(CategoriesCompanion data) {
    return Category(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      icon: data.icon.present ? data.icon.value : this.icon,
      isDefault: data.isDefault.present ? data.isDefault.value : this.isDefault,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Category(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('icon: $icon, ')
          ..write('isDefault: $isDefault')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, type, icon, isDefault);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Category &&
          other.id == this.id &&
          other.name == this.name &&
          other.type == this.type &&
          other.icon == this.icon &&
          other.isDefault == this.isDefault);
}

class CategoriesCompanion extends UpdateCompanion<Category> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> type;
  final Value<String> icon;
  final Value<bool> isDefault;
  const CategoriesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.icon = const Value.absent(),
    this.isDefault = const Value.absent(),
  });
  CategoriesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String type,
    this.icon = const Value.absent(),
    this.isDefault = const Value.absent(),
  }) : name = Value(name),
       type = Value(type);
  static Insertable<Category> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? type,
    Expression<String>? icon,
    Expression<bool>? isDefault,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (icon != null) 'icon': icon,
      if (isDefault != null) 'is_default': isDefault,
    });
  }

  CategoriesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? type,
    Value<String>? icon,
    Value<bool>? isDefault,
  }) {
    return CategoriesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      icon: icon ?? this.icon,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (isDefault.present) {
      map['is_default'] = Variable<bool>(isDefault.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoriesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('icon: $icon, ')
          ..write('isDefault: $isDefault')
          ..write(')'))
        .toString();
  }
}

class $LifeItemsTable extends LifeItems
    with TableInfo<$LifeItemsTable, LifeItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LifeItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 200,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<int> categoryId = GeneratedColumn<int>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _itemTypeMeta = const VerificationMeta(
    'itemType',
  );
  @override
  late final GeneratedColumn<String> itemType = GeneratedColumn<String>(
    'item_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('todo'),
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<int> amount = GeneratedColumn<int>(
    'amount',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _amountTypeMeta = const VerificationMeta(
    'amountType',
  );
  @override
  late final GeneratedColumn<String> amountType = GeneratedColumn<String>(
    'amount_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('none'),
  );
  static const VerificationMeta _dueTimeMeta = const VerificationMeta(
    'dueTime',
  );
  @override
  late final GeneratedColumn<DateTime> dueTime = GeneratedColumn<DateTime>(
    'due_time',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _remindTimeMeta = const VerificationMeta(
    'remindTime',
  );
  @override
  late final GeneratedColumn<DateTime> remindTime = GeneratedColumn<DateTime>(
    'remind_time',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _repeatRuleMeta = const VerificationMeta(
    'repeatRule',
  );
  @override
  late final GeneratedColumn<String> repeatRule = GeneratedColumn<String>(
    'repeat_rule',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    description,
    categoryId,
    itemType,
    amount,
    amountType,
    dueTime,
    remindTime,
    repeatRule,
    status,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'life_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<LifeItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('item_type')) {
      context.handle(
        _itemTypeMeta,
        itemType.isAcceptableOrUnknown(data['item_type']!, _itemTypeMeta),
      );
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    }
    if (data.containsKey('amount_type')) {
      context.handle(
        _amountTypeMeta,
        amountType.isAcceptableOrUnknown(data['amount_type']!, _amountTypeMeta),
      );
    }
    if (data.containsKey('due_time')) {
      context.handle(
        _dueTimeMeta,
        dueTime.isAcceptableOrUnknown(data['due_time']!, _dueTimeMeta),
      );
    } else if (isInserting) {
      context.missing(_dueTimeMeta);
    }
    if (data.containsKey('remind_time')) {
      context.handle(
        _remindTimeMeta,
        remindTime.isAcceptableOrUnknown(data['remind_time']!, _remindTimeMeta),
      );
    }
    if (data.containsKey('repeat_rule')) {
      context.handle(
        _repeatRuleMeta,
        repeatRule.isAcceptableOrUnknown(data['repeat_rule']!, _repeatRuleMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LifeItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LifeItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}category_id'],
      ),
      itemType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_type'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount'],
      ),
      amountType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}amount_type'],
      )!,
      dueTime: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}due_time'],
      )!,
      remindTime: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}remind_time'],
      ),
      repeatRule: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}repeat_rule'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $LifeItemsTable createAlias(String alias) {
    return $LifeItemsTable(attachedDatabase, alias);
  }
}

class LifeItem extends DataClass implements Insertable<LifeItem> {
  final int id;
  final String title;
  final String? description;
  final int? categoryId;
  final String itemType;
  final int? amount;
  final String amountType;
  final DateTime dueTime;
  final DateTime? remindTime;
  final String? repeatRule;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  const LifeItem({
    required this.id,
    required this.title,
    this.description,
    this.categoryId,
    required this.itemType,
    this.amount,
    required this.amountType,
    required this.dueTime,
    this.remindTime,
    this.repeatRule,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<int>(categoryId);
    }
    map['item_type'] = Variable<String>(itemType);
    if (!nullToAbsent || amount != null) {
      map['amount'] = Variable<int>(amount);
    }
    map['amount_type'] = Variable<String>(amountType);
    map['due_time'] = Variable<DateTime>(dueTime);
    if (!nullToAbsent || remindTime != null) {
      map['remind_time'] = Variable<DateTime>(remindTime);
    }
    if (!nullToAbsent || repeatRule != null) {
      map['repeat_rule'] = Variable<String>(repeatRule);
    }
    map['status'] = Variable<String>(status);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  LifeItemsCompanion toCompanion(bool nullToAbsent) {
    return LifeItemsCompanion(
      id: Value(id),
      title: Value(title),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      itemType: Value(itemType),
      amount: amount == null && nullToAbsent
          ? const Value.absent()
          : Value(amount),
      amountType: Value(amountType),
      dueTime: Value(dueTime),
      remindTime: remindTime == null && nullToAbsent
          ? const Value.absent()
          : Value(remindTime),
      repeatRule: repeatRule == null && nullToAbsent
          ? const Value.absent()
          : Value(repeatRule),
      status: Value(status),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory LifeItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LifeItem(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String?>(json['description']),
      categoryId: serializer.fromJson<int?>(json['categoryId']),
      itemType: serializer.fromJson<String>(json['itemType']),
      amount: serializer.fromJson<int?>(json['amount']),
      amountType: serializer.fromJson<String>(json['amountType']),
      dueTime: serializer.fromJson<DateTime>(json['dueTime']),
      remindTime: serializer.fromJson<DateTime?>(json['remindTime']),
      repeatRule: serializer.fromJson<String?>(json['repeatRule']),
      status: serializer.fromJson<String>(json['status']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String?>(description),
      'categoryId': serializer.toJson<int?>(categoryId),
      'itemType': serializer.toJson<String>(itemType),
      'amount': serializer.toJson<int?>(amount),
      'amountType': serializer.toJson<String>(amountType),
      'dueTime': serializer.toJson<DateTime>(dueTime),
      'remindTime': serializer.toJson<DateTime?>(remindTime),
      'repeatRule': serializer.toJson<String?>(repeatRule),
      'status': serializer.toJson<String>(status),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  LifeItem copyWith({
    int? id,
    String? title,
    Value<String?> description = const Value.absent(),
    Value<int?> categoryId = const Value.absent(),
    String? itemType,
    Value<int?> amount = const Value.absent(),
    String? amountType,
    DateTime? dueTime,
    Value<DateTime?> remindTime = const Value.absent(),
    Value<String?> repeatRule = const Value.absent(),
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => LifeItem(
    id: id ?? this.id,
    title: title ?? this.title,
    description: description.present ? description.value : this.description,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    itemType: itemType ?? this.itemType,
    amount: amount.present ? amount.value : this.amount,
    amountType: amountType ?? this.amountType,
    dueTime: dueTime ?? this.dueTime,
    remindTime: remindTime.present ? remindTime.value : this.remindTime,
    repeatRule: repeatRule.present ? repeatRule.value : this.repeatRule,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  LifeItem copyWithCompanion(LifeItemsCompanion data) {
    return LifeItem(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      description: data.description.present
          ? data.description.value
          : this.description,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      itemType: data.itemType.present ? data.itemType.value : this.itemType,
      amount: data.amount.present ? data.amount.value : this.amount,
      amountType: data.amountType.present
          ? data.amountType.value
          : this.amountType,
      dueTime: data.dueTime.present ? data.dueTime.value : this.dueTime,
      remindTime: data.remindTime.present
          ? data.remindTime.value
          : this.remindTime,
      repeatRule: data.repeatRule.present
          ? data.repeatRule.value
          : this.repeatRule,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LifeItem(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('categoryId: $categoryId, ')
          ..write('itemType: $itemType, ')
          ..write('amount: $amount, ')
          ..write('amountType: $amountType, ')
          ..write('dueTime: $dueTime, ')
          ..write('remindTime: $remindTime, ')
          ..write('repeatRule: $repeatRule, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    description,
    categoryId,
    itemType,
    amount,
    amountType,
    dueTime,
    remindTime,
    repeatRule,
    status,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LifeItem &&
          other.id == this.id &&
          other.title == this.title &&
          other.description == this.description &&
          other.categoryId == this.categoryId &&
          other.itemType == this.itemType &&
          other.amount == this.amount &&
          other.amountType == this.amountType &&
          other.dueTime == this.dueTime &&
          other.remindTime == this.remindTime &&
          other.repeatRule == this.repeatRule &&
          other.status == this.status &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class LifeItemsCompanion extends UpdateCompanion<LifeItem> {
  final Value<int> id;
  final Value<String> title;
  final Value<String?> description;
  final Value<int?> categoryId;
  final Value<String> itemType;
  final Value<int?> amount;
  final Value<String> amountType;
  final Value<DateTime> dueTime;
  final Value<DateTime?> remindTime;
  final Value<String?> repeatRule;
  final Value<String> status;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const LifeItemsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.itemType = const Value.absent(),
    this.amount = const Value.absent(),
    this.amountType = const Value.absent(),
    this.dueTime = const Value.absent(),
    this.remindTime = const Value.absent(),
    this.repeatRule = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  LifeItemsCompanion.insert({
    this.id = const Value.absent(),
    required String title,
    this.description = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.itemType = const Value.absent(),
    this.amount = const Value.absent(),
    this.amountType = const Value.absent(),
    required DateTime dueTime,
    this.remindTime = const Value.absent(),
    this.repeatRule = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : title = Value(title),
       dueTime = Value(dueTime);
  static Insertable<LifeItem> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<String>? description,
    Expression<int>? categoryId,
    Expression<String>? itemType,
    Expression<int>? amount,
    Expression<String>? amountType,
    Expression<DateTime>? dueTime,
    Expression<DateTime>? remindTime,
    Expression<String>? repeatRule,
    Expression<String>? status,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (categoryId != null) 'category_id': categoryId,
      if (itemType != null) 'item_type': itemType,
      if (amount != null) 'amount': amount,
      if (amountType != null) 'amount_type': amountType,
      if (dueTime != null) 'due_time': dueTime,
      if (remindTime != null) 'remind_time': remindTime,
      if (repeatRule != null) 'repeat_rule': repeatRule,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  LifeItemsCompanion copyWith({
    Value<int>? id,
    Value<String>? title,
    Value<String?>? description,
    Value<int?>? categoryId,
    Value<String>? itemType,
    Value<int?>? amount,
    Value<String>? amountType,
    Value<DateTime>? dueTime,
    Value<DateTime?>? remindTime,
    Value<String?>? repeatRule,
    Value<String>? status,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return LifeItemsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      itemType: itemType ?? this.itemType,
      amount: amount ?? this.amount,
      amountType: amountType ?? this.amountType,
      dueTime: dueTime ?? this.dueTime,
      remindTime: remindTime ?? this.remindTime,
      repeatRule: repeatRule ?? this.repeatRule,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<int>(categoryId.value);
    }
    if (itemType.present) {
      map['item_type'] = Variable<String>(itemType.value);
    }
    if (amount.present) {
      map['amount'] = Variable<int>(amount.value);
    }
    if (amountType.present) {
      map['amount_type'] = Variable<String>(amountType.value);
    }
    if (dueTime.present) {
      map['due_time'] = Variable<DateTime>(dueTime.value);
    }
    if (remindTime.present) {
      map['remind_time'] = Variable<DateTime>(remindTime.value);
    }
    if (repeatRule.present) {
      map['repeat_rule'] = Variable<String>(repeatRule.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LifeItemsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('categoryId: $categoryId, ')
          ..write('itemType: $itemType, ')
          ..write('amount: $amount, ')
          ..write('amountType: $amountType, ')
          ..write('dueTime: $dueTime, ')
          ..write('remindTime: $remindTime, ')
          ..write('repeatRule: $repeatRule, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $BillRecordsTable extends BillRecords
    with TableInfo<$BillRecordsTable, BillRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BillRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _lifeItemIdMeta = const VerificationMeta(
    'lifeItemId',
  );
  @override
  late final GeneratedColumn<int> lifeItemId = GeneratedColumn<int>(
    'life_item_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 200,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<int> categoryId = GeneratedColumn<int>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<int> amount = GeneratedColumn<int>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountTypeMeta = const VerificationMeta(
    'amountType',
  );
  @override
  late final GeneratedColumn<String> amountType = GeneratedColumn<String>(
    'amount_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('expense'),
  );
  static const VerificationMeta _billTimeMeta = const VerificationMeta(
    'billTime',
  );
  @override
  late final GeneratedColumn<DateTime> billTime = GeneratedColumn<DateTime>(
    'bill_time',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    lifeItemId,
    title,
    categoryId,
    amount,
    amountType,
    billTime,
    note,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bill_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<BillRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('life_item_id')) {
      context.handle(
        _lifeItemIdMeta,
        lifeItemId.isAcceptableOrUnknown(
          data['life_item_id']!,
          _lifeItemIdMeta,
        ),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('amount_type')) {
      context.handle(
        _amountTypeMeta,
        amountType.isAcceptableOrUnknown(data['amount_type']!, _amountTypeMeta),
      );
    }
    if (data.containsKey('bill_time')) {
      context.handle(
        _billTimeMeta,
        billTime.isAcceptableOrUnknown(data['bill_time']!, _billTimeMeta),
      );
    } else if (isInserting) {
      context.missing(_billTimeMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BillRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BillRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      lifeItemId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}life_item_id'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}category_id'],
      ),
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount'],
      )!,
      amountType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}amount_type'],
      )!,
      billTime: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}bill_time'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $BillRecordsTable createAlias(String alias) {
    return $BillRecordsTable(attachedDatabase, alias);
  }
}

class BillRecord extends DataClass implements Insertable<BillRecord> {
  final int id;
  final int? lifeItemId;
  final String title;
  final int? categoryId;
  final int amount;
  final String amountType;
  final DateTime billTime;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;
  const BillRecord({
    required this.id,
    this.lifeItemId,
    required this.title,
    this.categoryId,
    required this.amount,
    required this.amountType,
    required this.billTime,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || lifeItemId != null) {
      map['life_item_id'] = Variable<int>(lifeItemId);
    }
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<int>(categoryId);
    }
    map['amount'] = Variable<int>(amount);
    map['amount_type'] = Variable<String>(amountType);
    map['bill_time'] = Variable<DateTime>(billTime);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  BillRecordsCompanion toCompanion(bool nullToAbsent) {
    return BillRecordsCompanion(
      id: Value(id),
      lifeItemId: lifeItemId == null && nullToAbsent
          ? const Value.absent()
          : Value(lifeItemId),
      title: Value(title),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      amount: Value(amount),
      amountType: Value(amountType),
      billTime: Value(billTime),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory BillRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BillRecord(
      id: serializer.fromJson<int>(json['id']),
      lifeItemId: serializer.fromJson<int?>(json['lifeItemId']),
      title: serializer.fromJson<String>(json['title']),
      categoryId: serializer.fromJson<int?>(json['categoryId']),
      amount: serializer.fromJson<int>(json['amount']),
      amountType: serializer.fromJson<String>(json['amountType']),
      billTime: serializer.fromJson<DateTime>(json['billTime']),
      note: serializer.fromJson<String?>(json['note']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'lifeItemId': serializer.toJson<int?>(lifeItemId),
      'title': serializer.toJson<String>(title),
      'categoryId': serializer.toJson<int?>(categoryId),
      'amount': serializer.toJson<int>(amount),
      'amountType': serializer.toJson<String>(amountType),
      'billTime': serializer.toJson<DateTime>(billTime),
      'note': serializer.toJson<String?>(note),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  BillRecord copyWith({
    int? id,
    Value<int?> lifeItemId = const Value.absent(),
    String? title,
    Value<int?> categoryId = const Value.absent(),
    int? amount,
    String? amountType,
    DateTime? billTime,
    Value<String?> note = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => BillRecord(
    id: id ?? this.id,
    lifeItemId: lifeItemId.present ? lifeItemId.value : this.lifeItemId,
    title: title ?? this.title,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    amount: amount ?? this.amount,
    amountType: amountType ?? this.amountType,
    billTime: billTime ?? this.billTime,
    note: note.present ? note.value : this.note,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  BillRecord copyWithCompanion(BillRecordsCompanion data) {
    return BillRecord(
      id: data.id.present ? data.id.value : this.id,
      lifeItemId: data.lifeItemId.present
          ? data.lifeItemId.value
          : this.lifeItemId,
      title: data.title.present ? data.title.value : this.title,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      amount: data.amount.present ? data.amount.value : this.amount,
      amountType: data.amountType.present
          ? data.amountType.value
          : this.amountType,
      billTime: data.billTime.present ? data.billTime.value : this.billTime,
      note: data.note.present ? data.note.value : this.note,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BillRecord(')
          ..write('id: $id, ')
          ..write('lifeItemId: $lifeItemId, ')
          ..write('title: $title, ')
          ..write('categoryId: $categoryId, ')
          ..write('amount: $amount, ')
          ..write('amountType: $amountType, ')
          ..write('billTime: $billTime, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    lifeItemId,
    title,
    categoryId,
    amount,
    amountType,
    billTime,
    note,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BillRecord &&
          other.id == this.id &&
          other.lifeItemId == this.lifeItemId &&
          other.title == this.title &&
          other.categoryId == this.categoryId &&
          other.amount == this.amount &&
          other.amountType == this.amountType &&
          other.billTime == this.billTime &&
          other.note == this.note &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class BillRecordsCompanion extends UpdateCompanion<BillRecord> {
  final Value<int> id;
  final Value<int?> lifeItemId;
  final Value<String> title;
  final Value<int?> categoryId;
  final Value<int> amount;
  final Value<String> amountType;
  final Value<DateTime> billTime;
  final Value<String?> note;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const BillRecordsCompanion({
    this.id = const Value.absent(),
    this.lifeItemId = const Value.absent(),
    this.title = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.amount = const Value.absent(),
    this.amountType = const Value.absent(),
    this.billTime = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  BillRecordsCompanion.insert({
    this.id = const Value.absent(),
    this.lifeItemId = const Value.absent(),
    required String title,
    this.categoryId = const Value.absent(),
    required int amount,
    this.amountType = const Value.absent(),
    required DateTime billTime,
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : title = Value(title),
       amount = Value(amount),
       billTime = Value(billTime);
  static Insertable<BillRecord> custom({
    Expression<int>? id,
    Expression<int>? lifeItemId,
    Expression<String>? title,
    Expression<int>? categoryId,
    Expression<int>? amount,
    Expression<String>? amountType,
    Expression<DateTime>? billTime,
    Expression<String>? note,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (lifeItemId != null) 'life_item_id': lifeItemId,
      if (title != null) 'title': title,
      if (categoryId != null) 'category_id': categoryId,
      if (amount != null) 'amount': amount,
      if (amountType != null) 'amount_type': amountType,
      if (billTime != null) 'bill_time': billTime,
      if (note != null) 'note': note,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  BillRecordsCompanion copyWith({
    Value<int>? id,
    Value<int?>? lifeItemId,
    Value<String>? title,
    Value<int?>? categoryId,
    Value<int>? amount,
    Value<String>? amountType,
    Value<DateTime>? billTime,
    Value<String?>? note,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return BillRecordsCompanion(
      id: id ?? this.id,
      lifeItemId: lifeItemId ?? this.lifeItemId,
      title: title ?? this.title,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
      amountType: amountType ?? this.amountType,
      billTime: billTime ?? this.billTime,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (lifeItemId.present) {
      map['life_item_id'] = Variable<int>(lifeItemId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<int>(categoryId.value);
    }
    if (amount.present) {
      map['amount'] = Variable<int>(amount.value);
    }
    if (amountType.present) {
      map['amount_type'] = Variable<String>(amountType.value);
    }
    if (billTime.present) {
      map['bill_time'] = Variable<DateTime>(billTime.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BillRecordsCompanion(')
          ..write('id: $id, ')
          ..write('lifeItemId: $lifeItemId, ')
          ..write('title: $title, ')
          ..write('categoryId: $categoryId, ')
          ..write('amount: $amount, ')
          ..write('amountType: $amountType, ')
          ..write('billTime: $billTime, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CategoriesTable categories = $CategoriesTable(this);
  late final $LifeItemsTable lifeItems = $LifeItemsTable(this);
  late final $BillRecordsTable billRecords = $BillRecordsTable(this);
  late final LifeItemDao lifeItemDao = LifeItemDao(this as AppDatabase);
  late final BillRecordDao billRecordDao = BillRecordDao(this as AppDatabase);
  late final CategoryDao categoryDao = CategoryDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    categories,
    lifeItems,
    billRecords,
  ];
}

typedef $$CategoriesTableCreateCompanionBuilder =
    CategoriesCompanion Function({
      Value<int> id,
      required String name,
      required String type,
      Value<String> icon,
      Value<bool> isDefault,
    });
typedef $$CategoriesTableUpdateCompanionBuilder =
    CategoriesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> type,
      Value<String> icon,
      Value<bool> isDefault,
    });

class $$CategoriesTableFilterComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CategoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CategoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<bool> get isDefault =>
      $composableBuilder(column: $table.isDefault, builder: (column) => column);
}

class $$CategoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CategoriesTable,
          Category,
          $$CategoriesTableFilterComposer,
          $$CategoriesTableOrderingComposer,
          $$CategoriesTableAnnotationComposer,
          $$CategoriesTableCreateCompanionBuilder,
          $$CategoriesTableUpdateCompanionBuilder,
          (Category, BaseReferences<_$AppDatabase, $CategoriesTable, Category>),
          Category,
          PrefetchHooks Function()
        > {
  $$CategoriesTableTableManager(_$AppDatabase db, $CategoriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> icon = const Value.absent(),
                Value<bool> isDefault = const Value.absent(),
              }) => CategoriesCompanion(
                id: id,
                name: name,
                type: type,
                icon: icon,
                isDefault: isDefault,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String type,
                Value<String> icon = const Value.absent(),
                Value<bool> isDefault = const Value.absent(),
              }) => CategoriesCompanion.insert(
                id: id,
                name: name,
                type: type,
                icon: icon,
                isDefault: isDefault,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CategoriesTable,
      Category,
      $$CategoriesTableFilterComposer,
      $$CategoriesTableOrderingComposer,
      $$CategoriesTableAnnotationComposer,
      $$CategoriesTableCreateCompanionBuilder,
      $$CategoriesTableUpdateCompanionBuilder,
      (Category, BaseReferences<_$AppDatabase, $CategoriesTable, Category>),
      Category,
      PrefetchHooks Function()
    >;
typedef $$LifeItemsTableCreateCompanionBuilder =
    LifeItemsCompanion Function({
      Value<int> id,
      required String title,
      Value<String?> description,
      Value<int?> categoryId,
      Value<String> itemType,
      Value<int?> amount,
      Value<String> amountType,
      required DateTime dueTime,
      Value<DateTime?> remindTime,
      Value<String?> repeatRule,
      Value<String> status,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$LifeItemsTableUpdateCompanionBuilder =
    LifeItemsCompanion Function({
      Value<int> id,
      Value<String> title,
      Value<String?> description,
      Value<int?> categoryId,
      Value<String> itemType,
      Value<int?> amount,
      Value<String> amountType,
      Value<DateTime> dueTime,
      Value<DateTime?> remindTime,
      Value<String?> repeatRule,
      Value<String> status,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

class $$LifeItemsTableFilterComposer
    extends Composer<_$AppDatabase, $LifeItemsTable> {
  $$LifeItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemType => $composableBuilder(
    column: $table.itemType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get amountType => $composableBuilder(
    column: $table.amountType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dueTime => $composableBuilder(
    column: $table.dueTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get remindTime => $composableBuilder(
    column: $table.remindTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get repeatRule => $composableBuilder(
    column: $table.repeatRule,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LifeItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $LifeItemsTable> {
  $$LifeItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemType => $composableBuilder(
    column: $table.itemType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get amountType => $composableBuilder(
    column: $table.amountType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dueTime => $composableBuilder(
    column: $table.dueTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get remindTime => $composableBuilder(
    column: $table.remindTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get repeatRule => $composableBuilder(
    column: $table.repeatRule,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LifeItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LifeItemsTable> {
  $$LifeItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<int> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get itemType =>
      $composableBuilder(column: $table.itemType, builder: (column) => column);

  GeneratedColumn<int> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get amountType => $composableBuilder(
    column: $table.amountType,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get dueTime =>
      $composableBuilder(column: $table.dueTime, builder: (column) => column);

  GeneratedColumn<DateTime> get remindTime => $composableBuilder(
    column: $table.remindTime,
    builder: (column) => column,
  );

  GeneratedColumn<String> get repeatRule => $composableBuilder(
    column: $table.repeatRule,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$LifeItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LifeItemsTable,
          LifeItem,
          $$LifeItemsTableFilterComposer,
          $$LifeItemsTableOrderingComposer,
          $$LifeItemsTableAnnotationComposer,
          $$LifeItemsTableCreateCompanionBuilder,
          $$LifeItemsTableUpdateCompanionBuilder,
          (LifeItem, BaseReferences<_$AppDatabase, $LifeItemsTable, LifeItem>),
          LifeItem,
          PrefetchHooks Function()
        > {
  $$LifeItemsTableTableManager(_$AppDatabase db, $LifeItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LifeItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LifeItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LifeItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<int?> categoryId = const Value.absent(),
                Value<String> itemType = const Value.absent(),
                Value<int?> amount = const Value.absent(),
                Value<String> amountType = const Value.absent(),
                Value<DateTime> dueTime = const Value.absent(),
                Value<DateTime?> remindTime = const Value.absent(),
                Value<String?> repeatRule = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => LifeItemsCompanion(
                id: id,
                title: title,
                description: description,
                categoryId: categoryId,
                itemType: itemType,
                amount: amount,
                amountType: amountType,
                dueTime: dueTime,
                remindTime: remindTime,
                repeatRule: repeatRule,
                status: status,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String title,
                Value<String?> description = const Value.absent(),
                Value<int?> categoryId = const Value.absent(),
                Value<String> itemType = const Value.absent(),
                Value<int?> amount = const Value.absent(),
                Value<String> amountType = const Value.absent(),
                required DateTime dueTime,
                Value<DateTime?> remindTime = const Value.absent(),
                Value<String?> repeatRule = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => LifeItemsCompanion.insert(
                id: id,
                title: title,
                description: description,
                categoryId: categoryId,
                itemType: itemType,
                amount: amount,
                amountType: amountType,
                dueTime: dueTime,
                remindTime: remindTime,
                repeatRule: repeatRule,
                status: status,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LifeItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LifeItemsTable,
      LifeItem,
      $$LifeItemsTableFilterComposer,
      $$LifeItemsTableOrderingComposer,
      $$LifeItemsTableAnnotationComposer,
      $$LifeItemsTableCreateCompanionBuilder,
      $$LifeItemsTableUpdateCompanionBuilder,
      (LifeItem, BaseReferences<_$AppDatabase, $LifeItemsTable, LifeItem>),
      LifeItem,
      PrefetchHooks Function()
    >;
typedef $$BillRecordsTableCreateCompanionBuilder =
    BillRecordsCompanion Function({
      Value<int> id,
      Value<int?> lifeItemId,
      required String title,
      Value<int?> categoryId,
      required int amount,
      Value<String> amountType,
      required DateTime billTime,
      Value<String?> note,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$BillRecordsTableUpdateCompanionBuilder =
    BillRecordsCompanion Function({
      Value<int> id,
      Value<int?> lifeItemId,
      Value<String> title,
      Value<int?> categoryId,
      Value<int> amount,
      Value<String> amountType,
      Value<DateTime> billTime,
      Value<String?> note,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

class $$BillRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $BillRecordsTable> {
  $$BillRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lifeItemId => $composableBuilder(
    column: $table.lifeItemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get amountType => $composableBuilder(
    column: $table.amountType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get billTime => $composableBuilder(
    column: $table.billTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BillRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $BillRecordsTable> {
  $$BillRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lifeItemId => $composableBuilder(
    column: $table.lifeItemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get amountType => $composableBuilder(
    column: $table.amountType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get billTime => $composableBuilder(
    column: $table.billTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BillRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BillRecordsTable> {
  $$BillRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get lifeItemId => $composableBuilder(
    column: $table.lifeItemId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get amountType => $composableBuilder(
    column: $table.amountType,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get billTime =>
      $composableBuilder(column: $table.billTime, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$BillRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BillRecordsTable,
          BillRecord,
          $$BillRecordsTableFilterComposer,
          $$BillRecordsTableOrderingComposer,
          $$BillRecordsTableAnnotationComposer,
          $$BillRecordsTableCreateCompanionBuilder,
          $$BillRecordsTableUpdateCompanionBuilder,
          (
            BillRecord,
            BaseReferences<_$AppDatabase, $BillRecordsTable, BillRecord>,
          ),
          BillRecord,
          PrefetchHooks Function()
        > {
  $$BillRecordsTableTableManager(_$AppDatabase db, $BillRecordsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BillRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BillRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BillRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> lifeItemId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<int?> categoryId = const Value.absent(),
                Value<int> amount = const Value.absent(),
                Value<String> amountType = const Value.absent(),
                Value<DateTime> billTime = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => BillRecordsCompanion(
                id: id,
                lifeItemId: lifeItemId,
                title: title,
                categoryId: categoryId,
                amount: amount,
                amountType: amountType,
                billTime: billTime,
                note: note,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> lifeItemId = const Value.absent(),
                required String title,
                Value<int?> categoryId = const Value.absent(),
                required int amount,
                Value<String> amountType = const Value.absent(),
                required DateTime billTime,
                Value<String?> note = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => BillRecordsCompanion.insert(
                id: id,
                lifeItemId: lifeItemId,
                title: title,
                categoryId: categoryId,
                amount: amount,
                amountType: amountType,
                billTime: billTime,
                note: note,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BillRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BillRecordsTable,
      BillRecord,
      $$BillRecordsTableFilterComposer,
      $$BillRecordsTableOrderingComposer,
      $$BillRecordsTableAnnotationComposer,
      $$BillRecordsTableCreateCompanionBuilder,
      $$BillRecordsTableUpdateCompanionBuilder,
      (
        BillRecord,
        BaseReferences<_$AppDatabase, $BillRecordsTable, BillRecord>,
      ),
      BillRecord,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db, _db.categories);
  $$LifeItemsTableTableManager get lifeItems =>
      $$LifeItemsTableTableManager(_db, _db.lifeItems);
  $$BillRecordsTableTableManager get billRecords =>
      $$BillRecordsTableTableManager(_db, _db.billRecords);
}
