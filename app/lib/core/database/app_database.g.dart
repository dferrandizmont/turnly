// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $CalendarsTable extends Calendars
    with TableInfo<$CalendarsTable, CalendarRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CalendarsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorValueMeta = const VerificationMeta(
    'colorValue',
  );
  @override
  late final GeneratedColumn<int> colorValue = GeneratedColumn<int>(
    'color_value',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _archivedMeta = const VerificationMeta(
    'archived',
  );
  @override
  late final GeneratedColumn<bool> archived = GeneratedColumn<bool>(
    'archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    colorValue,
    sortOrder,
    archived,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'calendars';
  @override
  VerificationContext validateIntegrity(
    Insertable<CalendarRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color_value')) {
      context.handle(
        _colorValueMeta,
        colorValue.isAcceptableOrUnknown(data['color_value']!, _colorValueMeta),
      );
    } else if (isInserting) {
      context.missing(_colorValueMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    if (data.containsKey('archived')) {
      context.handle(
        _archivedMeta,
        archived.isAcceptableOrUnknown(data['archived']!, _archivedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CalendarRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CalendarRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      colorValue: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_value'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      archived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}archived'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $CalendarsTable createAlias(String alias) {
    return $CalendarsTable(attachedDatabase, alias);
  }
}

class CalendarRow extends DataClass implements Insertable<CalendarRow> {
  final String id;
  final String name;
  final int colorValue;
  final int sortOrder;
  final bool archived;
  final int createdAt;
  final int updatedAt;
  const CalendarRow({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.sortOrder,
    required this.archived,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['color_value'] = Variable<int>(colorValue);
    map['sort_order'] = Variable<int>(sortOrder);
    map['archived'] = Variable<bool>(archived);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  CalendarsCompanion toCompanion(bool nullToAbsent) {
    return CalendarsCompanion(
      id: Value(id),
      name: Value(name),
      colorValue: Value(colorValue),
      sortOrder: Value(sortOrder),
      archived: Value(archived),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory CalendarRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CalendarRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      colorValue: serializer.fromJson<int>(json['colorValue']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      archived: serializer.fromJson<bool>(json['archived']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'colorValue': serializer.toJson<int>(colorValue),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'archived': serializer.toJson<bool>(archived),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  CalendarRow copyWith({
    String? id,
    String? name,
    int? colorValue,
    int? sortOrder,
    bool? archived,
    int? createdAt,
    int? updatedAt,
  }) => CalendarRow(
    id: id ?? this.id,
    name: name ?? this.name,
    colorValue: colorValue ?? this.colorValue,
    sortOrder: sortOrder ?? this.sortOrder,
    archived: archived ?? this.archived,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  CalendarRow copyWithCompanion(CalendarsCompanion data) {
    return CalendarRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      colorValue: data.colorValue.present
          ? data.colorValue.value
          : this.colorValue,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      archived: data.archived.present ? data.archived.value : this.archived,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CalendarRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('colorValue: $colorValue, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('archived: $archived, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    colorValue,
    sortOrder,
    archived,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CalendarRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.colorValue == this.colorValue &&
          other.sortOrder == this.sortOrder &&
          other.archived == this.archived &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class CalendarsCompanion extends UpdateCompanion<CalendarRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> colorValue;
  final Value<int> sortOrder;
  final Value<bool> archived;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const CalendarsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.colorValue = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.archived = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CalendarsCompanion.insert({
    required String id,
    required String name,
    required int colorValue,
    required int sortOrder,
    this.archived = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       colorValue = Value(colorValue),
       sortOrder = Value(sortOrder),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<CalendarRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? colorValue,
    Expression<int>? sortOrder,
    Expression<bool>? archived,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (colorValue != null) 'color_value': colorValue,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (archived != null) 'archived': archived,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CalendarsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int>? colorValue,
    Value<int>? sortOrder,
    Value<bool>? archived,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return CalendarsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      sortOrder: sortOrder ?? this.sortOrder,
      archived: archived ?? this.archived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (colorValue.present) {
      map['color_value'] = Variable<int>(colorValue.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (archived.present) {
      map['archived'] = Variable<bool>(archived.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CalendarsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('colorValue: $colorValue, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('archived: $archived, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ShiftTypesTable extends ShiftTypes
    with TableInfo<$ShiftTypesTable, ShiftTypeRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ShiftTypesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
    'code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorValueMeta = const VerificationMeta(
    'colorValue',
  );
  @override
  late final GeneratedColumn<int> colorValue = GeneratedColumn<int>(
    'color_value',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<ShiftCategory, String> category =
      GeneratedColumn<String>(
        'category',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<ShiftCategory>($ShiftTypesTable.$convertercategory);
  static const VerificationMeta _startMinuteMeta = const VerificationMeta(
    'startMinute',
  );
  @override
  late final GeneratedColumn<int> startMinute = GeneratedColumn<int>(
    'start_minute',
    aliasedName,
    true,
    check: () => ComparableExpr(startMinute).isBetweenValues(0, 1439),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endMinuteMeta = const VerificationMeta(
    'endMinute',
  );
  @override
  late final GeneratedColumn<int> endMinute = GeneratedColumn<int>(
    'end_minute',
    aliasedName,
    true,
    check: () => ComparableExpr(endMinute).isBetweenValues(0, 1439),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _paidMinutesMeta = const VerificationMeta(
    'paidMinutes',
  );
  @override
  late final GeneratedColumn<int> paidMinutes = GeneratedColumn<int>(
    'paid_minutes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nightOverrideMeta = const VerificationMeta(
    'nightOverride',
  );
  @override
  late final GeneratedColumn<bool> nightOverride = GeneratedColumn<bool>(
    'night_override',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("night_override" IN (0, 1))',
    ),
  );
  static const VerificationMeta _hourlyRateCentsMeta = const VerificationMeta(
    'hourlyRateCents',
  );
  @override
  late final GeneratedColumn<int> hourlyRateCents = GeneratedColumn<int>(
    'hourly_rate_cents',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fixedPlusCentsMeta = const VerificationMeta(
    'fixedPlusCents',
  );
  @override
  late final GeneratedColumn<int> fixedPlusCents = GeneratedColumn<int>(
    'fixed_plus_cents',
    aliasedName,
    true,
    check: () =>
        ComparableExpr(fixedPlusCents).isBetweenValues(0, maxStoredMoneyCents),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
    'icon',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _alarmSoundMeta = const VerificationMeta(
    'alarmSound',
  );
  @override
  late final GeneratedColumn<String> alarmSound = GeneratedColumn<String>(
    'alarm_sound',
    aliasedName,
    true,
    check: () =>
        alarmSound.isNull() |
        BooleanExpressionOperators(alarmSound.equals('')).not(),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _segment2StartMinuteMeta =
      const VerificationMeta('segment2StartMinute');
  @override
  late final GeneratedColumn<int> segment2StartMinute = GeneratedColumn<int>(
    'segment2_start_minute',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _segment2DurationMinutesMeta =
      const VerificationMeta('segment2DurationMinutes');
  @override
  late final GeneratedColumn<int> segment2DurationMinutes =
      GeneratedColumn<int>(
        'segment2_duration_minutes',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _locationMeta = const VerificationMeta(
    'location',
  );
  @override
  late final GeneratedColumn<String> location = GeneratedColumn<String>(
    'location',
    aliasedName,
    true,
    check: () =>
        location.isNull() |
        (ComparableExpr(StringExpressionOperators(location).trim().length)
                .isBiggerThanValue(0) &
            ComparableExpr(location.length)
                .isSmallerOrEqualValue(maxShiftLocationLength)),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nightPlusCentsPerHourMeta =
      const VerificationMeta('nightPlusCentsPerHour');
  @override
  late final GeneratedColumn<int> nightPlusCentsPerHour = GeneratedColumn<int>(
    'night_plus_cents_per_hour',
    aliasedName,
    true,
    check: () =>
        ComparableExpr(nightPlusCentsPerHour)
            .isBetweenValues(0, maxStoredMoneyCents),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _holidayPlusCentsPerHourMeta =
      const VerificationMeta('holidayPlusCentsPerHour');
  @override
  late final GeneratedColumn<int> holidayPlusCentsPerHour =
      GeneratedColumn<int>(
        'holiday_plus_cents_per_hour',
        aliasedName,
        true,
        check: () =>
            ComparableExpr(holidayPlusCentsPerHour)
                .isBetweenValues(0, maxStoredMoneyCents),
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _archivedMeta = const VerificationMeta(
    'archived',
  );
  @override
  late final GeneratedColumn<bool> archived = GeneratedColumn<bool>(
    'archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    code,
    name,
    colorValue,
    category,
    startMinute,
    endMinute,
    paidMinutes,
    nightOverride,
    hourlyRateCents,
    fixedPlusCents,
    icon,
    alarmSound,
    segment2StartMinute,
    segment2DurationMinutes,
    location,
    nightPlusCentsPerHour,
    holidayPlusCentsPerHour,
    sortOrder,
    archived,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'shift_types';
  @override
  VerificationContext validateIntegrity(
    Insertable<ShiftTypeRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('code')) {
      context.handle(
        _codeMeta,
        code.isAcceptableOrUnknown(data['code']!, _codeMeta),
      );
    } else if (isInserting) {
      context.missing(_codeMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color_value')) {
      context.handle(
        _colorValueMeta,
        colorValue.isAcceptableOrUnknown(data['color_value']!, _colorValueMeta),
      );
    } else if (isInserting) {
      context.missing(_colorValueMeta);
    }
    if (data.containsKey('start_minute')) {
      context.handle(
        _startMinuteMeta,
        startMinute.isAcceptableOrUnknown(
          data['start_minute']!,
          _startMinuteMeta,
        ),
      );
    }
    if (data.containsKey('end_minute')) {
      context.handle(
        _endMinuteMeta,
        endMinute.isAcceptableOrUnknown(data['end_minute']!, _endMinuteMeta),
      );
    }
    if (data.containsKey('paid_minutes')) {
      context.handle(
        _paidMinutesMeta,
        paidMinutes.isAcceptableOrUnknown(
          data['paid_minutes']!,
          _paidMinutesMeta,
        ),
      );
    }
    if (data.containsKey('night_override')) {
      context.handle(
        _nightOverrideMeta,
        nightOverride.isAcceptableOrUnknown(
          data['night_override']!,
          _nightOverrideMeta,
        ),
      );
    }
    if (data.containsKey('hourly_rate_cents')) {
      context.handle(
        _hourlyRateCentsMeta,
        hourlyRateCents.isAcceptableOrUnknown(
          data['hourly_rate_cents']!,
          _hourlyRateCentsMeta,
        ),
      );
    }
    if (data.containsKey('fixed_plus_cents')) {
      context.handle(
        _fixedPlusCentsMeta,
        fixedPlusCents.isAcceptableOrUnknown(
          data['fixed_plus_cents']!,
          _fixedPlusCentsMeta,
        ),
      );
    }
    if (data.containsKey('icon')) {
      context.handle(
        _iconMeta,
        icon.isAcceptableOrUnknown(data['icon']!, _iconMeta),
      );
    }
    if (data.containsKey('alarm_sound')) {
      context.handle(
        _alarmSoundMeta,
        alarmSound.isAcceptableOrUnknown(data['alarm_sound']!, _alarmSoundMeta),
      );
    }
    if (data.containsKey('segment2_start_minute')) {
      context.handle(
        _segment2StartMinuteMeta,
        segment2StartMinute.isAcceptableOrUnknown(
          data['segment2_start_minute']!,
          _segment2StartMinuteMeta,
        ),
      );
    }
    if (data.containsKey('segment2_duration_minutes')) {
      context.handle(
        _segment2DurationMinutesMeta,
        segment2DurationMinutes.isAcceptableOrUnknown(
          data['segment2_duration_minutes']!,
          _segment2DurationMinutesMeta,
        ),
      );
    }
    if (data.containsKey('location')) {
      context.handle(
        _locationMeta,
        location.isAcceptableOrUnknown(data['location']!, _locationMeta),
      );
    }
    if (data.containsKey('night_plus_cents_per_hour')) {
      context.handle(
        _nightPlusCentsPerHourMeta,
        nightPlusCentsPerHour.isAcceptableOrUnknown(
          data['night_plus_cents_per_hour']!,
          _nightPlusCentsPerHourMeta,
        ),
      );
    }
    if (data.containsKey('holiday_plus_cents_per_hour')) {
      context.handle(
        _holidayPlusCentsPerHourMeta,
        holidayPlusCentsPerHour.isAcceptableOrUnknown(
          data['holiday_plus_cents_per_hour']!,
          _holidayPlusCentsPerHourMeta,
        ),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    if (data.containsKey('archived')) {
      context.handle(
        _archivedMeta,
        archived.isAcceptableOrUnknown(data['archived']!, _archivedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ShiftTypeRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ShiftTypeRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      code: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      colorValue: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_value'],
      )!,
      category: $ShiftTypesTable.$convertercategory.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}category'],
        )!,
      ),
      startMinute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_minute'],
      ),
      endMinute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_minute'],
      ),
      paidMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}paid_minutes'],
      ),
      nightOverride: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}night_override'],
      ),
      hourlyRateCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}hourly_rate_cents'],
      ),
      fixedPlusCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fixed_plus_cents'],
      ),
      icon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon'],
      ),
      alarmSound: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}alarm_sound'],
      ),
      segment2StartMinute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}segment2_start_minute'],
      ),
      segment2DurationMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}segment2_duration_minutes'],
      ),
      location: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location'],
      ),
      nightPlusCentsPerHour: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}night_plus_cents_per_hour'],
      ),
      holidayPlusCentsPerHour: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}holiday_plus_cents_per_hour'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      archived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}archived'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ShiftTypesTable createAlias(String alias) {
    return $ShiftTypesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ShiftCategory, String, String> $convertercategory =
      const EnumNameConverter<ShiftCategory>(ShiftCategory.values);
}

class ShiftTypeRow extends DataClass implements Insertable<ShiftTypeRow> {
  final String id;
  final String code;
  final String name;
  final int colorValue;
  final ShiftCategory category;
  final int? startMinute;
  final int? endMinute;
  final int? paidMinutes;
  final bool? nightOverride;

  /// Hourly rate in cents (no floating point). Added in schema v2.
  final int? hourlyRateCents;

  /// Fixed payment per worked shift, in cents. Added in schema v4; the
  /// upper bound went from 999 999 to [maxStoredMoneyCents] in v6.
  final int? fixedPlusCents;

  /// Key of the icon (`ShiftIcon.key`), or NULL. Plain text on purpose: a key
  /// this build does not know reads as no icon instead of failing. Added in
  /// schema v3.
  final String? icon;

  /// Opaque id of the system sound the alarm of this type uses; NULL = the
  /// default of the channel. Added in schema v3.
  final String? alarmSound;

  /// Second segment of a split shift: clock minute where it starts and how
  /// long it lasts. Both or none, and only on a shift with times (CHECKs
  /// below). That it fits after the first segment within 24 h is checked by
  /// the domain (`checkSegment2`). Added in schema v3.
  final int? segment2StartMinute;
  final int? segment2DurationMinutes;

  /// Where the shift is worked, free text (not blank, at most
  /// [maxShiftLocationLength]). Added in schema v6.
  final String? location;

  /// Extra pay per hour at night and per hour on a holiday, in the minor
  /// unit of the currency. Added in schema v6.
  final int? nightPlusCentsPerHour;
  final int? holidayPlusCentsPerHour;
  final int sortOrder;
  final bool archived;
  final int createdAt;
  final int updatedAt;
  const ShiftTypeRow({
    required this.id,
    required this.code,
    required this.name,
    required this.colorValue,
    required this.category,
    this.startMinute,
    this.endMinute,
    this.paidMinutes,
    this.nightOverride,
    this.hourlyRateCents,
    this.fixedPlusCents,
    this.icon,
    this.alarmSound,
    this.segment2StartMinute,
    this.segment2DurationMinutes,
    this.location,
    this.nightPlusCentsPerHour,
    this.holidayPlusCentsPerHour,
    required this.sortOrder,
    required this.archived,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['code'] = Variable<String>(code);
    map['name'] = Variable<String>(name);
    map['color_value'] = Variable<int>(colorValue);
    {
      map['category'] = Variable<String>(
        $ShiftTypesTable.$convertercategory.toSql(category),
      );
    }
    if (!nullToAbsent || startMinute != null) {
      map['start_minute'] = Variable<int>(startMinute);
    }
    if (!nullToAbsent || endMinute != null) {
      map['end_minute'] = Variable<int>(endMinute);
    }
    if (!nullToAbsent || paidMinutes != null) {
      map['paid_minutes'] = Variable<int>(paidMinutes);
    }
    if (!nullToAbsent || nightOverride != null) {
      map['night_override'] = Variable<bool>(nightOverride);
    }
    if (!nullToAbsent || hourlyRateCents != null) {
      map['hourly_rate_cents'] = Variable<int>(hourlyRateCents);
    }
    if (!nullToAbsent || fixedPlusCents != null) {
      map['fixed_plus_cents'] = Variable<int>(fixedPlusCents);
    }
    if (!nullToAbsent || icon != null) {
      map['icon'] = Variable<String>(icon);
    }
    if (!nullToAbsent || alarmSound != null) {
      map['alarm_sound'] = Variable<String>(alarmSound);
    }
    if (!nullToAbsent || segment2StartMinute != null) {
      map['segment2_start_minute'] = Variable<int>(segment2StartMinute);
    }
    if (!nullToAbsent || segment2DurationMinutes != null) {
      map['segment2_duration_minutes'] = Variable<int>(segment2DurationMinutes);
    }
    if (!nullToAbsent || location != null) {
      map['location'] = Variable<String>(location);
    }
    if (!nullToAbsent || nightPlusCentsPerHour != null) {
      map['night_plus_cents_per_hour'] = Variable<int>(nightPlusCentsPerHour);
    }
    if (!nullToAbsent || holidayPlusCentsPerHour != null) {
      map['holiday_plus_cents_per_hour'] = Variable<int>(
        holidayPlusCentsPerHour,
      );
    }
    map['sort_order'] = Variable<int>(sortOrder);
    map['archived'] = Variable<bool>(archived);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  ShiftTypesCompanion toCompanion(bool nullToAbsent) {
    return ShiftTypesCompanion(
      id: Value(id),
      code: Value(code),
      name: Value(name),
      colorValue: Value(colorValue),
      category: Value(category),
      startMinute: startMinute == null && nullToAbsent
          ? const Value.absent()
          : Value(startMinute),
      endMinute: endMinute == null && nullToAbsent
          ? const Value.absent()
          : Value(endMinute),
      paidMinutes: paidMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(paidMinutes),
      nightOverride: nightOverride == null && nullToAbsent
          ? const Value.absent()
          : Value(nightOverride),
      hourlyRateCents: hourlyRateCents == null && nullToAbsent
          ? const Value.absent()
          : Value(hourlyRateCents),
      fixedPlusCents: fixedPlusCents == null && nullToAbsent
          ? const Value.absent()
          : Value(fixedPlusCents),
      icon: icon == null && nullToAbsent ? const Value.absent() : Value(icon),
      alarmSound: alarmSound == null && nullToAbsent
          ? const Value.absent()
          : Value(alarmSound),
      segment2StartMinute: segment2StartMinute == null && nullToAbsent
          ? const Value.absent()
          : Value(segment2StartMinute),
      segment2DurationMinutes: segment2DurationMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(segment2DurationMinutes),
      location: location == null && nullToAbsent
          ? const Value.absent()
          : Value(location),
      nightPlusCentsPerHour: nightPlusCentsPerHour == null && nullToAbsent
          ? const Value.absent()
          : Value(nightPlusCentsPerHour),
      holidayPlusCentsPerHour: holidayPlusCentsPerHour == null && nullToAbsent
          ? const Value.absent()
          : Value(holidayPlusCentsPerHour),
      sortOrder: Value(sortOrder),
      archived: Value(archived),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ShiftTypeRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ShiftTypeRow(
      id: serializer.fromJson<String>(json['id']),
      code: serializer.fromJson<String>(json['code']),
      name: serializer.fromJson<String>(json['name']),
      colorValue: serializer.fromJson<int>(json['colorValue']),
      category: $ShiftTypesTable.$convertercategory.fromJson(
        serializer.fromJson<String>(json['category']),
      ),
      startMinute: serializer.fromJson<int?>(json['startMinute']),
      endMinute: serializer.fromJson<int?>(json['endMinute']),
      paidMinutes: serializer.fromJson<int?>(json['paidMinutes']),
      nightOverride: serializer.fromJson<bool?>(json['nightOverride']),
      hourlyRateCents: serializer.fromJson<int?>(json['hourlyRateCents']),
      fixedPlusCents: serializer.fromJson<int?>(json['fixedPlusCents']),
      icon: serializer.fromJson<String?>(json['icon']),
      alarmSound: serializer.fromJson<String?>(json['alarmSound']),
      segment2StartMinute: serializer.fromJson<int?>(
        json['segment2StartMinute'],
      ),
      segment2DurationMinutes: serializer.fromJson<int?>(
        json['segment2DurationMinutes'],
      ),
      location: serializer.fromJson<String?>(json['location']),
      nightPlusCentsPerHour: serializer.fromJson<int?>(
        json['nightPlusCentsPerHour'],
      ),
      holidayPlusCentsPerHour: serializer.fromJson<int?>(
        json['holidayPlusCentsPerHour'],
      ),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      archived: serializer.fromJson<bool>(json['archived']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'code': serializer.toJson<String>(code),
      'name': serializer.toJson<String>(name),
      'colorValue': serializer.toJson<int>(colorValue),
      'category': serializer.toJson<String>(
        $ShiftTypesTable.$convertercategory.toJson(category),
      ),
      'startMinute': serializer.toJson<int?>(startMinute),
      'endMinute': serializer.toJson<int?>(endMinute),
      'paidMinutes': serializer.toJson<int?>(paidMinutes),
      'nightOverride': serializer.toJson<bool?>(nightOverride),
      'hourlyRateCents': serializer.toJson<int?>(hourlyRateCents),
      'fixedPlusCents': serializer.toJson<int?>(fixedPlusCents),
      'icon': serializer.toJson<String?>(icon),
      'alarmSound': serializer.toJson<String?>(alarmSound),
      'segment2StartMinute': serializer.toJson<int?>(segment2StartMinute),
      'segment2DurationMinutes': serializer.toJson<int?>(
        segment2DurationMinutes,
      ),
      'location': serializer.toJson<String?>(location),
      'nightPlusCentsPerHour': serializer.toJson<int?>(nightPlusCentsPerHour),
      'holidayPlusCentsPerHour': serializer.toJson<int?>(
        holidayPlusCentsPerHour,
      ),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'archived': serializer.toJson<bool>(archived),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  ShiftTypeRow copyWith({
    String? id,
    String? code,
    String? name,
    int? colorValue,
    ShiftCategory? category,
    Value<int?> startMinute = const Value.absent(),
    Value<int?> endMinute = const Value.absent(),
    Value<int?> paidMinutes = const Value.absent(),
    Value<bool?> nightOverride = const Value.absent(),
    Value<int?> hourlyRateCents = const Value.absent(),
    Value<int?> fixedPlusCents = const Value.absent(),
    Value<String?> icon = const Value.absent(),
    Value<String?> alarmSound = const Value.absent(),
    Value<int?> segment2StartMinute = const Value.absent(),
    Value<int?> segment2DurationMinutes = const Value.absent(),
    Value<String?> location = const Value.absent(),
    Value<int?> nightPlusCentsPerHour = const Value.absent(),
    Value<int?> holidayPlusCentsPerHour = const Value.absent(),
    int? sortOrder,
    bool? archived,
    int? createdAt,
    int? updatedAt,
  }) => ShiftTypeRow(
    id: id ?? this.id,
    code: code ?? this.code,
    name: name ?? this.name,
    colorValue: colorValue ?? this.colorValue,
    category: category ?? this.category,
    startMinute: startMinute.present ? startMinute.value : this.startMinute,
    endMinute: endMinute.present ? endMinute.value : this.endMinute,
    paidMinutes: paidMinutes.present ? paidMinutes.value : this.paidMinutes,
    nightOverride: nightOverride.present
        ? nightOverride.value
        : this.nightOverride,
    hourlyRateCents: hourlyRateCents.present
        ? hourlyRateCents.value
        : this.hourlyRateCents,
    fixedPlusCents: fixedPlusCents.present
        ? fixedPlusCents.value
        : this.fixedPlusCents,
    icon: icon.present ? icon.value : this.icon,
    alarmSound: alarmSound.present ? alarmSound.value : this.alarmSound,
    segment2StartMinute: segment2StartMinute.present
        ? segment2StartMinute.value
        : this.segment2StartMinute,
    segment2DurationMinutes: segment2DurationMinutes.present
        ? segment2DurationMinutes.value
        : this.segment2DurationMinutes,
    location: location.present ? location.value : this.location,
    nightPlusCentsPerHour: nightPlusCentsPerHour.present
        ? nightPlusCentsPerHour.value
        : this.nightPlusCentsPerHour,
    holidayPlusCentsPerHour: holidayPlusCentsPerHour.present
        ? holidayPlusCentsPerHour.value
        : this.holidayPlusCentsPerHour,
    sortOrder: sortOrder ?? this.sortOrder,
    archived: archived ?? this.archived,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ShiftTypeRow copyWithCompanion(ShiftTypesCompanion data) {
    return ShiftTypeRow(
      id: data.id.present ? data.id.value : this.id,
      code: data.code.present ? data.code.value : this.code,
      name: data.name.present ? data.name.value : this.name,
      colorValue: data.colorValue.present
          ? data.colorValue.value
          : this.colorValue,
      category: data.category.present ? data.category.value : this.category,
      startMinute: data.startMinute.present
          ? data.startMinute.value
          : this.startMinute,
      endMinute: data.endMinute.present ? data.endMinute.value : this.endMinute,
      paidMinutes: data.paidMinutes.present
          ? data.paidMinutes.value
          : this.paidMinutes,
      nightOverride: data.nightOverride.present
          ? data.nightOverride.value
          : this.nightOverride,
      hourlyRateCents: data.hourlyRateCents.present
          ? data.hourlyRateCents.value
          : this.hourlyRateCents,
      fixedPlusCents: data.fixedPlusCents.present
          ? data.fixedPlusCents.value
          : this.fixedPlusCents,
      icon: data.icon.present ? data.icon.value : this.icon,
      alarmSound: data.alarmSound.present
          ? data.alarmSound.value
          : this.alarmSound,
      segment2StartMinute: data.segment2StartMinute.present
          ? data.segment2StartMinute.value
          : this.segment2StartMinute,
      segment2DurationMinutes: data.segment2DurationMinutes.present
          ? data.segment2DurationMinutes.value
          : this.segment2DurationMinutes,
      location: data.location.present ? data.location.value : this.location,
      nightPlusCentsPerHour: data.nightPlusCentsPerHour.present
          ? data.nightPlusCentsPerHour.value
          : this.nightPlusCentsPerHour,
      holidayPlusCentsPerHour: data.holidayPlusCentsPerHour.present
          ? data.holidayPlusCentsPerHour.value
          : this.holidayPlusCentsPerHour,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      archived: data.archived.present ? data.archived.value : this.archived,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ShiftTypeRow(')
          ..write('id: $id, ')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('colorValue: $colorValue, ')
          ..write('category: $category, ')
          ..write('startMinute: $startMinute, ')
          ..write('endMinute: $endMinute, ')
          ..write('paidMinutes: $paidMinutes, ')
          ..write('nightOverride: $nightOverride, ')
          ..write('hourlyRateCents: $hourlyRateCents, ')
          ..write('fixedPlusCents: $fixedPlusCents, ')
          ..write('icon: $icon, ')
          ..write('alarmSound: $alarmSound, ')
          ..write('segment2StartMinute: $segment2StartMinute, ')
          ..write('segment2DurationMinutes: $segment2DurationMinutes, ')
          ..write('location: $location, ')
          ..write('nightPlusCentsPerHour: $nightPlusCentsPerHour, ')
          ..write('holidayPlusCentsPerHour: $holidayPlusCentsPerHour, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('archived: $archived, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    code,
    name,
    colorValue,
    category,
    startMinute,
    endMinute,
    paidMinutes,
    nightOverride,
    hourlyRateCents,
    fixedPlusCents,
    icon,
    alarmSound,
    segment2StartMinute,
    segment2DurationMinutes,
    location,
    nightPlusCentsPerHour,
    holidayPlusCentsPerHour,
    sortOrder,
    archived,
    createdAt,
    updatedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ShiftTypeRow &&
          other.id == this.id &&
          other.code == this.code &&
          other.name == this.name &&
          other.colorValue == this.colorValue &&
          other.category == this.category &&
          other.startMinute == this.startMinute &&
          other.endMinute == this.endMinute &&
          other.paidMinutes == this.paidMinutes &&
          other.nightOverride == this.nightOverride &&
          other.hourlyRateCents == this.hourlyRateCents &&
          other.fixedPlusCents == this.fixedPlusCents &&
          other.icon == this.icon &&
          other.alarmSound == this.alarmSound &&
          other.segment2StartMinute == this.segment2StartMinute &&
          other.segment2DurationMinutes == this.segment2DurationMinutes &&
          other.location == this.location &&
          other.nightPlusCentsPerHour == this.nightPlusCentsPerHour &&
          other.holidayPlusCentsPerHour == this.holidayPlusCentsPerHour &&
          other.sortOrder == this.sortOrder &&
          other.archived == this.archived &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ShiftTypesCompanion extends UpdateCompanion<ShiftTypeRow> {
  final Value<String> id;
  final Value<String> code;
  final Value<String> name;
  final Value<int> colorValue;
  final Value<ShiftCategory> category;
  final Value<int?> startMinute;
  final Value<int?> endMinute;
  final Value<int?> paidMinutes;
  final Value<bool?> nightOverride;
  final Value<int?> hourlyRateCents;
  final Value<int?> fixedPlusCents;
  final Value<String?> icon;
  final Value<String?> alarmSound;
  final Value<int?> segment2StartMinute;
  final Value<int?> segment2DurationMinutes;
  final Value<String?> location;
  final Value<int?> nightPlusCentsPerHour;
  final Value<int?> holidayPlusCentsPerHour;
  final Value<int> sortOrder;
  final Value<bool> archived;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const ShiftTypesCompanion({
    this.id = const Value.absent(),
    this.code = const Value.absent(),
    this.name = const Value.absent(),
    this.colorValue = const Value.absent(),
    this.category = const Value.absent(),
    this.startMinute = const Value.absent(),
    this.endMinute = const Value.absent(),
    this.paidMinutes = const Value.absent(),
    this.nightOverride = const Value.absent(),
    this.hourlyRateCents = const Value.absent(),
    this.fixedPlusCents = const Value.absent(),
    this.icon = const Value.absent(),
    this.alarmSound = const Value.absent(),
    this.segment2StartMinute = const Value.absent(),
    this.segment2DurationMinutes = const Value.absent(),
    this.location = const Value.absent(),
    this.nightPlusCentsPerHour = const Value.absent(),
    this.holidayPlusCentsPerHour = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.archived = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ShiftTypesCompanion.insert({
    required String id,
    required String code,
    required String name,
    required int colorValue,
    required ShiftCategory category,
    this.startMinute = const Value.absent(),
    this.endMinute = const Value.absent(),
    this.paidMinutes = const Value.absent(),
    this.nightOverride = const Value.absent(),
    this.hourlyRateCents = const Value.absent(),
    this.fixedPlusCents = const Value.absent(),
    this.icon = const Value.absent(),
    this.alarmSound = const Value.absent(),
    this.segment2StartMinute = const Value.absent(),
    this.segment2DurationMinutes = const Value.absent(),
    this.location = const Value.absent(),
    this.nightPlusCentsPerHour = const Value.absent(),
    this.holidayPlusCentsPerHour = const Value.absent(),
    required int sortOrder,
    this.archived = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       code = Value(code),
       name = Value(name),
       colorValue = Value(colorValue),
       category = Value(category),
       sortOrder = Value(sortOrder),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ShiftTypeRow> custom({
    Expression<String>? id,
    Expression<String>? code,
    Expression<String>? name,
    Expression<int>? colorValue,
    Expression<String>? category,
    Expression<int>? startMinute,
    Expression<int>? endMinute,
    Expression<int>? paidMinutes,
    Expression<bool>? nightOverride,
    Expression<int>? hourlyRateCents,
    Expression<int>? fixedPlusCents,
    Expression<String>? icon,
    Expression<String>? alarmSound,
    Expression<int>? segment2StartMinute,
    Expression<int>? segment2DurationMinutes,
    Expression<String>? location,
    Expression<int>? nightPlusCentsPerHour,
    Expression<int>? holidayPlusCentsPerHour,
    Expression<int>? sortOrder,
    Expression<bool>? archived,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (code != null) 'code': code,
      if (name != null) 'name': name,
      if (colorValue != null) 'color_value': colorValue,
      if (category != null) 'category': category,
      if (startMinute != null) 'start_minute': startMinute,
      if (endMinute != null) 'end_minute': endMinute,
      if (paidMinutes != null) 'paid_minutes': paidMinutes,
      if (nightOverride != null) 'night_override': nightOverride,
      if (hourlyRateCents != null) 'hourly_rate_cents': hourlyRateCents,
      if (fixedPlusCents != null) 'fixed_plus_cents': fixedPlusCents,
      if (icon != null) 'icon': icon,
      if (alarmSound != null) 'alarm_sound': alarmSound,
      if (segment2StartMinute != null)
        'segment2_start_minute': segment2StartMinute,
      if (segment2DurationMinutes != null)
        'segment2_duration_minutes': segment2DurationMinutes,
      if (location != null) 'location': location,
      if (nightPlusCentsPerHour != null)
        'night_plus_cents_per_hour': nightPlusCentsPerHour,
      if (holidayPlusCentsPerHour != null)
        'holiday_plus_cents_per_hour': holidayPlusCentsPerHour,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (archived != null) 'archived': archived,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ShiftTypesCompanion copyWith({
    Value<String>? id,
    Value<String>? code,
    Value<String>? name,
    Value<int>? colorValue,
    Value<ShiftCategory>? category,
    Value<int?>? startMinute,
    Value<int?>? endMinute,
    Value<int?>? paidMinutes,
    Value<bool?>? nightOverride,
    Value<int?>? hourlyRateCents,
    Value<int?>? fixedPlusCents,
    Value<String?>? icon,
    Value<String?>? alarmSound,
    Value<int?>? segment2StartMinute,
    Value<int?>? segment2DurationMinutes,
    Value<String?>? location,
    Value<int?>? nightPlusCentsPerHour,
    Value<int?>? holidayPlusCentsPerHour,
    Value<int>? sortOrder,
    Value<bool>? archived,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return ShiftTypesCompanion(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      category: category ?? this.category,
      startMinute: startMinute ?? this.startMinute,
      endMinute: endMinute ?? this.endMinute,
      paidMinutes: paidMinutes ?? this.paidMinutes,
      nightOverride: nightOverride ?? this.nightOverride,
      hourlyRateCents: hourlyRateCents ?? this.hourlyRateCents,
      fixedPlusCents: fixedPlusCents ?? this.fixedPlusCents,
      icon: icon ?? this.icon,
      alarmSound: alarmSound ?? this.alarmSound,
      segment2StartMinute: segment2StartMinute ?? this.segment2StartMinute,
      segment2DurationMinutes:
          segment2DurationMinutes ?? this.segment2DurationMinutes,
      location: location ?? this.location,
      nightPlusCentsPerHour:
          nightPlusCentsPerHour ?? this.nightPlusCentsPerHour,
      holidayPlusCentsPerHour:
          holidayPlusCentsPerHour ?? this.holidayPlusCentsPerHour,
      sortOrder: sortOrder ?? this.sortOrder,
      archived: archived ?? this.archived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (colorValue.present) {
      map['color_value'] = Variable<int>(colorValue.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(
        $ShiftTypesTable.$convertercategory.toSql(category.value),
      );
    }
    if (startMinute.present) {
      map['start_minute'] = Variable<int>(startMinute.value);
    }
    if (endMinute.present) {
      map['end_minute'] = Variable<int>(endMinute.value);
    }
    if (paidMinutes.present) {
      map['paid_minutes'] = Variable<int>(paidMinutes.value);
    }
    if (nightOverride.present) {
      map['night_override'] = Variable<bool>(nightOverride.value);
    }
    if (hourlyRateCents.present) {
      map['hourly_rate_cents'] = Variable<int>(hourlyRateCents.value);
    }
    if (fixedPlusCents.present) {
      map['fixed_plus_cents'] = Variable<int>(fixedPlusCents.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (alarmSound.present) {
      map['alarm_sound'] = Variable<String>(alarmSound.value);
    }
    if (segment2StartMinute.present) {
      map['segment2_start_minute'] = Variable<int>(segment2StartMinute.value);
    }
    if (segment2DurationMinutes.present) {
      map['segment2_duration_minutes'] = Variable<int>(
        segment2DurationMinutes.value,
      );
    }
    if (location.present) {
      map['location'] = Variable<String>(location.value);
    }
    if (nightPlusCentsPerHour.present) {
      map['night_plus_cents_per_hour'] = Variable<int>(
        nightPlusCentsPerHour.value,
      );
    }
    if (holidayPlusCentsPerHour.present) {
      map['holiday_plus_cents_per_hour'] = Variable<int>(
        holidayPlusCentsPerHour.value,
      );
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (archived.present) {
      map['archived'] = Variable<bool>(archived.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ShiftTypesCompanion(')
          ..write('id: $id, ')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('colorValue: $colorValue, ')
          ..write('category: $category, ')
          ..write('startMinute: $startMinute, ')
          ..write('endMinute: $endMinute, ')
          ..write('paidMinutes: $paidMinutes, ')
          ..write('nightOverride: $nightOverride, ')
          ..write('hourlyRateCents: $hourlyRateCents, ')
          ..write('fixedPlusCents: $fixedPlusCents, ')
          ..write('icon: $icon, ')
          ..write('alarmSound: $alarmSound, ')
          ..write('segment2StartMinute: $segment2StartMinute, ')
          ..write('segment2DurationMinutes: $segment2DurationMinutes, ')
          ..write('location: $location, ')
          ..write('nightPlusCentsPerHour: $nightPlusCentsPerHour, ')
          ..write('holidayPlusCentsPerHour: $holidayPlusCentsPerHour, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('archived: $archived, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ShiftTypeVersionsTable extends ShiftTypeVersions
    with TableInfo<$ShiftTypeVersionsTable, ShiftTypeVersionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ShiftTypeVersionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _shiftTypeIdMeta = const VerificationMeta(
    'shiftTypeId',
  );
  @override
  late final GeneratedColumn<String> shiftTypeId = GeneratedColumn<String>(
    'shift_type_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES shift_types (id) ON DELETE CASCADE',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<CivilDate, String> untilDate =
      GeneratedColumn<String>(
        'until_date',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<CivilDate>($ShiftTypeVersionsTable.$converteruntilDate);
  @override
  late final GeneratedColumnWithTypeConverter<ShiftCategory, String> category =
      GeneratedColumn<String>(
        'category',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<ShiftCategory>(
        $ShiftTypeVersionsTable.$convertercategory,
      );
  static const VerificationMeta _startMinuteMeta = const VerificationMeta(
    'startMinute',
  );
  @override
  late final GeneratedColumn<int> startMinute = GeneratedColumn<int>(
    'start_minute',
    aliasedName,
    true,
    check: () => ComparableExpr(startMinute).isBetweenValues(0, 1439),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endMinuteMeta = const VerificationMeta(
    'endMinute',
  );
  @override
  late final GeneratedColumn<int> endMinute = GeneratedColumn<int>(
    'end_minute',
    aliasedName,
    true,
    check: () => ComparableExpr(endMinute).isBetweenValues(0, 1439),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _paidMinutesMeta = const VerificationMeta(
    'paidMinutes',
  );
  @override
  late final GeneratedColumn<int> paidMinutes = GeneratedColumn<int>(
    'paid_minutes',
    aliasedName,
    true,
    check: () => ComparableExpr(paidMinutes).isBiggerOrEqualValue(0),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nightOverrideMeta = const VerificationMeta(
    'nightOverride',
  );
  @override
  late final GeneratedColumn<bool> nightOverride = GeneratedColumn<bool>(
    'night_override',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("night_override" IN (0, 1))',
    ),
  );
  static const VerificationMeta _hourlyRateCentsMeta = const VerificationMeta(
    'hourlyRateCents',
  );
  @override
  late final GeneratedColumn<int> hourlyRateCents = GeneratedColumn<int>(
    'hourly_rate_cents',
    aliasedName,
    true,
    check: () =>
        ComparableExpr(hourlyRateCents).isBetweenValues(0, maxStoredMoneyCents),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fixedPlusCentsMeta = const VerificationMeta(
    'fixedPlusCents',
  );
  @override
  late final GeneratedColumn<int> fixedPlusCents = GeneratedColumn<int>(
    'fixed_plus_cents',
    aliasedName,
    true,
    check: () =>
        ComparableExpr(fixedPlusCents).isBetweenValues(0, maxStoredMoneyCents),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _segment2StartMinuteMeta =
      const VerificationMeta('segment2StartMinute');
  @override
  late final GeneratedColumn<int> segment2StartMinute = GeneratedColumn<int>(
    'segment2_start_minute',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _segment2DurationMinutesMeta =
      const VerificationMeta('segment2DurationMinutes');
  @override
  late final GeneratedColumn<int> segment2DurationMinutes =
      GeneratedColumn<int>(
        'segment2_duration_minutes',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _nightPlusCentsPerHourMeta =
      const VerificationMeta('nightPlusCentsPerHour');
  @override
  late final GeneratedColumn<int> nightPlusCentsPerHour = GeneratedColumn<int>(
    'night_plus_cents_per_hour',
    aliasedName,
    true,
    check: () =>
        ComparableExpr(nightPlusCentsPerHour)
            .isBetweenValues(0, maxStoredMoneyCents),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _holidayPlusCentsPerHourMeta =
      const VerificationMeta('holidayPlusCentsPerHour');
  @override
  late final GeneratedColumn<int> holidayPlusCentsPerHour =
      GeneratedColumn<int>(
        'holiday_plus_cents_per_hour',
        aliasedName,
        true,
        check: () =>
            ComparableExpr(holidayPlusCentsPerHour)
                .isBetweenValues(0, maxStoredMoneyCents),
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    shiftTypeId,
    untilDate,
    category,
    startMinute,
    endMinute,
    paidMinutes,
    nightOverride,
    hourlyRateCents,
    fixedPlusCents,
    segment2StartMinute,
    segment2DurationMinutes,
    nightPlusCentsPerHour,
    holidayPlusCentsPerHour,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'shift_type_versions';
  @override
  VerificationContext validateIntegrity(
    Insertable<ShiftTypeVersionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('shift_type_id')) {
      context.handle(
        _shiftTypeIdMeta,
        shiftTypeId.isAcceptableOrUnknown(
          data['shift_type_id']!,
          _shiftTypeIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_shiftTypeIdMeta);
    }
    if (data.containsKey('start_minute')) {
      context.handle(
        _startMinuteMeta,
        startMinute.isAcceptableOrUnknown(
          data['start_minute']!,
          _startMinuteMeta,
        ),
      );
    }
    if (data.containsKey('end_minute')) {
      context.handle(
        _endMinuteMeta,
        endMinute.isAcceptableOrUnknown(data['end_minute']!, _endMinuteMeta),
      );
    }
    if (data.containsKey('paid_minutes')) {
      context.handle(
        _paidMinutesMeta,
        paidMinutes.isAcceptableOrUnknown(
          data['paid_minutes']!,
          _paidMinutesMeta,
        ),
      );
    }
    if (data.containsKey('night_override')) {
      context.handle(
        _nightOverrideMeta,
        nightOverride.isAcceptableOrUnknown(
          data['night_override']!,
          _nightOverrideMeta,
        ),
      );
    }
    if (data.containsKey('hourly_rate_cents')) {
      context.handle(
        _hourlyRateCentsMeta,
        hourlyRateCents.isAcceptableOrUnknown(
          data['hourly_rate_cents']!,
          _hourlyRateCentsMeta,
        ),
      );
    }
    if (data.containsKey('fixed_plus_cents')) {
      context.handle(
        _fixedPlusCentsMeta,
        fixedPlusCents.isAcceptableOrUnknown(
          data['fixed_plus_cents']!,
          _fixedPlusCentsMeta,
        ),
      );
    }
    if (data.containsKey('segment2_start_minute')) {
      context.handle(
        _segment2StartMinuteMeta,
        segment2StartMinute.isAcceptableOrUnknown(
          data['segment2_start_minute']!,
          _segment2StartMinuteMeta,
        ),
      );
    }
    if (data.containsKey('segment2_duration_minutes')) {
      context.handle(
        _segment2DurationMinutesMeta,
        segment2DurationMinutes.isAcceptableOrUnknown(
          data['segment2_duration_minutes']!,
          _segment2DurationMinutesMeta,
        ),
      );
    }
    if (data.containsKey('night_plus_cents_per_hour')) {
      context.handle(
        _nightPlusCentsPerHourMeta,
        nightPlusCentsPerHour.isAcceptableOrUnknown(
          data['night_plus_cents_per_hour']!,
          _nightPlusCentsPerHourMeta,
        ),
      );
    }
    if (data.containsKey('holiday_plus_cents_per_hour')) {
      context.handle(
        _holidayPlusCentsPerHourMeta,
        holidayPlusCentsPerHour.isAcceptableOrUnknown(
          data['holiday_plus_cents_per_hour']!,
          _holidayPlusCentsPerHourMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {shiftTypeId, untilDate};
  @override
  ShiftTypeVersionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ShiftTypeVersionRow(
      shiftTypeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}shift_type_id'],
      )!,
      untilDate: $ShiftTypeVersionsTable.$converteruntilDate.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}until_date'],
        )!,
      ),
      category: $ShiftTypeVersionsTable.$convertercategory.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}category'],
        )!,
      ),
      startMinute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_minute'],
      ),
      endMinute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_minute'],
      ),
      paidMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}paid_minutes'],
      ),
      nightOverride: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}night_override'],
      ),
      hourlyRateCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}hourly_rate_cents'],
      ),
      fixedPlusCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fixed_plus_cents'],
      ),
      segment2StartMinute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}segment2_start_minute'],
      ),
      segment2DurationMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}segment2_duration_minutes'],
      ),
      nightPlusCentsPerHour: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}night_plus_cents_per_hour'],
      ),
      holidayPlusCentsPerHour: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}holiday_plus_cents_per_hour'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ShiftTypeVersionsTable createAlias(String alias) {
    return $ShiftTypeVersionsTable(attachedDatabase, alias);
  }

  static TypeConverter<CivilDate, String> $converteruntilDate =
      const CivilDateConverter();
  static JsonTypeConverter2<ShiftCategory, String, String> $convertercategory =
      const EnumNameConverter<ShiftCategory>(ShiftCategory.values);
}

class ShiftTypeVersionRow extends DataClass
    implements Insertable<ShiftTypeVersionRow> {
  final String shiftTypeId;
  final CivilDate untilDate;
  final ShiftCategory category;
  final int? startMinute;
  final int? endMinute;
  final int? paidMinutes;
  final bool? nightOverride;
  final int? hourlyRateCents;
  final int? fixedPlusCents;
  final int? segment2StartMinute;
  final int? segment2DurationMinutes;

  /// Night and holiday pluses per hour of these terms. Added in schema v6.
  final int? nightPlusCentsPerHour;
  final int? holidayPlusCentsPerHour;
  final int createdAt;
  const ShiftTypeVersionRow({
    required this.shiftTypeId,
    required this.untilDate,
    required this.category,
    this.startMinute,
    this.endMinute,
    this.paidMinutes,
    this.nightOverride,
    this.hourlyRateCents,
    this.fixedPlusCents,
    this.segment2StartMinute,
    this.segment2DurationMinutes,
    this.nightPlusCentsPerHour,
    this.holidayPlusCentsPerHour,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['shift_type_id'] = Variable<String>(shiftTypeId);
    {
      map['until_date'] = Variable<String>(
        $ShiftTypeVersionsTable.$converteruntilDate.toSql(untilDate),
      );
    }
    {
      map['category'] = Variable<String>(
        $ShiftTypeVersionsTable.$convertercategory.toSql(category),
      );
    }
    if (!nullToAbsent || startMinute != null) {
      map['start_minute'] = Variable<int>(startMinute);
    }
    if (!nullToAbsent || endMinute != null) {
      map['end_minute'] = Variable<int>(endMinute);
    }
    if (!nullToAbsent || paidMinutes != null) {
      map['paid_minutes'] = Variable<int>(paidMinutes);
    }
    if (!nullToAbsent || nightOverride != null) {
      map['night_override'] = Variable<bool>(nightOverride);
    }
    if (!nullToAbsent || hourlyRateCents != null) {
      map['hourly_rate_cents'] = Variable<int>(hourlyRateCents);
    }
    if (!nullToAbsent || fixedPlusCents != null) {
      map['fixed_plus_cents'] = Variable<int>(fixedPlusCents);
    }
    if (!nullToAbsent || segment2StartMinute != null) {
      map['segment2_start_minute'] = Variable<int>(segment2StartMinute);
    }
    if (!nullToAbsent || segment2DurationMinutes != null) {
      map['segment2_duration_minutes'] = Variable<int>(segment2DurationMinutes);
    }
    if (!nullToAbsent || nightPlusCentsPerHour != null) {
      map['night_plus_cents_per_hour'] = Variable<int>(nightPlusCentsPerHour);
    }
    if (!nullToAbsent || holidayPlusCentsPerHour != null) {
      map['holiday_plus_cents_per_hour'] = Variable<int>(
        holidayPlusCentsPerHour,
      );
    }
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  ShiftTypeVersionsCompanion toCompanion(bool nullToAbsent) {
    return ShiftTypeVersionsCompanion(
      shiftTypeId: Value(shiftTypeId),
      untilDate: Value(untilDate),
      category: Value(category),
      startMinute: startMinute == null && nullToAbsent
          ? const Value.absent()
          : Value(startMinute),
      endMinute: endMinute == null && nullToAbsent
          ? const Value.absent()
          : Value(endMinute),
      paidMinutes: paidMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(paidMinutes),
      nightOverride: nightOverride == null && nullToAbsent
          ? const Value.absent()
          : Value(nightOverride),
      hourlyRateCents: hourlyRateCents == null && nullToAbsent
          ? const Value.absent()
          : Value(hourlyRateCents),
      fixedPlusCents: fixedPlusCents == null && nullToAbsent
          ? const Value.absent()
          : Value(fixedPlusCents),
      segment2StartMinute: segment2StartMinute == null && nullToAbsent
          ? const Value.absent()
          : Value(segment2StartMinute),
      segment2DurationMinutes: segment2DurationMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(segment2DurationMinutes),
      nightPlusCentsPerHour: nightPlusCentsPerHour == null && nullToAbsent
          ? const Value.absent()
          : Value(nightPlusCentsPerHour),
      holidayPlusCentsPerHour: holidayPlusCentsPerHour == null && nullToAbsent
          ? const Value.absent()
          : Value(holidayPlusCentsPerHour),
      createdAt: Value(createdAt),
    );
  }

  factory ShiftTypeVersionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ShiftTypeVersionRow(
      shiftTypeId: serializer.fromJson<String>(json['shiftTypeId']),
      untilDate: serializer.fromJson<CivilDate>(json['untilDate']),
      category: $ShiftTypeVersionsTable.$convertercategory.fromJson(
        serializer.fromJson<String>(json['category']),
      ),
      startMinute: serializer.fromJson<int?>(json['startMinute']),
      endMinute: serializer.fromJson<int?>(json['endMinute']),
      paidMinutes: serializer.fromJson<int?>(json['paidMinutes']),
      nightOverride: serializer.fromJson<bool?>(json['nightOverride']),
      hourlyRateCents: serializer.fromJson<int?>(json['hourlyRateCents']),
      fixedPlusCents: serializer.fromJson<int?>(json['fixedPlusCents']),
      segment2StartMinute: serializer.fromJson<int?>(
        json['segment2StartMinute'],
      ),
      segment2DurationMinutes: serializer.fromJson<int?>(
        json['segment2DurationMinutes'],
      ),
      nightPlusCentsPerHour: serializer.fromJson<int?>(
        json['nightPlusCentsPerHour'],
      ),
      holidayPlusCentsPerHour: serializer.fromJson<int?>(
        json['holidayPlusCentsPerHour'],
      ),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'shiftTypeId': serializer.toJson<String>(shiftTypeId),
      'untilDate': serializer.toJson<CivilDate>(untilDate),
      'category': serializer.toJson<String>(
        $ShiftTypeVersionsTable.$convertercategory.toJson(category),
      ),
      'startMinute': serializer.toJson<int?>(startMinute),
      'endMinute': serializer.toJson<int?>(endMinute),
      'paidMinutes': serializer.toJson<int?>(paidMinutes),
      'nightOverride': serializer.toJson<bool?>(nightOverride),
      'hourlyRateCents': serializer.toJson<int?>(hourlyRateCents),
      'fixedPlusCents': serializer.toJson<int?>(fixedPlusCents),
      'segment2StartMinute': serializer.toJson<int?>(segment2StartMinute),
      'segment2DurationMinutes': serializer.toJson<int?>(
        segment2DurationMinutes,
      ),
      'nightPlusCentsPerHour': serializer.toJson<int?>(nightPlusCentsPerHour),
      'holidayPlusCentsPerHour': serializer.toJson<int?>(
        holidayPlusCentsPerHour,
      ),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  ShiftTypeVersionRow copyWith({
    String? shiftTypeId,
    CivilDate? untilDate,
    ShiftCategory? category,
    Value<int?> startMinute = const Value.absent(),
    Value<int?> endMinute = const Value.absent(),
    Value<int?> paidMinutes = const Value.absent(),
    Value<bool?> nightOverride = const Value.absent(),
    Value<int?> hourlyRateCents = const Value.absent(),
    Value<int?> fixedPlusCents = const Value.absent(),
    Value<int?> segment2StartMinute = const Value.absent(),
    Value<int?> segment2DurationMinutes = const Value.absent(),
    Value<int?> nightPlusCentsPerHour = const Value.absent(),
    Value<int?> holidayPlusCentsPerHour = const Value.absent(),
    int? createdAt,
  }) => ShiftTypeVersionRow(
    shiftTypeId: shiftTypeId ?? this.shiftTypeId,
    untilDate: untilDate ?? this.untilDate,
    category: category ?? this.category,
    startMinute: startMinute.present ? startMinute.value : this.startMinute,
    endMinute: endMinute.present ? endMinute.value : this.endMinute,
    paidMinutes: paidMinutes.present ? paidMinutes.value : this.paidMinutes,
    nightOverride: nightOverride.present
        ? nightOverride.value
        : this.nightOverride,
    hourlyRateCents: hourlyRateCents.present
        ? hourlyRateCents.value
        : this.hourlyRateCents,
    fixedPlusCents: fixedPlusCents.present
        ? fixedPlusCents.value
        : this.fixedPlusCents,
    segment2StartMinute: segment2StartMinute.present
        ? segment2StartMinute.value
        : this.segment2StartMinute,
    segment2DurationMinutes: segment2DurationMinutes.present
        ? segment2DurationMinutes.value
        : this.segment2DurationMinutes,
    nightPlusCentsPerHour: nightPlusCentsPerHour.present
        ? nightPlusCentsPerHour.value
        : this.nightPlusCentsPerHour,
    holidayPlusCentsPerHour: holidayPlusCentsPerHour.present
        ? holidayPlusCentsPerHour.value
        : this.holidayPlusCentsPerHour,
    createdAt: createdAt ?? this.createdAt,
  );
  ShiftTypeVersionRow copyWithCompanion(ShiftTypeVersionsCompanion data) {
    return ShiftTypeVersionRow(
      shiftTypeId: data.shiftTypeId.present
          ? data.shiftTypeId.value
          : this.shiftTypeId,
      untilDate: data.untilDate.present ? data.untilDate.value : this.untilDate,
      category: data.category.present ? data.category.value : this.category,
      startMinute: data.startMinute.present
          ? data.startMinute.value
          : this.startMinute,
      endMinute: data.endMinute.present ? data.endMinute.value : this.endMinute,
      paidMinutes: data.paidMinutes.present
          ? data.paidMinutes.value
          : this.paidMinutes,
      nightOverride: data.nightOverride.present
          ? data.nightOverride.value
          : this.nightOverride,
      hourlyRateCents: data.hourlyRateCents.present
          ? data.hourlyRateCents.value
          : this.hourlyRateCents,
      fixedPlusCents: data.fixedPlusCents.present
          ? data.fixedPlusCents.value
          : this.fixedPlusCents,
      segment2StartMinute: data.segment2StartMinute.present
          ? data.segment2StartMinute.value
          : this.segment2StartMinute,
      segment2DurationMinutes: data.segment2DurationMinutes.present
          ? data.segment2DurationMinutes.value
          : this.segment2DurationMinutes,
      nightPlusCentsPerHour: data.nightPlusCentsPerHour.present
          ? data.nightPlusCentsPerHour.value
          : this.nightPlusCentsPerHour,
      holidayPlusCentsPerHour: data.holidayPlusCentsPerHour.present
          ? data.holidayPlusCentsPerHour.value
          : this.holidayPlusCentsPerHour,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ShiftTypeVersionRow(')
          ..write('shiftTypeId: $shiftTypeId, ')
          ..write('untilDate: $untilDate, ')
          ..write('category: $category, ')
          ..write('startMinute: $startMinute, ')
          ..write('endMinute: $endMinute, ')
          ..write('paidMinutes: $paidMinutes, ')
          ..write('nightOverride: $nightOverride, ')
          ..write('hourlyRateCents: $hourlyRateCents, ')
          ..write('fixedPlusCents: $fixedPlusCents, ')
          ..write('segment2StartMinute: $segment2StartMinute, ')
          ..write('segment2DurationMinutes: $segment2DurationMinutes, ')
          ..write('nightPlusCentsPerHour: $nightPlusCentsPerHour, ')
          ..write('holidayPlusCentsPerHour: $holidayPlusCentsPerHour, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    shiftTypeId,
    untilDate,
    category,
    startMinute,
    endMinute,
    paidMinutes,
    nightOverride,
    hourlyRateCents,
    fixedPlusCents,
    segment2StartMinute,
    segment2DurationMinutes,
    nightPlusCentsPerHour,
    holidayPlusCentsPerHour,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ShiftTypeVersionRow &&
          other.shiftTypeId == this.shiftTypeId &&
          other.untilDate == this.untilDate &&
          other.category == this.category &&
          other.startMinute == this.startMinute &&
          other.endMinute == this.endMinute &&
          other.paidMinutes == this.paidMinutes &&
          other.nightOverride == this.nightOverride &&
          other.hourlyRateCents == this.hourlyRateCents &&
          other.fixedPlusCents == this.fixedPlusCents &&
          other.segment2StartMinute == this.segment2StartMinute &&
          other.segment2DurationMinutes == this.segment2DurationMinutes &&
          other.nightPlusCentsPerHour == this.nightPlusCentsPerHour &&
          other.holidayPlusCentsPerHour == this.holidayPlusCentsPerHour &&
          other.createdAt == this.createdAt);
}

class ShiftTypeVersionsCompanion extends UpdateCompanion<ShiftTypeVersionRow> {
  final Value<String> shiftTypeId;
  final Value<CivilDate> untilDate;
  final Value<ShiftCategory> category;
  final Value<int?> startMinute;
  final Value<int?> endMinute;
  final Value<int?> paidMinutes;
  final Value<bool?> nightOverride;
  final Value<int?> hourlyRateCents;
  final Value<int?> fixedPlusCents;
  final Value<int?> segment2StartMinute;
  final Value<int?> segment2DurationMinutes;
  final Value<int?> nightPlusCentsPerHour;
  final Value<int?> holidayPlusCentsPerHour;
  final Value<int> createdAt;
  final Value<int> rowid;
  const ShiftTypeVersionsCompanion({
    this.shiftTypeId = const Value.absent(),
    this.untilDate = const Value.absent(),
    this.category = const Value.absent(),
    this.startMinute = const Value.absent(),
    this.endMinute = const Value.absent(),
    this.paidMinutes = const Value.absent(),
    this.nightOverride = const Value.absent(),
    this.hourlyRateCents = const Value.absent(),
    this.fixedPlusCents = const Value.absent(),
    this.segment2StartMinute = const Value.absent(),
    this.segment2DurationMinutes = const Value.absent(),
    this.nightPlusCentsPerHour = const Value.absent(),
    this.holidayPlusCentsPerHour = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ShiftTypeVersionsCompanion.insert({
    required String shiftTypeId,
    required CivilDate untilDate,
    required ShiftCategory category,
    this.startMinute = const Value.absent(),
    this.endMinute = const Value.absent(),
    this.paidMinutes = const Value.absent(),
    this.nightOverride = const Value.absent(),
    this.hourlyRateCents = const Value.absent(),
    this.fixedPlusCents = const Value.absent(),
    this.segment2StartMinute = const Value.absent(),
    this.segment2DurationMinutes = const Value.absent(),
    this.nightPlusCentsPerHour = const Value.absent(),
    this.holidayPlusCentsPerHour = const Value.absent(),
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : shiftTypeId = Value(shiftTypeId),
       untilDate = Value(untilDate),
       category = Value(category),
       createdAt = Value(createdAt);
  static Insertable<ShiftTypeVersionRow> custom({
    Expression<String>? shiftTypeId,
    Expression<String>? untilDate,
    Expression<String>? category,
    Expression<int>? startMinute,
    Expression<int>? endMinute,
    Expression<int>? paidMinutes,
    Expression<bool>? nightOverride,
    Expression<int>? hourlyRateCents,
    Expression<int>? fixedPlusCents,
    Expression<int>? segment2StartMinute,
    Expression<int>? segment2DurationMinutes,
    Expression<int>? nightPlusCentsPerHour,
    Expression<int>? holidayPlusCentsPerHour,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (shiftTypeId != null) 'shift_type_id': shiftTypeId,
      if (untilDate != null) 'until_date': untilDate,
      if (category != null) 'category': category,
      if (startMinute != null) 'start_minute': startMinute,
      if (endMinute != null) 'end_minute': endMinute,
      if (paidMinutes != null) 'paid_minutes': paidMinutes,
      if (nightOverride != null) 'night_override': nightOverride,
      if (hourlyRateCents != null) 'hourly_rate_cents': hourlyRateCents,
      if (fixedPlusCents != null) 'fixed_plus_cents': fixedPlusCents,
      if (segment2StartMinute != null)
        'segment2_start_minute': segment2StartMinute,
      if (segment2DurationMinutes != null)
        'segment2_duration_minutes': segment2DurationMinutes,
      if (nightPlusCentsPerHour != null)
        'night_plus_cents_per_hour': nightPlusCentsPerHour,
      if (holidayPlusCentsPerHour != null)
        'holiday_plus_cents_per_hour': holidayPlusCentsPerHour,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ShiftTypeVersionsCompanion copyWith({
    Value<String>? shiftTypeId,
    Value<CivilDate>? untilDate,
    Value<ShiftCategory>? category,
    Value<int?>? startMinute,
    Value<int?>? endMinute,
    Value<int?>? paidMinutes,
    Value<bool?>? nightOverride,
    Value<int?>? hourlyRateCents,
    Value<int?>? fixedPlusCents,
    Value<int?>? segment2StartMinute,
    Value<int?>? segment2DurationMinutes,
    Value<int?>? nightPlusCentsPerHour,
    Value<int?>? holidayPlusCentsPerHour,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return ShiftTypeVersionsCompanion(
      shiftTypeId: shiftTypeId ?? this.shiftTypeId,
      untilDate: untilDate ?? this.untilDate,
      category: category ?? this.category,
      startMinute: startMinute ?? this.startMinute,
      endMinute: endMinute ?? this.endMinute,
      paidMinutes: paidMinutes ?? this.paidMinutes,
      nightOverride: nightOverride ?? this.nightOverride,
      hourlyRateCents: hourlyRateCents ?? this.hourlyRateCents,
      fixedPlusCents: fixedPlusCents ?? this.fixedPlusCents,
      segment2StartMinute: segment2StartMinute ?? this.segment2StartMinute,
      segment2DurationMinutes:
          segment2DurationMinutes ?? this.segment2DurationMinutes,
      nightPlusCentsPerHour:
          nightPlusCentsPerHour ?? this.nightPlusCentsPerHour,
      holidayPlusCentsPerHour:
          holidayPlusCentsPerHour ?? this.holidayPlusCentsPerHour,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (shiftTypeId.present) {
      map['shift_type_id'] = Variable<String>(shiftTypeId.value);
    }
    if (untilDate.present) {
      map['until_date'] = Variable<String>(
        $ShiftTypeVersionsTable.$converteruntilDate.toSql(untilDate.value),
      );
    }
    if (category.present) {
      map['category'] = Variable<String>(
        $ShiftTypeVersionsTable.$convertercategory.toSql(category.value),
      );
    }
    if (startMinute.present) {
      map['start_minute'] = Variable<int>(startMinute.value);
    }
    if (endMinute.present) {
      map['end_minute'] = Variable<int>(endMinute.value);
    }
    if (paidMinutes.present) {
      map['paid_minutes'] = Variable<int>(paidMinutes.value);
    }
    if (nightOverride.present) {
      map['night_override'] = Variable<bool>(nightOverride.value);
    }
    if (hourlyRateCents.present) {
      map['hourly_rate_cents'] = Variable<int>(hourlyRateCents.value);
    }
    if (fixedPlusCents.present) {
      map['fixed_plus_cents'] = Variable<int>(fixedPlusCents.value);
    }
    if (segment2StartMinute.present) {
      map['segment2_start_minute'] = Variable<int>(segment2StartMinute.value);
    }
    if (segment2DurationMinutes.present) {
      map['segment2_duration_minutes'] = Variable<int>(
        segment2DurationMinutes.value,
      );
    }
    if (nightPlusCentsPerHour.present) {
      map['night_plus_cents_per_hour'] = Variable<int>(
        nightPlusCentsPerHour.value,
      );
    }
    if (holidayPlusCentsPerHour.present) {
      map['holiday_plus_cents_per_hour'] = Variable<int>(
        holidayPlusCentsPerHour.value,
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ShiftTypeVersionsCompanion(')
          ..write('shiftTypeId: $shiftTypeId, ')
          ..write('untilDate: $untilDate, ')
          ..write('category: $category, ')
          ..write('startMinute: $startMinute, ')
          ..write('endMinute: $endMinute, ')
          ..write('paidMinutes: $paidMinutes, ')
          ..write('nightOverride: $nightOverride, ')
          ..write('hourlyRateCents: $hourlyRateCents, ')
          ..write('fixedPlusCents: $fixedPlusCents, ')
          ..write('segment2StartMinute: $segment2StartMinute, ')
          ..write('segment2DurationMinutes: $segment2DurationMinutes, ')
          ..write('nightPlusCentsPerHour: $nightPlusCentsPerHour, ')
          ..write('holidayPlusCentsPerHour: $holidayPlusCentsPerHour, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PatternsTable extends Patterns
    with TableInfo<$PatternsTable, PatternRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PatternsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<List<String>>, String>
  steps = GeneratedColumn<String>(
    'steps',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<List<List<String>>>($PatternsTable.$convertersteps);
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, steps, createdAt, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'patterns';
  @override
  VerificationContext validateIntegrity(
    Insertable<PatternRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PatternRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PatternRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      steps: $PatternsTable.$convertersteps.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}steps'],
        )!,
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $PatternsTable createAlias(String alias) {
    return $PatternsTable(attachedDatabase, alias);
  }

  static TypeConverter<List<List<String>>, String> $convertersteps =
      const StepsConverter();
}

class PatternRow extends DataClass implements Insertable<PatternRow> {
  final String id;
  final String name;

  /// JSON `[[id, ...], ...]`, at least one step.
  final List<List<String>> steps;
  final int createdAt;
  final int updatedAt;
  const PatternRow({
    required this.id,
    required this.name,
    required this.steps,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    {
      map['steps'] = Variable<String>(
        $PatternsTable.$convertersteps.toSql(steps),
      );
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  PatternsCompanion toCompanion(bool nullToAbsent) {
    return PatternsCompanion(
      id: Value(id),
      name: Value(name),
      steps: Value(steps),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory PatternRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PatternRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      steps: serializer.fromJson<List<List<String>>>(json['steps']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'steps': serializer.toJson<List<List<String>>>(steps),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  PatternRow copyWith({
    String? id,
    String? name,
    List<List<String>>? steps,
    int? createdAt,
    int? updatedAt,
  }) => PatternRow(
    id: id ?? this.id,
    name: name ?? this.name,
    steps: steps ?? this.steps,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  PatternRow copyWithCompanion(PatternsCompanion data) {
    return PatternRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      steps: data.steps.present ? data.steps.value : this.steps,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PatternRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('steps: $steps, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, steps, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PatternRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.steps == this.steps &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class PatternsCompanion extends UpdateCompanion<PatternRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<List<List<String>>> steps;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const PatternsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.steps = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PatternsCompanion.insert({
    required String id,
    required String name,
    required List<List<String>> steps,
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       steps = Value(steps),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<PatternRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? steps,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (steps != null) 'steps': steps,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PatternsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<List<List<String>>>? steps,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return PatternsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      steps: steps ?? this.steps,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (steps.present) {
      map['steps'] = Variable<String>(
        $PatternsTable.$convertersteps.toSql(steps.value),
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PatternsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('steps: $steps, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PatternRunsTable extends PatternRuns
    with TableInfo<$PatternRunsTable, PatternRunRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PatternRunsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _calendarIdMeta = const VerificationMeta(
    'calendarId',
  );
  @override
  late final GeneratedColumn<String> calendarId = GeneratedColumn<String>(
    'calendar_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES calendars (id)',
    ),
  );
  static const VerificationMeta _patternIdMeta = const VerificationMeta(
    'patternId',
  );
  @override
  late final GeneratedColumn<String> patternId = GeneratedColumn<String>(
    'pattern_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES patterns (id)',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<CivilDate, String> startDate =
      GeneratedColumn<String>(
        'start_date',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<CivilDate>($PatternRunsTable.$converterstartDate);
  @override
  late final GeneratedColumnWithTypeConverter<CivilDate?, String> endDate =
      GeneratedColumn<String>(
        'end_date',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<CivilDate?>($PatternRunsTable.$converterendDaten);
  static const VerificationMeta _stepOffsetMeta = const VerificationMeta(
    'stepOffset',
  );
  @override
  late final GeneratedColumn<int> stepOffset = GeneratedColumn<int>(
    'step_offset',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    calendarId,
    patternId,
    startDate,
    endDate,
    stepOffset,
    seq,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pattern_runs';
  @override
  VerificationContext validateIntegrity(
    Insertable<PatternRunRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('calendar_id')) {
      context.handle(
        _calendarIdMeta,
        calendarId.isAcceptableOrUnknown(data['calendar_id']!, _calendarIdMeta),
      );
    } else if (isInserting) {
      context.missing(_calendarIdMeta);
    }
    if (data.containsKey('pattern_id')) {
      context.handle(
        _patternIdMeta,
        patternId.isAcceptableOrUnknown(data['pattern_id']!, _patternIdMeta),
      );
    } else if (isInserting) {
      context.missing(_patternIdMeta);
    }
    if (data.containsKey('step_offset')) {
      context.handle(
        _stepOffsetMeta,
        stepOffset.isAcceptableOrUnknown(data['step_offset']!, _stepOffsetMeta),
      );
    }
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    } else if (isInserting) {
      context.missing(_seqMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PatternRunRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PatternRunRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      calendarId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}calendar_id'],
      )!,
      patternId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pattern_id'],
      )!,
      startDate: $PatternRunsTable.$converterstartDate.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}start_date'],
        )!,
      ),
      endDate: $PatternRunsTable.$converterendDaten.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}end_date'],
        ),
      ),
      stepOffset: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}step_offset'],
      )!,
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $PatternRunsTable createAlias(String alias) {
    return $PatternRunsTable(attachedDatabase, alias);
  }

  static TypeConverter<CivilDate, String> $converterstartDate =
      const CivilDateConverter();
  static TypeConverter<CivilDate, String> $converterendDate =
      const CivilDateConverter();
  static TypeConverter<CivilDate?, String?> $converterendDaten =
      NullAwareTypeConverter.wrap($converterendDate);
}

class PatternRunRow extends DataClass implements Insertable<PatternRunRow> {
  final String id;

  /// Calendar the run belongs to (schema v2).
  final String calendarId;
  final String patternId;
  final CivilDate startDate;
  final CivilDate? endDate;
  final int stepOffset;
  final int seq;
  final int createdAt;
  const PatternRunRow({
    required this.id,
    required this.calendarId,
    required this.patternId,
    required this.startDate,
    this.endDate,
    required this.stepOffset,
    required this.seq,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['calendar_id'] = Variable<String>(calendarId);
    map['pattern_id'] = Variable<String>(patternId);
    {
      map['start_date'] = Variable<String>(
        $PatternRunsTable.$converterstartDate.toSql(startDate),
      );
    }
    if (!nullToAbsent || endDate != null) {
      map['end_date'] = Variable<String>(
        $PatternRunsTable.$converterendDaten.toSql(endDate),
      );
    }
    map['step_offset'] = Variable<int>(stepOffset);
    map['seq'] = Variable<int>(seq);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  PatternRunsCompanion toCompanion(bool nullToAbsent) {
    return PatternRunsCompanion(
      id: Value(id),
      calendarId: Value(calendarId),
      patternId: Value(patternId),
      startDate: Value(startDate),
      endDate: endDate == null && nullToAbsent
          ? const Value.absent()
          : Value(endDate),
      stepOffset: Value(stepOffset),
      seq: Value(seq),
      createdAt: Value(createdAt),
    );
  }

  factory PatternRunRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PatternRunRow(
      id: serializer.fromJson<String>(json['id']),
      calendarId: serializer.fromJson<String>(json['calendarId']),
      patternId: serializer.fromJson<String>(json['patternId']),
      startDate: serializer.fromJson<CivilDate>(json['startDate']),
      endDate: serializer.fromJson<CivilDate?>(json['endDate']),
      stepOffset: serializer.fromJson<int>(json['stepOffset']),
      seq: serializer.fromJson<int>(json['seq']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'calendarId': serializer.toJson<String>(calendarId),
      'patternId': serializer.toJson<String>(patternId),
      'startDate': serializer.toJson<CivilDate>(startDate),
      'endDate': serializer.toJson<CivilDate?>(endDate),
      'stepOffset': serializer.toJson<int>(stepOffset),
      'seq': serializer.toJson<int>(seq),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  PatternRunRow copyWith({
    String? id,
    String? calendarId,
    String? patternId,
    CivilDate? startDate,
    Value<CivilDate?> endDate = const Value.absent(),
    int? stepOffset,
    int? seq,
    int? createdAt,
  }) => PatternRunRow(
    id: id ?? this.id,
    calendarId: calendarId ?? this.calendarId,
    patternId: patternId ?? this.patternId,
    startDate: startDate ?? this.startDate,
    endDate: endDate.present ? endDate.value : this.endDate,
    stepOffset: stepOffset ?? this.stepOffset,
    seq: seq ?? this.seq,
    createdAt: createdAt ?? this.createdAt,
  );
  PatternRunRow copyWithCompanion(PatternRunsCompanion data) {
    return PatternRunRow(
      id: data.id.present ? data.id.value : this.id,
      calendarId: data.calendarId.present
          ? data.calendarId.value
          : this.calendarId,
      patternId: data.patternId.present ? data.patternId.value : this.patternId,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      endDate: data.endDate.present ? data.endDate.value : this.endDate,
      stepOffset: data.stepOffset.present
          ? data.stepOffset.value
          : this.stepOffset,
      seq: data.seq.present ? data.seq.value : this.seq,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PatternRunRow(')
          ..write('id: $id, ')
          ..write('calendarId: $calendarId, ')
          ..write('patternId: $patternId, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('stepOffset: $stepOffset, ')
          ..write('seq: $seq, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    calendarId,
    patternId,
    startDate,
    endDate,
    stepOffset,
    seq,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PatternRunRow &&
          other.id == this.id &&
          other.calendarId == this.calendarId &&
          other.patternId == this.patternId &&
          other.startDate == this.startDate &&
          other.endDate == this.endDate &&
          other.stepOffset == this.stepOffset &&
          other.seq == this.seq &&
          other.createdAt == this.createdAt);
}

class PatternRunsCompanion extends UpdateCompanion<PatternRunRow> {
  final Value<String> id;
  final Value<String> calendarId;
  final Value<String> patternId;
  final Value<CivilDate> startDate;
  final Value<CivilDate?> endDate;
  final Value<int> stepOffset;
  final Value<int> seq;
  final Value<int> createdAt;
  final Value<int> rowid;
  const PatternRunsCompanion({
    this.id = const Value.absent(),
    this.calendarId = const Value.absent(),
    this.patternId = const Value.absent(),
    this.startDate = const Value.absent(),
    this.endDate = const Value.absent(),
    this.stepOffset = const Value.absent(),
    this.seq = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PatternRunsCompanion.insert({
    required String id,
    required String calendarId,
    required String patternId,
    required CivilDate startDate,
    this.endDate = const Value.absent(),
    this.stepOffset = const Value.absent(),
    required int seq,
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       calendarId = Value(calendarId),
       patternId = Value(patternId),
       startDate = Value(startDate),
       seq = Value(seq),
       createdAt = Value(createdAt);
  static Insertable<PatternRunRow> custom({
    Expression<String>? id,
    Expression<String>? calendarId,
    Expression<String>? patternId,
    Expression<String>? startDate,
    Expression<String>? endDate,
    Expression<int>? stepOffset,
    Expression<int>? seq,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (calendarId != null) 'calendar_id': calendarId,
      if (patternId != null) 'pattern_id': patternId,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (stepOffset != null) 'step_offset': stepOffset,
      if (seq != null) 'seq': seq,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PatternRunsCompanion copyWith({
    Value<String>? id,
    Value<String>? calendarId,
    Value<String>? patternId,
    Value<CivilDate>? startDate,
    Value<CivilDate?>? endDate,
    Value<int>? stepOffset,
    Value<int>? seq,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return PatternRunsCompanion(
      id: id ?? this.id,
      calendarId: calendarId ?? this.calendarId,
      patternId: patternId ?? this.patternId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      stepOffset: stepOffset ?? this.stepOffset,
      seq: seq ?? this.seq,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (calendarId.present) {
      map['calendar_id'] = Variable<String>(calendarId.value);
    }
    if (patternId.present) {
      map['pattern_id'] = Variable<String>(patternId.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<String>(
        $PatternRunsTable.$converterstartDate.toSql(startDate.value),
      );
    }
    if (endDate.present) {
      map['end_date'] = Variable<String>(
        $PatternRunsTable.$converterendDaten.toSql(endDate.value),
      );
    }
    if (stepOffset.present) {
      map['step_offset'] = Variable<int>(stepOffset.value);
    }
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PatternRunsCompanion(')
          ..write('id: $id, ')
          ..write('calendarId: $calendarId, ')
          ..write('patternId: $patternId, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('stepOffset: $stepOffset, ')
          ..write('seq: $seq, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DayEntriesTable extends DayEntries
    with TableInfo<$DayEntriesTable, DayEntryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DayEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _calendarIdMeta = const VerificationMeta(
    'calendarId',
  );
  @override
  late final GeneratedColumn<String> calendarId = GeneratedColumn<String>(
    'calendar_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES calendars (id)',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<CivilDate, String> date =
      GeneratedColumn<String>(
        'date',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<CivilDate>($DayEntriesTable.$converterdate);
  @override
  late final GeneratedColumnWithTypeConverter<List<String>?, String>
  shiftTypeIds = GeneratedColumn<String>(
    'shift_type_ids',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  ).withConverter<List<String>?>($DayEntriesTable.$convertershiftTypeIdsn);
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteReminderMinuteMeta =
      const VerificationMeta('noteReminderMinute');
  @override
  late final GeneratedColumn<int> noteReminderMinute = GeneratedColumn<int>(
    'note_reminder_minute',
    aliasedName,
    true,
    check: () => ComparableExpr(noteReminderMinute).isBetweenValues(0, 1439),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _overtimeMinutesMeta = const VerificationMeta(
    'overtimeMinutes',
  );
  @override
  late final GeneratedColumn<int> overtimeMinutes = GeneratedColumn<int>(
    'overtime_minutes',
    aliasedName,
    true,
    check: () => ComparableExpr(overtimeMinutes).isBiggerOrEqualValue(0),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _earlyLeaveMinutesMeta = const VerificationMeta(
    'earlyLeaveMinutes',
  );
  @override
  late final GeneratedColumn<int> earlyLeaveMinutes = GeneratedColumn<int>(
    'early_leave_minutes',
    aliasedName,
    true,
    check: () => ComparableExpr(earlyLeaveMinutes).isBiggerOrEqualValue(0),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _extraAmountCentsMeta = const VerificationMeta(
    'extraAmountCents',
  );
  @override
  late final GeneratedColumn<int> extraAmountCents = GeneratedColumn<int>(
    'extra_amount_cents',
    aliasedName,
    true,
    check: () =>
        ComparableExpr(extraAmountCents)
            .isBetweenValues(-maxStoredMoneyCents, maxStoredMoneyCents),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    calendarId,
    date,
    shiftTypeIds,
    note,
    updatedAt,
    noteReminderMinute,
    overtimeMinutes,
    earlyLeaveMinutes,
    extraAmountCents,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'day_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<DayEntryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('calendar_id')) {
      context.handle(
        _calendarIdMeta,
        calendarId.isAcceptableOrUnknown(data['calendar_id']!, _calendarIdMeta),
      );
    } else if (isInserting) {
      context.missing(_calendarIdMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('note_reminder_minute')) {
      context.handle(
        _noteReminderMinuteMeta,
        noteReminderMinute.isAcceptableOrUnknown(
          data['note_reminder_minute']!,
          _noteReminderMinuteMeta,
        ),
      );
    }
    if (data.containsKey('overtime_minutes')) {
      context.handle(
        _overtimeMinutesMeta,
        overtimeMinutes.isAcceptableOrUnknown(
          data['overtime_minutes']!,
          _overtimeMinutesMeta,
        ),
      );
    }
    if (data.containsKey('early_leave_minutes')) {
      context.handle(
        _earlyLeaveMinutesMeta,
        earlyLeaveMinutes.isAcceptableOrUnknown(
          data['early_leave_minutes']!,
          _earlyLeaveMinutesMeta,
        ),
      );
    }
    if (data.containsKey('extra_amount_cents')) {
      context.handle(
        _extraAmountCentsMeta,
        extraAmountCents.isAcceptableOrUnknown(
          data['extra_amount_cents']!,
          _extraAmountCentsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {calendarId, date};
  @override
  DayEntryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DayEntryRow(
      calendarId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}calendar_id'],
      )!,
      date: $DayEntriesTable.$converterdate.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}date'],
        )!,
      ),
      shiftTypeIds: $DayEntriesTable.$convertershiftTypeIdsn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}shift_type_ids'],
        ),
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      noteReminderMinute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}note_reminder_minute'],
      ),
      overtimeMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}overtime_minutes'],
      ),
      earlyLeaveMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}early_leave_minutes'],
      ),
      extraAmountCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}extra_amount_cents'],
      ),
    );
  }

  @override
  $DayEntriesTable createAlias(String alias) {
    return $DayEntriesTable(attachedDatabase, alias);
  }

  static TypeConverter<CivilDate, String> $converterdate =
      const CivilDateConverter();
  static TypeConverter<List<String>, String> $convertershiftTypeIds =
      const StringListConverter();
  static TypeConverter<List<String>?, String?> $convertershiftTypeIdsn =
      NullAwareTypeConverter.wrap($convertershiftTypeIds);
}

class DayEntryRow extends DataClass implements Insertable<DayEntryRow> {
  /// Calendar the day belongs to (schema v2: the key is calendar + date).
  final String calendarId;
  final CivilDate date;

  /// JSON list. NULL = does not replace the pattern; `[]` = empty day. A row
  /// exists only if the day holds something (override, note, reminder,
  /// overtime or early leave).
  final List<String>? shiftTypeIds;
  final String? note;
  final int updatedAt;

  /// Minute of this civil day (0-1439) at which the note rings. Added in
  /// schema v3.
  final int? noteReminderMinute;

  /// Extra minutes worked this day (>= 0). Added in schema v3; since schema
  /// v7 the extra hours are blocks ([OvertimeBlocks]): the step to v7 turns
  /// every value into a block and leaves the column NULL, and nothing writes
  /// it again (kept so the older steps and backups stay as they were).
  final int? overtimeMinutes;

  /// Minutes left before the end of the shift (>= 0). Added in schema v3.
  final int? earlyLeaveMinutes;

  /// Extra money of the day (allowances, bonus; negative for a deduction),
  /// in the minor unit of the currency. Added in schema v6.
  final int? extraAmountCents;
  const DayEntryRow({
    required this.calendarId,
    required this.date,
    this.shiftTypeIds,
    this.note,
    required this.updatedAt,
    this.noteReminderMinute,
    this.overtimeMinutes,
    this.earlyLeaveMinutes,
    this.extraAmountCents,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['calendar_id'] = Variable<String>(calendarId);
    {
      map['date'] = Variable<String>(
        $DayEntriesTable.$converterdate.toSql(date),
      );
    }
    if (!nullToAbsent || shiftTypeIds != null) {
      map['shift_type_ids'] = Variable<String>(
        $DayEntriesTable.$convertershiftTypeIdsn.toSql(shiftTypeIds),
      );
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || noteReminderMinute != null) {
      map['note_reminder_minute'] = Variable<int>(noteReminderMinute);
    }
    if (!nullToAbsent || overtimeMinutes != null) {
      map['overtime_minutes'] = Variable<int>(overtimeMinutes);
    }
    if (!nullToAbsent || earlyLeaveMinutes != null) {
      map['early_leave_minutes'] = Variable<int>(earlyLeaveMinutes);
    }
    if (!nullToAbsent || extraAmountCents != null) {
      map['extra_amount_cents'] = Variable<int>(extraAmountCents);
    }
    return map;
  }

  DayEntriesCompanion toCompanion(bool nullToAbsent) {
    return DayEntriesCompanion(
      calendarId: Value(calendarId),
      date: Value(date),
      shiftTypeIds: shiftTypeIds == null && nullToAbsent
          ? const Value.absent()
          : Value(shiftTypeIds),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      updatedAt: Value(updatedAt),
      noteReminderMinute: noteReminderMinute == null && nullToAbsent
          ? const Value.absent()
          : Value(noteReminderMinute),
      overtimeMinutes: overtimeMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(overtimeMinutes),
      earlyLeaveMinutes: earlyLeaveMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(earlyLeaveMinutes),
      extraAmountCents: extraAmountCents == null && nullToAbsent
          ? const Value.absent()
          : Value(extraAmountCents),
    );
  }

  factory DayEntryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DayEntryRow(
      calendarId: serializer.fromJson<String>(json['calendarId']),
      date: serializer.fromJson<CivilDate>(json['date']),
      shiftTypeIds: serializer.fromJson<List<String>?>(json['shiftTypeIds']),
      note: serializer.fromJson<String?>(json['note']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      noteReminderMinute: serializer.fromJson<int?>(json['noteReminderMinute']),
      overtimeMinutes: serializer.fromJson<int?>(json['overtimeMinutes']),
      earlyLeaveMinutes: serializer.fromJson<int?>(json['earlyLeaveMinutes']),
      extraAmountCents: serializer.fromJson<int?>(json['extraAmountCents']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'calendarId': serializer.toJson<String>(calendarId),
      'date': serializer.toJson<CivilDate>(date),
      'shiftTypeIds': serializer.toJson<List<String>?>(shiftTypeIds),
      'note': serializer.toJson<String?>(note),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'noteReminderMinute': serializer.toJson<int?>(noteReminderMinute),
      'overtimeMinutes': serializer.toJson<int?>(overtimeMinutes),
      'earlyLeaveMinutes': serializer.toJson<int?>(earlyLeaveMinutes),
      'extraAmountCents': serializer.toJson<int?>(extraAmountCents),
    };
  }

  DayEntryRow copyWith({
    String? calendarId,
    CivilDate? date,
    Value<List<String>?> shiftTypeIds = const Value.absent(),
    Value<String?> note = const Value.absent(),
    int? updatedAt,
    Value<int?> noteReminderMinute = const Value.absent(),
    Value<int?> overtimeMinutes = const Value.absent(),
    Value<int?> earlyLeaveMinutes = const Value.absent(),
    Value<int?> extraAmountCents = const Value.absent(),
  }) => DayEntryRow(
    calendarId: calendarId ?? this.calendarId,
    date: date ?? this.date,
    shiftTypeIds: shiftTypeIds.present ? shiftTypeIds.value : this.shiftTypeIds,
    note: note.present ? note.value : this.note,
    updatedAt: updatedAt ?? this.updatedAt,
    noteReminderMinute: noteReminderMinute.present
        ? noteReminderMinute.value
        : this.noteReminderMinute,
    overtimeMinutes: overtimeMinutes.present
        ? overtimeMinutes.value
        : this.overtimeMinutes,
    earlyLeaveMinutes: earlyLeaveMinutes.present
        ? earlyLeaveMinutes.value
        : this.earlyLeaveMinutes,
    extraAmountCents: extraAmountCents.present
        ? extraAmountCents.value
        : this.extraAmountCents,
  );
  DayEntryRow copyWithCompanion(DayEntriesCompanion data) {
    return DayEntryRow(
      calendarId: data.calendarId.present
          ? data.calendarId.value
          : this.calendarId,
      date: data.date.present ? data.date.value : this.date,
      shiftTypeIds: data.shiftTypeIds.present
          ? data.shiftTypeIds.value
          : this.shiftTypeIds,
      note: data.note.present ? data.note.value : this.note,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      noteReminderMinute: data.noteReminderMinute.present
          ? data.noteReminderMinute.value
          : this.noteReminderMinute,
      overtimeMinutes: data.overtimeMinutes.present
          ? data.overtimeMinutes.value
          : this.overtimeMinutes,
      earlyLeaveMinutes: data.earlyLeaveMinutes.present
          ? data.earlyLeaveMinutes.value
          : this.earlyLeaveMinutes,
      extraAmountCents: data.extraAmountCents.present
          ? data.extraAmountCents.value
          : this.extraAmountCents,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DayEntryRow(')
          ..write('calendarId: $calendarId, ')
          ..write('date: $date, ')
          ..write('shiftTypeIds: $shiftTypeIds, ')
          ..write('note: $note, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('noteReminderMinute: $noteReminderMinute, ')
          ..write('overtimeMinutes: $overtimeMinutes, ')
          ..write('earlyLeaveMinutes: $earlyLeaveMinutes, ')
          ..write('extraAmountCents: $extraAmountCents')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    calendarId,
    date,
    shiftTypeIds,
    note,
    updatedAt,
    noteReminderMinute,
    overtimeMinutes,
    earlyLeaveMinutes,
    extraAmountCents,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DayEntryRow &&
          other.calendarId == this.calendarId &&
          other.date == this.date &&
          other.shiftTypeIds == this.shiftTypeIds &&
          other.note == this.note &&
          other.updatedAt == this.updatedAt &&
          other.noteReminderMinute == this.noteReminderMinute &&
          other.overtimeMinutes == this.overtimeMinutes &&
          other.earlyLeaveMinutes == this.earlyLeaveMinutes &&
          other.extraAmountCents == this.extraAmountCents);
}

class DayEntriesCompanion extends UpdateCompanion<DayEntryRow> {
  final Value<String> calendarId;
  final Value<CivilDate> date;
  final Value<List<String>?> shiftTypeIds;
  final Value<String?> note;
  final Value<int> updatedAt;
  final Value<int?> noteReminderMinute;
  final Value<int?> overtimeMinutes;
  final Value<int?> earlyLeaveMinutes;
  final Value<int?> extraAmountCents;
  final Value<int> rowid;
  const DayEntriesCompanion({
    this.calendarId = const Value.absent(),
    this.date = const Value.absent(),
    this.shiftTypeIds = const Value.absent(),
    this.note = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.noteReminderMinute = const Value.absent(),
    this.overtimeMinutes = const Value.absent(),
    this.earlyLeaveMinutes = const Value.absent(),
    this.extraAmountCents = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DayEntriesCompanion.insert({
    required String calendarId,
    required CivilDate date,
    this.shiftTypeIds = const Value.absent(),
    this.note = const Value.absent(),
    required int updatedAt,
    this.noteReminderMinute = const Value.absent(),
    this.overtimeMinutes = const Value.absent(),
    this.earlyLeaveMinutes = const Value.absent(),
    this.extraAmountCents = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : calendarId = Value(calendarId),
       date = Value(date),
       updatedAt = Value(updatedAt);
  static Insertable<DayEntryRow> custom({
    Expression<String>? calendarId,
    Expression<String>? date,
    Expression<String>? shiftTypeIds,
    Expression<String>? note,
    Expression<int>? updatedAt,
    Expression<int>? noteReminderMinute,
    Expression<int>? overtimeMinutes,
    Expression<int>? earlyLeaveMinutes,
    Expression<int>? extraAmountCents,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (calendarId != null) 'calendar_id': calendarId,
      if (date != null) 'date': date,
      if (shiftTypeIds != null) 'shift_type_ids': shiftTypeIds,
      if (note != null) 'note': note,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (noteReminderMinute != null)
        'note_reminder_minute': noteReminderMinute,
      if (overtimeMinutes != null) 'overtime_minutes': overtimeMinutes,
      if (earlyLeaveMinutes != null) 'early_leave_minutes': earlyLeaveMinutes,
      if (extraAmountCents != null) 'extra_amount_cents': extraAmountCents,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DayEntriesCompanion copyWith({
    Value<String>? calendarId,
    Value<CivilDate>? date,
    Value<List<String>?>? shiftTypeIds,
    Value<String?>? note,
    Value<int>? updatedAt,
    Value<int?>? noteReminderMinute,
    Value<int?>? overtimeMinutes,
    Value<int?>? earlyLeaveMinutes,
    Value<int?>? extraAmountCents,
    Value<int>? rowid,
  }) {
    return DayEntriesCompanion(
      calendarId: calendarId ?? this.calendarId,
      date: date ?? this.date,
      shiftTypeIds: shiftTypeIds ?? this.shiftTypeIds,
      note: note ?? this.note,
      updatedAt: updatedAt ?? this.updatedAt,
      noteReminderMinute: noteReminderMinute ?? this.noteReminderMinute,
      overtimeMinutes: overtimeMinutes ?? this.overtimeMinutes,
      earlyLeaveMinutes: earlyLeaveMinutes ?? this.earlyLeaveMinutes,
      extraAmountCents: extraAmountCents ?? this.extraAmountCents,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (calendarId.present) {
      map['calendar_id'] = Variable<String>(calendarId.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(
        $DayEntriesTable.$converterdate.toSql(date.value),
      );
    }
    if (shiftTypeIds.present) {
      map['shift_type_ids'] = Variable<String>(
        $DayEntriesTable.$convertershiftTypeIdsn.toSql(shiftTypeIds.value),
      );
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (noteReminderMinute.present) {
      map['note_reminder_minute'] = Variable<int>(noteReminderMinute.value);
    }
    if (overtimeMinutes.present) {
      map['overtime_minutes'] = Variable<int>(overtimeMinutes.value);
    }
    if (earlyLeaveMinutes.present) {
      map['early_leave_minutes'] = Variable<int>(earlyLeaveMinutes.value);
    }
    if (extraAmountCents.present) {
      map['extra_amount_cents'] = Variable<int>(extraAmountCents.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DayEntriesCompanion(')
          ..write('calendarId: $calendarId, ')
          ..write('date: $date, ')
          ..write('shiftTypeIds: $shiftTypeIds, ')
          ..write('note: $note, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('noteReminderMinute: $noteReminderMinute, ')
          ..write('overtimeMinutes: $overtimeMinutes, ')
          ..write('earlyLeaveMinutes: $earlyLeaveMinutes, ')
          ..write('extraAmountCents: $extraAmountCents, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NoteAttachmentsTable extends NoteAttachments
    with TableInfo<$NoteAttachmentsTable, NoteAttachmentRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NoteAttachmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _calendarIdMeta = const VerificationMeta(
    'calendarId',
  );
  @override
  late final GeneratedColumn<String> calendarId = GeneratedColumn<String>(
    'calendar_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES calendars (id) ON DELETE CASCADE',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<CivilDate, String> date =
      GeneratedColumn<String>(
        'date',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<CivilDate>($NoteAttachmentsTable.$converterdate);
  @override
  late final GeneratedColumnWithTypeConverter<AttachmentKind, String> kind =
      GeneratedColumn<String>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<AttachmentKind>($NoteAttachmentsTable.$converterkind);
  static const VerificationMeta _relativePathMeta = const VerificationMeta(
    'relativePath',
  );
  @override
  late final GeneratedColumn<String> relativePath = GeneratedColumn<String>(
    'relative_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mimeTypeMeta = const VerificationMeta(
    'mimeType',
  );
  @override
  late final GeneratedColumn<String> mimeType = GeneratedColumn<String>(
    'mime_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sizeBytesMeta = const VerificationMeta(
    'sizeBytes',
  );
  @override
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
    'size_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sha256Meta = const VerificationMeta('sha256');
  @override
  late final GeneratedColumn<String> sha256 = GeneratedColumn<String>(
    'sha256',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    calendarId,
    date,
    kind,
    relativePath,
    mimeType,
    sizeBytes,
    sha256,
    displayName,
    sortOrder,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'note_attachments';
  @override
  VerificationContext validateIntegrity(
    Insertable<NoteAttachmentRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('calendar_id')) {
      context.handle(
        _calendarIdMeta,
        calendarId.isAcceptableOrUnknown(data['calendar_id']!, _calendarIdMeta),
      );
    } else if (isInserting) {
      context.missing(_calendarIdMeta);
    }
    if (data.containsKey('relative_path')) {
      context.handle(
        _relativePathMeta,
        relativePath.isAcceptableOrUnknown(
          data['relative_path']!,
          _relativePathMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_relativePathMeta);
    }
    if (data.containsKey('mime_type')) {
      context.handle(
        _mimeTypeMeta,
        mimeType.isAcceptableOrUnknown(data['mime_type']!, _mimeTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_mimeTypeMeta);
    }
    if (data.containsKey('size_bytes')) {
      context.handle(
        _sizeBytesMeta,
        sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta),
      );
    } else if (isInserting) {
      context.missing(_sizeBytesMeta);
    }
    if (data.containsKey('sha256')) {
      context.handle(
        _sha256Meta,
        sha256.isAcceptableOrUnknown(data['sha256']!, _sha256Meta),
      );
    } else if (isInserting) {
      context.missing(_sha256Meta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  NoteAttachmentRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NoteAttachmentRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      calendarId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}calendar_id'],
      )!,
      date: $NoteAttachmentsTable.$converterdate.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}date'],
        )!,
      ),
      kind: $NoteAttachmentsTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
      relativePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}relative_path'],
      )!,
      mimeType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime_type'],
      )!,
      sizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size_bytes'],
      )!,
      sha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sha256'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $NoteAttachmentsTable createAlias(String alias) {
    return $NoteAttachmentsTable(attachedDatabase, alias);
  }

  static TypeConverter<CivilDate, String> $converterdate =
      const CivilDateConverter();
  static JsonTypeConverter2<AttachmentKind, String, String> $converterkind =
      const EnumNameConverter<AttachmentKind>(AttachmentKind.values);
}

class NoteAttachmentRow extends DataClass
    implements Insertable<NoteAttachmentRow> {
  final String id;
  final String calendarId;
  final CivilDate date;
  final AttachmentKind kind;

  /// Relative to `<Application Support>/attachments/`. Unique ignoring
  /// case (constraint below): APFS does not tell `a.jpg` from `A.jpg`.
  final String relativePath;
  final String mimeType;
  final int sizeBytes;

  /// Lowercase hex SHA-256 of the file.
  final String sha256;
  final String? displayName;
  final int sortOrder;
  final int createdAt;
  const NoteAttachmentRow({
    required this.id,
    required this.calendarId,
    required this.date,
    required this.kind,
    required this.relativePath,
    required this.mimeType,
    required this.sizeBytes,
    required this.sha256,
    this.displayName,
    required this.sortOrder,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['calendar_id'] = Variable<String>(calendarId);
    {
      map['date'] = Variable<String>(
        $NoteAttachmentsTable.$converterdate.toSql(date),
      );
    }
    {
      map['kind'] = Variable<String>(
        $NoteAttachmentsTable.$converterkind.toSql(kind),
      );
    }
    map['relative_path'] = Variable<String>(relativePath);
    map['mime_type'] = Variable<String>(mimeType);
    map['size_bytes'] = Variable<int>(sizeBytes);
    map['sha256'] = Variable<String>(sha256);
    if (!nullToAbsent || displayName != null) {
      map['display_name'] = Variable<String>(displayName);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  NoteAttachmentsCompanion toCompanion(bool nullToAbsent) {
    return NoteAttachmentsCompanion(
      id: Value(id),
      calendarId: Value(calendarId),
      date: Value(date),
      kind: Value(kind),
      relativePath: Value(relativePath),
      mimeType: Value(mimeType),
      sizeBytes: Value(sizeBytes),
      sha256: Value(sha256),
      displayName: displayName == null && nullToAbsent
          ? const Value.absent()
          : Value(displayName),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
    );
  }

  factory NoteAttachmentRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NoteAttachmentRow(
      id: serializer.fromJson<String>(json['id']),
      calendarId: serializer.fromJson<String>(json['calendarId']),
      date: serializer.fromJson<CivilDate>(json['date']),
      kind: $NoteAttachmentsTable.$converterkind.fromJson(
        serializer.fromJson<String>(json['kind']),
      ),
      relativePath: serializer.fromJson<String>(json['relativePath']),
      mimeType: serializer.fromJson<String>(json['mimeType']),
      sizeBytes: serializer.fromJson<int>(json['sizeBytes']),
      sha256: serializer.fromJson<String>(json['sha256']),
      displayName: serializer.fromJson<String?>(json['displayName']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'calendarId': serializer.toJson<String>(calendarId),
      'date': serializer.toJson<CivilDate>(date),
      'kind': serializer.toJson<String>(
        $NoteAttachmentsTable.$converterkind.toJson(kind),
      ),
      'relativePath': serializer.toJson<String>(relativePath),
      'mimeType': serializer.toJson<String>(mimeType),
      'sizeBytes': serializer.toJson<int>(sizeBytes),
      'sha256': serializer.toJson<String>(sha256),
      'displayName': serializer.toJson<String?>(displayName),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  NoteAttachmentRow copyWith({
    String? id,
    String? calendarId,
    CivilDate? date,
    AttachmentKind? kind,
    String? relativePath,
    String? mimeType,
    int? sizeBytes,
    String? sha256,
    Value<String?> displayName = const Value.absent(),
    int? sortOrder,
    int? createdAt,
  }) => NoteAttachmentRow(
    id: id ?? this.id,
    calendarId: calendarId ?? this.calendarId,
    date: date ?? this.date,
    kind: kind ?? this.kind,
    relativePath: relativePath ?? this.relativePath,
    mimeType: mimeType ?? this.mimeType,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    sha256: sha256 ?? this.sha256,
    displayName: displayName.present ? displayName.value : this.displayName,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
  );
  NoteAttachmentRow copyWithCompanion(NoteAttachmentsCompanion data) {
    return NoteAttachmentRow(
      id: data.id.present ? data.id.value : this.id,
      calendarId: data.calendarId.present
          ? data.calendarId.value
          : this.calendarId,
      date: data.date.present ? data.date.value : this.date,
      kind: data.kind.present ? data.kind.value : this.kind,
      relativePath: data.relativePath.present
          ? data.relativePath.value
          : this.relativePath,
      mimeType: data.mimeType.present ? data.mimeType.value : this.mimeType,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      sha256: data.sha256.present ? data.sha256.value : this.sha256,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NoteAttachmentRow(')
          ..write('id: $id, ')
          ..write('calendarId: $calendarId, ')
          ..write('date: $date, ')
          ..write('kind: $kind, ')
          ..write('relativePath: $relativePath, ')
          ..write('mimeType: $mimeType, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('sha256: $sha256, ')
          ..write('displayName: $displayName, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    calendarId,
    date,
    kind,
    relativePath,
    mimeType,
    sizeBytes,
    sha256,
    displayName,
    sortOrder,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NoteAttachmentRow &&
          other.id == this.id &&
          other.calendarId == this.calendarId &&
          other.date == this.date &&
          other.kind == this.kind &&
          other.relativePath == this.relativePath &&
          other.mimeType == this.mimeType &&
          other.sizeBytes == this.sizeBytes &&
          other.sha256 == this.sha256 &&
          other.displayName == this.displayName &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt);
}

class NoteAttachmentsCompanion extends UpdateCompanion<NoteAttachmentRow> {
  final Value<String> id;
  final Value<String> calendarId;
  final Value<CivilDate> date;
  final Value<AttachmentKind> kind;
  final Value<String> relativePath;
  final Value<String> mimeType;
  final Value<int> sizeBytes;
  final Value<String> sha256;
  final Value<String?> displayName;
  final Value<int> sortOrder;
  final Value<int> createdAt;
  final Value<int> rowid;
  const NoteAttachmentsCompanion({
    this.id = const Value.absent(),
    this.calendarId = const Value.absent(),
    this.date = const Value.absent(),
    this.kind = const Value.absent(),
    this.relativePath = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.sha256 = const Value.absent(),
    this.displayName = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NoteAttachmentsCompanion.insert({
    required String id,
    required String calendarId,
    required CivilDate date,
    required AttachmentKind kind,
    required String relativePath,
    required String mimeType,
    required int sizeBytes,
    required String sha256,
    this.displayName = const Value.absent(),
    this.sortOrder = const Value.absent(),
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       calendarId = Value(calendarId),
       date = Value(date),
       kind = Value(kind),
       relativePath = Value(relativePath),
       mimeType = Value(mimeType),
       sizeBytes = Value(sizeBytes),
       sha256 = Value(sha256),
       createdAt = Value(createdAt);
  static Insertable<NoteAttachmentRow> custom({
    Expression<String>? id,
    Expression<String>? calendarId,
    Expression<String>? date,
    Expression<String>? kind,
    Expression<String>? relativePath,
    Expression<String>? mimeType,
    Expression<int>? sizeBytes,
    Expression<String>? sha256,
    Expression<String>? displayName,
    Expression<int>? sortOrder,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (calendarId != null) 'calendar_id': calendarId,
      if (date != null) 'date': date,
      if (kind != null) 'kind': kind,
      if (relativePath != null) 'relative_path': relativePath,
      if (mimeType != null) 'mime_type': mimeType,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (sha256 != null) 'sha256': sha256,
      if (displayName != null) 'display_name': displayName,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NoteAttachmentsCompanion copyWith({
    Value<String>? id,
    Value<String>? calendarId,
    Value<CivilDate>? date,
    Value<AttachmentKind>? kind,
    Value<String>? relativePath,
    Value<String>? mimeType,
    Value<int>? sizeBytes,
    Value<String>? sha256,
    Value<String?>? displayName,
    Value<int>? sortOrder,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return NoteAttachmentsCompanion(
      id: id ?? this.id,
      calendarId: calendarId ?? this.calendarId,
      date: date ?? this.date,
      kind: kind ?? this.kind,
      relativePath: relativePath ?? this.relativePath,
      mimeType: mimeType ?? this.mimeType,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      sha256: sha256 ?? this.sha256,
      displayName: displayName ?? this.displayName,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (calendarId.present) {
      map['calendar_id'] = Variable<String>(calendarId.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(
        $NoteAttachmentsTable.$converterdate.toSql(date.value),
      );
    }
    if (kind.present) {
      map['kind'] = Variable<String>(
        $NoteAttachmentsTable.$converterkind.toSql(kind.value),
      );
    }
    if (relativePath.present) {
      map['relative_path'] = Variable<String>(relativePath.value);
    }
    if (mimeType.present) {
      map['mime_type'] = Variable<String>(mimeType.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (sha256.present) {
      map['sha256'] = Variable<String>(sha256.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NoteAttachmentsCompanion(')
          ..write('id: $id, ')
          ..write('calendarId: $calendarId, ')
          ..write('date: $date, ')
          ..write('kind: $kind, ')
          ..write('relativePath: $relativePath, ')
          ..write('mimeType: $mimeType, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('sha256: $sha256, ')
          ..write('displayName: $displayName, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DayTasksTable extends DayTasks
    with TableInfo<$DayTasksTable, DayTaskRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DayTasksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _calendarIdMeta = const VerificationMeta(
    'calendarId',
  );
  @override
  late final GeneratedColumn<String> calendarId = GeneratedColumn<String>(
    'calendar_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES calendars (id) ON DELETE CASCADE',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<CivilDate, String> date =
      GeneratedColumn<String>(
        'date',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<CivilDate>($DayTasksTable.$converterdate);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _doneMeta = const VerificationMeta('done');
  @override
  late final GeneratedColumn<bool> done = GeneratedColumn<bool>(
    'done',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("done" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    calendarId,
    date,
    title,
    done,
    sortOrder,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'day_tasks';
  @override
  VerificationContext validateIntegrity(
    Insertable<DayTaskRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('calendar_id')) {
      context.handle(
        _calendarIdMeta,
        calendarId.isAcceptableOrUnknown(data['calendar_id']!, _calendarIdMeta),
      );
    } else if (isInserting) {
      context.missing(_calendarIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('done')) {
      context.handle(
        _doneMeta,
        done.isAcceptableOrUnknown(data['done']!, _doneMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DayTaskRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DayTaskRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      calendarId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}calendar_id'],
      )!,
      date: $DayTasksTable.$converterdate.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}date'],
        )!,
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      done: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}done'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $DayTasksTable createAlias(String alias) {
    return $DayTasksTable(attachedDatabase, alias);
  }

  static TypeConverter<CivilDate, String> $converterdate =
      const CivilDateConverter();
}

class DayTaskRow extends DataClass implements Insertable<DayTaskRow> {
  final String id;
  final String calendarId;
  final CivilDate date;
  final String title;
  final bool done;
  final int sortOrder;
  final int createdAt;
  final int updatedAt;
  const DayTaskRow({
    required this.id,
    required this.calendarId,
    required this.date,
    required this.title,
    required this.done,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['calendar_id'] = Variable<String>(calendarId);
    {
      map['date'] = Variable<String>($DayTasksTable.$converterdate.toSql(date));
    }
    map['title'] = Variable<String>(title);
    map['done'] = Variable<bool>(done);
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  DayTasksCompanion toCompanion(bool nullToAbsent) {
    return DayTasksCompanion(
      id: Value(id),
      calendarId: Value(calendarId),
      date: Value(date),
      title: Value(title),
      done: Value(done),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory DayTaskRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DayTaskRow(
      id: serializer.fromJson<String>(json['id']),
      calendarId: serializer.fromJson<String>(json['calendarId']),
      date: serializer.fromJson<CivilDate>(json['date']),
      title: serializer.fromJson<String>(json['title']),
      done: serializer.fromJson<bool>(json['done']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'calendarId': serializer.toJson<String>(calendarId),
      'date': serializer.toJson<CivilDate>(date),
      'title': serializer.toJson<String>(title),
      'done': serializer.toJson<bool>(done),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  DayTaskRow copyWith({
    String? id,
    String? calendarId,
    CivilDate? date,
    String? title,
    bool? done,
    int? sortOrder,
    int? createdAt,
    int? updatedAt,
  }) => DayTaskRow(
    id: id ?? this.id,
    calendarId: calendarId ?? this.calendarId,
    date: date ?? this.date,
    title: title ?? this.title,
    done: done ?? this.done,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  DayTaskRow copyWithCompanion(DayTasksCompanion data) {
    return DayTaskRow(
      id: data.id.present ? data.id.value : this.id,
      calendarId: data.calendarId.present
          ? data.calendarId.value
          : this.calendarId,
      date: data.date.present ? data.date.value : this.date,
      title: data.title.present ? data.title.value : this.title,
      done: data.done.present ? data.done.value : this.done,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DayTaskRow(')
          ..write('id: $id, ')
          ..write('calendarId: $calendarId, ')
          ..write('date: $date, ')
          ..write('title: $title, ')
          ..write('done: $done, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    calendarId,
    date,
    title,
    done,
    sortOrder,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DayTaskRow &&
          other.id == this.id &&
          other.calendarId == this.calendarId &&
          other.date == this.date &&
          other.title == this.title &&
          other.done == this.done &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class DayTasksCompanion extends UpdateCompanion<DayTaskRow> {
  final Value<String> id;
  final Value<String> calendarId;
  final Value<CivilDate> date;
  final Value<String> title;
  final Value<bool> done;
  final Value<int> sortOrder;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const DayTasksCompanion({
    this.id = const Value.absent(),
    this.calendarId = const Value.absent(),
    this.date = const Value.absent(),
    this.title = const Value.absent(),
    this.done = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DayTasksCompanion.insert({
    required String id,
    required String calendarId,
    required CivilDate date,
    required String title,
    this.done = const Value.absent(),
    this.sortOrder = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       calendarId = Value(calendarId),
       date = Value(date),
       title = Value(title),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<DayTaskRow> custom({
    Expression<String>? id,
    Expression<String>? calendarId,
    Expression<String>? date,
    Expression<String>? title,
    Expression<bool>? done,
    Expression<int>? sortOrder,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (calendarId != null) 'calendar_id': calendarId,
      if (date != null) 'date': date,
      if (title != null) 'title': title,
      if (done != null) 'done': done,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DayTasksCompanion copyWith({
    Value<String>? id,
    Value<String>? calendarId,
    Value<CivilDate>? date,
    Value<String>? title,
    Value<bool>? done,
    Value<int>? sortOrder,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return DayTasksCompanion(
      id: id ?? this.id,
      calendarId: calendarId ?? this.calendarId,
      date: date ?? this.date,
      title: title ?? this.title,
      done: done ?? this.done,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (calendarId.present) {
      map['calendar_id'] = Variable<String>(calendarId.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(
        $DayTasksTable.$converterdate.toSql(date.value),
      );
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (done.present) {
      map['done'] = Variable<bool>(done.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DayTasksCompanion(')
          ..write('id: $id, ')
          ..write('calendarId: $calendarId, ')
          ..write('date: $date, ')
          ..write('title: $title, ')
          ..write('done: $done, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ShiftSwapsTable extends ShiftSwaps
    with TableInfo<$ShiftSwapsTable, ShiftSwapRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ShiftSwapsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _calendarIdMeta = const VerificationMeta(
    'calendarId',
  );
  @override
  late final GeneratedColumn<String> calendarId = GeneratedColumn<String>(
    'calendar_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES calendars (id) ON DELETE CASCADE',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<CivilDate, String> date =
      GeneratedColumn<String>(
        'date',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<CivilDate>($ShiftSwapsTable.$converterdate);
  static const VerificationMeta _colleagueMeta = const VerificationMeta(
    'colleague',
  );
  @override
  late final GeneratedColumn<String> colleague = GeneratedColumn<String>(
    'colleague',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<SwapDirection, String> direction =
      GeneratedColumn<String>(
        'direction',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<SwapDirection>($ShiftSwapsTable.$converterdirection);
  @override
  late final GeneratedColumnWithTypeConverter<List<String>?, String>
  givenShiftTypeIds = GeneratedColumn<String>(
    'given_shift_type_ids',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  ).withConverter<List<String>?>($ShiftSwapsTable.$convertergivenShiftTypeIdsn);
  @override
  late final GeneratedColumnWithTypeConverter<List<String>?, String>
  receivedShiftTypeIds =
      GeneratedColumn<String>(
        'received_shift_type_ids',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<List<String>?>(
        $ShiftSwapsTable.$converterreceivedShiftTypeIdsn,
      );
  @override
  late final GeneratedColumnWithTypeConverter<CivilDate?, String> returnDate =
      GeneratedColumn<String>(
        'return_date',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<CivilDate?>($ShiftSwapsTable.$converterreturnDaten);
  @override
  late final GeneratedColumnWithTypeConverter<SwapStatus, String> status =
      GeneratedColumn<String>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('pending'),
      ).withConverter<SwapStatus>($ShiftSwapsTable.$converterstatus);
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _closedAtMeta = const VerificationMeta(
    'closedAt',
  );
  @override
  late final GeneratedColumn<int> closedAt = GeneratedColumn<int>(
    'closed_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    calendarId,
    date,
    colleague,
    direction,
    givenShiftTypeIds,
    receivedShiftTypeIds,
    returnDate,
    status,
    note,
    createdAt,
    updatedAt,
    closedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'shift_swaps';
  @override
  VerificationContext validateIntegrity(
    Insertable<ShiftSwapRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('calendar_id')) {
      context.handle(
        _calendarIdMeta,
        calendarId.isAcceptableOrUnknown(data['calendar_id']!, _calendarIdMeta),
      );
    } else if (isInserting) {
      context.missing(_calendarIdMeta);
    }
    if (data.containsKey('colleague')) {
      context.handle(
        _colleagueMeta,
        colleague.isAcceptableOrUnknown(data['colleague']!, _colleagueMeta),
      );
    } else if (isInserting) {
      context.missing(_colleagueMeta);
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
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('closed_at')) {
      context.handle(
        _closedAtMeta,
        closedAt.isAcceptableOrUnknown(data['closed_at']!, _closedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ShiftSwapRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ShiftSwapRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      calendarId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}calendar_id'],
      )!,
      date: $ShiftSwapsTable.$converterdate.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}date'],
        )!,
      ),
      colleague: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}colleague'],
      )!,
      direction: $ShiftSwapsTable.$converterdirection.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}direction'],
        )!,
      ),
      givenShiftTypeIds: $ShiftSwapsTable.$convertergivenShiftTypeIdsn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}given_shift_type_ids'],
        ),
      ),
      receivedShiftTypeIds: $ShiftSwapsTable.$converterreceivedShiftTypeIdsn
          .fromSql(
            attachedDatabase.typeMapping.read(
              DriftSqlType.string,
              data['${effectivePrefix}received_shift_type_ids'],
            ),
          ),
      returnDate: $ShiftSwapsTable.$converterreturnDaten.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}return_date'],
        ),
      ),
      status: $ShiftSwapsTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      closedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}closed_at'],
      ),
    );
  }

  @override
  $ShiftSwapsTable createAlias(String alias) {
    return $ShiftSwapsTable(attachedDatabase, alias);
  }

  static TypeConverter<CivilDate, String> $converterdate =
      const CivilDateConverter();
  static JsonTypeConverter2<SwapDirection, String, String> $converterdirection =
      const EnumNameConverter<SwapDirection>(SwapDirection.values);
  static TypeConverter<List<String>, String> $convertergivenShiftTypeIds =
      const StringListConverter();
  static TypeConverter<List<String>?, String?> $convertergivenShiftTypeIdsn =
      NullAwareTypeConverter.wrap($convertergivenShiftTypeIds);
  static TypeConverter<List<String>, String> $converterreceivedShiftTypeIds =
      const StringListConverter();
  static TypeConverter<List<String>?, String?> $converterreceivedShiftTypeIdsn =
      NullAwareTypeConverter.wrap($converterreceivedShiftTypeIds);
  static TypeConverter<CivilDate, String> $converterreturnDate =
      const CivilDateConverter();
  static TypeConverter<CivilDate?, String?> $converterreturnDaten =
      NullAwareTypeConverter.wrap($converterreturnDate);
  static JsonTypeConverter2<SwapStatus, String, String> $converterstatus =
      const EnumNameConverter<SwapStatus>(SwapStatus.values);
}

class ShiftSwapRow extends DataClass implements Insertable<ShiftSwapRow> {
  final String id;
  final String calendarId;
  final CivilDate date;
  final String colleague;
  final SwapDirection direction;

  /// JSON lists of shift type ids; `NULL` = not recorded.
  final List<String>? givenShiftTypeIds;
  final List<String>? receivedShiftTypeIds;
  final CivilDate? returnDate;
  final SwapStatus status;
  final String? note;
  final int createdAt;
  final int updatedAt;
  final int? closedAt;
  const ShiftSwapRow({
    required this.id,
    required this.calendarId,
    required this.date,
    required this.colleague,
    required this.direction,
    this.givenShiftTypeIds,
    this.receivedShiftTypeIds,
    this.returnDate,
    required this.status,
    this.note,
    required this.createdAt,
    required this.updatedAt,
    this.closedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['calendar_id'] = Variable<String>(calendarId);
    {
      map['date'] = Variable<String>(
        $ShiftSwapsTable.$converterdate.toSql(date),
      );
    }
    map['colleague'] = Variable<String>(colleague);
    {
      map['direction'] = Variable<String>(
        $ShiftSwapsTable.$converterdirection.toSql(direction),
      );
    }
    if (!nullToAbsent || givenShiftTypeIds != null) {
      map['given_shift_type_ids'] = Variable<String>(
        $ShiftSwapsTable.$convertergivenShiftTypeIdsn.toSql(givenShiftTypeIds),
      );
    }
    if (!nullToAbsent || receivedShiftTypeIds != null) {
      map['received_shift_type_ids'] = Variable<String>(
        $ShiftSwapsTable.$converterreceivedShiftTypeIdsn.toSql(
          receivedShiftTypeIds,
        ),
      );
    }
    if (!nullToAbsent || returnDate != null) {
      map['return_date'] = Variable<String>(
        $ShiftSwapsTable.$converterreturnDaten.toSql(returnDate),
      );
    }
    {
      map['status'] = Variable<String>(
        $ShiftSwapsTable.$converterstatus.toSql(status),
      );
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || closedAt != null) {
      map['closed_at'] = Variable<int>(closedAt);
    }
    return map;
  }

  ShiftSwapsCompanion toCompanion(bool nullToAbsent) {
    return ShiftSwapsCompanion(
      id: Value(id),
      calendarId: Value(calendarId),
      date: Value(date),
      colleague: Value(colleague),
      direction: Value(direction),
      givenShiftTypeIds: givenShiftTypeIds == null && nullToAbsent
          ? const Value.absent()
          : Value(givenShiftTypeIds),
      receivedShiftTypeIds: receivedShiftTypeIds == null && nullToAbsent
          ? const Value.absent()
          : Value(receivedShiftTypeIds),
      returnDate: returnDate == null && nullToAbsent
          ? const Value.absent()
          : Value(returnDate),
      status: Value(status),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      closedAt: closedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(closedAt),
    );
  }

  factory ShiftSwapRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ShiftSwapRow(
      id: serializer.fromJson<String>(json['id']),
      calendarId: serializer.fromJson<String>(json['calendarId']),
      date: serializer.fromJson<CivilDate>(json['date']),
      colleague: serializer.fromJson<String>(json['colleague']),
      direction: $ShiftSwapsTable.$converterdirection.fromJson(
        serializer.fromJson<String>(json['direction']),
      ),
      givenShiftTypeIds: serializer.fromJson<List<String>?>(
        json['givenShiftTypeIds'],
      ),
      receivedShiftTypeIds: serializer.fromJson<List<String>?>(
        json['receivedShiftTypeIds'],
      ),
      returnDate: serializer.fromJson<CivilDate?>(json['returnDate']),
      status: $ShiftSwapsTable.$converterstatus.fromJson(
        serializer.fromJson<String>(json['status']),
      ),
      note: serializer.fromJson<String?>(json['note']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      closedAt: serializer.fromJson<int?>(json['closedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'calendarId': serializer.toJson<String>(calendarId),
      'date': serializer.toJson<CivilDate>(date),
      'colleague': serializer.toJson<String>(colleague),
      'direction': serializer.toJson<String>(
        $ShiftSwapsTable.$converterdirection.toJson(direction),
      ),
      'givenShiftTypeIds': serializer.toJson<List<String>?>(givenShiftTypeIds),
      'receivedShiftTypeIds': serializer.toJson<List<String>?>(
        receivedShiftTypeIds,
      ),
      'returnDate': serializer.toJson<CivilDate?>(returnDate),
      'status': serializer.toJson<String>(
        $ShiftSwapsTable.$converterstatus.toJson(status),
      ),
      'note': serializer.toJson<String?>(note),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'closedAt': serializer.toJson<int?>(closedAt),
    };
  }

  ShiftSwapRow copyWith({
    String? id,
    String? calendarId,
    CivilDate? date,
    String? colleague,
    SwapDirection? direction,
    Value<List<String>?> givenShiftTypeIds = const Value.absent(),
    Value<List<String>?> receivedShiftTypeIds = const Value.absent(),
    Value<CivilDate?> returnDate = const Value.absent(),
    SwapStatus? status,
    Value<String?> note = const Value.absent(),
    int? createdAt,
    int? updatedAt,
    Value<int?> closedAt = const Value.absent(),
  }) => ShiftSwapRow(
    id: id ?? this.id,
    calendarId: calendarId ?? this.calendarId,
    date: date ?? this.date,
    colleague: colleague ?? this.colleague,
    direction: direction ?? this.direction,
    givenShiftTypeIds: givenShiftTypeIds.present
        ? givenShiftTypeIds.value
        : this.givenShiftTypeIds,
    receivedShiftTypeIds: receivedShiftTypeIds.present
        ? receivedShiftTypeIds.value
        : this.receivedShiftTypeIds,
    returnDate: returnDate.present ? returnDate.value : this.returnDate,
    status: status ?? this.status,
    note: note.present ? note.value : this.note,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    closedAt: closedAt.present ? closedAt.value : this.closedAt,
  );
  ShiftSwapRow copyWithCompanion(ShiftSwapsCompanion data) {
    return ShiftSwapRow(
      id: data.id.present ? data.id.value : this.id,
      calendarId: data.calendarId.present
          ? data.calendarId.value
          : this.calendarId,
      date: data.date.present ? data.date.value : this.date,
      colleague: data.colleague.present ? data.colleague.value : this.colleague,
      direction: data.direction.present ? data.direction.value : this.direction,
      givenShiftTypeIds: data.givenShiftTypeIds.present
          ? data.givenShiftTypeIds.value
          : this.givenShiftTypeIds,
      receivedShiftTypeIds: data.receivedShiftTypeIds.present
          ? data.receivedShiftTypeIds.value
          : this.receivedShiftTypeIds,
      returnDate: data.returnDate.present
          ? data.returnDate.value
          : this.returnDate,
      status: data.status.present ? data.status.value : this.status,
      note: data.note.present ? data.note.value : this.note,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      closedAt: data.closedAt.present ? data.closedAt.value : this.closedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ShiftSwapRow(')
          ..write('id: $id, ')
          ..write('calendarId: $calendarId, ')
          ..write('date: $date, ')
          ..write('colleague: $colleague, ')
          ..write('direction: $direction, ')
          ..write('givenShiftTypeIds: $givenShiftTypeIds, ')
          ..write('receivedShiftTypeIds: $receivedShiftTypeIds, ')
          ..write('returnDate: $returnDate, ')
          ..write('status: $status, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('closedAt: $closedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    calendarId,
    date,
    colleague,
    direction,
    givenShiftTypeIds,
    receivedShiftTypeIds,
    returnDate,
    status,
    note,
    createdAt,
    updatedAt,
    closedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ShiftSwapRow &&
          other.id == this.id &&
          other.calendarId == this.calendarId &&
          other.date == this.date &&
          other.colleague == this.colleague &&
          other.direction == this.direction &&
          other.givenShiftTypeIds == this.givenShiftTypeIds &&
          other.receivedShiftTypeIds == this.receivedShiftTypeIds &&
          other.returnDate == this.returnDate &&
          other.status == this.status &&
          other.note == this.note &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.closedAt == this.closedAt);
}

class ShiftSwapsCompanion extends UpdateCompanion<ShiftSwapRow> {
  final Value<String> id;
  final Value<String> calendarId;
  final Value<CivilDate> date;
  final Value<String> colleague;
  final Value<SwapDirection> direction;
  final Value<List<String>?> givenShiftTypeIds;
  final Value<List<String>?> receivedShiftTypeIds;
  final Value<CivilDate?> returnDate;
  final Value<SwapStatus> status;
  final Value<String?> note;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> closedAt;
  final Value<int> rowid;
  const ShiftSwapsCompanion({
    this.id = const Value.absent(),
    this.calendarId = const Value.absent(),
    this.date = const Value.absent(),
    this.colleague = const Value.absent(),
    this.direction = const Value.absent(),
    this.givenShiftTypeIds = const Value.absent(),
    this.receivedShiftTypeIds = const Value.absent(),
    this.returnDate = const Value.absent(),
    this.status = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.closedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ShiftSwapsCompanion.insert({
    required String id,
    required String calendarId,
    required CivilDate date,
    required String colleague,
    required SwapDirection direction,
    this.givenShiftTypeIds = const Value.absent(),
    this.receivedShiftTypeIds = const Value.absent(),
    this.returnDate = const Value.absent(),
    this.status = const Value.absent(),
    this.note = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.closedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       calendarId = Value(calendarId),
       date = Value(date),
       colleague = Value(colleague),
       direction = Value(direction),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ShiftSwapRow> custom({
    Expression<String>? id,
    Expression<String>? calendarId,
    Expression<String>? date,
    Expression<String>? colleague,
    Expression<String>? direction,
    Expression<String>? givenShiftTypeIds,
    Expression<String>? receivedShiftTypeIds,
    Expression<String>? returnDate,
    Expression<String>? status,
    Expression<String>? note,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? closedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (calendarId != null) 'calendar_id': calendarId,
      if (date != null) 'date': date,
      if (colleague != null) 'colleague': colleague,
      if (direction != null) 'direction': direction,
      if (givenShiftTypeIds != null) 'given_shift_type_ids': givenShiftTypeIds,
      if (receivedShiftTypeIds != null)
        'received_shift_type_ids': receivedShiftTypeIds,
      if (returnDate != null) 'return_date': returnDate,
      if (status != null) 'status': status,
      if (note != null) 'note': note,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (closedAt != null) 'closed_at': closedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ShiftSwapsCompanion copyWith({
    Value<String>? id,
    Value<String>? calendarId,
    Value<CivilDate>? date,
    Value<String>? colleague,
    Value<SwapDirection>? direction,
    Value<List<String>?>? givenShiftTypeIds,
    Value<List<String>?>? receivedShiftTypeIds,
    Value<CivilDate?>? returnDate,
    Value<SwapStatus>? status,
    Value<String?>? note,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? closedAt,
    Value<int>? rowid,
  }) {
    return ShiftSwapsCompanion(
      id: id ?? this.id,
      calendarId: calendarId ?? this.calendarId,
      date: date ?? this.date,
      colleague: colleague ?? this.colleague,
      direction: direction ?? this.direction,
      givenShiftTypeIds: givenShiftTypeIds ?? this.givenShiftTypeIds,
      receivedShiftTypeIds: receivedShiftTypeIds ?? this.receivedShiftTypeIds,
      returnDate: returnDate ?? this.returnDate,
      status: status ?? this.status,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      closedAt: closedAt ?? this.closedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (calendarId.present) {
      map['calendar_id'] = Variable<String>(calendarId.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(
        $ShiftSwapsTable.$converterdate.toSql(date.value),
      );
    }
    if (colleague.present) {
      map['colleague'] = Variable<String>(colleague.value);
    }
    if (direction.present) {
      map['direction'] = Variable<String>(
        $ShiftSwapsTable.$converterdirection.toSql(direction.value),
      );
    }
    if (givenShiftTypeIds.present) {
      map['given_shift_type_ids'] = Variable<String>(
        $ShiftSwapsTable.$convertergivenShiftTypeIdsn.toSql(
          givenShiftTypeIds.value,
        ),
      );
    }
    if (receivedShiftTypeIds.present) {
      map['received_shift_type_ids'] = Variable<String>(
        $ShiftSwapsTable.$converterreceivedShiftTypeIdsn.toSql(
          receivedShiftTypeIds.value,
        ),
      );
    }
    if (returnDate.present) {
      map['return_date'] = Variable<String>(
        $ShiftSwapsTable.$converterreturnDaten.toSql(returnDate.value),
      );
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $ShiftSwapsTable.$converterstatus.toSql(status.value),
      );
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (closedAt.present) {
      map['closed_at'] = Variable<int>(closedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ShiftSwapsCompanion(')
          ..write('id: $id, ')
          ..write('calendarId: $calendarId, ')
          ..write('date: $date, ')
          ..write('colleague: $colleague, ')
          ..write('direction: $direction, ')
          ..write('givenShiftTypeIds: $givenShiftTypeIds, ')
          ..write('receivedShiftTypeIds: $receivedShiftTypeIds, ')
          ..write('returnDate: $returnDate, ')
          ..write('status: $status, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('closedAt: $closedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HolidaysTable extends Holidays
    with TableInfo<$HolidaysTable, HolidayRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HolidaysTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scopeMeta = const VerificationMeta('scope');
  @override
  late final GeneratedColumn<String> scope = GeneratedColumn<String>(
    'scope',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _regionCodeMeta = const VerificationMeta(
    'regionCode',
  );
  @override
  late final GeneratedColumn<String> regionCode = GeneratedColumn<String>(
    'region_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _municipalityCodeMeta = const VerificationMeta(
    'municipalityCode',
  );
  @override
  late final GeneratedColumn<String> municipalityCode = GeneratedColumn<String>(
    'municipality_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    date,
    scope,
    name,
    regionCode,
    municipalityCode,
    source,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'holidays';
  @override
  VerificationContext validateIntegrity(
    Insertable<HolidayRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('scope')) {
      context.handle(
        _scopeMeta,
        scope.isAcceptableOrUnknown(data['scope']!, _scopeMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('region_code')) {
      context.handle(
        _regionCodeMeta,
        regionCode.isAcceptableOrUnknown(data['region_code']!, _regionCodeMeta),
      );
    }
    if (data.containsKey('municipality_code')) {
      context.handle(
        _municipalityCodeMeta,
        municipalityCode.isAcceptableOrUnknown(
          data['municipality_code']!,
          _municipalityCodeMeta,
        ),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HolidayRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HolidayRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      )!,
      scope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      regionCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}region_code'],
      ),
      municipalityCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}municipality_code'],
      ),
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
    );
  }

  @override
  $HolidaysTable createAlias(String alias) {
    return $HolidaysTable(attachedDatabase, alias);
  }
}

class HolidayRow extends DataClass implements Insertable<HolidayRow> {
  final int id;

  /// ISO `YYYY-MM-DD`.
  final String date;

  /// `national` / `regional` / `local`.
  final String scope;
  final String name;
  final String? regionCode;
  final String? municipalityCode;

  /// `bundled` / `remote` / `user`.
  final String source;
  const HolidayRow({
    required this.id,
    required this.date,
    required this.scope,
    required this.name,
    this.regionCode,
    this.municipalityCode,
    required this.source,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['date'] = Variable<String>(date);
    map['scope'] = Variable<String>(scope);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || regionCode != null) {
      map['region_code'] = Variable<String>(regionCode);
    }
    if (!nullToAbsent || municipalityCode != null) {
      map['municipality_code'] = Variable<String>(municipalityCode);
    }
    map['source'] = Variable<String>(source);
    return map;
  }

  HolidaysCompanion toCompanion(bool nullToAbsent) {
    return HolidaysCompanion(
      id: Value(id),
      date: Value(date),
      scope: Value(scope),
      name: Value(name),
      regionCode: regionCode == null && nullToAbsent
          ? const Value.absent()
          : Value(regionCode),
      municipalityCode: municipalityCode == null && nullToAbsent
          ? const Value.absent()
          : Value(municipalityCode),
      source: Value(source),
    );
  }

  factory HolidayRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HolidayRow(
      id: serializer.fromJson<int>(json['id']),
      date: serializer.fromJson<String>(json['date']),
      scope: serializer.fromJson<String>(json['scope']),
      name: serializer.fromJson<String>(json['name']),
      regionCode: serializer.fromJson<String?>(json['regionCode']),
      municipalityCode: serializer.fromJson<String?>(json['municipalityCode']),
      source: serializer.fromJson<String>(json['source']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'date': serializer.toJson<String>(date),
      'scope': serializer.toJson<String>(scope),
      'name': serializer.toJson<String>(name),
      'regionCode': serializer.toJson<String?>(regionCode),
      'municipalityCode': serializer.toJson<String?>(municipalityCode),
      'source': serializer.toJson<String>(source),
    };
  }

  HolidayRow copyWith({
    int? id,
    String? date,
    String? scope,
    String? name,
    Value<String?> regionCode = const Value.absent(),
    Value<String?> municipalityCode = const Value.absent(),
    String? source,
  }) => HolidayRow(
    id: id ?? this.id,
    date: date ?? this.date,
    scope: scope ?? this.scope,
    name: name ?? this.name,
    regionCode: regionCode.present ? regionCode.value : this.regionCode,
    municipalityCode: municipalityCode.present
        ? municipalityCode.value
        : this.municipalityCode,
    source: source ?? this.source,
  );
  HolidayRow copyWithCompanion(HolidaysCompanion data) {
    return HolidayRow(
      id: data.id.present ? data.id.value : this.id,
      date: data.date.present ? data.date.value : this.date,
      scope: data.scope.present ? data.scope.value : this.scope,
      name: data.name.present ? data.name.value : this.name,
      regionCode: data.regionCode.present
          ? data.regionCode.value
          : this.regionCode,
      municipalityCode: data.municipalityCode.present
          ? data.municipalityCode.value
          : this.municipalityCode,
      source: data.source.present ? data.source.value : this.source,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HolidayRow(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('scope: $scope, ')
          ..write('name: $name, ')
          ..write('regionCode: $regionCode, ')
          ..write('municipalityCode: $municipalityCode, ')
          ..write('source: $source')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, date, scope, name, regionCode, municipalityCode, source);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HolidayRow &&
          other.id == this.id &&
          other.date == this.date &&
          other.scope == this.scope &&
          other.name == this.name &&
          other.regionCode == this.regionCode &&
          other.municipalityCode == this.municipalityCode &&
          other.source == this.source);
}

class HolidaysCompanion extends UpdateCompanion<HolidayRow> {
  final Value<int> id;
  final Value<String> date;
  final Value<String> scope;
  final Value<String> name;
  final Value<String?> regionCode;
  final Value<String?> municipalityCode;
  final Value<String> source;
  const HolidaysCompanion({
    this.id = const Value.absent(),
    this.date = const Value.absent(),
    this.scope = const Value.absent(),
    this.name = const Value.absent(),
    this.regionCode = const Value.absent(),
    this.municipalityCode = const Value.absent(),
    this.source = const Value.absent(),
  });
  HolidaysCompanion.insert({
    this.id = const Value.absent(),
    required String date,
    required String scope,
    required String name,
    this.regionCode = const Value.absent(),
    this.municipalityCode = const Value.absent(),
    required String source,
  }) : date = Value(date),
       scope = Value(scope),
       name = Value(name),
       source = Value(source);
  static Insertable<HolidayRow> custom({
    Expression<int>? id,
    Expression<String>? date,
    Expression<String>? scope,
    Expression<String>? name,
    Expression<String>? regionCode,
    Expression<String>? municipalityCode,
    Expression<String>? source,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (date != null) 'date': date,
      if (scope != null) 'scope': scope,
      if (name != null) 'name': name,
      if (regionCode != null) 'region_code': regionCode,
      if (municipalityCode != null) 'municipality_code': municipalityCode,
      if (source != null) 'source': source,
    });
  }

  HolidaysCompanion copyWith({
    Value<int>? id,
    Value<String>? date,
    Value<String>? scope,
    Value<String>? name,
    Value<String?>? regionCode,
    Value<String?>? municipalityCode,
    Value<String>? source,
  }) {
    return HolidaysCompanion(
      id: id ?? this.id,
      date: date ?? this.date,
      scope: scope ?? this.scope,
      name: name ?? this.name,
      regionCode: regionCode ?? this.regionCode,
      municipalityCode: municipalityCode ?? this.municipalityCode,
      source: source ?? this.source,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (scope.present) {
      map['scope'] = Variable<String>(scope.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (regionCode.present) {
      map['region_code'] = Variable<String>(regionCode.value);
    }
    if (municipalityCode.present) {
      map['municipality_code'] = Variable<String>(municipalityCode.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HolidaysCompanion(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('scope: $scope, ')
          ..write('name: $name, ')
          ..write('regionCode: $regionCode, ')
          ..write('municipalityCode: $municipalityCode, ')
          ..write('source: $source')
          ..write(')'))
        .toString();
  }
}

class $AbsenceBalancesTable extends AbsenceBalances
    with TableInfo<$AbsenceBalancesTable, AbsenceBalanceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AbsenceBalancesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<int> year = GeneratedColumn<int>(
    'year',
    aliasedName,
    false,
    type: DriftSqlType.int,
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
  static const VerificationMeta _allowedDaysMeta = const VerificationMeta(
    'allowedDays',
  );
  @override
  late final GeneratedColumn<double> allowedDays = GeneratedColumn<double>(
    'allowed_days',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _calendarIdMeta = const VerificationMeta(
    'calendarId',
  );
  @override
  late final GeneratedColumn<String> calendarId = GeneratedColumn<String>(
    'calendar_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES calendars (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<CivilDate?, String> periodStart =
      GeneratedColumn<String>(
        'period_start',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<CivilDate?>($AbsenceBalancesTable.$converterperiodStartn);
  @override
  late final GeneratedColumnWithTypeConverter<CivilDate?, String> periodEnd =
      GeneratedColumn<String>(
        'period_end',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<CivilDate?>($AbsenceBalancesTable.$converterperiodEndn);
  @override
  late final GeneratedColumnWithTypeConverter<AbsenceUnit, String> unit =
      GeneratedColumn<String>(
        'unit',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('day'),
      ).withConverter<AbsenceUnit>($AbsenceBalancesTable.$converterunit);
  @override
  late final GeneratedColumnWithTypeConverter<Map<String, int>?, String>
  shiftTypeQuarters =
      GeneratedColumn<String>(
        'shift_type_quarters',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<Map<String, int>?>(
        $AbsenceBalancesTable.$convertershiftTypeQuartersn,
      );
  static const VerificationMeta _carryOverMeta = const VerificationMeta(
    'carryOver',
  );
  @override
  late final GeneratedColumn<bool> carryOver = GeneratedColumn<bool>(
    'carry_over',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("carry_over" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _carryOverMaxDaysMeta = const VerificationMeta(
    'carryOverMaxDays',
  );
  @override
  late final GeneratedColumn<double> carryOverMaxDays = GeneratedColumn<double>(
    'carry_over_max_days',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _adjustmentDaysMeta = const VerificationMeta(
    'adjustmentDays',
  );
  @override
  late final GeneratedColumn<double> adjustmentDays = GeneratedColumn<double>(
    'adjustment_days',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    year,
    type,
    allowedDays,
    calendarId,
    name,
    periodStart,
    periodEnd,
    unit,
    shiftTypeQuarters,
    carryOver,
    carryOverMaxDays,
    adjustmentDays,
    sortOrder,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'absence_balances';
  @override
  VerificationContext validateIntegrity(
    Insertable<AbsenceBalanceRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('year')) {
      context.handle(
        _yearMeta,
        year.isAcceptableOrUnknown(data['year']!, _yearMeta),
      );
    } else if (isInserting) {
      context.missing(_yearMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('allowed_days')) {
      context.handle(
        _allowedDaysMeta,
        allowedDays.isAcceptableOrUnknown(
          data['allowed_days']!,
          _allowedDaysMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_allowedDaysMeta);
    }
    if (data.containsKey('calendar_id')) {
      context.handle(
        _calendarIdMeta,
        calendarId.isAcceptableOrUnknown(data['calendar_id']!, _calendarIdMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('carry_over')) {
      context.handle(
        _carryOverMeta,
        carryOver.isAcceptableOrUnknown(data['carry_over']!, _carryOverMeta),
      );
    }
    if (data.containsKey('carry_over_max_days')) {
      context.handle(
        _carryOverMaxDaysMeta,
        carryOverMaxDays.isAcceptableOrUnknown(
          data['carry_over_max_days']!,
          _carryOverMaxDaysMeta,
        ),
      );
    }
    if (data.containsKey('adjustment_days')) {
      context.handle(
        _adjustmentDaysMeta,
        adjustmentDays.isAcceptableOrUnknown(
          data['adjustment_days']!,
          _adjustmentDaysMeta,
        ),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
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
  Set<GeneratedColumn> get $primaryKey => {year, type};
  @override
  AbsenceBalanceRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AbsenceBalanceRow(
      year: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}year'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      allowedDays: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}allowed_days'],
      )!,
      calendarId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}calendar_id'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
      periodStart: $AbsenceBalancesTable.$converterperiodStartn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}period_start'],
        ),
      ),
      periodEnd: $AbsenceBalancesTable.$converterperiodEndn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}period_end'],
        ),
      ),
      unit: $AbsenceBalancesTable.$converterunit.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}unit'],
        )!,
      ),
      shiftTypeQuarters: $AbsenceBalancesTable.$convertershiftTypeQuartersn
          .fromSql(
            attachedDatabase.typeMapping.read(
              DriftSqlType.string,
              data['${effectivePrefix}shift_type_quarters'],
            ),
          ),
      carryOver: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}carry_over'],
      )!,
      carryOverMaxDays: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}carry_over_max_days'],
      ),
      adjustmentDays: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}adjustment_days'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      ),
    );
  }

  @override
  $AbsenceBalancesTable createAlias(String alias) {
    return $AbsenceBalancesTable(attachedDatabase, alias);
  }

  static TypeConverter<CivilDate, String> $converterperiodStart =
      const CivilDateConverter();
  static TypeConverter<CivilDate?, String?> $converterperiodStartn =
      NullAwareTypeConverter.wrap($converterperiodStart);
  static TypeConverter<CivilDate, String> $converterperiodEnd =
      const CivilDateConverter();
  static TypeConverter<CivilDate?, String?> $converterperiodEndn =
      NullAwareTypeConverter.wrap($converterperiodEnd);
  static JsonTypeConverter2<AbsenceUnit, String, String> $converterunit =
      const EnumNameConverter<AbsenceUnit>(AbsenceUnit.values);
  static TypeConverter<Map<String, int>, String> $convertershiftTypeQuarters =
      const StringIntMapConverter();
  static TypeConverter<Map<String, int>?, String?>
  $convertershiftTypeQuartersn = NullAwareTypeConverter.wrap(
    $convertershiftTypeQuarters,
  );
}

class AbsenceBalanceRow extends DataClass
    implements Insertable<AbsenceBalanceRow> {
  final int year;
  final String type;
  final double allowedDays;

  /// Calendar whose days count; NULL = the primary one. Schema v6.
  final String? calendarId;
  final String? name;

  /// Both or none; none = the calendar year `year`. Schema v6.
  final CivilDate? periodStart;
  final CivilDate? periodEnd;
  final AbsenceUnit unit;

  /// JSON object shift type id -> quarters of a day it uses (1-4).
  final Map<String, int>? shiftTypeQuarters;
  final bool carryOver;
  final double? carryOverMaxDays;
  final double adjustmentDays;
  final int sortOrder;
  final int? createdAt;
  final int? updatedAt;
  const AbsenceBalanceRow({
    required this.year,
    required this.type,
    required this.allowedDays,
    this.calendarId,
    this.name,
    this.periodStart,
    this.periodEnd,
    required this.unit,
    this.shiftTypeQuarters,
    required this.carryOver,
    this.carryOverMaxDays,
    required this.adjustmentDays,
    required this.sortOrder,
    this.createdAt,
    this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['year'] = Variable<int>(year);
    map['type'] = Variable<String>(type);
    map['allowed_days'] = Variable<double>(allowedDays);
    if (!nullToAbsent || calendarId != null) {
      map['calendar_id'] = Variable<String>(calendarId);
    }
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    if (!nullToAbsent || periodStart != null) {
      map['period_start'] = Variable<String>(
        $AbsenceBalancesTable.$converterperiodStartn.toSql(periodStart),
      );
    }
    if (!nullToAbsent || periodEnd != null) {
      map['period_end'] = Variable<String>(
        $AbsenceBalancesTable.$converterperiodEndn.toSql(periodEnd),
      );
    }
    {
      map['unit'] = Variable<String>(
        $AbsenceBalancesTable.$converterunit.toSql(unit),
      );
    }
    if (!nullToAbsent || shiftTypeQuarters != null) {
      map['shift_type_quarters'] = Variable<String>(
        $AbsenceBalancesTable.$convertershiftTypeQuartersn.toSql(
          shiftTypeQuarters,
        ),
      );
    }
    map['carry_over'] = Variable<bool>(carryOver);
    if (!nullToAbsent || carryOverMaxDays != null) {
      map['carry_over_max_days'] = Variable<double>(carryOverMaxDays);
    }
    map['adjustment_days'] = Variable<double>(adjustmentDays);
    map['sort_order'] = Variable<int>(sortOrder);
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<int>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<int>(updatedAt);
    }
    return map;
  }

  AbsenceBalancesCompanion toCompanion(bool nullToAbsent) {
    return AbsenceBalancesCompanion(
      year: Value(year),
      type: Value(type),
      allowedDays: Value(allowedDays),
      calendarId: calendarId == null && nullToAbsent
          ? const Value.absent()
          : Value(calendarId),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      periodStart: periodStart == null && nullToAbsent
          ? const Value.absent()
          : Value(periodStart),
      periodEnd: periodEnd == null && nullToAbsent
          ? const Value.absent()
          : Value(periodEnd),
      unit: Value(unit),
      shiftTypeQuarters: shiftTypeQuarters == null && nullToAbsent
          ? const Value.absent()
          : Value(shiftTypeQuarters),
      carryOver: Value(carryOver),
      carryOverMaxDays: carryOverMaxDays == null && nullToAbsent
          ? const Value.absent()
          : Value(carryOverMaxDays),
      adjustmentDays: Value(adjustmentDays),
      sortOrder: Value(sortOrder),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory AbsenceBalanceRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AbsenceBalanceRow(
      year: serializer.fromJson<int>(json['year']),
      type: serializer.fromJson<String>(json['type']),
      allowedDays: serializer.fromJson<double>(json['allowedDays']),
      calendarId: serializer.fromJson<String?>(json['calendarId']),
      name: serializer.fromJson<String?>(json['name']),
      periodStart: serializer.fromJson<CivilDate?>(json['periodStart']),
      periodEnd: serializer.fromJson<CivilDate?>(json['periodEnd']),
      unit: $AbsenceBalancesTable.$converterunit.fromJson(
        serializer.fromJson<String>(json['unit']),
      ),
      shiftTypeQuarters: serializer.fromJson<Map<String, int>?>(
        json['shiftTypeQuarters'],
      ),
      carryOver: serializer.fromJson<bool>(json['carryOver']),
      carryOverMaxDays: serializer.fromJson<double?>(json['carryOverMaxDays']),
      adjustmentDays: serializer.fromJson<double>(json['adjustmentDays']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<int?>(json['createdAt']),
      updatedAt: serializer.fromJson<int?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'year': serializer.toJson<int>(year),
      'type': serializer.toJson<String>(type),
      'allowedDays': serializer.toJson<double>(allowedDays),
      'calendarId': serializer.toJson<String?>(calendarId),
      'name': serializer.toJson<String?>(name),
      'periodStart': serializer.toJson<CivilDate?>(periodStart),
      'periodEnd': serializer.toJson<CivilDate?>(periodEnd),
      'unit': serializer.toJson<String>(
        $AbsenceBalancesTable.$converterunit.toJson(unit),
      ),
      'shiftTypeQuarters': serializer.toJson<Map<String, int>?>(
        shiftTypeQuarters,
      ),
      'carryOver': serializer.toJson<bool>(carryOver),
      'carryOverMaxDays': serializer.toJson<double?>(carryOverMaxDays),
      'adjustmentDays': serializer.toJson<double>(adjustmentDays),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<int?>(createdAt),
      'updatedAt': serializer.toJson<int?>(updatedAt),
    };
  }

  AbsenceBalanceRow copyWith({
    int? year,
    String? type,
    double? allowedDays,
    Value<String?> calendarId = const Value.absent(),
    Value<String?> name = const Value.absent(),
    Value<CivilDate?> periodStart = const Value.absent(),
    Value<CivilDate?> periodEnd = const Value.absent(),
    AbsenceUnit? unit,
    Value<Map<String, int>?> shiftTypeQuarters = const Value.absent(),
    bool? carryOver,
    Value<double?> carryOverMaxDays = const Value.absent(),
    double? adjustmentDays,
    int? sortOrder,
    Value<int?> createdAt = const Value.absent(),
    Value<int?> updatedAt = const Value.absent(),
  }) => AbsenceBalanceRow(
    year: year ?? this.year,
    type: type ?? this.type,
    allowedDays: allowedDays ?? this.allowedDays,
    calendarId: calendarId.present ? calendarId.value : this.calendarId,
    name: name.present ? name.value : this.name,
    periodStart: periodStart.present ? periodStart.value : this.periodStart,
    periodEnd: periodEnd.present ? periodEnd.value : this.periodEnd,
    unit: unit ?? this.unit,
    shiftTypeQuarters: shiftTypeQuarters.present
        ? shiftTypeQuarters.value
        : this.shiftTypeQuarters,
    carryOver: carryOver ?? this.carryOver,
    carryOverMaxDays: carryOverMaxDays.present
        ? carryOverMaxDays.value
        : this.carryOverMaxDays,
    adjustmentDays: adjustmentDays ?? this.adjustmentDays,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
  );
  AbsenceBalanceRow copyWithCompanion(AbsenceBalancesCompanion data) {
    return AbsenceBalanceRow(
      year: data.year.present ? data.year.value : this.year,
      type: data.type.present ? data.type.value : this.type,
      allowedDays: data.allowedDays.present
          ? data.allowedDays.value
          : this.allowedDays,
      calendarId: data.calendarId.present
          ? data.calendarId.value
          : this.calendarId,
      name: data.name.present ? data.name.value : this.name,
      periodStart: data.periodStart.present
          ? data.periodStart.value
          : this.periodStart,
      periodEnd: data.periodEnd.present ? data.periodEnd.value : this.periodEnd,
      unit: data.unit.present ? data.unit.value : this.unit,
      shiftTypeQuarters: data.shiftTypeQuarters.present
          ? data.shiftTypeQuarters.value
          : this.shiftTypeQuarters,
      carryOver: data.carryOver.present ? data.carryOver.value : this.carryOver,
      carryOverMaxDays: data.carryOverMaxDays.present
          ? data.carryOverMaxDays.value
          : this.carryOverMaxDays,
      adjustmentDays: data.adjustmentDays.present
          ? data.adjustmentDays.value
          : this.adjustmentDays,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AbsenceBalanceRow(')
          ..write('year: $year, ')
          ..write('type: $type, ')
          ..write('allowedDays: $allowedDays, ')
          ..write('calendarId: $calendarId, ')
          ..write('name: $name, ')
          ..write('periodStart: $periodStart, ')
          ..write('periodEnd: $periodEnd, ')
          ..write('unit: $unit, ')
          ..write('shiftTypeQuarters: $shiftTypeQuarters, ')
          ..write('carryOver: $carryOver, ')
          ..write('carryOverMaxDays: $carryOverMaxDays, ')
          ..write('adjustmentDays: $adjustmentDays, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    year,
    type,
    allowedDays,
    calendarId,
    name,
    periodStart,
    periodEnd,
    unit,
    shiftTypeQuarters,
    carryOver,
    carryOverMaxDays,
    adjustmentDays,
    sortOrder,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AbsenceBalanceRow &&
          other.year == this.year &&
          other.type == this.type &&
          other.allowedDays == this.allowedDays &&
          other.calendarId == this.calendarId &&
          other.name == this.name &&
          other.periodStart == this.periodStart &&
          other.periodEnd == this.periodEnd &&
          other.unit == this.unit &&
          other.shiftTypeQuarters == this.shiftTypeQuarters &&
          other.carryOver == this.carryOver &&
          other.carryOverMaxDays == this.carryOverMaxDays &&
          other.adjustmentDays == this.adjustmentDays &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class AbsenceBalancesCompanion extends UpdateCompanion<AbsenceBalanceRow> {
  final Value<int> year;
  final Value<String> type;
  final Value<double> allowedDays;
  final Value<String?> calendarId;
  final Value<String?> name;
  final Value<CivilDate?> periodStart;
  final Value<CivilDate?> periodEnd;
  final Value<AbsenceUnit> unit;
  final Value<Map<String, int>?> shiftTypeQuarters;
  final Value<bool> carryOver;
  final Value<double?> carryOverMaxDays;
  final Value<double> adjustmentDays;
  final Value<int> sortOrder;
  final Value<int?> createdAt;
  final Value<int?> updatedAt;
  final Value<int> rowid;
  const AbsenceBalancesCompanion({
    this.year = const Value.absent(),
    this.type = const Value.absent(),
    this.allowedDays = const Value.absent(),
    this.calendarId = const Value.absent(),
    this.name = const Value.absent(),
    this.periodStart = const Value.absent(),
    this.periodEnd = const Value.absent(),
    this.unit = const Value.absent(),
    this.shiftTypeQuarters = const Value.absent(),
    this.carryOver = const Value.absent(),
    this.carryOverMaxDays = const Value.absent(),
    this.adjustmentDays = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AbsenceBalancesCompanion.insert({
    required int year,
    required String type,
    required double allowedDays,
    this.calendarId = const Value.absent(),
    this.name = const Value.absent(),
    this.periodStart = const Value.absent(),
    this.periodEnd = const Value.absent(),
    this.unit = const Value.absent(),
    this.shiftTypeQuarters = const Value.absent(),
    this.carryOver = const Value.absent(),
    this.carryOverMaxDays = const Value.absent(),
    this.adjustmentDays = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : year = Value(year),
       type = Value(type),
       allowedDays = Value(allowedDays);
  static Insertable<AbsenceBalanceRow> custom({
    Expression<int>? year,
    Expression<String>? type,
    Expression<double>? allowedDays,
    Expression<String>? calendarId,
    Expression<String>? name,
    Expression<String>? periodStart,
    Expression<String>? periodEnd,
    Expression<String>? unit,
    Expression<String>? shiftTypeQuarters,
    Expression<bool>? carryOver,
    Expression<double>? carryOverMaxDays,
    Expression<double>? adjustmentDays,
    Expression<int>? sortOrder,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (year != null) 'year': year,
      if (type != null) 'type': type,
      if (allowedDays != null) 'allowed_days': allowedDays,
      if (calendarId != null) 'calendar_id': calendarId,
      if (name != null) 'name': name,
      if (periodStart != null) 'period_start': periodStart,
      if (periodEnd != null) 'period_end': periodEnd,
      if (unit != null) 'unit': unit,
      if (shiftTypeQuarters != null) 'shift_type_quarters': shiftTypeQuarters,
      if (carryOver != null) 'carry_over': carryOver,
      if (carryOverMaxDays != null) 'carry_over_max_days': carryOverMaxDays,
      if (adjustmentDays != null) 'adjustment_days': adjustmentDays,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AbsenceBalancesCompanion copyWith({
    Value<int>? year,
    Value<String>? type,
    Value<double>? allowedDays,
    Value<String?>? calendarId,
    Value<String?>? name,
    Value<CivilDate?>? periodStart,
    Value<CivilDate?>? periodEnd,
    Value<AbsenceUnit>? unit,
    Value<Map<String, int>?>? shiftTypeQuarters,
    Value<bool>? carryOver,
    Value<double?>? carryOverMaxDays,
    Value<double>? adjustmentDays,
    Value<int>? sortOrder,
    Value<int?>? createdAt,
    Value<int?>? updatedAt,
    Value<int>? rowid,
  }) {
    return AbsenceBalancesCompanion(
      year: year ?? this.year,
      type: type ?? this.type,
      allowedDays: allowedDays ?? this.allowedDays,
      calendarId: calendarId ?? this.calendarId,
      name: name ?? this.name,
      periodStart: periodStart ?? this.periodStart,
      periodEnd: periodEnd ?? this.periodEnd,
      unit: unit ?? this.unit,
      shiftTypeQuarters: shiftTypeQuarters ?? this.shiftTypeQuarters,
      carryOver: carryOver ?? this.carryOver,
      carryOverMaxDays: carryOverMaxDays ?? this.carryOverMaxDays,
      adjustmentDays: adjustmentDays ?? this.adjustmentDays,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (allowedDays.present) {
      map['allowed_days'] = Variable<double>(allowedDays.value);
    }
    if (calendarId.present) {
      map['calendar_id'] = Variable<String>(calendarId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (periodStart.present) {
      map['period_start'] = Variable<String>(
        $AbsenceBalancesTable.$converterperiodStartn.toSql(periodStart.value),
      );
    }
    if (periodEnd.present) {
      map['period_end'] = Variable<String>(
        $AbsenceBalancesTable.$converterperiodEndn.toSql(periodEnd.value),
      );
    }
    if (unit.present) {
      map['unit'] = Variable<String>(
        $AbsenceBalancesTable.$converterunit.toSql(unit.value),
      );
    }
    if (shiftTypeQuarters.present) {
      map['shift_type_quarters'] = Variable<String>(
        $AbsenceBalancesTable.$convertershiftTypeQuartersn.toSql(
          shiftTypeQuarters.value,
        ),
      );
    }
    if (carryOver.present) {
      map['carry_over'] = Variable<bool>(carryOver.value);
    }
    if (carryOverMaxDays.present) {
      map['carry_over_max_days'] = Variable<double>(carryOverMaxDays.value);
    }
    if (adjustmentDays.present) {
      map['adjustment_days'] = Variable<double>(adjustmentDays.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AbsenceBalancesCompanion(')
          ..write('year: $year, ')
          ..write('type: $type, ')
          ..write('allowedDays: $allowedDays, ')
          ..write('calendarId: $calendarId, ')
          ..write('name: $name, ')
          ..write('periodStart: $periodStart, ')
          ..write('periodEnd: $periodEnd, ')
          ..write('unit: $unit, ')
          ..write('shiftTypeQuarters: $shiftTypeQuarters, ')
          ..write('carryOver: $carryOver, ')
          ..write('carryOverMaxDays: $carryOverMaxDays, ')
          ..write('adjustmentDays: $adjustmentDays, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings
    with TableInfo<$SettingsTable, SettingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<SettingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SettingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class SettingRow extends DataClass implements Insertable<SettingRow> {
  final String key;

  /// JSON.
  final String value;
  const SettingRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(key: Value(key), value: Value(value));
  }

  factory SettingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  SettingRow copyWith({String? key, String? value}) =>
      SettingRow(key: key ?? this.key, value: value ?? this.value);
  SettingRow copyWithCompanion(SettingsCompanion data) {
    return SettingRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingRow &&
          other.key == this.key &&
          other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<SettingRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SettingRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OvertimeTypesTable extends OvertimeTypes
    with TableInfo<$OvertimeTypesTable, OvertimeTypeRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OvertimeTypesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorValueMeta = const VerificationMeta(
    'colorValue',
  );
  @override
  late final GeneratedColumn<int> colorValue = GeneratedColumn<int>(
    'color_value',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<OvertimeRateMode, String>
  rateMode = GeneratedColumn<String>(
    'rate_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<OvertimeRateMode>($OvertimeTypesTable.$converterrateMode);
  static const VerificationMeta _multiplierBasisPointsMeta =
      const VerificationMeta('multiplierBasisPoints');
  @override
  late final GeneratedColumn<int> multiplierBasisPoints = GeneratedColumn<int>(
    'multiplier_basis_points',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(10000),
  );
  static const VerificationMeta _hourlyRateCentsMeta = const VerificationMeta(
    'hourlyRateCents',
  );
  @override
  late final GeneratedColumn<int> hourlyRateCents = GeneratedColumn<int>(
    'hourly_rate_cents',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _countsForGoalMeta = const VerificationMeta(
    'countsForGoal',
  );
  @override
  late final GeneratedColumn<bool> countsForGoal = GeneratedColumn<bool>(
    'counts_for_goal',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("counts_for_goal" IN (0, 1))',
    ),
  );
  static const VerificationMeta _archivedMeta = const VerificationMeta(
    'archived',
  );
  @override
  late final GeneratedColumn<bool> archived = GeneratedColumn<bool>(
    'archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    colorValue,
    rateMode,
    multiplierBasisPoints,
    hourlyRateCents,
    countsForGoal,
    archived,
    sortOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'overtime_types';
  @override
  VerificationContext validateIntegrity(
    Insertable<OvertimeTypeRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('color_value')) {
      context.handle(
        _colorValueMeta,
        colorValue.isAcceptableOrUnknown(data['color_value']!, _colorValueMeta),
      );
    } else if (isInserting) {
      context.missing(_colorValueMeta);
    }
    if (data.containsKey('multiplier_basis_points')) {
      context.handle(
        _multiplierBasisPointsMeta,
        multiplierBasisPoints.isAcceptableOrUnknown(
          data['multiplier_basis_points']!,
          _multiplierBasisPointsMeta,
        ),
      );
    }
    if (data.containsKey('hourly_rate_cents')) {
      context.handle(
        _hourlyRateCentsMeta,
        hourlyRateCents.isAcceptableOrUnknown(
          data['hourly_rate_cents']!,
          _hourlyRateCentsMeta,
        ),
      );
    }
    if (data.containsKey('counts_for_goal')) {
      context.handle(
        _countsForGoalMeta,
        countsForGoal.isAcceptableOrUnknown(
          data['counts_for_goal']!,
          _countsForGoalMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_countsForGoalMeta);
    }
    if (data.containsKey('archived')) {
      context.handle(
        _archivedMeta,
        archived.isAcceptableOrUnknown(data['archived']!, _archivedMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OvertimeTypeRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OvertimeTypeRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
      colorValue: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_value'],
      )!,
      rateMode: $OvertimeTypesTable.$converterrateMode.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}rate_mode'],
        )!,
      ),
      multiplierBasisPoints: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}multiplier_basis_points'],
      )!,
      hourlyRateCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}hourly_rate_cents'],
      ),
      countsForGoal: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}counts_for_goal'],
      )!,
      archived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}archived'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $OvertimeTypesTable createAlias(String alias) {
    return $OvertimeTypesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<OvertimeRateMode, String, String>
  $converterrateMode = const EnumNameConverter<OvertimeRateMode>(
    OvertimeRateMode.values,
  );
}

class OvertimeTypeRow extends DataClass implements Insertable<OvertimeTypeRow> {
  final String id;

  /// NULL = a built-in type the user has not renamed (shown in the app's
  /// language).
  final String? name;
  final int colorValue;
  final OvertimeRateMode rateMode;
  final int multiplierBasisPoints;
  final int? hourlyRateCents;
  final bool countsForGoal;
  final bool archived;
  final int sortOrder;
  const OvertimeTypeRow({
    required this.id,
    this.name,
    required this.colorValue,
    required this.rateMode,
    required this.multiplierBasisPoints,
    this.hourlyRateCents,
    required this.countsForGoal,
    required this.archived,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    map['color_value'] = Variable<int>(colorValue);
    {
      map['rate_mode'] = Variable<String>(
        $OvertimeTypesTable.$converterrateMode.toSql(rateMode),
      );
    }
    map['multiplier_basis_points'] = Variable<int>(multiplierBasisPoints);
    if (!nullToAbsent || hourlyRateCents != null) {
      map['hourly_rate_cents'] = Variable<int>(hourlyRateCents);
    }
    map['counts_for_goal'] = Variable<bool>(countsForGoal);
    map['archived'] = Variable<bool>(archived);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  OvertimeTypesCompanion toCompanion(bool nullToAbsent) {
    return OvertimeTypesCompanion(
      id: Value(id),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      colorValue: Value(colorValue),
      rateMode: Value(rateMode),
      multiplierBasisPoints: Value(multiplierBasisPoints),
      hourlyRateCents: hourlyRateCents == null && nullToAbsent
          ? const Value.absent()
          : Value(hourlyRateCents),
      countsForGoal: Value(countsForGoal),
      archived: Value(archived),
      sortOrder: Value(sortOrder),
    );
  }

  factory OvertimeTypeRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OvertimeTypeRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String?>(json['name']),
      colorValue: serializer.fromJson<int>(json['colorValue']),
      rateMode: $OvertimeTypesTable.$converterrateMode.fromJson(
        serializer.fromJson<String>(json['rateMode']),
      ),
      multiplierBasisPoints: serializer.fromJson<int>(
        json['multiplierBasisPoints'],
      ),
      hourlyRateCents: serializer.fromJson<int?>(json['hourlyRateCents']),
      countsForGoal: serializer.fromJson<bool>(json['countsForGoal']),
      archived: serializer.fromJson<bool>(json['archived']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String?>(name),
      'colorValue': serializer.toJson<int>(colorValue),
      'rateMode': serializer.toJson<String>(
        $OvertimeTypesTable.$converterrateMode.toJson(rateMode),
      ),
      'multiplierBasisPoints': serializer.toJson<int>(multiplierBasisPoints),
      'hourlyRateCents': serializer.toJson<int?>(hourlyRateCents),
      'countsForGoal': serializer.toJson<bool>(countsForGoal),
      'archived': serializer.toJson<bool>(archived),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  OvertimeTypeRow copyWith({
    String? id,
    Value<String?> name = const Value.absent(),
    int? colorValue,
    OvertimeRateMode? rateMode,
    int? multiplierBasisPoints,
    Value<int?> hourlyRateCents = const Value.absent(),
    bool? countsForGoal,
    bool? archived,
    int? sortOrder,
  }) => OvertimeTypeRow(
    id: id ?? this.id,
    name: name.present ? name.value : this.name,
    colorValue: colorValue ?? this.colorValue,
    rateMode: rateMode ?? this.rateMode,
    multiplierBasisPoints: multiplierBasisPoints ?? this.multiplierBasisPoints,
    hourlyRateCents: hourlyRateCents.present
        ? hourlyRateCents.value
        : this.hourlyRateCents,
    countsForGoal: countsForGoal ?? this.countsForGoal,
    archived: archived ?? this.archived,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  OvertimeTypeRow copyWithCompanion(OvertimeTypesCompanion data) {
    return OvertimeTypeRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      colorValue: data.colorValue.present
          ? data.colorValue.value
          : this.colorValue,
      rateMode: data.rateMode.present ? data.rateMode.value : this.rateMode,
      multiplierBasisPoints: data.multiplierBasisPoints.present
          ? data.multiplierBasisPoints.value
          : this.multiplierBasisPoints,
      hourlyRateCents: data.hourlyRateCents.present
          ? data.hourlyRateCents.value
          : this.hourlyRateCents,
      countsForGoal: data.countsForGoal.present
          ? data.countsForGoal.value
          : this.countsForGoal,
      archived: data.archived.present ? data.archived.value : this.archived,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OvertimeTypeRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('colorValue: $colorValue, ')
          ..write('rateMode: $rateMode, ')
          ..write('multiplierBasisPoints: $multiplierBasisPoints, ')
          ..write('hourlyRateCents: $hourlyRateCents, ')
          ..write('countsForGoal: $countsForGoal, ')
          ..write('archived: $archived, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    colorValue,
    rateMode,
    multiplierBasisPoints,
    hourlyRateCents,
    countsForGoal,
    archived,
    sortOrder,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OvertimeTypeRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.colorValue == this.colorValue &&
          other.rateMode == this.rateMode &&
          other.multiplierBasisPoints == this.multiplierBasisPoints &&
          other.hourlyRateCents == this.hourlyRateCents &&
          other.countsForGoal == this.countsForGoal &&
          other.archived == this.archived &&
          other.sortOrder == this.sortOrder);
}

class OvertimeTypesCompanion extends UpdateCompanion<OvertimeTypeRow> {
  final Value<String> id;
  final Value<String?> name;
  final Value<int> colorValue;
  final Value<OvertimeRateMode> rateMode;
  final Value<int> multiplierBasisPoints;
  final Value<int?> hourlyRateCents;
  final Value<bool> countsForGoal;
  final Value<bool> archived;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const OvertimeTypesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.colorValue = const Value.absent(),
    this.rateMode = const Value.absent(),
    this.multiplierBasisPoints = const Value.absent(),
    this.hourlyRateCents = const Value.absent(),
    this.countsForGoal = const Value.absent(),
    this.archived = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OvertimeTypesCompanion.insert({
    required String id,
    this.name = const Value.absent(),
    required int colorValue,
    required OvertimeRateMode rateMode,
    this.multiplierBasisPoints = const Value.absent(),
    this.hourlyRateCents = const Value.absent(),
    required bool countsForGoal,
    this.archived = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       colorValue = Value(colorValue),
       rateMode = Value(rateMode),
       countsForGoal = Value(countsForGoal);
  static Insertable<OvertimeTypeRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? colorValue,
    Expression<String>? rateMode,
    Expression<int>? multiplierBasisPoints,
    Expression<int>? hourlyRateCents,
    Expression<bool>? countsForGoal,
    Expression<bool>? archived,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (colorValue != null) 'color_value': colorValue,
      if (rateMode != null) 'rate_mode': rateMode,
      if (multiplierBasisPoints != null)
        'multiplier_basis_points': multiplierBasisPoints,
      if (hourlyRateCents != null) 'hourly_rate_cents': hourlyRateCents,
      if (countsForGoal != null) 'counts_for_goal': countsForGoal,
      if (archived != null) 'archived': archived,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OvertimeTypesCompanion copyWith({
    Value<String>? id,
    Value<String?>? name,
    Value<int>? colorValue,
    Value<OvertimeRateMode>? rateMode,
    Value<int>? multiplierBasisPoints,
    Value<int?>? hourlyRateCents,
    Value<bool>? countsForGoal,
    Value<bool>? archived,
    Value<int>? sortOrder,
    Value<int>? rowid,
  }) {
    return OvertimeTypesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      rateMode: rateMode ?? this.rateMode,
      multiplierBasisPoints:
          multiplierBasisPoints ?? this.multiplierBasisPoints,
      hourlyRateCents: hourlyRateCents ?? this.hourlyRateCents,
      countsForGoal: countsForGoal ?? this.countsForGoal,
      archived: archived ?? this.archived,
      sortOrder: sortOrder ?? this.sortOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (colorValue.present) {
      map['color_value'] = Variable<int>(colorValue.value);
    }
    if (rateMode.present) {
      map['rate_mode'] = Variable<String>(
        $OvertimeTypesTable.$converterrateMode.toSql(rateMode.value),
      );
    }
    if (multiplierBasisPoints.present) {
      map['multiplier_basis_points'] = Variable<int>(
        multiplierBasisPoints.value,
      );
    }
    if (hourlyRateCents.present) {
      map['hourly_rate_cents'] = Variable<int>(hourlyRateCents.value);
    }
    if (countsForGoal.present) {
      map['counts_for_goal'] = Variable<bool>(countsForGoal.value);
    }
    if (archived.present) {
      map['archived'] = Variable<bool>(archived.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OvertimeTypesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('colorValue: $colorValue, ')
          ..write('rateMode: $rateMode, ')
          ..write('multiplierBasisPoints: $multiplierBasisPoints, ')
          ..write('hourlyRateCents: $hourlyRateCents, ')
          ..write('countsForGoal: $countsForGoal, ')
          ..write('archived: $archived, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OvertimeBlocksTable extends OvertimeBlocks
    with TableInfo<$OvertimeBlocksTable, OvertimeBlockRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OvertimeBlocksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _calendarIdMeta = const VerificationMeta(
    'calendarId',
  );
  @override
  late final GeneratedColumn<String> calendarId = GeneratedColumn<String>(
    'calendar_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES calendars (id) ON DELETE CASCADE',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<CivilDate, String> date =
      GeneratedColumn<String>(
        'date',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<CivilDate>($OvertimeBlocksTable.$converterdate);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeIdMeta = const VerificationMeta('typeId');
  @override
  late final GeneratedColumn<String> typeId = GeneratedColumn<String>(
    'type_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES overtime_types (id)',
    ),
  );
  static const VerificationMeta _startMinuteMeta = const VerificationMeta(
    'startMinute',
  );
  @override
  late final GeneratedColumn<int> startMinute = GeneratedColumn<int>(
    'start_minute',
    aliasedName,
    false,
    check: () => ComparableExpr(startMinute).isBetweenValues(0, 1439),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endMinuteMeta = const VerificationMeta(
    'endMinute',
  );
  @override
  late final GeneratedColumn<int> endMinute = GeneratedColumn<int>(
    'end_minute',
    aliasedName,
    false,
    check: () => ComparableExpr(endMinute).isBetweenValues(0, 1439),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _breakMinutesMeta = const VerificationMeta(
    'breakMinutes',
  );
  @override
  late final GeneratedColumn<int> breakMinutes = GeneratedColumn<int>(
    'break_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    calendarId,
    date,
    id,
    typeId,
    startMinute,
    endMinute,
    breakMinutes,
    note,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'overtime_blocks';
  @override
  VerificationContext validateIntegrity(
    Insertable<OvertimeBlockRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('calendar_id')) {
      context.handle(
        _calendarIdMeta,
        calendarId.isAcceptableOrUnknown(data['calendar_id']!, _calendarIdMeta),
      );
    } else if (isInserting) {
      context.missing(_calendarIdMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('type_id')) {
      context.handle(
        _typeIdMeta,
        typeId.isAcceptableOrUnknown(data['type_id']!, _typeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_typeIdMeta);
    }
    if (data.containsKey('start_minute')) {
      context.handle(
        _startMinuteMeta,
        startMinute.isAcceptableOrUnknown(
          data['start_minute']!,
          _startMinuteMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startMinuteMeta);
    }
    if (data.containsKey('end_minute')) {
      context.handle(
        _endMinuteMeta,
        endMinute.isAcceptableOrUnknown(data['end_minute']!, _endMinuteMeta),
      );
    } else if (isInserting) {
      context.missing(_endMinuteMeta);
    }
    if (data.containsKey('break_minutes')) {
      context.handle(
        _breakMinutesMeta,
        breakMinutes.isAcceptableOrUnknown(
          data['break_minutes']!,
          _breakMinutesMeta,
        ),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {calendarId, date, id};
  @override
  OvertimeBlockRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OvertimeBlockRow(
      calendarId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}calendar_id'],
      )!,
      date: $OvertimeBlocksTable.$converterdate.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}date'],
        )!,
      ),
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      typeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type_id'],
      )!,
      startMinute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_minute'],
      )!,
      endMinute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_minute'],
      )!,
      breakMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}break_minutes'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
    );
  }

  @override
  $OvertimeBlocksTable createAlias(String alias) {
    return $OvertimeBlocksTable(attachedDatabase, alias);
  }

  static TypeConverter<CivilDate, String> $converterdate =
      const CivilDateConverter();
}

class OvertimeBlockRow extends DataClass
    implements Insertable<OvertimeBlockRow> {
  final String calendarId;
  final CivilDate date;
  final String id;

  /// A type in use cannot be deleted (no cascade): it is archived.
  final String typeId;
  final int startMinute;
  final int endMinute;
  final int breakMinutes;
  final String? note;
  const OvertimeBlockRow({
    required this.calendarId,
    required this.date,
    required this.id,
    required this.typeId,
    required this.startMinute,
    required this.endMinute,
    required this.breakMinutes,
    this.note,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['calendar_id'] = Variable<String>(calendarId);
    {
      map['date'] = Variable<String>(
        $OvertimeBlocksTable.$converterdate.toSql(date),
      );
    }
    map['id'] = Variable<String>(id);
    map['type_id'] = Variable<String>(typeId);
    map['start_minute'] = Variable<int>(startMinute);
    map['end_minute'] = Variable<int>(endMinute);
    map['break_minutes'] = Variable<int>(breakMinutes);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    return map;
  }

  OvertimeBlocksCompanion toCompanion(bool nullToAbsent) {
    return OvertimeBlocksCompanion(
      calendarId: Value(calendarId),
      date: Value(date),
      id: Value(id),
      typeId: Value(typeId),
      startMinute: Value(startMinute),
      endMinute: Value(endMinute),
      breakMinutes: Value(breakMinutes),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
    );
  }

  factory OvertimeBlockRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OvertimeBlockRow(
      calendarId: serializer.fromJson<String>(json['calendarId']),
      date: serializer.fromJson<CivilDate>(json['date']),
      id: serializer.fromJson<String>(json['id']),
      typeId: serializer.fromJson<String>(json['typeId']),
      startMinute: serializer.fromJson<int>(json['startMinute']),
      endMinute: serializer.fromJson<int>(json['endMinute']),
      breakMinutes: serializer.fromJson<int>(json['breakMinutes']),
      note: serializer.fromJson<String?>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'calendarId': serializer.toJson<String>(calendarId),
      'date': serializer.toJson<CivilDate>(date),
      'id': serializer.toJson<String>(id),
      'typeId': serializer.toJson<String>(typeId),
      'startMinute': serializer.toJson<int>(startMinute),
      'endMinute': serializer.toJson<int>(endMinute),
      'breakMinutes': serializer.toJson<int>(breakMinutes),
      'note': serializer.toJson<String?>(note),
    };
  }

  OvertimeBlockRow copyWith({
    String? calendarId,
    CivilDate? date,
    String? id,
    String? typeId,
    int? startMinute,
    int? endMinute,
    int? breakMinutes,
    Value<String?> note = const Value.absent(),
  }) => OvertimeBlockRow(
    calendarId: calendarId ?? this.calendarId,
    date: date ?? this.date,
    id: id ?? this.id,
    typeId: typeId ?? this.typeId,
    startMinute: startMinute ?? this.startMinute,
    endMinute: endMinute ?? this.endMinute,
    breakMinutes: breakMinutes ?? this.breakMinutes,
    note: note.present ? note.value : this.note,
  );
  OvertimeBlockRow copyWithCompanion(OvertimeBlocksCompanion data) {
    return OvertimeBlockRow(
      calendarId: data.calendarId.present
          ? data.calendarId.value
          : this.calendarId,
      date: data.date.present ? data.date.value : this.date,
      id: data.id.present ? data.id.value : this.id,
      typeId: data.typeId.present ? data.typeId.value : this.typeId,
      startMinute: data.startMinute.present
          ? data.startMinute.value
          : this.startMinute,
      endMinute: data.endMinute.present ? data.endMinute.value : this.endMinute,
      breakMinutes: data.breakMinutes.present
          ? data.breakMinutes.value
          : this.breakMinutes,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OvertimeBlockRow(')
          ..write('calendarId: $calendarId, ')
          ..write('date: $date, ')
          ..write('id: $id, ')
          ..write('typeId: $typeId, ')
          ..write('startMinute: $startMinute, ')
          ..write('endMinute: $endMinute, ')
          ..write('breakMinutes: $breakMinutes, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    calendarId,
    date,
    id,
    typeId,
    startMinute,
    endMinute,
    breakMinutes,
    note,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OvertimeBlockRow &&
          other.calendarId == this.calendarId &&
          other.date == this.date &&
          other.id == this.id &&
          other.typeId == this.typeId &&
          other.startMinute == this.startMinute &&
          other.endMinute == this.endMinute &&
          other.breakMinutes == this.breakMinutes &&
          other.note == this.note);
}

class OvertimeBlocksCompanion extends UpdateCompanion<OvertimeBlockRow> {
  final Value<String> calendarId;
  final Value<CivilDate> date;
  final Value<String> id;
  final Value<String> typeId;
  final Value<int> startMinute;
  final Value<int> endMinute;
  final Value<int> breakMinutes;
  final Value<String?> note;
  final Value<int> rowid;
  const OvertimeBlocksCompanion({
    this.calendarId = const Value.absent(),
    this.date = const Value.absent(),
    this.id = const Value.absent(),
    this.typeId = const Value.absent(),
    this.startMinute = const Value.absent(),
    this.endMinute = const Value.absent(),
    this.breakMinutes = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OvertimeBlocksCompanion.insert({
    required String calendarId,
    required CivilDate date,
    required String id,
    required String typeId,
    required int startMinute,
    required int endMinute,
    this.breakMinutes = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : calendarId = Value(calendarId),
       date = Value(date),
       id = Value(id),
       typeId = Value(typeId),
       startMinute = Value(startMinute),
       endMinute = Value(endMinute);
  static Insertable<OvertimeBlockRow> custom({
    Expression<String>? calendarId,
    Expression<String>? date,
    Expression<String>? id,
    Expression<String>? typeId,
    Expression<int>? startMinute,
    Expression<int>? endMinute,
    Expression<int>? breakMinutes,
    Expression<String>? note,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (calendarId != null) 'calendar_id': calendarId,
      if (date != null) 'date': date,
      if (id != null) 'id': id,
      if (typeId != null) 'type_id': typeId,
      if (startMinute != null) 'start_minute': startMinute,
      if (endMinute != null) 'end_minute': endMinute,
      if (breakMinutes != null) 'break_minutes': breakMinutes,
      if (note != null) 'note': note,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OvertimeBlocksCompanion copyWith({
    Value<String>? calendarId,
    Value<CivilDate>? date,
    Value<String>? id,
    Value<String>? typeId,
    Value<int>? startMinute,
    Value<int>? endMinute,
    Value<int>? breakMinutes,
    Value<String?>? note,
    Value<int>? rowid,
  }) {
    return OvertimeBlocksCompanion(
      calendarId: calendarId ?? this.calendarId,
      date: date ?? this.date,
      id: id ?? this.id,
      typeId: typeId ?? this.typeId,
      startMinute: startMinute ?? this.startMinute,
      endMinute: endMinute ?? this.endMinute,
      breakMinutes: breakMinutes ?? this.breakMinutes,
      note: note ?? this.note,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (calendarId.present) {
      map['calendar_id'] = Variable<String>(calendarId.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(
        $OvertimeBlocksTable.$converterdate.toSql(date.value),
      );
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (typeId.present) {
      map['type_id'] = Variable<String>(typeId.value);
    }
    if (startMinute.present) {
      map['start_minute'] = Variable<int>(startMinute.value);
    }
    if (endMinute.present) {
      map['end_minute'] = Variable<int>(endMinute.value);
    }
    if (breakMinutes.present) {
      map['break_minutes'] = Variable<int>(breakMinutes.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OvertimeBlocksCompanion(')
          ..write('calendarId: $calendarId, ')
          ..write('date: $date, ')
          ..write('id: $id, ')
          ..write('typeId: $typeId, ')
          ..write('startMinute: $startMinute, ')
          ..write('endMinute: $endMinute, ')
          ..write('breakMinutes: $breakMinutes, ')
          ..write('note: $note, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CalendarsTable calendars = $CalendarsTable(this);
  late final $ShiftTypesTable shiftTypes = $ShiftTypesTable(this);
  late final $ShiftTypeVersionsTable shiftTypeVersions =
      $ShiftTypeVersionsTable(this);
  late final $PatternsTable patterns = $PatternsTable(this);
  late final $PatternRunsTable patternRuns = $PatternRunsTable(this);
  late final $DayEntriesTable dayEntries = $DayEntriesTable(this);
  late final $NoteAttachmentsTable noteAttachments = $NoteAttachmentsTable(
    this,
  );
  late final $DayTasksTable dayTasks = $DayTasksTable(this);
  late final $ShiftSwapsTable shiftSwaps = $ShiftSwapsTable(this);
  late final $HolidaysTable holidays = $HolidaysTable(this);
  late final $AbsenceBalancesTable absenceBalances = $AbsenceBalancesTable(
    this,
  );
  late final $SettingsTable settings = $SettingsTable(this);
  late final $OvertimeTypesTable overtimeTypes = $OvertimeTypesTable(this);
  late final $OvertimeBlocksTable overtimeBlocks = $OvertimeBlocksTable(this);
  late final Index idxNoteAttachmentsDay = Index(
    'idx_note_attachments_day',
    'CREATE INDEX idx_note_attachments_day ON note_attachments (calendar_id, date)',
  );
  late final Index idxDayTasksDay = Index(
    'idx_day_tasks_day',
    'CREATE INDEX idx_day_tasks_day ON day_tasks (calendar_id, date)',
  );
  late final Index idxShiftSwapsDay = Index(
    'idx_shift_swaps_day',
    'CREATE INDEX idx_shift_swaps_day ON shift_swaps (calendar_id, date)',
  );
  late final Index idxHolidaysDate = Index(
    'idx_holidays_date',
    'CREATE INDEX idx_holidays_date ON holidays (date)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    calendars,
    shiftTypes,
    shiftTypeVersions,
    patterns,
    patternRuns,
    dayEntries,
    noteAttachments,
    dayTasks,
    shiftSwaps,
    holidays,
    absenceBalances,
    settings,
    overtimeTypes,
    overtimeBlocks,
    idxNoteAttachmentsDay,
    idxDayTasksDay,
    idxShiftSwapsDay,
    idxHolidaysDate,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'shift_types',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('shift_type_versions', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'calendars',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('note_attachments', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'calendars',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('day_tasks', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'calendars',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('shift_swaps', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'calendars',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('absence_balances', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'calendars',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('overtime_blocks', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$CalendarsTableCreateCompanionBuilder = CalendarsCompanion Function({
  required String id,
  required String name,
  required int colorValue,
  required int sortOrder,
  Value<bool> archived,
  required int createdAt,
  required int updatedAt,
  Value<int> rowid,
});
typedef $$CalendarsTableUpdateCompanionBuilder = CalendarsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<int> colorValue,
  Value<int> sortOrder,
  Value<bool> archived,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<int> rowid,
});

final class $$CalendarsTableReferences
    extends BaseReferences<_$AppDatabase, $CalendarsTable, CalendarRow> {
  $$CalendarsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$PatternRunsTable, List<PatternRunRow>>
  _patternRunsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.patternRuns,
    aliasName: 'calendars__id__pattern_runs__calendar_id',
  );

  $$PatternRunsTableProcessedTableManager get patternRunsRefs {
    final manager = $$PatternRunsTableTableManager(
      $_db,
      $_db.patternRuns,
    ).filter((f) => f.calendarId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_patternRunsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$DayEntriesTable, List<DayEntryRow>>
  _dayEntriesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.dayEntries,
    aliasName: 'calendars__id__day_entries__calendar_id',
  );

  $$DayEntriesTableProcessedTableManager get dayEntriesRefs {
    final manager = $$DayEntriesTableTableManager(
      $_db,
      $_db.dayEntries,
    ).filter((f) => f.calendarId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_dayEntriesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$NoteAttachmentsTable, List<NoteAttachmentRow>>
  _noteAttachmentsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.noteAttachments,
    aliasName: 'calendars__id__note_attachments__calendar_id',
  );

  $$NoteAttachmentsTableProcessedTableManager get noteAttachmentsRefs {
    final manager = $$NoteAttachmentsTableTableManager(
      $_db,
      $_db.noteAttachments,
    ).filter((f) => f.calendarId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _noteAttachmentsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$DayTasksTable, List<DayTaskRow>>
  _dayTasksRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.dayTasks,
    aliasName: 'calendars__id__day_tasks__calendar_id',
  );

  $$DayTasksTableProcessedTableManager get dayTasksRefs {
    final manager = $$DayTasksTableTableManager(
      $_db,
      $_db.dayTasks,
    ).filter((f) => f.calendarId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_dayTasksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ShiftSwapsTable, List<ShiftSwapRow>>
  _shiftSwapsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.shiftSwaps,
    aliasName: 'calendars__id__shift_swaps__calendar_id',
  );

  $$ShiftSwapsTableProcessedTableManager get shiftSwapsRefs {
    final manager = $$ShiftSwapsTableTableManager(
      $_db,
      $_db.shiftSwaps,
    ).filter((f) => f.calendarId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_shiftSwapsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$AbsenceBalancesTable, List<AbsenceBalanceRow>>
  _absenceBalancesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.absenceBalances,
    aliasName: 'calendars__id__absence_balances__calendar_id',
  );

  $$AbsenceBalancesTableProcessedTableManager get absenceBalancesRefs {
    final manager = $$AbsenceBalancesTableTableManager(
      $_db,
      $_db.absenceBalances,
    ).filter((f) => f.calendarId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _absenceBalancesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$OvertimeBlocksTable, List<OvertimeBlockRow>>
  _overtimeBlocksRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.overtimeBlocks,
    aliasName: 'calendars__id__overtime_blocks__calendar_id',
  );

  $$OvertimeBlocksTableProcessedTableManager get overtimeBlocksRefs {
    final manager = $$OvertimeBlocksTableTableManager(
      $_db,
      $_db.overtimeBlocks,
    ).filter((f) => f.calendarId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_overtimeBlocksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CalendarsTableFilterComposer
    extends Composer<_$AppDatabase, $CalendarsTable> {
  $$CalendarsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> patternRunsRefs(
    Expression<bool> Function($$PatternRunsTableFilterComposer f) f,
  ) {
    final $$PatternRunsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.patternRuns,
      getReferencedColumn: (t) => t.calendarId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PatternRunsTableFilterComposer(
            $db: $db,
            $table: $db.patternRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> dayEntriesRefs(
    Expression<bool> Function($$DayEntriesTableFilterComposer f) f,
  ) {
    final $$DayEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.dayEntries,
      getReferencedColumn: (t) => t.calendarId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DayEntriesTableFilterComposer(
            $db: $db,
            $table: $db.dayEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> noteAttachmentsRefs(
    Expression<bool> Function($$NoteAttachmentsTableFilterComposer f) f,
  ) {
    final $$NoteAttachmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.noteAttachments,
      getReferencedColumn: (t) => t.calendarId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NoteAttachmentsTableFilterComposer(
            $db: $db,
            $table: $db.noteAttachments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> dayTasksRefs(
    Expression<bool> Function($$DayTasksTableFilterComposer f) f,
  ) {
    final $$DayTasksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.dayTasks,
      getReferencedColumn: (t) => t.calendarId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DayTasksTableFilterComposer(
            $db: $db,
            $table: $db.dayTasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> shiftSwapsRefs(
    Expression<bool> Function($$ShiftSwapsTableFilterComposer f) f,
  ) {
    final $$ShiftSwapsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.shiftSwaps,
      getReferencedColumn: (t) => t.calendarId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShiftSwapsTableFilterComposer(
            $db: $db,
            $table: $db.shiftSwaps,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> absenceBalancesRefs(
    Expression<bool> Function($$AbsenceBalancesTableFilterComposer f) f,
  ) {
    final $$AbsenceBalancesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.absenceBalances,
      getReferencedColumn: (t) => t.calendarId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AbsenceBalancesTableFilterComposer(
            $db: $db,
            $table: $db.absenceBalances,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> overtimeBlocksRefs(
    Expression<bool> Function($$OvertimeBlocksTableFilterComposer f) f,
  ) {
    final $$OvertimeBlocksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.overtimeBlocks,
      getReferencedColumn: (t) => t.calendarId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OvertimeBlocksTableFilterComposer(
            $db: $db,
            $table: $db.overtimeBlocks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CalendarsTableOrderingComposer
    extends Composer<_$AppDatabase, $CalendarsTable> {
  $$CalendarsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CalendarsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CalendarsTable> {
  $$CalendarsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<bool> get archived =>
      $composableBuilder(column: $table.archived, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> patternRunsRefs<T extends Object>(
    Expression<T> Function($$PatternRunsTableAnnotationComposer a) f,
  ) {
    final $$PatternRunsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.patternRuns,
      getReferencedColumn: (t) => t.calendarId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PatternRunsTableAnnotationComposer(
            $db: $db,
            $table: $db.patternRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> dayEntriesRefs<T extends Object>(
    Expression<T> Function($$DayEntriesTableAnnotationComposer a) f,
  ) {
    final $$DayEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.dayEntries,
      getReferencedColumn: (t) => t.calendarId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DayEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.dayEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> noteAttachmentsRefs<T extends Object>(
    Expression<T> Function($$NoteAttachmentsTableAnnotationComposer a) f,
  ) {
    final $$NoteAttachmentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.noteAttachments,
      getReferencedColumn: (t) => t.calendarId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NoteAttachmentsTableAnnotationComposer(
            $db: $db,
            $table: $db.noteAttachments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> dayTasksRefs<T extends Object>(
    Expression<T> Function($$DayTasksTableAnnotationComposer a) f,
  ) {
    final $$DayTasksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.dayTasks,
      getReferencedColumn: (t) => t.calendarId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DayTasksTableAnnotationComposer(
            $db: $db,
            $table: $db.dayTasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> shiftSwapsRefs<T extends Object>(
    Expression<T> Function($$ShiftSwapsTableAnnotationComposer a) f,
  ) {
    final $$ShiftSwapsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.shiftSwaps,
      getReferencedColumn: (t) => t.calendarId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShiftSwapsTableAnnotationComposer(
            $db: $db,
            $table: $db.shiftSwaps,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> absenceBalancesRefs<T extends Object>(
    Expression<T> Function($$AbsenceBalancesTableAnnotationComposer a) f,
  ) {
    final $$AbsenceBalancesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.absenceBalances,
      getReferencedColumn: (t) => t.calendarId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AbsenceBalancesTableAnnotationComposer(
            $db: $db,
            $table: $db.absenceBalances,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> overtimeBlocksRefs<T extends Object>(
    Expression<T> Function($$OvertimeBlocksTableAnnotationComposer a) f,
  ) {
    final $$OvertimeBlocksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.overtimeBlocks,
      getReferencedColumn: (t) => t.calendarId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OvertimeBlocksTableAnnotationComposer(
            $db: $db,
            $table: $db.overtimeBlocks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CalendarsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CalendarsTable,
          CalendarRow,
          $$CalendarsTableFilterComposer,
          $$CalendarsTableOrderingComposer,
          $$CalendarsTableAnnotationComposer,
          $$CalendarsTableCreateCompanionBuilder,
          $$CalendarsTableUpdateCompanionBuilder,
          (CalendarRow, $$CalendarsTableReferences),
          CalendarRow,
          PrefetchHooks Function({
            bool patternRunsRefs,
            bool dayEntriesRefs,
            bool noteAttachmentsRefs,
            bool dayTasksRefs,
            bool shiftSwapsRefs,
            bool absenceBalancesRefs,
            bool overtimeBlocksRefs,
          })
        > {
  $$CalendarsTableTableManager(_$AppDatabase db, $CalendarsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CalendarsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CalendarsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CalendarsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> colorValue = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CalendarsCompanion(
                id: id,
                name: name,
                colorValue: colorValue,
                sortOrder: sortOrder,
                archived: archived,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required int colorValue,
                required int sortOrder,
                Value<bool> archived = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => CalendarsCompanion.insert(
                id: id,
                name: name,
                colorValue: colorValue,
                sortOrder: sortOrder,
                archived: archived,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CalendarsTable, CalendarRow>(table),
                  $$CalendarsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                patternRunsRefs = false,
                dayEntriesRefs = false,
                noteAttachmentsRefs = false,
                dayTasksRefs = false,
                shiftSwapsRefs = false,
                absenceBalancesRefs = false,
                overtimeBlocksRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (patternRunsRefs) db.patternRuns,
                    if (dayEntriesRefs) db.dayEntries,
                    if (noteAttachmentsRefs) db.noteAttachments,
                    if (dayTasksRefs) db.dayTasks,
                    if (shiftSwapsRefs) db.shiftSwaps,
                    if (absenceBalancesRefs) db.absenceBalances,
                    if (overtimeBlocksRefs) db.overtimeBlocks,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (patternRunsRefs)
                        await $_getPrefetchedData<
                          CalendarRow,
                          $CalendarsTable,
                          PatternRunRow
                        >(
                          currentTable: table,
                          referencedTable: $$CalendarsTableReferences
                              ._patternRunsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CalendarsTableReferences(
                                db,
                                table,
                                p0,
                              ).patternRunsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.calendarId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (dayEntriesRefs)
                        await $_getPrefetchedData<
                          CalendarRow,
                          $CalendarsTable,
                          DayEntryRow
                        >(
                          currentTable: table,
                          referencedTable: $$CalendarsTableReferences
                              ._dayEntriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CalendarsTableReferences(
                                db,
                                table,
                                p0,
                              ).dayEntriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.calendarId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (noteAttachmentsRefs)
                        await $_getPrefetchedData<
                          CalendarRow,
                          $CalendarsTable,
                          NoteAttachmentRow
                        >(
                          currentTable: table,
                          referencedTable: $$CalendarsTableReferences
                              ._noteAttachmentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CalendarsTableReferences(
                                db,
                                table,
                                p0,
                              ).noteAttachmentsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.calendarId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (dayTasksRefs)
                        await $_getPrefetchedData<
                          CalendarRow,
                          $CalendarsTable,
                          DayTaskRow
                        >(
                          currentTable: table,
                          referencedTable: $$CalendarsTableReferences
                              ._dayTasksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CalendarsTableReferences(
                                db,
                                table,
                                p0,
                              ).dayTasksRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.calendarId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (shiftSwapsRefs)
                        await $_getPrefetchedData<
                          CalendarRow,
                          $CalendarsTable,
                          ShiftSwapRow
                        >(
                          currentTable: table,
                          referencedTable: $$CalendarsTableReferences
                              ._shiftSwapsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CalendarsTableReferences(
                                db,
                                table,
                                p0,
                              ).shiftSwapsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.calendarId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (absenceBalancesRefs)
                        await $_getPrefetchedData<
                          CalendarRow,
                          $CalendarsTable,
                          AbsenceBalanceRow
                        >(
                          currentTable: table,
                          referencedTable: $$CalendarsTableReferences
                              ._absenceBalancesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CalendarsTableReferences(
                                db,
                                table,
                                p0,
                              ).absenceBalancesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.calendarId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (overtimeBlocksRefs)
                        await $_getPrefetchedData<
                          CalendarRow,
                          $CalendarsTable,
                          OvertimeBlockRow
                        >(
                          currentTable: table,
                          referencedTable: $$CalendarsTableReferences
                              ._overtimeBlocksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CalendarsTableReferences(
                                db,
                                table,
                                p0,
                              ).overtimeBlocksRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.calendarId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$CalendarsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CalendarsTable,
      CalendarRow,
      $$CalendarsTableFilterComposer,
      $$CalendarsTableOrderingComposer,
      $$CalendarsTableAnnotationComposer,
      $$CalendarsTableCreateCompanionBuilder,
      $$CalendarsTableUpdateCompanionBuilder,
      (CalendarRow, $$CalendarsTableReferences),
      CalendarRow,
      PrefetchHooks Function({
        bool patternRunsRefs,
        bool dayEntriesRefs,
        bool noteAttachmentsRefs,
        bool dayTasksRefs,
        bool shiftSwapsRefs,
        bool absenceBalancesRefs,
        bool overtimeBlocksRefs,
      })
    >;
typedef $$ShiftTypesTableCreateCompanionBuilder = ShiftTypesCompanion Function({
  required String id,
  required String code,
  required String name,
  required int colorValue,
  required ShiftCategory category,
  Value<int?> startMinute,
  Value<int?> endMinute,
  Value<int?> paidMinutes,
  Value<bool?> nightOverride,
  Value<int?> hourlyRateCents,
  Value<int?> fixedPlusCents,
  Value<String?> icon,
  Value<String?> alarmSound,
  Value<int?> segment2StartMinute,
  Value<int?> segment2DurationMinutes,
  Value<String?> location,
  Value<int?> nightPlusCentsPerHour,
  Value<int?> holidayPlusCentsPerHour,
  required int sortOrder,
  Value<bool> archived,
  required int createdAt,
  required int updatedAt,
  Value<int> rowid,
});
typedef $$ShiftTypesTableUpdateCompanionBuilder = ShiftTypesCompanion Function({
  Value<String> id,
  Value<String> code,
  Value<String> name,
  Value<int> colorValue,
  Value<ShiftCategory> category,
  Value<int?> startMinute,
  Value<int?> endMinute,
  Value<int?> paidMinutes,
  Value<bool?> nightOverride,
  Value<int?> hourlyRateCents,
  Value<int?> fixedPlusCents,
  Value<String?> icon,
  Value<String?> alarmSound,
  Value<int?> segment2StartMinute,
  Value<int?> segment2DurationMinutes,
  Value<String?> location,
  Value<int?> nightPlusCentsPerHour,
  Value<int?> holidayPlusCentsPerHour,
  Value<int> sortOrder,
  Value<bool> archived,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<int> rowid,
});

final class $$ShiftTypesTableReferences
    extends BaseReferences<_$AppDatabase, $ShiftTypesTable, ShiftTypeRow> {
  $$ShiftTypesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ShiftTypeVersionsTable, List<ShiftTypeVersionRow>>
  _shiftTypeVersionsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.shiftTypeVersions,
        aliasName: 'shift_types__id__shift_type_versions__shift_type_id',
      );

  $$ShiftTypeVersionsTableProcessedTableManager get shiftTypeVersionsRefs {
    final manager = $$ShiftTypeVersionsTableTableManager(
      $_db,
      $_db.shiftTypeVersions,
    ).filter((f) => f.shiftTypeId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _shiftTypeVersionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ShiftTypesTableFilterComposer
    extends Composer<_$AppDatabase, $ShiftTypesTable> {
  $$ShiftTypesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ShiftCategory, ShiftCategory, String>
  get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get startMinute => $composableBuilder(
    column: $table.startMinute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endMinute => $composableBuilder(
    column: $table.endMinute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get paidMinutes => $composableBuilder(
    column: $table.paidMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get nightOverride => $composableBuilder(
    column: $table.nightOverride,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get hourlyRateCents => $composableBuilder(
    column: $table.hourlyRateCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fixedPlusCents => $composableBuilder(
    column: $table.fixedPlusCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get alarmSound => $composableBuilder(
    column: $table.alarmSound,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get segment2StartMinute => $composableBuilder(
    column: $table.segment2StartMinute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get segment2DurationMinutes => $composableBuilder(
    column: $table.segment2DurationMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get nightPlusCentsPerHour => $composableBuilder(
    column: $table.nightPlusCentsPerHour,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get holidayPlusCentsPerHour => $composableBuilder(
    column: $table.holidayPlusCentsPerHour,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> shiftTypeVersionsRefs(
    Expression<bool> Function($$ShiftTypeVersionsTableFilterComposer f) f,
  ) {
    final $$ShiftTypeVersionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.shiftTypeVersions,
      getReferencedColumn: (t) => t.shiftTypeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShiftTypeVersionsTableFilterComposer(
            $db: $db,
            $table: $db.shiftTypeVersions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ShiftTypesTableOrderingComposer
    extends Composer<_$AppDatabase, $ShiftTypesTable> {
  $$ShiftTypesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startMinute => $composableBuilder(
    column: $table.startMinute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endMinute => $composableBuilder(
    column: $table.endMinute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get paidMinutes => $composableBuilder(
    column: $table.paidMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get nightOverride => $composableBuilder(
    column: $table.nightOverride,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get hourlyRateCents => $composableBuilder(
    column: $table.hourlyRateCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fixedPlusCents => $composableBuilder(
    column: $table.fixedPlusCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get alarmSound => $composableBuilder(
    column: $table.alarmSound,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get segment2StartMinute => $composableBuilder(
    column: $table.segment2StartMinute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get segment2DurationMinutes => $composableBuilder(
    column: $table.segment2DurationMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get nightPlusCentsPerHour => $composableBuilder(
    column: $table.nightPlusCentsPerHour,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get holidayPlusCentsPerHour => $composableBuilder(
    column: $table.holidayPlusCentsPerHour,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ShiftTypesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ShiftTypesTable> {
  $$ShiftTypesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<ShiftCategory, String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<int> get startMinute => $composableBuilder(
    column: $table.startMinute,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endMinute =>
      $composableBuilder(column: $table.endMinute, builder: (column) => column);

  GeneratedColumn<int> get paidMinutes => $composableBuilder(
    column: $table.paidMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get nightOverride => $composableBuilder(
    column: $table.nightOverride,
    builder: (column) => column,
  );

  GeneratedColumn<int> get hourlyRateCents => $composableBuilder(
    column: $table.hourlyRateCents,
    builder: (column) => column,
  );

  GeneratedColumn<int> get fixedPlusCents => $composableBuilder(
    column: $table.fixedPlusCents,
    builder: (column) => column,
  );

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<String> get alarmSound => $composableBuilder(
    column: $table.alarmSound,
    builder: (column) => column,
  );

  GeneratedColumn<int> get segment2StartMinute => $composableBuilder(
    column: $table.segment2StartMinute,
    builder: (column) => column,
  );

  GeneratedColumn<int> get segment2DurationMinutes => $composableBuilder(
    column: $table.segment2DurationMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get location =>
      $composableBuilder(column: $table.location, builder: (column) => column);

  GeneratedColumn<int> get nightPlusCentsPerHour => $composableBuilder(
    column: $table.nightPlusCentsPerHour,
    builder: (column) => column,
  );

  GeneratedColumn<int> get holidayPlusCentsPerHour => $composableBuilder(
    column: $table.holidayPlusCentsPerHour,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<bool> get archived =>
      $composableBuilder(column: $table.archived, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> shiftTypeVersionsRefs<T extends Object>(
    Expression<T> Function($$ShiftTypeVersionsTableAnnotationComposer a) f,
  ) {
    final $$ShiftTypeVersionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.shiftTypeVersions,
          getReferencedColumn: (t) => t.shiftTypeId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ShiftTypeVersionsTableAnnotationComposer(
                $db: $db,
                $table: $db.shiftTypeVersions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$ShiftTypesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ShiftTypesTable,
          ShiftTypeRow,
          $$ShiftTypesTableFilterComposer,
          $$ShiftTypesTableOrderingComposer,
          $$ShiftTypesTableAnnotationComposer,
          $$ShiftTypesTableCreateCompanionBuilder,
          $$ShiftTypesTableUpdateCompanionBuilder,
          (ShiftTypeRow, $$ShiftTypesTableReferences),
          ShiftTypeRow,
          PrefetchHooks Function({bool shiftTypeVersionsRefs})
        > {
  $$ShiftTypesTableTableManager(_$AppDatabase db, $ShiftTypesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ShiftTypesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ShiftTypesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ShiftTypesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> code = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> colorValue = const Value.absent(),
                Value<ShiftCategory> category = const Value.absent(),
                Value<int?> startMinute = const Value.absent(),
                Value<int?> endMinute = const Value.absent(),
                Value<int?> paidMinutes = const Value.absent(),
                Value<bool?> nightOverride = const Value.absent(),
                Value<int?> hourlyRateCents = const Value.absent(),
                Value<int?> fixedPlusCents = const Value.absent(),
                Value<String?> icon = const Value.absent(),
                Value<String?> alarmSound = const Value.absent(),
                Value<int?> segment2StartMinute = const Value.absent(),
                Value<int?> segment2DurationMinutes = const Value.absent(),
                Value<String?> location = const Value.absent(),
                Value<int?> nightPlusCentsPerHour = const Value.absent(),
                Value<int?> holidayPlusCentsPerHour = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ShiftTypesCompanion(
                id: id,
                code: code,
                name: name,
                colorValue: colorValue,
                category: category,
                startMinute: startMinute,
                endMinute: endMinute,
                paidMinutes: paidMinutes,
                nightOverride: nightOverride,
                hourlyRateCents: hourlyRateCents,
                fixedPlusCents: fixedPlusCents,
                icon: icon,
                alarmSound: alarmSound,
                segment2StartMinute: segment2StartMinute,
                segment2DurationMinutes: segment2DurationMinutes,
                location: location,
                nightPlusCentsPerHour: nightPlusCentsPerHour,
                holidayPlusCentsPerHour: holidayPlusCentsPerHour,
                sortOrder: sortOrder,
                archived: archived,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String code,
                required String name,
                required int colorValue,
                required ShiftCategory category,
                Value<int?> startMinute = const Value.absent(),
                Value<int?> endMinute = const Value.absent(),
                Value<int?> paidMinutes = const Value.absent(),
                Value<bool?> nightOverride = const Value.absent(),
                Value<int?> hourlyRateCents = const Value.absent(),
                Value<int?> fixedPlusCents = const Value.absent(),
                Value<String?> icon = const Value.absent(),
                Value<String?> alarmSound = const Value.absent(),
                Value<int?> segment2StartMinute = const Value.absent(),
                Value<int?> segment2DurationMinutes = const Value.absent(),
                Value<String?> location = const Value.absent(),
                Value<int?> nightPlusCentsPerHour = const Value.absent(),
                Value<int?> holidayPlusCentsPerHour = const Value.absent(),
                required int sortOrder,
                Value<bool> archived = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ShiftTypesCompanion.insert(
                id: id,
                code: code,
                name: name,
                colorValue: colorValue,
                category: category,
                startMinute: startMinute,
                endMinute: endMinute,
                paidMinutes: paidMinutes,
                nightOverride: nightOverride,
                hourlyRateCents: hourlyRateCents,
                fixedPlusCents: fixedPlusCents,
                icon: icon,
                alarmSound: alarmSound,
                segment2StartMinute: segment2StartMinute,
                segment2DurationMinutes: segment2DurationMinutes,
                location: location,
                nightPlusCentsPerHour: nightPlusCentsPerHour,
                holidayPlusCentsPerHour: holidayPlusCentsPerHour,
                sortOrder: sortOrder,
                archived: archived,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ShiftTypesTable, ShiftTypeRow>(table),
                  $$ShiftTypesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({shiftTypeVersionsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (shiftTypeVersionsRefs) db.shiftTypeVersions,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (shiftTypeVersionsRefs)
                    await $_getPrefetchedData<
                      ShiftTypeRow,
                      $ShiftTypesTable,
                      ShiftTypeVersionRow
                    >(
                      currentTable: table,
                      referencedTable: $$ShiftTypesTableReferences
                          ._shiftTypeVersionsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$ShiftTypesTableReferences(
                            db,
                            table,
                            p0,
                          ).shiftTypeVersionsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.shiftTypeId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$ShiftTypesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ShiftTypesTable,
      ShiftTypeRow,
      $$ShiftTypesTableFilterComposer,
      $$ShiftTypesTableOrderingComposer,
      $$ShiftTypesTableAnnotationComposer,
      $$ShiftTypesTableCreateCompanionBuilder,
      $$ShiftTypesTableUpdateCompanionBuilder,
      (ShiftTypeRow, $$ShiftTypesTableReferences),
      ShiftTypeRow,
      PrefetchHooks Function({bool shiftTypeVersionsRefs})
    >;
typedef $$ShiftTypeVersionsTableCreateCompanionBuilder =
    ShiftTypeVersionsCompanion Function({
      required String shiftTypeId,
      required CivilDate untilDate,
      required ShiftCategory category,
      Value<int?> startMinute,
      Value<int?> endMinute,
      Value<int?> paidMinutes,
      Value<bool?> nightOverride,
      Value<int?> hourlyRateCents,
      Value<int?> fixedPlusCents,
      Value<int?> segment2StartMinute,
      Value<int?> segment2DurationMinutes,
      Value<int?> nightPlusCentsPerHour,
      Value<int?> holidayPlusCentsPerHour,
      required int createdAt,
      Value<int> rowid,
    });
typedef $$ShiftTypeVersionsTableUpdateCompanionBuilder =
    ShiftTypeVersionsCompanion Function({
      Value<String> shiftTypeId,
      Value<CivilDate> untilDate,
      Value<ShiftCategory> category,
      Value<int?> startMinute,
      Value<int?> endMinute,
      Value<int?> paidMinutes,
      Value<bool?> nightOverride,
      Value<int?> hourlyRateCents,
      Value<int?> fixedPlusCents,
      Value<int?> segment2StartMinute,
      Value<int?> segment2DurationMinutes,
      Value<int?> nightPlusCentsPerHour,
      Value<int?> holidayPlusCentsPerHour,
      Value<int> createdAt,
      Value<int> rowid,
    });

final class $$ShiftTypeVersionsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $ShiftTypeVersionsTable,
          ShiftTypeVersionRow
        > {
  $$ShiftTypeVersionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ShiftTypesTable _shiftTypeIdTable(_$AppDatabase db) => db.shiftTypes
      .createAlias('shift_type_versions__shift_type_id__shift_types__id');

  $$ShiftTypesTableProcessedTableManager get shiftTypeId {
    final $_column = $_itemColumn<String>('shift_type_id')!;

    final manager = $$ShiftTypesTableTableManager(
      $_db,
      $_db.shiftTypes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_shiftTypeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ShiftTypeVersionsTableFilterComposer
    extends Composer<_$AppDatabase, $ShiftTypeVersionsTable> {
  $$ShiftTypeVersionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnWithTypeConverterFilters<CivilDate, CivilDate, String> get untilDate =>
      $composableBuilder(
        column: $table.untilDate,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<ShiftCategory, ShiftCategory, String>
  get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get startMinute => $composableBuilder(
    column: $table.startMinute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endMinute => $composableBuilder(
    column: $table.endMinute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get paidMinutes => $composableBuilder(
    column: $table.paidMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get nightOverride => $composableBuilder(
    column: $table.nightOverride,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get hourlyRateCents => $composableBuilder(
    column: $table.hourlyRateCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fixedPlusCents => $composableBuilder(
    column: $table.fixedPlusCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get segment2StartMinute => $composableBuilder(
    column: $table.segment2StartMinute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get segment2DurationMinutes => $composableBuilder(
    column: $table.segment2DurationMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get nightPlusCentsPerHour => $composableBuilder(
    column: $table.nightPlusCentsPerHour,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get holidayPlusCentsPerHour => $composableBuilder(
    column: $table.holidayPlusCentsPerHour,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ShiftTypesTableFilterComposer get shiftTypeId {
    final $$ShiftTypesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.shiftTypeId,
      referencedTable: $db.shiftTypes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShiftTypesTableFilterComposer(
            $db: $db,
            $table: $db.shiftTypes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ShiftTypeVersionsTableOrderingComposer
    extends Composer<_$AppDatabase, $ShiftTypeVersionsTable> {
  $$ShiftTypeVersionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get untilDate => $composableBuilder(
    column: $table.untilDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startMinute => $composableBuilder(
    column: $table.startMinute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endMinute => $composableBuilder(
    column: $table.endMinute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get paidMinutes => $composableBuilder(
    column: $table.paidMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get nightOverride => $composableBuilder(
    column: $table.nightOverride,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get hourlyRateCents => $composableBuilder(
    column: $table.hourlyRateCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fixedPlusCents => $composableBuilder(
    column: $table.fixedPlusCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get segment2StartMinute => $composableBuilder(
    column: $table.segment2StartMinute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get segment2DurationMinutes => $composableBuilder(
    column: $table.segment2DurationMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get nightPlusCentsPerHour => $composableBuilder(
    column: $table.nightPlusCentsPerHour,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get holidayPlusCentsPerHour => $composableBuilder(
    column: $table.holidayPlusCentsPerHour,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ShiftTypesTableOrderingComposer get shiftTypeId {
    final $$ShiftTypesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.shiftTypeId,
      referencedTable: $db.shiftTypes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShiftTypesTableOrderingComposer(
            $db: $db,
            $table: $db.shiftTypes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ShiftTypeVersionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ShiftTypeVersionsTable> {
  $$ShiftTypeVersionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumnWithTypeConverter<CivilDate, String> get untilDate =>
      $composableBuilder(column: $table.untilDate, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ShiftCategory, String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<int> get startMinute => $composableBuilder(
    column: $table.startMinute,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endMinute =>
      $composableBuilder(column: $table.endMinute, builder: (column) => column);

  GeneratedColumn<int> get paidMinutes => $composableBuilder(
    column: $table.paidMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get nightOverride => $composableBuilder(
    column: $table.nightOverride,
    builder: (column) => column,
  );

  GeneratedColumn<int> get hourlyRateCents => $composableBuilder(
    column: $table.hourlyRateCents,
    builder: (column) => column,
  );

  GeneratedColumn<int> get fixedPlusCents => $composableBuilder(
    column: $table.fixedPlusCents,
    builder: (column) => column,
  );

  GeneratedColumn<int> get segment2StartMinute => $composableBuilder(
    column: $table.segment2StartMinute,
    builder: (column) => column,
  );

  GeneratedColumn<int> get segment2DurationMinutes => $composableBuilder(
    column: $table.segment2DurationMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get nightPlusCentsPerHour => $composableBuilder(
    column: $table.nightPlusCentsPerHour,
    builder: (column) => column,
  );

  GeneratedColumn<int> get holidayPlusCentsPerHour => $composableBuilder(
    column: $table.holidayPlusCentsPerHour,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$ShiftTypesTableAnnotationComposer get shiftTypeId {
    final $$ShiftTypesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.shiftTypeId,
      referencedTable: $db.shiftTypes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShiftTypesTableAnnotationComposer(
            $db: $db,
            $table: $db.shiftTypes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ShiftTypeVersionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ShiftTypeVersionsTable,
          ShiftTypeVersionRow,
          $$ShiftTypeVersionsTableFilterComposer,
          $$ShiftTypeVersionsTableOrderingComposer,
          $$ShiftTypeVersionsTableAnnotationComposer,
          $$ShiftTypeVersionsTableCreateCompanionBuilder,
          $$ShiftTypeVersionsTableUpdateCompanionBuilder,
          (ShiftTypeVersionRow, $$ShiftTypeVersionsTableReferences),
          ShiftTypeVersionRow,
          PrefetchHooks Function({bool shiftTypeId})
        > {
  $$ShiftTypeVersionsTableTableManager(
    _$AppDatabase db,
    $ShiftTypeVersionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ShiftTypeVersionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ShiftTypeVersionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ShiftTypeVersionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> shiftTypeId = const Value.absent(),
                Value<CivilDate> untilDate = const Value.absent(),
                Value<ShiftCategory> category = const Value.absent(),
                Value<int?> startMinute = const Value.absent(),
                Value<int?> endMinute = const Value.absent(),
                Value<int?> paidMinutes = const Value.absent(),
                Value<bool?> nightOverride = const Value.absent(),
                Value<int?> hourlyRateCents = const Value.absent(),
                Value<int?> fixedPlusCents = const Value.absent(),
                Value<int?> segment2StartMinute = const Value.absent(),
                Value<int?> segment2DurationMinutes = const Value.absent(),
                Value<int?> nightPlusCentsPerHour = const Value.absent(),
                Value<int?> holidayPlusCentsPerHour = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ShiftTypeVersionsCompanion(
                shiftTypeId: shiftTypeId,
                untilDate: untilDate,
                category: category,
                startMinute: startMinute,
                endMinute: endMinute,
                paidMinutes: paidMinutes,
                nightOverride: nightOverride,
                hourlyRateCents: hourlyRateCents,
                fixedPlusCents: fixedPlusCents,
                segment2StartMinute: segment2StartMinute,
                segment2DurationMinutes: segment2DurationMinutes,
                nightPlusCentsPerHour: nightPlusCentsPerHour,
                holidayPlusCentsPerHour: holidayPlusCentsPerHour,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String shiftTypeId,
                required CivilDate untilDate,
                required ShiftCategory category,
                Value<int?> startMinute = const Value.absent(),
                Value<int?> endMinute = const Value.absent(),
                Value<int?> paidMinutes = const Value.absent(),
                Value<bool?> nightOverride = const Value.absent(),
                Value<int?> hourlyRateCents = const Value.absent(),
                Value<int?> fixedPlusCents = const Value.absent(),
                Value<int?> segment2StartMinute = const Value.absent(),
                Value<int?> segment2DurationMinutes = const Value.absent(),
                Value<int?> nightPlusCentsPerHour = const Value.absent(),
                Value<int?> holidayPlusCentsPerHour = const Value.absent(),
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => ShiftTypeVersionsCompanion.insert(
                shiftTypeId: shiftTypeId,
                untilDate: untilDate,
                category: category,
                startMinute: startMinute,
                endMinute: endMinute,
                paidMinutes: paidMinutes,
                nightOverride: nightOverride,
                hourlyRateCents: hourlyRateCents,
                fixedPlusCents: fixedPlusCents,
                segment2StartMinute: segment2StartMinute,
                segment2DurationMinutes: segment2DurationMinutes,
                nightPlusCentsPerHour: nightPlusCentsPerHour,
                holidayPlusCentsPerHour: holidayPlusCentsPerHour,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ShiftTypeVersionsTable, ShiftTypeVersionRow>(
                    table,
                  ),
                  $$ShiftTypeVersionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({shiftTypeId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (shiftTypeId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.shiftTypeId,
                        referencedTable: $$ShiftTypeVersionsTableReferences
                            ._shiftTypeIdTable(db),
                        referencedColumn: $$ShiftTypeVersionsTableReferences
                            ._shiftTypeIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ShiftTypeVersionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ShiftTypeVersionsTable,
      ShiftTypeVersionRow,
      $$ShiftTypeVersionsTableFilterComposer,
      $$ShiftTypeVersionsTableOrderingComposer,
      $$ShiftTypeVersionsTableAnnotationComposer,
      $$ShiftTypeVersionsTableCreateCompanionBuilder,
      $$ShiftTypeVersionsTableUpdateCompanionBuilder,
      (ShiftTypeVersionRow, $$ShiftTypeVersionsTableReferences),
      ShiftTypeVersionRow,
      PrefetchHooks Function({bool shiftTypeId})
    >;
typedef $$PatternsTableCreateCompanionBuilder = PatternsCompanion Function({
  required String id,
  required String name,
  required List<List<String>> steps,
  required int createdAt,
  required int updatedAt,
  Value<int> rowid,
});
typedef $$PatternsTableUpdateCompanionBuilder = PatternsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<List<List<String>>> steps,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<int> rowid,
});

final class $$PatternsTableReferences
    extends BaseReferences<_$AppDatabase, $PatternsTable, PatternRow> {
  $$PatternsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$PatternRunsTable, List<PatternRunRow>>
  _patternRunsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.patternRuns,
    aliasName: 'patterns__id__pattern_runs__pattern_id',
  );

  $$PatternRunsTableProcessedTableManager get patternRunsRefs {
    final manager = $$PatternRunsTableTableManager(
      $_db,
      $_db.patternRuns,
    ).filter((f) => f.patternId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_patternRunsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PatternsTableFilterComposer
    extends Composer<_$AppDatabase, $PatternsTable> {
  $$PatternsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<List<String>>, List<List<String>>, String>
  get steps => $composableBuilder(
    column: $table.steps,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> patternRunsRefs(
    Expression<bool> Function($$PatternRunsTableFilterComposer f) f,
  ) {
    final $$PatternRunsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.patternRuns,
      getReferencedColumn: (t) => t.patternId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PatternRunsTableFilterComposer(
            $db: $db,
            $table: $db.patternRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PatternsTableOrderingComposer
    extends Composer<_$AppDatabase, $PatternsTable> {
  $$PatternsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get steps => $composableBuilder(
    column: $table.steps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PatternsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PatternsTable> {
  $$PatternsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<List<String>>, String> get steps =>
      $composableBuilder(column: $table.steps, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> patternRunsRefs<T extends Object>(
    Expression<T> Function($$PatternRunsTableAnnotationComposer a) f,
  ) {
    final $$PatternRunsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.patternRuns,
      getReferencedColumn: (t) => t.patternId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PatternRunsTableAnnotationComposer(
            $db: $db,
            $table: $db.patternRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PatternsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PatternsTable,
          PatternRow,
          $$PatternsTableFilterComposer,
          $$PatternsTableOrderingComposer,
          $$PatternsTableAnnotationComposer,
          $$PatternsTableCreateCompanionBuilder,
          $$PatternsTableUpdateCompanionBuilder,
          (PatternRow, $$PatternsTableReferences),
          PatternRow,
          PrefetchHooks Function({bool patternRunsRefs})
        > {
  $$PatternsTableTableManager(_$AppDatabase db, $PatternsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PatternsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PatternsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PatternsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<List<List<String>>> steps = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PatternsCompanion(
                id: id,
                name: name,
                steps: steps,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required List<List<String>> steps,
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => PatternsCompanion.insert(
                id: id,
                name: name,
                steps: steps,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PatternsTable, PatternRow>(table),
                  $$PatternsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({patternRunsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (patternRunsRefs) db.patternRuns],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (patternRunsRefs)
                    await $_getPrefetchedData<
                      PatternRow,
                      $PatternsTable,
                      PatternRunRow
                    >(
                      currentTable: table,
                      referencedTable: $$PatternsTableReferences
                          ._patternRunsRefsTable(db),
                      managerFromTypedResult: (p0) => $$PatternsTableReferences(
                        db,
                        table,
                        p0,
                      ).patternRunsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.patternId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$PatternsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PatternsTable,
      PatternRow,
      $$PatternsTableFilterComposer,
      $$PatternsTableOrderingComposer,
      $$PatternsTableAnnotationComposer,
      $$PatternsTableCreateCompanionBuilder,
      $$PatternsTableUpdateCompanionBuilder,
      (PatternRow, $$PatternsTableReferences),
      PatternRow,
      PrefetchHooks Function({bool patternRunsRefs})
    >;
typedef $$PatternRunsTableCreateCompanionBuilder =
    PatternRunsCompanion Function({
      required String id,
      required String calendarId,
      required String patternId,
      required CivilDate startDate,
      Value<CivilDate?> endDate,
      Value<int> stepOffset,
      required int seq,
      required int createdAt,
      Value<int> rowid,
    });
typedef $$PatternRunsTableUpdateCompanionBuilder =
    PatternRunsCompanion Function({
      Value<String> id,
      Value<String> calendarId,
      Value<String> patternId,
      Value<CivilDate> startDate,
      Value<CivilDate?> endDate,
      Value<int> stepOffset,
      Value<int> seq,
      Value<int> createdAt,
      Value<int> rowid,
    });

final class $$PatternRunsTableReferences
    extends BaseReferences<_$AppDatabase, $PatternRunsTable, PatternRunRow> {
  $$PatternRunsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CalendarsTable _calendarIdTable(_$AppDatabase db) =>
      db.calendars.createAlias('pattern_runs__calendar_id__calendars__id');

  $$CalendarsTableProcessedTableManager get calendarId {
    final $_column = $_itemColumn<String>('calendar_id')!;

    final manager = $$CalendarsTableTableManager(
      $_db,
      $_db.calendars,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_calendarIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $PatternsTable _patternIdTable(_$AppDatabase db) =>
      db.patterns.createAlias('pattern_runs__pattern_id__patterns__id');

  $$PatternsTableProcessedTableManager get patternId {
    final $_column = $_itemColumn<String>('pattern_id')!;

    final manager = $$PatternsTableTableManager(
      $_db,
      $_db.patterns,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_patternIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PatternRunsTableFilterComposer
    extends Composer<_$AppDatabase, $PatternRunsTable> {
  $$PatternRunsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<CivilDate, CivilDate, String> get startDate =>
      $composableBuilder(
        column: $table.startDate,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<CivilDate?, CivilDate, String> get endDate =>
      $composableBuilder(
        column: $table.endDate,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get stepOffset => $composableBuilder(
    column: $table.stepOffset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$CalendarsTableFilterComposer get calendarId {
    final $$CalendarsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.calendarId,
      referencedTable: $db.calendars,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CalendarsTableFilterComposer(
            $db: $db,
            $table: $db.calendars,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PatternsTableFilterComposer get patternId {
    final $$PatternsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.patternId,
      referencedTable: $db.patterns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PatternsTableFilterComposer(
            $db: $db,
            $table: $db.patterns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PatternRunsTableOrderingComposer
    extends Composer<_$AppDatabase, $PatternRunsTable> {
  $$PatternRunsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get stepOffset => $composableBuilder(
    column: $table.stepOffset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$CalendarsTableOrderingComposer get calendarId {
    final $$CalendarsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.calendarId,
      referencedTable: $db.calendars,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CalendarsTableOrderingComposer(
            $db: $db,
            $table: $db.calendars,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PatternsTableOrderingComposer get patternId {
    final $$PatternsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.patternId,
      referencedTable: $db.patterns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PatternsTableOrderingComposer(
            $db: $db,
            $table: $db.patterns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PatternRunsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PatternRunsTable> {
  $$PatternRunsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<CivilDate, String> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumnWithTypeConverter<CivilDate?, String> get endDate =>
      $composableBuilder(column: $table.endDate, builder: (column) => column);

  GeneratedColumn<int> get stepOffset => $composableBuilder(
    column: $table.stepOffset,
    builder: (column) => column,
  );

  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$CalendarsTableAnnotationComposer get calendarId {
    final $$CalendarsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.calendarId,
      referencedTable: $db.calendars,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CalendarsTableAnnotationComposer(
            $db: $db,
            $table: $db.calendars,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PatternsTableAnnotationComposer get patternId {
    final $$PatternsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.patternId,
      referencedTable: $db.patterns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PatternsTableAnnotationComposer(
            $db: $db,
            $table: $db.patterns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PatternRunsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PatternRunsTable,
          PatternRunRow,
          $$PatternRunsTableFilterComposer,
          $$PatternRunsTableOrderingComposer,
          $$PatternRunsTableAnnotationComposer,
          $$PatternRunsTableCreateCompanionBuilder,
          $$PatternRunsTableUpdateCompanionBuilder,
          (PatternRunRow, $$PatternRunsTableReferences),
          PatternRunRow,
          PrefetchHooks Function({bool calendarId, bool patternId})
        > {
  $$PatternRunsTableTableManager(_$AppDatabase db, $PatternRunsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PatternRunsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PatternRunsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PatternRunsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> calendarId = const Value.absent(),
                Value<String> patternId = const Value.absent(),
                Value<CivilDate> startDate = const Value.absent(),
                Value<CivilDate?> endDate = const Value.absent(),
                Value<int> stepOffset = const Value.absent(),
                Value<int> seq = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PatternRunsCompanion(
                id: id,
                calendarId: calendarId,
                patternId: patternId,
                startDate: startDate,
                endDate: endDate,
                stepOffset: stepOffset,
                seq: seq,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String calendarId,
                required String patternId,
                required CivilDate startDate,
                Value<CivilDate?> endDate = const Value.absent(),
                Value<int> stepOffset = const Value.absent(),
                required int seq,
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => PatternRunsCompanion.insert(
                id: id,
                calendarId: calendarId,
                patternId: patternId,
                startDate: startDate,
                endDate: endDate,
                stepOffset: stepOffset,
                seq: seq,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PatternRunsTable, PatternRunRow>(table),
                  $$PatternRunsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({calendarId = false, patternId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (calendarId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.calendarId,
                        referencedTable: $$PatternRunsTableReferences
                            ._calendarIdTable(db),
                        referencedColumn: $$PatternRunsTableReferences
                            ._calendarIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (patternId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.patternId,
                        referencedTable: $$PatternRunsTableReferences
                            ._patternIdTable(db),
                        referencedColumn: $$PatternRunsTableReferences
                            ._patternIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PatternRunsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PatternRunsTable,
      PatternRunRow,
      $$PatternRunsTableFilterComposer,
      $$PatternRunsTableOrderingComposer,
      $$PatternRunsTableAnnotationComposer,
      $$PatternRunsTableCreateCompanionBuilder,
      $$PatternRunsTableUpdateCompanionBuilder,
      (PatternRunRow, $$PatternRunsTableReferences),
      PatternRunRow,
      PrefetchHooks Function({bool calendarId, bool patternId})
    >;
typedef $$DayEntriesTableCreateCompanionBuilder = DayEntriesCompanion Function({
  required String calendarId,
  required CivilDate date,
  Value<List<String>?> shiftTypeIds,
  Value<String?> note,
  required int updatedAt,
  Value<int?> noteReminderMinute,
  Value<int?> overtimeMinutes,
  Value<int?> earlyLeaveMinutes,
  Value<int?> extraAmountCents,
  Value<int> rowid,
});
typedef $$DayEntriesTableUpdateCompanionBuilder = DayEntriesCompanion Function({
  Value<String> calendarId,
  Value<CivilDate> date,
  Value<List<String>?> shiftTypeIds,
  Value<String?> note,
  Value<int> updatedAt,
  Value<int?> noteReminderMinute,
  Value<int?> overtimeMinutes,
  Value<int?> earlyLeaveMinutes,
  Value<int?> extraAmountCents,
  Value<int> rowid,
});

final class $$DayEntriesTableReferences
    extends BaseReferences<_$AppDatabase, $DayEntriesTable, DayEntryRow> {
  $$DayEntriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CalendarsTable _calendarIdTable(_$AppDatabase db) =>
      db.calendars.createAlias('day_entries__calendar_id__calendars__id');

  $$CalendarsTableProcessedTableManager get calendarId {
    final $_column = $_itemColumn<String>('calendar_id')!;

    final manager = $$CalendarsTableTableManager(
      $_db,
      $_db.calendars,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_calendarIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DayEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $DayEntriesTable> {
  $$DayEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnWithTypeConverterFilters<CivilDate, CivilDate, String> get date =>
      $composableBuilder(
        column: $table.date,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<List<String>?, List<String>, String>
  get shiftTypeIds => $composableBuilder(
    column: $table.shiftTypeIds,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get noteReminderMinute => $composableBuilder(
    column: $table.noteReminderMinute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get overtimeMinutes => $composableBuilder(
    column: $table.overtimeMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get earlyLeaveMinutes => $composableBuilder(
    column: $table.earlyLeaveMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get extraAmountCents => $composableBuilder(
    column: $table.extraAmountCents,
    builder: (column) => ColumnFilters(column),
  );

  $$CalendarsTableFilterComposer get calendarId {
    final $$CalendarsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.calendarId,
      referencedTable: $db.calendars,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CalendarsTableFilterComposer(
            $db: $db,
            $table: $db.calendars,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DayEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $DayEntriesTable> {
  $$DayEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get shiftTypeIds => $composableBuilder(
    column: $table.shiftTypeIds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get noteReminderMinute => $composableBuilder(
    column: $table.noteReminderMinute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get overtimeMinutes => $composableBuilder(
    column: $table.overtimeMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get earlyLeaveMinutes => $composableBuilder(
    column: $table.earlyLeaveMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get extraAmountCents => $composableBuilder(
    column: $table.extraAmountCents,
    builder: (column) => ColumnOrderings(column),
  );

  $$CalendarsTableOrderingComposer get calendarId {
    final $$CalendarsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.calendarId,
      referencedTable: $db.calendars,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CalendarsTableOrderingComposer(
            $db: $db,
            $table: $db.calendars,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DayEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DayEntriesTable> {
  $$DayEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumnWithTypeConverter<CivilDate, String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<String>?, String> get shiftTypeIds =>
      $composableBuilder(
        column: $table.shiftTypeIds,
        builder: (column) => column,
      );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get noteReminderMinute => $composableBuilder(
    column: $table.noteReminderMinute,
    builder: (column) => column,
  );

  GeneratedColumn<int> get overtimeMinutes => $composableBuilder(
    column: $table.overtimeMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get earlyLeaveMinutes => $composableBuilder(
    column: $table.earlyLeaveMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get extraAmountCents => $composableBuilder(
    column: $table.extraAmountCents,
    builder: (column) => column,
  );

  $$CalendarsTableAnnotationComposer get calendarId {
    final $$CalendarsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.calendarId,
      referencedTable: $db.calendars,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CalendarsTableAnnotationComposer(
            $db: $db,
            $table: $db.calendars,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DayEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DayEntriesTable,
          DayEntryRow,
          $$DayEntriesTableFilterComposer,
          $$DayEntriesTableOrderingComposer,
          $$DayEntriesTableAnnotationComposer,
          $$DayEntriesTableCreateCompanionBuilder,
          $$DayEntriesTableUpdateCompanionBuilder,
          (DayEntryRow, $$DayEntriesTableReferences),
          DayEntryRow,
          PrefetchHooks Function({bool calendarId})
        > {
  $$DayEntriesTableTableManager(_$AppDatabase db, $DayEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DayEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DayEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DayEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> calendarId = const Value.absent(),
                Value<CivilDate> date = const Value.absent(),
                Value<List<String>?> shiftTypeIds = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> noteReminderMinute = const Value.absent(),
                Value<int?> overtimeMinutes = const Value.absent(),
                Value<int?> earlyLeaveMinutes = const Value.absent(),
                Value<int?> extraAmountCents = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DayEntriesCompanion(
                calendarId: calendarId,
                date: date,
                shiftTypeIds: shiftTypeIds,
                note: note,
                updatedAt: updatedAt,
                noteReminderMinute: noteReminderMinute,
                overtimeMinutes: overtimeMinutes,
                earlyLeaveMinutes: earlyLeaveMinutes,
                extraAmountCents: extraAmountCents,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String calendarId,
                required CivilDate date,
                Value<List<String>?> shiftTypeIds = const Value.absent(),
                Value<String?> note = const Value.absent(),
                required int updatedAt,
                Value<int?> noteReminderMinute = const Value.absent(),
                Value<int?> overtimeMinutes = const Value.absent(),
                Value<int?> earlyLeaveMinutes = const Value.absent(),
                Value<int?> extraAmountCents = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DayEntriesCompanion.insert(
                calendarId: calendarId,
                date: date,
                shiftTypeIds: shiftTypeIds,
                note: note,
                updatedAt: updatedAt,
                noteReminderMinute: noteReminderMinute,
                overtimeMinutes: overtimeMinutes,
                earlyLeaveMinutes: earlyLeaveMinutes,
                extraAmountCents: extraAmountCents,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DayEntriesTable, DayEntryRow>(table),
                  $$DayEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({calendarId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (calendarId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.calendarId,
                        referencedTable: $$DayEntriesTableReferences
                            ._calendarIdTable(db),
                        referencedColumn: $$DayEntriesTableReferences
                            ._calendarIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$DayEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DayEntriesTable,
      DayEntryRow,
      $$DayEntriesTableFilterComposer,
      $$DayEntriesTableOrderingComposer,
      $$DayEntriesTableAnnotationComposer,
      $$DayEntriesTableCreateCompanionBuilder,
      $$DayEntriesTableUpdateCompanionBuilder,
      (DayEntryRow, $$DayEntriesTableReferences),
      DayEntryRow,
      PrefetchHooks Function({bool calendarId})
    >;
typedef $$NoteAttachmentsTableCreateCompanionBuilder =
    NoteAttachmentsCompanion Function({
      required String id,
      required String calendarId,
      required CivilDate date,
      required AttachmentKind kind,
      required String relativePath,
      required String mimeType,
      required int sizeBytes,
      required String sha256,
      Value<String?> displayName,
      Value<int> sortOrder,
      required int createdAt,
      Value<int> rowid,
    });
typedef $$NoteAttachmentsTableUpdateCompanionBuilder =
    NoteAttachmentsCompanion Function({
      Value<String> id,
      Value<String> calendarId,
      Value<CivilDate> date,
      Value<AttachmentKind> kind,
      Value<String> relativePath,
      Value<String> mimeType,
      Value<int> sizeBytes,
      Value<String> sha256,
      Value<String?> displayName,
      Value<int> sortOrder,
      Value<int> createdAt,
      Value<int> rowid,
    });

final class $$NoteAttachmentsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $NoteAttachmentsTable,
          NoteAttachmentRow
        > {
  $$NoteAttachmentsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CalendarsTable _calendarIdTable(_$AppDatabase db) =>
      db.calendars.createAlias('note_attachments__calendar_id__calendars__id');

  $$CalendarsTableProcessedTableManager get calendarId {
    final $_column = $_itemColumn<String>('calendar_id')!;

    final manager = $$CalendarsTableTableManager(
      $_db,
      $_db.calendars,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_calendarIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$NoteAttachmentsTableFilterComposer
    extends Composer<_$AppDatabase, $NoteAttachmentsTable> {
  $$NoteAttachmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<CivilDate, CivilDate, String> get date =>
      $composableBuilder(
        column: $table.date,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<AttachmentKind, AttachmentKind, String>
  get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$CalendarsTableFilterComposer get calendarId {
    final $$CalendarsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.calendarId,
      referencedTable: $db.calendars,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CalendarsTableFilterComposer(
            $db: $db,
            $table: $db.calendars,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NoteAttachmentsTableOrderingComposer
    extends Composer<_$AppDatabase, $NoteAttachmentsTable> {
  $$NoteAttachmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$CalendarsTableOrderingComposer get calendarId {
    final $$CalendarsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.calendarId,
      referencedTable: $db.calendars,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CalendarsTableOrderingComposer(
            $db: $db,
            $table: $db.calendars,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NoteAttachmentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $NoteAttachmentsTable> {
  $$NoteAttachmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<CivilDate, String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumnWithTypeConverter<AttachmentKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mimeType =>
      $composableBuilder(column: $table.mimeType, builder: (column) => column);

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<String> get sha256 =>
      $composableBuilder(column: $table.sha256, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$CalendarsTableAnnotationComposer get calendarId {
    final $$CalendarsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.calendarId,
      referencedTable: $db.calendars,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CalendarsTableAnnotationComposer(
            $db: $db,
            $table: $db.calendars,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NoteAttachmentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NoteAttachmentsTable,
          NoteAttachmentRow,
          $$NoteAttachmentsTableFilterComposer,
          $$NoteAttachmentsTableOrderingComposer,
          $$NoteAttachmentsTableAnnotationComposer,
          $$NoteAttachmentsTableCreateCompanionBuilder,
          $$NoteAttachmentsTableUpdateCompanionBuilder,
          (NoteAttachmentRow, $$NoteAttachmentsTableReferences),
          NoteAttachmentRow,
          PrefetchHooks Function({bool calendarId})
        > {
  $$NoteAttachmentsTableTableManager(
    _$AppDatabase db,
    $NoteAttachmentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NoteAttachmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NoteAttachmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NoteAttachmentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> calendarId = const Value.absent(),
                Value<CivilDate> date = const Value.absent(),
                Value<AttachmentKind> kind = const Value.absent(),
                Value<String> relativePath = const Value.absent(),
                Value<String> mimeType = const Value.absent(),
                Value<int> sizeBytes = const Value.absent(),
                Value<String> sha256 = const Value.absent(),
                Value<String?> displayName = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NoteAttachmentsCompanion(
                id: id,
                calendarId: calendarId,
                date: date,
                kind: kind,
                relativePath: relativePath,
                mimeType: mimeType,
                sizeBytes: sizeBytes,
                sha256: sha256,
                displayName: displayName,
                sortOrder: sortOrder,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String calendarId,
                required CivilDate date,
                required AttachmentKind kind,
                required String relativePath,
                required String mimeType,
                required int sizeBytes,
                required String sha256,
                Value<String?> displayName = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => NoteAttachmentsCompanion.insert(
                id: id,
                calendarId: calendarId,
                date: date,
                kind: kind,
                relativePath: relativePath,
                mimeType: mimeType,
                sizeBytes: sizeBytes,
                sha256: sha256,
                displayName: displayName,
                sortOrder: sortOrder,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$NoteAttachmentsTable, NoteAttachmentRow>(table),
                  $$NoteAttachmentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({calendarId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (calendarId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.calendarId,
                        referencedTable: $$NoteAttachmentsTableReferences
                            ._calendarIdTable(db),
                        referencedColumn: $$NoteAttachmentsTableReferences
                            ._calendarIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$NoteAttachmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NoteAttachmentsTable,
      NoteAttachmentRow,
      $$NoteAttachmentsTableFilterComposer,
      $$NoteAttachmentsTableOrderingComposer,
      $$NoteAttachmentsTableAnnotationComposer,
      $$NoteAttachmentsTableCreateCompanionBuilder,
      $$NoteAttachmentsTableUpdateCompanionBuilder,
      (NoteAttachmentRow, $$NoteAttachmentsTableReferences),
      NoteAttachmentRow,
      PrefetchHooks Function({bool calendarId})
    >;
typedef $$DayTasksTableCreateCompanionBuilder = DayTasksCompanion Function({
  required String id,
  required String calendarId,
  required CivilDate date,
  required String title,
  Value<bool> done,
  Value<int> sortOrder,
  required int createdAt,
  required int updatedAt,
  Value<int> rowid,
});
typedef $$DayTasksTableUpdateCompanionBuilder = DayTasksCompanion Function({
  Value<String> id,
  Value<String> calendarId,
  Value<CivilDate> date,
  Value<String> title,
  Value<bool> done,
  Value<int> sortOrder,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<int> rowid,
});

final class $$DayTasksTableReferences
    extends BaseReferences<_$AppDatabase, $DayTasksTable, DayTaskRow> {
  $$DayTasksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CalendarsTable _calendarIdTable(_$AppDatabase db) =>
      db.calendars.createAlias('day_tasks__calendar_id__calendars__id');

  $$CalendarsTableProcessedTableManager get calendarId {
    final $_column = $_itemColumn<String>('calendar_id')!;

    final manager = $$CalendarsTableTableManager(
      $_db,
      $_db.calendars,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_calendarIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DayTasksTableFilterComposer
    extends Composer<_$AppDatabase, $DayTasksTable> {
  $$DayTasksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<CivilDate, CivilDate, String> get date =>
      $composableBuilder(
        column: $table.date,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get done => $composableBuilder(
    column: $table.done,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$CalendarsTableFilterComposer get calendarId {
    final $$CalendarsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.calendarId,
      referencedTable: $db.calendars,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CalendarsTableFilterComposer(
            $db: $db,
            $table: $db.calendars,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DayTasksTableOrderingComposer
    extends Composer<_$AppDatabase, $DayTasksTable> {
  $$DayTasksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get done => $composableBuilder(
    column: $table.done,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$CalendarsTableOrderingComposer get calendarId {
    final $$CalendarsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.calendarId,
      referencedTable: $db.calendars,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CalendarsTableOrderingComposer(
            $db: $db,
            $table: $db.calendars,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DayTasksTableAnnotationComposer
    extends Composer<_$AppDatabase, $DayTasksTable> {
  $$DayTasksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<CivilDate, String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<bool> get done =>
      $composableBuilder(column: $table.done, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$CalendarsTableAnnotationComposer get calendarId {
    final $$CalendarsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.calendarId,
      referencedTable: $db.calendars,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CalendarsTableAnnotationComposer(
            $db: $db,
            $table: $db.calendars,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DayTasksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DayTasksTable,
          DayTaskRow,
          $$DayTasksTableFilterComposer,
          $$DayTasksTableOrderingComposer,
          $$DayTasksTableAnnotationComposer,
          $$DayTasksTableCreateCompanionBuilder,
          $$DayTasksTableUpdateCompanionBuilder,
          (DayTaskRow, $$DayTasksTableReferences),
          DayTaskRow,
          PrefetchHooks Function({bool calendarId})
        > {
  $$DayTasksTableTableManager(_$AppDatabase db, $DayTasksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DayTasksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DayTasksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DayTasksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> calendarId = const Value.absent(),
                Value<CivilDate> date = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<bool> done = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DayTasksCompanion(
                id: id,
                calendarId: calendarId,
                date: date,
                title: title,
                done: done,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String calendarId,
                required CivilDate date,
                required String title,
                Value<bool> done = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => DayTasksCompanion.insert(
                id: id,
                calendarId: calendarId,
                date: date,
                title: title,
                done: done,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DayTasksTable, DayTaskRow>(table),
                  $$DayTasksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({calendarId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (calendarId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.calendarId,
                        referencedTable: $$DayTasksTableReferences
                            ._calendarIdTable(db),
                        referencedColumn: $$DayTasksTableReferences
                            ._calendarIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$DayTasksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DayTasksTable,
      DayTaskRow,
      $$DayTasksTableFilterComposer,
      $$DayTasksTableOrderingComposer,
      $$DayTasksTableAnnotationComposer,
      $$DayTasksTableCreateCompanionBuilder,
      $$DayTasksTableUpdateCompanionBuilder,
      (DayTaskRow, $$DayTasksTableReferences),
      DayTaskRow,
      PrefetchHooks Function({bool calendarId})
    >;
typedef $$ShiftSwapsTableCreateCompanionBuilder = ShiftSwapsCompanion Function({
  required String id,
  required String calendarId,
  required CivilDate date,
  required String colleague,
  required SwapDirection direction,
  Value<List<String>?> givenShiftTypeIds,
  Value<List<String>?> receivedShiftTypeIds,
  Value<CivilDate?> returnDate,
  Value<SwapStatus> status,
  Value<String?> note,
  required int createdAt,
  required int updatedAt,
  Value<int?> closedAt,
  Value<int> rowid,
});
typedef $$ShiftSwapsTableUpdateCompanionBuilder = ShiftSwapsCompanion Function({
  Value<String> id,
  Value<String> calendarId,
  Value<CivilDate> date,
  Value<String> colleague,
  Value<SwapDirection> direction,
  Value<List<String>?> givenShiftTypeIds,
  Value<List<String>?> receivedShiftTypeIds,
  Value<CivilDate?> returnDate,
  Value<SwapStatus> status,
  Value<String?> note,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<int?> closedAt,
  Value<int> rowid,
});

final class $$ShiftSwapsTableReferences
    extends BaseReferences<_$AppDatabase, $ShiftSwapsTable, ShiftSwapRow> {
  $$ShiftSwapsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CalendarsTable _calendarIdTable(_$AppDatabase db) =>
      db.calendars.createAlias('shift_swaps__calendar_id__calendars__id');

  $$CalendarsTableProcessedTableManager get calendarId {
    final $_column = $_itemColumn<String>('calendar_id')!;

    final manager = $$CalendarsTableTableManager(
      $_db,
      $_db.calendars,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_calendarIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ShiftSwapsTableFilterComposer
    extends Composer<_$AppDatabase, $ShiftSwapsTable> {
  $$ShiftSwapsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<CivilDate, CivilDate, String> get date =>
      $composableBuilder(
        column: $table.date,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get colleague => $composableBuilder(
    column: $table.colleague,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<SwapDirection, SwapDirection, String>
  get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>?, List<String>, String>
  get givenShiftTypeIds => $composableBuilder(
    column: $table.givenShiftTypeIds,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>?, List<String>, String>
  get receivedShiftTypeIds => $composableBuilder(
    column: $table.receivedShiftTypeIds,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<CivilDate?, CivilDate, String>
  get returnDate => $composableBuilder(
    column: $table.returnDate,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<SwapStatus, SwapStatus, String> get status =>
      $composableBuilder(
        column: $table.status,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get closedAt => $composableBuilder(
    column: $table.closedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$CalendarsTableFilterComposer get calendarId {
    final $$CalendarsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.calendarId,
      referencedTable: $db.calendars,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CalendarsTableFilterComposer(
            $db: $db,
            $table: $db.calendars,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ShiftSwapsTableOrderingComposer
    extends Composer<_$AppDatabase, $ShiftSwapsTable> {
  $$ShiftSwapsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get colleague => $composableBuilder(
    column: $table.colleague,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get givenShiftTypeIds => $composableBuilder(
    column: $table.givenShiftTypeIds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get receivedShiftTypeIds => $composableBuilder(
    column: $table.receivedShiftTypeIds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get returnDate => $composableBuilder(
    column: $table.returnDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get closedAt => $composableBuilder(
    column: $table.closedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$CalendarsTableOrderingComposer get calendarId {
    final $$CalendarsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.calendarId,
      referencedTable: $db.calendars,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CalendarsTableOrderingComposer(
            $db: $db,
            $table: $db.calendars,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ShiftSwapsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ShiftSwapsTable> {
  $$ShiftSwapsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<CivilDate, String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get colleague =>
      $composableBuilder(column: $table.colleague, builder: (column) => column);

  GeneratedColumnWithTypeConverter<SwapDirection, String> get direction =>
      $composableBuilder(column: $table.direction, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<String>?, String>
  get givenShiftTypeIds => $composableBuilder(
    column: $table.givenShiftTypeIds,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<List<String>?, String>
  get receivedShiftTypeIds => $composableBuilder(
    column: $table.receivedShiftTypeIds,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<CivilDate?, String> get returnDate =>
      $composableBuilder(
        column: $table.returnDate,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<SwapStatus, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get closedAt =>
      $composableBuilder(column: $table.closedAt, builder: (column) => column);

  $$CalendarsTableAnnotationComposer get calendarId {
    final $$CalendarsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.calendarId,
      referencedTable: $db.calendars,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CalendarsTableAnnotationComposer(
            $db: $db,
            $table: $db.calendars,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ShiftSwapsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ShiftSwapsTable,
          ShiftSwapRow,
          $$ShiftSwapsTableFilterComposer,
          $$ShiftSwapsTableOrderingComposer,
          $$ShiftSwapsTableAnnotationComposer,
          $$ShiftSwapsTableCreateCompanionBuilder,
          $$ShiftSwapsTableUpdateCompanionBuilder,
          (ShiftSwapRow, $$ShiftSwapsTableReferences),
          ShiftSwapRow,
          PrefetchHooks Function({bool calendarId})
        > {
  $$ShiftSwapsTableTableManager(_$AppDatabase db, $ShiftSwapsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ShiftSwapsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ShiftSwapsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ShiftSwapsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> calendarId = const Value.absent(),
                Value<CivilDate> date = const Value.absent(),
                Value<String> colleague = const Value.absent(),
                Value<SwapDirection> direction = const Value.absent(),
                Value<List<String>?> givenShiftTypeIds = const Value.absent(),
                Value<List<String>?> receivedShiftTypeIds =
                    const Value.absent(),
                Value<CivilDate?> returnDate = const Value.absent(),
                Value<SwapStatus> status = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> closedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ShiftSwapsCompanion(
                id: id,
                calendarId: calendarId,
                date: date,
                colleague: colleague,
                direction: direction,
                givenShiftTypeIds: givenShiftTypeIds,
                receivedShiftTypeIds: receivedShiftTypeIds,
                returnDate: returnDate,
                status: status,
                note: note,
                createdAt: createdAt,
                updatedAt: updatedAt,
                closedAt: closedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String calendarId,
                required CivilDate date,
                required String colleague,
                required SwapDirection direction,
                Value<List<String>?> givenShiftTypeIds = const Value.absent(),
                Value<List<String>?> receivedShiftTypeIds =
                    const Value.absent(),
                Value<CivilDate?> returnDate = const Value.absent(),
                Value<SwapStatus> status = const Value.absent(),
                Value<String?> note = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int?> closedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ShiftSwapsCompanion.insert(
                id: id,
                calendarId: calendarId,
                date: date,
                colleague: colleague,
                direction: direction,
                givenShiftTypeIds: givenShiftTypeIds,
                receivedShiftTypeIds: receivedShiftTypeIds,
                returnDate: returnDate,
                status: status,
                note: note,
                createdAt: createdAt,
                updatedAt: updatedAt,
                closedAt: closedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ShiftSwapsTable, ShiftSwapRow>(table),
                  $$ShiftSwapsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({calendarId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (calendarId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.calendarId,
                        referencedTable: $$ShiftSwapsTableReferences
                            ._calendarIdTable(db),
                        referencedColumn: $$ShiftSwapsTableReferences
                            ._calendarIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ShiftSwapsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ShiftSwapsTable,
      ShiftSwapRow,
      $$ShiftSwapsTableFilterComposer,
      $$ShiftSwapsTableOrderingComposer,
      $$ShiftSwapsTableAnnotationComposer,
      $$ShiftSwapsTableCreateCompanionBuilder,
      $$ShiftSwapsTableUpdateCompanionBuilder,
      (ShiftSwapRow, $$ShiftSwapsTableReferences),
      ShiftSwapRow,
      PrefetchHooks Function({bool calendarId})
    >;
typedef $$HolidaysTableCreateCompanionBuilder = HolidaysCompanion Function({
  Value<int> id,
  required String date,
  required String scope,
  required String name,
  Value<String?> regionCode,
  Value<String?> municipalityCode,
  required String source,
});
typedef $$HolidaysTableUpdateCompanionBuilder = HolidaysCompanion Function({
  Value<int> id,
  Value<String> date,
  Value<String> scope,
  Value<String> name,
  Value<String?> regionCode,
  Value<String?> municipalityCode,
  Value<String> source,
});

class $$HolidaysTableFilterComposer
    extends Composer<_$AppDatabase, $HolidaysTable> {
  $$HolidaysTableFilterComposer({
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

  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get regionCode => $composableBuilder(
    column: $table.regionCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get municipalityCode => $composableBuilder(
    column: $table.municipalityCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );
}

class $$HolidaysTableOrderingComposer
    extends Composer<_$AppDatabase, $HolidaysTable> {
  $$HolidaysTableOrderingComposer({
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

  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get regionCode => $composableBuilder(
    column: $table.regionCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get municipalityCode => $composableBuilder(
    column: $table.municipalityCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HolidaysTableAnnotationComposer
    extends Composer<_$AppDatabase, $HolidaysTable> {
  $$HolidaysTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get regionCode => $composableBuilder(
    column: $table.regionCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get municipalityCode => $composableBuilder(
    column: $table.municipalityCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);
}

class $$HolidaysTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HolidaysTable,
          HolidayRow,
          $$HolidaysTableFilterComposer,
          $$HolidaysTableOrderingComposer,
          $$HolidaysTableAnnotationComposer,
          $$HolidaysTableCreateCompanionBuilder,
          $$HolidaysTableUpdateCompanionBuilder,
          (
            HolidayRow,
            BaseReferences<_$AppDatabase, $HolidaysTable, HolidayRow>,
          ),
          HolidayRow,
          PrefetchHooks Function()
        > {
  $$HolidaysTableTableManager(_$AppDatabase db, $HolidaysTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HolidaysTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HolidaysTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HolidaysTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> date = const Value.absent(),
                Value<String> scope = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> regionCode = const Value.absent(),
                Value<String?> municipalityCode = const Value.absent(),
                Value<String> source = const Value.absent(),
              }) => HolidaysCompanion(
                id: id,
                date: date,
                scope: scope,
                name: name,
                regionCode: regionCode,
                municipalityCode: municipalityCode,
                source: source,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String date,
                required String scope,
                required String name,
                Value<String?> regionCode = const Value.absent(),
                Value<String?> municipalityCode = const Value.absent(),
                required String source,
              }) => HolidaysCompanion.insert(
                id: id,
                date: date,
                scope: scope,
                name: name,
                regionCode: regionCode,
                municipalityCode: municipalityCode,
                source: source,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$HolidaysTable, HolidayRow>(table),
                  BaseReferences<_$AppDatabase, $HolidaysTable, HolidayRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HolidaysTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HolidaysTable,
      HolidayRow,
      $$HolidaysTableFilterComposer,
      $$HolidaysTableOrderingComposer,
      $$HolidaysTableAnnotationComposer,
      $$HolidaysTableCreateCompanionBuilder,
      $$HolidaysTableUpdateCompanionBuilder,
      (HolidayRow, BaseReferences<_$AppDatabase, $HolidaysTable, HolidayRow>),
      HolidayRow,
      PrefetchHooks Function()
    >;
typedef $$AbsenceBalancesTableCreateCompanionBuilder =
    AbsenceBalancesCompanion Function({
      required int year,
      required String type,
      required double allowedDays,
      Value<String?> calendarId,
      Value<String?> name,
      Value<CivilDate?> periodStart,
      Value<CivilDate?> periodEnd,
      Value<AbsenceUnit> unit,
      Value<Map<String, int>?> shiftTypeQuarters,
      Value<bool> carryOver,
      Value<double?> carryOverMaxDays,
      Value<double> adjustmentDays,
      Value<int> sortOrder,
      Value<int?> createdAt,
      Value<int?> updatedAt,
      Value<int> rowid,
    });
typedef $$AbsenceBalancesTableUpdateCompanionBuilder =
    AbsenceBalancesCompanion Function({
      Value<int> year,
      Value<String> type,
      Value<double> allowedDays,
      Value<String?> calendarId,
      Value<String?> name,
      Value<CivilDate?> periodStart,
      Value<CivilDate?> periodEnd,
      Value<AbsenceUnit> unit,
      Value<Map<String, int>?> shiftTypeQuarters,
      Value<bool> carryOver,
      Value<double?> carryOverMaxDays,
      Value<double> adjustmentDays,
      Value<int> sortOrder,
      Value<int?> createdAt,
      Value<int?> updatedAt,
      Value<int> rowid,
    });

final class $$AbsenceBalancesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $AbsenceBalancesTable,
          AbsenceBalanceRow
        > {
  $$AbsenceBalancesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CalendarsTable _calendarIdTable(_$AppDatabase db) =>
      db.calendars.createAlias('absence_balances__calendar_id__calendars__id');

  $$CalendarsTableProcessedTableManager? get calendarId {
    final $_column = $_itemColumn<String>('calendar_id');
    if ($_column == null) return null;
    final manager = $$CalendarsTableTableManager(
      $_db,
      $_db.calendars,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_calendarIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AbsenceBalancesTableFilterComposer
    extends Composer<_$AppDatabase, $AbsenceBalancesTable> {
  $$AbsenceBalancesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get allowedDays => $composableBuilder(
    column: $table.allowedDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<CivilDate?, CivilDate, String>
  get periodStart => $composableBuilder(
    column: $table.periodStart,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<CivilDate?, CivilDate, String> get periodEnd =>
      $composableBuilder(
        column: $table.periodEnd,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<AbsenceUnit, AbsenceUnit, String> get unit =>
      $composableBuilder(
        column: $table.unit,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<Map<String, int>?, Map<String, int>, String>
  get shiftTypeQuarters => $composableBuilder(
    column: $table.shiftTypeQuarters,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<bool> get carryOver => $composableBuilder(
    column: $table.carryOver,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get carryOverMaxDays => $composableBuilder(
    column: $table.carryOverMaxDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get adjustmentDays => $composableBuilder(
    column: $table.adjustmentDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$CalendarsTableFilterComposer get calendarId {
    final $$CalendarsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.calendarId,
      referencedTable: $db.calendars,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CalendarsTableFilterComposer(
            $db: $db,
            $table: $db.calendars,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AbsenceBalancesTableOrderingComposer
    extends Composer<_$AppDatabase, $AbsenceBalancesTable> {
  $$AbsenceBalancesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get allowedDays => $composableBuilder(
    column: $table.allowedDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get periodStart => $composableBuilder(
    column: $table.periodStart,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get periodEnd => $composableBuilder(
    column: $table.periodEnd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get shiftTypeQuarters => $composableBuilder(
    column: $table.shiftTypeQuarters,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get carryOver => $composableBuilder(
    column: $table.carryOver,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get carryOverMaxDays => $composableBuilder(
    column: $table.carryOverMaxDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get adjustmentDays => $composableBuilder(
    column: $table.adjustmentDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$CalendarsTableOrderingComposer get calendarId {
    final $$CalendarsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.calendarId,
      referencedTable: $db.calendars,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CalendarsTableOrderingComposer(
            $db: $db,
            $table: $db.calendars,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AbsenceBalancesTableAnnotationComposer
    extends Composer<_$AppDatabase, $AbsenceBalancesTable> {
  $$AbsenceBalancesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<double> get allowedDays => $composableBuilder(
    column: $table.allowedDays,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumnWithTypeConverter<CivilDate?, String> get periodStart =>
      $composableBuilder(
        column: $table.periodStart,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<CivilDate?, String> get periodEnd =>
      $composableBuilder(column: $table.periodEnd, builder: (column) => column);

  GeneratedColumnWithTypeConverter<AbsenceUnit, String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Map<String, int>?, String>
  get shiftTypeQuarters => $composableBuilder(
    column: $table.shiftTypeQuarters,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get carryOver =>
      $composableBuilder(column: $table.carryOver, builder: (column) => column);

  GeneratedColumn<double> get carryOverMaxDays => $composableBuilder(
    column: $table.carryOverMaxDays,
    builder: (column) => column,
  );

  GeneratedColumn<double> get adjustmentDays => $composableBuilder(
    column: $table.adjustmentDays,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$CalendarsTableAnnotationComposer get calendarId {
    final $$CalendarsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.calendarId,
      referencedTable: $db.calendars,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CalendarsTableAnnotationComposer(
            $db: $db,
            $table: $db.calendars,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AbsenceBalancesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AbsenceBalancesTable,
          AbsenceBalanceRow,
          $$AbsenceBalancesTableFilterComposer,
          $$AbsenceBalancesTableOrderingComposer,
          $$AbsenceBalancesTableAnnotationComposer,
          $$AbsenceBalancesTableCreateCompanionBuilder,
          $$AbsenceBalancesTableUpdateCompanionBuilder,
          (AbsenceBalanceRow, $$AbsenceBalancesTableReferences),
          AbsenceBalanceRow,
          PrefetchHooks Function({bool calendarId})
        > {
  $$AbsenceBalancesTableTableManager(
    _$AppDatabase db,
    $AbsenceBalancesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AbsenceBalancesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AbsenceBalancesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AbsenceBalancesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> year = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<double> allowedDays = const Value.absent(),
                Value<String?> calendarId = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<CivilDate?> periodStart = const Value.absent(),
                Value<CivilDate?> periodEnd = const Value.absent(),
                Value<AbsenceUnit> unit = const Value.absent(),
                Value<Map<String, int>?> shiftTypeQuarters =
                    const Value.absent(),
                Value<bool> carryOver = const Value.absent(),
                Value<double?> carryOverMaxDays = const Value.absent(),
                Value<double> adjustmentDays = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int?> createdAt = const Value.absent(),
                Value<int?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AbsenceBalancesCompanion(
                year: year,
                type: type,
                allowedDays: allowedDays,
                calendarId: calendarId,
                name: name,
                periodStart: periodStart,
                periodEnd: periodEnd,
                unit: unit,
                shiftTypeQuarters: shiftTypeQuarters,
                carryOver: carryOver,
                carryOverMaxDays: carryOverMaxDays,
                adjustmentDays: adjustmentDays,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int year,
                required String type,
                required double allowedDays,
                Value<String?> calendarId = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<CivilDate?> periodStart = const Value.absent(),
                Value<CivilDate?> periodEnd = const Value.absent(),
                Value<AbsenceUnit> unit = const Value.absent(),
                Value<Map<String, int>?> shiftTypeQuarters =
                    const Value.absent(),
                Value<bool> carryOver = const Value.absent(),
                Value<double?> carryOverMaxDays = const Value.absent(),
                Value<double> adjustmentDays = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int?> createdAt = const Value.absent(),
                Value<int?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AbsenceBalancesCompanion.insert(
                year: year,
                type: type,
                allowedDays: allowedDays,
                calendarId: calendarId,
                name: name,
                periodStart: periodStart,
                periodEnd: periodEnd,
                unit: unit,
                shiftTypeQuarters: shiftTypeQuarters,
                carryOver: carryOver,
                carryOverMaxDays: carryOverMaxDays,
                adjustmentDays: adjustmentDays,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AbsenceBalancesTable, AbsenceBalanceRow>(table),
                  $$AbsenceBalancesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({calendarId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (calendarId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.calendarId,
                        referencedTable: $$AbsenceBalancesTableReferences
                            ._calendarIdTable(db),
                        referencedColumn: $$AbsenceBalancesTableReferences
                            ._calendarIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$AbsenceBalancesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AbsenceBalancesTable,
      AbsenceBalanceRow,
      $$AbsenceBalancesTableFilterComposer,
      $$AbsenceBalancesTableOrderingComposer,
      $$AbsenceBalancesTableAnnotationComposer,
      $$AbsenceBalancesTableCreateCompanionBuilder,
      $$AbsenceBalancesTableUpdateCompanionBuilder,
      (AbsenceBalanceRow, $$AbsenceBalancesTableReferences),
      AbsenceBalanceRow,
      PrefetchHooks Function({bool calendarId})
    >;
typedef $$SettingsTableCreateCompanionBuilder = SettingsCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$SettingsTableUpdateCompanionBuilder = SettingsCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingsTable,
          SettingRow,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (
            SettingRow,
            BaseReferences<_$AppDatabase, $SettingsTable, SettingRow>,
          ),
          SettingRow,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => SettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) => SettingsCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SettingsTable, SettingRow>(table),
                  BaseReferences<_$AppDatabase, $SettingsTable, SettingRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsTable,
      SettingRow,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (SettingRow, BaseReferences<_$AppDatabase, $SettingsTable, SettingRow>),
      SettingRow,
      PrefetchHooks Function()
    >;
typedef $$OvertimeTypesTableCreateCompanionBuilder =
    OvertimeTypesCompanion Function({
      required String id,
      Value<String?> name,
      required int colorValue,
      required OvertimeRateMode rateMode,
      Value<int> multiplierBasisPoints,
      Value<int?> hourlyRateCents,
      required bool countsForGoal,
      Value<bool> archived,
      Value<int> sortOrder,
      Value<int> rowid,
    });
typedef $$OvertimeTypesTableUpdateCompanionBuilder =
    OvertimeTypesCompanion Function({
      Value<String> id,
      Value<String?> name,
      Value<int> colorValue,
      Value<OvertimeRateMode> rateMode,
      Value<int> multiplierBasisPoints,
      Value<int?> hourlyRateCents,
      Value<bool> countsForGoal,
      Value<bool> archived,
      Value<int> sortOrder,
      Value<int> rowid,
    });

final class $$OvertimeTypesTableReferences
    extends
        BaseReferences<_$AppDatabase, $OvertimeTypesTable, OvertimeTypeRow> {
  $$OvertimeTypesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$OvertimeBlocksTable, List<OvertimeBlockRow>>
  _overtimeBlocksRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.overtimeBlocks,
    aliasName: 'overtime_types__id__overtime_blocks__type_id',
  );

  $$OvertimeBlocksTableProcessedTableManager get overtimeBlocksRefs {
    final manager = $$OvertimeBlocksTableTableManager(
      $_db,
      $_db.overtimeBlocks,
    ).filter((f) => f.typeId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_overtimeBlocksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$OvertimeTypesTableFilterComposer
    extends Composer<_$AppDatabase, $OvertimeTypesTable> {
  $$OvertimeTypesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<OvertimeRateMode, OvertimeRateMode, String>
  get rateMode => $composableBuilder(
    column: $table.rateMode,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get multiplierBasisPoints => $composableBuilder(
    column: $table.multiplierBasisPoints,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get hourlyRateCents => $composableBuilder(
    column: $table.hourlyRateCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get countsForGoal => $composableBuilder(
    column: $table.countsForGoal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> overtimeBlocksRefs(
    Expression<bool> Function($$OvertimeBlocksTableFilterComposer f) f,
  ) {
    final $$OvertimeBlocksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.overtimeBlocks,
      getReferencedColumn: (t) => t.typeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OvertimeBlocksTableFilterComposer(
            $db: $db,
            $table: $db.overtimeBlocks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$OvertimeTypesTableOrderingComposer
    extends Composer<_$AppDatabase, $OvertimeTypesTable> {
  $$OvertimeTypesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rateMode => $composableBuilder(
    column: $table.rateMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get multiplierBasisPoints => $composableBuilder(
    column: $table.multiplierBasisPoints,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get hourlyRateCents => $composableBuilder(
    column: $table.hourlyRateCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get countsForGoal => $composableBuilder(
    column: $table.countsForGoal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OvertimeTypesTableAnnotationComposer
    extends Composer<_$AppDatabase, $OvertimeTypesTable> {
  $$OvertimeTypesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<OvertimeRateMode, String> get rateMode =>
      $composableBuilder(column: $table.rateMode, builder: (column) => column);

  GeneratedColumn<int> get multiplierBasisPoints => $composableBuilder(
    column: $table.multiplierBasisPoints,
    builder: (column) => column,
  );

  GeneratedColumn<int> get hourlyRateCents => $composableBuilder(
    column: $table.hourlyRateCents,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get countsForGoal => $composableBuilder(
    column: $table.countsForGoal,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get archived =>
      $composableBuilder(column: $table.archived, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  Expression<T> overtimeBlocksRefs<T extends Object>(
    Expression<T> Function($$OvertimeBlocksTableAnnotationComposer a) f,
  ) {
    final $$OvertimeBlocksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.overtimeBlocks,
      getReferencedColumn: (t) => t.typeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OvertimeBlocksTableAnnotationComposer(
            $db: $db,
            $table: $db.overtimeBlocks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$OvertimeTypesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OvertimeTypesTable,
          OvertimeTypeRow,
          $$OvertimeTypesTableFilterComposer,
          $$OvertimeTypesTableOrderingComposer,
          $$OvertimeTypesTableAnnotationComposer,
          $$OvertimeTypesTableCreateCompanionBuilder,
          $$OvertimeTypesTableUpdateCompanionBuilder,
          (OvertimeTypeRow, $$OvertimeTypesTableReferences),
          OvertimeTypeRow,
          PrefetchHooks Function({bool overtimeBlocksRefs})
        > {
  $$OvertimeTypesTableTableManager(_$AppDatabase db, $OvertimeTypesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OvertimeTypesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OvertimeTypesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OvertimeTypesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<int> colorValue = const Value.absent(),
                Value<OvertimeRateMode> rateMode = const Value.absent(),
                Value<int> multiplierBasisPoints = const Value.absent(),
                Value<int?> hourlyRateCents = const Value.absent(),
                Value<bool> countsForGoal = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OvertimeTypesCompanion(
                id: id,
                name: name,
                colorValue: colorValue,
                rateMode: rateMode,
                multiplierBasisPoints: multiplierBasisPoints,
                hourlyRateCents: hourlyRateCents,
                countsForGoal: countsForGoal,
                archived: archived,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> name = const Value.absent(),
                required int colorValue,
                required OvertimeRateMode rateMode,
                Value<int> multiplierBasisPoints = const Value.absent(),
                Value<int?> hourlyRateCents = const Value.absent(),
                required bool countsForGoal,
                Value<bool> archived = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OvertimeTypesCompanion.insert(
                id: id,
                name: name,
                colorValue: colorValue,
                rateMode: rateMode,
                multiplierBasisPoints: multiplierBasisPoints,
                hourlyRateCents: hourlyRateCents,
                countsForGoal: countsForGoal,
                archived: archived,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$OvertimeTypesTable, OvertimeTypeRow>(table),
                  $$OvertimeTypesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({overtimeBlocksRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (overtimeBlocksRefs) db.overtimeBlocks,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (overtimeBlocksRefs)
                    await $_getPrefetchedData<
                      OvertimeTypeRow,
                      $OvertimeTypesTable,
                      OvertimeBlockRow
                    >(
                      currentTable: table,
                      referencedTable: $$OvertimeTypesTableReferences
                          ._overtimeBlocksRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$OvertimeTypesTableReferences(
                            db,
                            table,
                            p0,
                          ).overtimeBlocksRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.typeId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$OvertimeTypesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OvertimeTypesTable,
      OvertimeTypeRow,
      $$OvertimeTypesTableFilterComposer,
      $$OvertimeTypesTableOrderingComposer,
      $$OvertimeTypesTableAnnotationComposer,
      $$OvertimeTypesTableCreateCompanionBuilder,
      $$OvertimeTypesTableUpdateCompanionBuilder,
      (OvertimeTypeRow, $$OvertimeTypesTableReferences),
      OvertimeTypeRow,
      PrefetchHooks Function({bool overtimeBlocksRefs})
    >;
typedef $$OvertimeBlocksTableCreateCompanionBuilder =
    OvertimeBlocksCompanion Function({
      required String calendarId,
      required CivilDate date,
      required String id,
      required String typeId,
      required int startMinute,
      required int endMinute,
      Value<int> breakMinutes,
      Value<String?> note,
      Value<int> rowid,
    });
typedef $$OvertimeBlocksTableUpdateCompanionBuilder =
    OvertimeBlocksCompanion Function({
      Value<String> calendarId,
      Value<CivilDate> date,
      Value<String> id,
      Value<String> typeId,
      Value<int> startMinute,
      Value<int> endMinute,
      Value<int> breakMinutes,
      Value<String?> note,
      Value<int> rowid,
    });

final class $$OvertimeBlocksTableReferences
    extends
        BaseReferences<_$AppDatabase, $OvertimeBlocksTable, OvertimeBlockRow> {
  $$OvertimeBlocksTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CalendarsTable _calendarIdTable(_$AppDatabase db) =>
      db.calendars.createAlias('overtime_blocks__calendar_id__calendars__id');

  $$CalendarsTableProcessedTableManager get calendarId {
    final $_column = $_itemColumn<String>('calendar_id')!;

    final manager = $$CalendarsTableTableManager(
      $_db,
      $_db.calendars,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_calendarIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $OvertimeTypesTable _typeIdTable(_$AppDatabase db) => db.overtimeTypes
      .createAlias('overtime_blocks__type_id__overtime_types__id');

  $$OvertimeTypesTableProcessedTableManager get typeId {
    final $_column = $_itemColumn<String>('type_id')!;

    final manager = $$OvertimeTypesTableTableManager(
      $_db,
      $_db.overtimeTypes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_typeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$OvertimeBlocksTableFilterComposer
    extends Composer<_$AppDatabase, $OvertimeBlocksTable> {
  $$OvertimeBlocksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnWithTypeConverterFilters<CivilDate, CivilDate, String> get date =>
      $composableBuilder(
        column: $table.date,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startMinute => $composableBuilder(
    column: $table.startMinute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endMinute => $composableBuilder(
    column: $table.endMinute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get breakMinutes => $composableBuilder(
    column: $table.breakMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  $$CalendarsTableFilterComposer get calendarId {
    final $$CalendarsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.calendarId,
      referencedTable: $db.calendars,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CalendarsTableFilterComposer(
            $db: $db,
            $table: $db.calendars,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$OvertimeTypesTableFilterComposer get typeId {
    final $$OvertimeTypesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.typeId,
      referencedTable: $db.overtimeTypes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OvertimeTypesTableFilterComposer(
            $db: $db,
            $table: $db.overtimeTypes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$OvertimeBlocksTableOrderingComposer
    extends Composer<_$AppDatabase, $OvertimeBlocksTable> {
  $$OvertimeBlocksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startMinute => $composableBuilder(
    column: $table.startMinute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endMinute => $composableBuilder(
    column: $table.endMinute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get breakMinutes => $composableBuilder(
    column: $table.breakMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  $$CalendarsTableOrderingComposer get calendarId {
    final $$CalendarsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.calendarId,
      referencedTable: $db.calendars,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CalendarsTableOrderingComposer(
            $db: $db,
            $table: $db.calendars,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$OvertimeTypesTableOrderingComposer get typeId {
    final $$OvertimeTypesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.typeId,
      referencedTable: $db.overtimeTypes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OvertimeTypesTableOrderingComposer(
            $db: $db,
            $table: $db.overtimeTypes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$OvertimeBlocksTableAnnotationComposer
    extends Composer<_$AppDatabase, $OvertimeBlocksTable> {
  $$OvertimeBlocksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumnWithTypeConverter<CivilDate, String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get startMinute => $composableBuilder(
    column: $table.startMinute,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endMinute =>
      $composableBuilder(column: $table.endMinute, builder: (column) => column);

  GeneratedColumn<int> get breakMinutes => $composableBuilder(
    column: $table.breakMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  $$CalendarsTableAnnotationComposer get calendarId {
    final $$CalendarsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.calendarId,
      referencedTable: $db.calendars,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CalendarsTableAnnotationComposer(
            $db: $db,
            $table: $db.calendars,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$OvertimeTypesTableAnnotationComposer get typeId {
    final $$OvertimeTypesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.typeId,
      referencedTable: $db.overtimeTypes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OvertimeTypesTableAnnotationComposer(
            $db: $db,
            $table: $db.overtimeTypes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$OvertimeBlocksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OvertimeBlocksTable,
          OvertimeBlockRow,
          $$OvertimeBlocksTableFilterComposer,
          $$OvertimeBlocksTableOrderingComposer,
          $$OvertimeBlocksTableAnnotationComposer,
          $$OvertimeBlocksTableCreateCompanionBuilder,
          $$OvertimeBlocksTableUpdateCompanionBuilder,
          (OvertimeBlockRow, $$OvertimeBlocksTableReferences),
          OvertimeBlockRow,
          PrefetchHooks Function({bool calendarId, bool typeId})
        > {
  $$OvertimeBlocksTableTableManager(
    _$AppDatabase db,
    $OvertimeBlocksTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OvertimeBlocksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OvertimeBlocksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OvertimeBlocksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> calendarId = const Value.absent(),
                Value<CivilDate> date = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> typeId = const Value.absent(),
                Value<int> startMinute = const Value.absent(),
                Value<int> endMinute = const Value.absent(),
                Value<int> breakMinutes = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OvertimeBlocksCompanion(
                calendarId: calendarId,
                date: date,
                id: id,
                typeId: typeId,
                startMinute: startMinute,
                endMinute: endMinute,
                breakMinutes: breakMinutes,
                note: note,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String calendarId,
                required CivilDate date,
                required String id,
                required String typeId,
                required int startMinute,
                required int endMinute,
                Value<int> breakMinutes = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OvertimeBlocksCompanion.insert(
                calendarId: calendarId,
                date: date,
                id: id,
                typeId: typeId,
                startMinute: startMinute,
                endMinute: endMinute,
                breakMinutes: breakMinutes,
                note: note,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$OvertimeBlocksTable, OvertimeBlockRow>(table),
                  $$OvertimeBlocksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({calendarId = false, typeId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (calendarId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.calendarId,
                        referencedTable: $$OvertimeBlocksTableReferences
                            ._calendarIdTable(db),
                        referencedColumn: $$OvertimeBlocksTableReferences
                            ._calendarIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (typeId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.typeId,
                        referencedTable: $$OvertimeBlocksTableReferences
                            ._typeIdTable(db),
                        referencedColumn: $$OvertimeBlocksTableReferences
                            ._typeIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$OvertimeBlocksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OvertimeBlocksTable,
      OvertimeBlockRow,
      $$OvertimeBlocksTableFilterComposer,
      $$OvertimeBlocksTableOrderingComposer,
      $$OvertimeBlocksTableAnnotationComposer,
      $$OvertimeBlocksTableCreateCompanionBuilder,
      $$OvertimeBlocksTableUpdateCompanionBuilder,
      (OvertimeBlockRow, $$OvertimeBlocksTableReferences),
      OvertimeBlockRow,
      PrefetchHooks Function({bool calendarId, bool typeId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CalendarsTableTableManager get calendars =>
      $$CalendarsTableTableManager(_db, _db.calendars);
  $$ShiftTypesTableTableManager get shiftTypes =>
      $$ShiftTypesTableTableManager(_db, _db.shiftTypes);
  $$ShiftTypeVersionsTableTableManager get shiftTypeVersions =>
      $$ShiftTypeVersionsTableTableManager(_db, _db.shiftTypeVersions);
  $$PatternsTableTableManager get patterns =>
      $$PatternsTableTableManager(_db, _db.patterns);
  $$PatternRunsTableTableManager get patternRuns =>
      $$PatternRunsTableTableManager(_db, _db.patternRuns);
  $$DayEntriesTableTableManager get dayEntries =>
      $$DayEntriesTableTableManager(_db, _db.dayEntries);
  $$NoteAttachmentsTableTableManager get noteAttachments =>
      $$NoteAttachmentsTableTableManager(_db, _db.noteAttachments);
  $$DayTasksTableTableManager get dayTasks =>
      $$DayTasksTableTableManager(_db, _db.dayTasks);
  $$ShiftSwapsTableTableManager get shiftSwaps =>
      $$ShiftSwapsTableTableManager(_db, _db.shiftSwaps);
  $$HolidaysTableTableManager get holidays =>
      $$HolidaysTableTableManager(_db, _db.holidays);
  $$AbsenceBalancesTableTableManager get absenceBalances =>
      $$AbsenceBalancesTableTableManager(_db, _db.absenceBalances);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
  $$OvertimeTypesTableTableManager get overtimeTypes =>
      $$OvertimeTypesTableTableManager(_db, _db.overtimeTypes);
  $$OvertimeBlocksTableTableManager get overtimeBlocks =>
      $$OvertimeBlocksTableTableManager(_db, _db.overtimeBlocks);
}
