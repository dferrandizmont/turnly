import 'package:collection/collection.dart';

import '../../absences/domain/absence_balance.dart';
import '../../calendars/domain/calendar.dart';
import '../../notes/domain/day_task.dart';
import '../../notes/domain/note_attachment.dart';
import '../../schedule/domain/schedule_domain.dart';
import '../../swaps/domain/shift_swap.dart';
import 'backup_errors.dart';

const _deepEq = DeepCollectionEquality();

/// Value equality over [props] for the plain data classes below.
abstract class _Value {
  const _Value();

  List<Object?> get props;

  @override
  bool operator ==(Object other) =>
      other.runtimeType == runtimeType &&
      _deepEq.equals(props, (other as _Value).props);

  @override
  int get hashCode => _deepEq.hash(props);

  @override
  String toString() => '$runtimeType$props';
}

/// A `calendars` row (format version 2). A version 1 file has none: reading
/// it creates [BackupCalendar.defaultMain].
class BackupCalendar extends _Value {
  const BackupCalendar({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    this.archived = false,
  });

  /// The calendar `main` ("Mi cuadrante", indigo) every database has, with
  /// the given timestamps.
  const BackupCalendar.defaultMain({this.createdAt = 0, this.updatedAt = 0})
    : id = mainCalendarId,
      name = mainCalendarName,
      colorValue = mainCalendarColor,
      sortOrder = 0,
      archived = false;

  factory BackupCalendar.fromJson(Map<String, Object?> json) {
    final r = _JsonReader(json, 'calendar');
    return BackupCalendar(
      id: r.string('id'),
      name: r.string('name'),
      colorValue: r.integer('colorValue'),
      sortOrder: r.integer('sortOrder'),
      archived: r.boolean('archived'),
      createdAt: r.integer('createdAt'),
      updatedAt: r.integer('updatedAt'),
    );
  }

  final String id;
  final String name;
  final int colorValue;
  final int sortOrder;
  final bool archived;

  /// Milliseconds since the epoch (UTC).
  final int createdAt;
  final int updatedAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'colorValue': colorValue,
    'sortOrder': sortOrder,
    'archived': archived,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };

  @override
  List<Object?> get props => [
    id,
    name,
    colorValue,
    sortOrder,
    archived,
    createdAt,
    updatedAt,
  ];
}

/// A `shift_types` row, timestamps and palette position included.
class BackupShiftType extends _Value {
  const BackupShiftType({
    required this.id,
    required this.code,
    required this.name,
    required this.colorValue,
    required this.category,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
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
    this.archived = false,
    this.pastVersions = const [],
    this.location,
    this.nightPlusCentsPerHour,
    this.holidayPlusCentsPerHour,
  });

  /// [readHourlyRate] is false for a version 1 file, which has no such field;
  /// [readV3Fields] is false for a version 1 or 2 file, which have no icon,
  /// alarm sound or second segment (they are ignored even if present).
  factory BackupShiftType.fromJson(
    Map<String, Object?> json, {
    bool readHourlyRate = true,
    bool readV3Fields = true,
  }) {
    final r = _JsonReader(json, 'shiftType');
    return BackupShiftType(
      id: r.string('id'),
      code: r.string('code'),
      name: r.string('name'),
      colorValue: r.integer('colorValue'),
      category: r.enumValue('category', ShiftCategory.values),
      startMinute: r.integerOrNull('startMinute'),
      endMinute: r.integerOrNull('endMinute'),
      paidMinutes: r.integerOrNull('paidMinutes'),
      nightOverride: r.boolOrNull('nightOverride'),
      hourlyRateCents: readHourlyRate
          ? r.integerOrNull('hourlyRateCents')
          : null,
      fixedPlusCents: readV3Fields ? r.integerOrNull('fixedPlusCents') : null,
      // A key this build does not know is no icon (never an error).
      icon: readV3Fields ? ShiftIcon.fromKey(r.stringOrNull('icon')) : null,
      alarmSound: readV3Fields ? r.stringOrNull('alarmSound') : null,
      segment2StartMinute: readV3Fields
          ? r.integerOrNull('segment2StartMinute')
          : null,
      segment2DurationMinutes: readV3Fields
          ? r.integerOrNull('segment2DurationMinutes')
          : null,
      sortOrder: r.integer('sortOrder'),
      archived: r.boolean('archived'),
      createdAt: r.integer('createdAt'),
      updatedAt: r.integer('updatedAt'),
      pastVersions: readV3Fields && json['pastVersions'] != null
          ? r.objects('pastVersions', BackupShiftTypeVersion.fromJson)
          : const [],
      location: readV3Fields ? r.stringOrNull('location') : null,
      nightPlusCentsPerHour: readV3Fields
          ? r.integerOrNull('nightPlusCentsPerHour')
          : null,
      holidayPlusCentsPerHour: readV3Fields
          ? r.integerOrNull('holidayPlusCentsPerHour')
          : null,
    );
  }

  final String id;
  final String code;
  final String name;
  final int colorValue;
  final ShiftCategory category;
  final int? startMinute;
  final int? endMinute;
  final int? paidMinutes;
  final bool? nightOverride;

  /// Pay per hour in cents; `null` = none.
  final int? hourlyRateCents;

  /// Optional format v3 extension: fixed cents per worked shift.
  final int? fixedPlusCents;

  /// Format version 3: icon, alarm sound and second segment of a split
  /// shift (docs/datos.md, "Esquema v3").
  final ShiftIcon? icon;
  final String? alarmSound;
  final int? segment2StartMinute;
  final int? segment2DurationMinutes;
  final int sortOrder;
  final bool archived;

  /// Optional format v3 extension (database v5): the terms this type had
  /// before each change made «only from today on», sorted by `until`. Empty
  /// for a type that has always had its current terms.
  final List<BackupShiftTypeVersion> pastVersions;

  /// Optional format v3 extensions (database v6): place and the night and
  /// holiday pluses per hour. Written only when set.
  final String? location;
  final int? nightPlusCentsPerHour;
  final int? holidayPlusCentsPerHour;

  /// Milliseconds since the epoch (UTC).
  final int createdAt;
  final int updatedAt;

  /// This shift type without its alarm sound (`alarmSound: null`).
  BackupShiftType withoutAlarmSound() => BackupShiftType(
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
    segment2StartMinute: segment2StartMinute,
    segment2DurationMinutes: segment2DurationMinutes,
    sortOrder: sortOrder,
    archived: archived,
    createdAt: createdAt,
    updatedAt: updatedAt,
    pastVersions: pastVersions,
    location: location,
    nightPlusCentsPerHour: nightPlusCentsPerHour,
    holidayPlusCentsPerHour: holidayPlusCentsPerHour,
  );

  ShiftType toShiftType() => ShiftType(
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
  );

  /// The engine view of [pastVersions].
  List<ShiftTypeVersion> toVersions() => [
    for (final v in pastVersions) v.toVersion(),
  ];

  /// The version 3 keys are written **only when they have a value**: a
  /// shift type without them serialises exactly as it did in version 2, so
  /// the canonical bytes and the fingerprint of data that never used them
  /// are the ones they always were.
  Map<String, Object?> toJson() => {
    'id': id,
    'code': code,
    'name': name,
    'colorValue': colorValue,
    'category': category.name,
    'startMinute': startMinute,
    'endMinute': endMinute,
    'paidMinutes': paidMinutes,
    'nightOverride': nightOverride,
    'hourlyRateCents': hourlyRateCents,
    'fixedPlusCents': ?fixedPlusCents,
    'icon': ?icon?.key,
    'alarmSound': ?alarmSound,
    'segment2StartMinute': ?segment2StartMinute,
    'segment2DurationMinutes': ?segment2DurationMinutes,
    'sortOrder': sortOrder,
    'archived': archived,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    if (pastVersions.isNotEmpty)
      'pastVersions': [for (final v in pastVersions) v.toJson()],
    'location': ?location,
    'nightPlusCentsPerHour': ?nightPlusCentsPerHour,
    'holidayPlusCentsPerHour': ?holidayPlusCentsPerHour,
  };

  @override
  List<Object?> get props => [
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
    sortOrder,
    archived,
    createdAt,
    updatedAt,
    pastVersions,
    location,
    nightPlusCentsPerHour,
    holidayPlusCentsPerHour,
  ];
}

/// A `shift_type_versions` row, nested in its shift type
/// (`shiftTypes[].pastVersions`): the terms the type had up to [until]
/// (included). Only `until`, `category` and `createdAt` are always written;
/// the other keys only when they have a value (absent = `null`).
class BackupShiftTypeVersion extends _Value {
  const BackupShiftTypeVersion({
    required this.until,
    required this.category,
    required this.createdAt,
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
  });

  factory BackupShiftTypeVersion.fromJson(Map<String, Object?> json) {
    final r = _JsonReader(json, 'shiftTypeVersion');
    return BackupShiftTypeVersion(
      until: r.date('until'),
      category: r.enumValue('category', ShiftCategory.values),
      startMinute: r.integerOrNull('startMinute'),
      endMinute: r.integerOrNull('endMinute'),
      paidMinutes: r.integerOrNull('paidMinutes'),
      nightOverride: r.boolOrNull('nightOverride'),
      hourlyRateCents: r.integerOrNull('hourlyRateCents'),
      fixedPlusCents: r.integerOrNull('fixedPlusCents'),
      segment2StartMinute: r.integerOrNull('segment2StartMinute'),
      segment2DurationMinutes: r.integerOrNull('segment2DurationMinutes'),
      nightPlusCentsPerHour: r.integerOrNull('nightPlusCentsPerHour'),
      holidayPlusCentsPerHour: r.integerOrNull('holidayPlusCentsPerHour'),
      createdAt: r.integer('createdAt'),
    );
  }

  factory BackupShiftTypeVersion.of(
    ShiftTypeVersion version, {
    required int createdAt,
  }) {
    final t = version.terms;
    return BackupShiftTypeVersion(
      until: version.until,
      category: t.category,
      startMinute: t.startMinute,
      endMinute: t.endMinute,
      paidMinutes: t.paidMinutes,
      nightOverride: t.nightOverride,
      hourlyRateCents: t.hourlyRateCents,
      fixedPlusCents: t.fixedPlusCents,
      segment2StartMinute: t.segment2StartMinute,
      segment2DurationMinutes: t.segment2DurationMinutes,
      nightPlusCentsPerHour: t.nightPlusCentsPerHour,
      holidayPlusCentsPerHour: t.holidayPlusCentsPerHour,
      createdAt: createdAt,
    );
  }

  /// Last day (included) these terms applied.
  final CivilDate until;
  final ShiftCategory category;
  final int? startMinute;
  final int? endMinute;
  final int? paidMinutes;
  final bool? nightOverride;
  final int? hourlyRateCents;
  final int? fixedPlusCents;
  final int? segment2StartMinute;
  final int? segment2DurationMinutes;

  /// Database v6: night and holiday pluses per hour of these terms.
  final int? nightPlusCentsPerHour;
  final int? holidayPlusCentsPerHour;

  /// Milliseconds since the epoch (UTC).
  final int createdAt;

  ShiftTypeVersion toVersion() => ShiftTypeVersion(
    until: until,
    terms: ShiftTerms(
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
    ),
  );

  Map<String, Object?> toJson() => {
    'until': until.toIso(),
    'category': category.name,
    'startMinute': ?startMinute,
    'endMinute': ?endMinute,
    'paidMinutes': ?paidMinutes,
    'nightOverride': ?nightOverride,
    'hourlyRateCents': ?hourlyRateCents,
    'fixedPlusCents': ?fixedPlusCents,
    'segment2StartMinute': ?segment2StartMinute,
    'segment2DurationMinutes': ?segment2DurationMinutes,
    'nightPlusCentsPerHour': ?nightPlusCentsPerHour,
    'holidayPlusCentsPerHour': ?holidayPlusCentsPerHour,
    'createdAt': createdAt,
  };

  @override
  List<Object?> get props => [
    until,
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
}

/// A `patterns` row.
class BackupPattern extends _Value {
  const BackupPattern({
    required this.id,
    required this.name,
    required this.steps,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BackupPattern.fromJson(Map<String, Object?> json) {
    final r = _JsonReader(json, 'pattern');
    return BackupPattern(
      id: r.string('id'),
      name: r.string('name'),
      steps: r.stringMatrix('steps'),
      createdAt: r.integer('createdAt'),
      updatedAt: r.integer('updatedAt'),
    );
  }

  final String id;
  final String name;

  /// One list of shift type ids per day of the cycle.
  final List<List<String>> steps;
  final int createdAt;
  final int updatedAt;

  Pattern toPattern() => Pattern(id: id, name: name, steps: steps);

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'steps': steps,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };

  @override
  List<Object?> get props => [id, name, steps, createdAt, updatedAt];
}

/// A `pattern_runs` row.
class BackupPatternRun extends _Value {
  const BackupPatternRun({
    required this.id,
    required this.patternId,
    required this.startDate,
    required this.seq,
    required this.createdAt,
    this.calendarId = mainCalendarId,
    this.endDate,
    this.stepOffset = 0,
  });

  /// Reads a run. A version 1 file has no calendars: its reader passes
  /// [calendarId] (`main`); a version 2 file carries it.
  factory BackupPatternRun.fromJson(
    Map<String, Object?> json, {
    String? calendarId,
  }) {
    final r = _JsonReader(json, 'patternRun');
    return BackupPatternRun(
      id: r.string('id'),
      calendarId: calendarId ?? r.string('calendarId'),
      patternId: r.string('patternId'),
      startDate: r.date('startDate'),
      endDate: r.dateOrNull('endDate'),
      stepOffset: r.integer('stepOffset'),
      seq: r.integer('seq'),
      createdAt: r.integer('createdAt'),
    );
  }

  final String id;

  /// The calendar the run belongs to.
  final String calendarId;
  final String patternId;
  final CivilDate startDate;
  final CivilDate? endDate;
  final int stepOffset;
  final int seq;
  final int createdAt;

  PatternRun toRun() => PatternRun(
    id: id,
    patternId: patternId,
    startDate: startDate,
    endDate: endDate,
    stepOffset: stepOffset,
    seq: seq,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'calendarId': calendarId,
    'patternId': patternId,
    'startDate': startDate.toIso(),
    'endDate': endDate?.toIso(),
    'stepOffset': stepOffset,
    'seq': seq,
    'createdAt': createdAt,
  };

  @override
  List<Object?> get props => [
    id,
    calendarId,
    patternId,
    startDate,
    endDate,
    stepOffset,
    seq,
    createdAt,
  ];
}

/// A `day_entries` row: a manual exception (override and/or note).
class BackupDayEntry extends _Value {
  const BackupDayEntry({
    required this.date,
    required this.updatedAt,
    this.calendarId = mainCalendarId,
    this.shiftTypeIds,
    this.note,
    this.noteReminderMinute,
    this.overtimeMinutes,
    this.earlyLeaveMinutes,
    this.extraAmountCents,
  });

  /// Reads an exception. A version 1 file has no calendars: its reader
  /// passes [calendarId] (`main`); a version 2 file carries it. [readV3Fields]
  /// is false for a version 1 or 2 file, which have no reminder, overtime or
  /// early leave (they are ignored even if present).
  factory BackupDayEntry.fromJson(
    Map<String, Object?> json, {
    String? calendarId,
    bool readV3Fields = true,
  }) {
    final r = _JsonReader(json, 'dayEntry');
    return BackupDayEntry(
      calendarId: calendarId ?? r.string('calendarId'),
      date: r.date('date'),
      shiftTypeIds: r.stringListOrNull('shiftTypeIds'),
      note: r.stringOrNull('note'),
      noteReminderMinute: readV3Fields
          ? r.integerOrNull('noteReminderMinute')
          : null,
      overtimeMinutes: readV3Fields ? r.integerOrNull('overtimeMinutes') : null,
      earlyLeaveMinutes: readV3Fields
          ? r.integerOrNull('earlyLeaveMinutes')
          : null,
      extraAmountCents: readV3Fields
          ? r.integerOrNull('extraAmountCents')
          : null,
      updatedAt: r.integer('updatedAt'),
    );
  }

  /// The calendar the day belongs to.
  final String calendarId;
  final CivilDate date;

  /// `null` = does not replace the pattern; `[]` = empty day.
  final List<String>? shiftTypeIds;
  final String? note;

  /// Format version 3: the minute of the day the note rings, and the extra
  /// and missing minutes of the day.
  final int? noteReminderMinute;
  final int? overtimeMinutes;
  final int? earlyLeaveMinutes;

  /// Optional format v3 extension (database v6): extra money of the day.
  final int? extraAmountCents;
  final int updatedAt;

  /// The same day without the old overtime minutes (once they are a block,
  /// [BackupData.upgradedOvertime]).
  BackupDayEntry withoutOvertimeMinutes() => overtimeMinutes == null
      ? this
      : BackupDayEntry(
          date: date,
          updatedAt: updatedAt,
          calendarId: calendarId,
          shiftTypeIds: shiftTypeIds,
          note: note,
          noteReminderMinute: noteReminderMinute,
          earlyLeaveMinutes: earlyLeaveMinutes,
          extraAmountCents: extraAmountCents,
        );

  DayEntry toEntry() => DayEntry(
    date: date,
    shiftTypeIds: shiftTypeIds,
    note: note,
    noteReminderMinute: noteReminderMinute,
    overtimeMinutes: overtimeMinutes,
    earlyLeaveMinutes: earlyLeaveMinutes,
    extraAmountCents: extraAmountCents,
  );

  /// The version 3 keys are written only when they have a value (see
  /// [BackupShiftType.toJson]).
  Map<String, Object?> toJson() => {
    'calendarId': calendarId,
    'date': date.toIso(),
    'shiftTypeIds': shiftTypeIds,
    'note': note,
    'noteReminderMinute': ?noteReminderMinute,
    'overtimeMinutes': ?overtimeMinutes,
    'earlyLeaveMinutes': ?earlyLeaveMinutes,
    'extraAmountCents': ?extraAmountCents,
    'updatedAt': updatedAt,
  };

  @override
  List<Object?> get props => [
    calendarId,
    date,
    shiftTypeIds,
    note,
    noteReminderMinute,
    overtimeMinutes,
    earlyLeaveMinutes,
    extraAmountCents,
    updatedAt,
  ];
}

/// A holiday the user added (`holidays.source = 'user'`). The database id is
/// not part of the backup: it is a meaningless auto-increment.
class BackupHoliday extends _Value {
  const BackupHoliday({
    required this.date,
    required this.scope,
    required this.name,
    this.regionCode,
    this.municipalityCode,
  });

  factory BackupHoliday.fromJson(Map<String, Object?> json) {
    final r = _JsonReader(json, 'holiday');
    return BackupHoliday(
      date: r.date('date'),
      scope: r.string('scope'),
      name: r.string('name'),
      regionCode: r.stringOrNull('regionCode'),
      municipalityCode: r.stringOrNull('municipalityCode'),
    );
  }

  final CivilDate date;

  /// `national` / `regional` / `local`.
  final String scope;
  final String name;
  final String? regionCode;
  final String? municipalityCode;

  Map<String, Object?> toJson() => {
    'date': date.toIso(),
    'scope': scope,
    'name': name,
    'regionCode': regionCode,
    'municipalityCode': municipalityCode,
  };

  String get _sortKey =>
      '${date.toIso()}\u0000$scope\u0000$name\u0000${regionCode ?? ''}'
      '\u0000${municipalityCode ?? ''}';

  @override
  List<Object?> get props => [date, scope, name, regionCode, municipalityCode];
}

/// An `absence_balances` row. `year`, `type` and `allowedDays` are those of
/// every format version; the rest are optional extensions of format v3
/// (database v6), written only when they are not at their default, so a
/// balance written before v6 serialises as it always did and an older app
/// still reads the list (it ignores the keys it does not know).
class BackupAbsenceBalance extends _Value {
  const BackupAbsenceBalance({
    required this.year,
    required this.type,
    required this.allowedDays,
    this.calendarId,
    this.name,
    this.periodStart,
    this.periodEnd,
    this.unit = AbsenceUnit.day,
    this.shiftTypeQuarters = const {},
    this.carryOver = false,
    this.carryOverMaxDays,
    this.adjustmentDays = 0,
    this.sortOrder = 0,
    this.createdAt,
    this.updatedAt,
  });

  /// [readExtensions] is false for a version 1 or 2 file, which only had the
  /// first three keys (anything else is ignored).
  factory BackupAbsenceBalance.fromJson(
    Map<String, Object?> json, {
    bool readExtensions = true,
  }) {
    final r = _JsonReader(json, 'absenceBalance');
    final base = (
      year: r.integer('year'),
      type: r.string('type'),
      allowedDays: r.number('allowedDays'),
    );
    if (!readExtensions) {
      return BackupAbsenceBalance(
        year: base.year,
        type: base.type,
        allowedDays: base.allowedDays,
      );
    }
    return BackupAbsenceBalance(
      year: base.year,
      type: base.type,
      allowedDays: base.allowedDays,
      calendarId: r.stringOrNull('calendarId'),
      name: r.stringOrNull('name'),
      periodStart: r.dateOrNull('periodStart'),
      periodEnd: r.dateOrNull('periodEnd'),
      unit: json['unit'] == null
          ? AbsenceUnit.day
          : r.enumValue('unit', AbsenceUnit.values),
      shiftTypeQuarters: json['shiftTypeQuarters'] == null
          ? const {}
          : r.intMap('shiftTypeQuarters'),
      carryOver: json['carryOver'] == null ? false : r.boolean('carryOver'),
      carryOverMaxDays: json['carryOverMaxDays'] == null
          ? null
          : r.number('carryOverMaxDays'),
      adjustmentDays: json['adjustmentDays'] == null
          ? 0
          : r.number('adjustmentDays'),
      sortOrder: json['sortOrder'] == null ? 0 : r.integer('sortOrder'),
      createdAt: r.integerOrNull('createdAt'),
      updatedAt: r.integerOrNull('updatedAt'),
    );
  }

  factory BackupAbsenceBalance.of(AbsenceBalance b) => BackupAbsenceBalance(
    year: b.year,
    type: b.type,
    allowedDays: b.allowedDays,
    calendarId: b.calendarId,
    name: b.name,
    periodStart: b.periodStart,
    periodEnd: b.periodEnd,
    unit: b.unit,
    shiftTypeQuarters: b.shiftTypeQuarters,
    carryOver: b.carryOver,
    carryOverMaxDays: b.carryOverMaxDays,
    adjustmentDays: b.adjustmentDays,
    sortOrder: b.sortOrder,
    createdAt: b.createdAt,
    updatedAt: b.updatedAt,
  );

  final int year;
  final String type;
  final double allowedDays;
  final String? calendarId;
  final String? name;
  final CivilDate? periodStart;
  final CivilDate? periodEnd;
  final AbsenceUnit unit;
  final Map<String, int> shiftTypeQuarters;
  final bool carryOver;
  final double? carryOverMaxDays;
  final double adjustmentDays;
  final int sortOrder;
  final int? createdAt;
  final int? updatedAt;

  /// Whether any database v6 field is set (not at its default).
  bool get hasExtensions =>
      calendarId != null ||
      name != null ||
      periodStart != null ||
      periodEnd != null ||
      unit != AbsenceUnit.day ||
      shiftTypeQuarters.isNotEmpty ||
      carryOver ||
      carryOverMaxDays != null ||
      adjustmentDays != 0 ||
      sortOrder != 0 ||
      createdAt != null ||
      updatedAt != null;

  AbsenceBalance toBalance() => AbsenceBalance(
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
  );

  Map<String, Object?> toJson() => {
    'year': year,
    'type': type,
    'allowedDays': allowedDays,
    'calendarId': ?calendarId,
    'name': ?name,
    'periodStart': ?periodStart?.toIso(),
    'periodEnd': ?periodEnd?.toIso(),
    if (unit != AbsenceUnit.day) 'unit': unit.name,
    if (shiftTypeQuarters.isNotEmpty)
      'shiftTypeQuarters': {
        for (final key in shiftTypeQuarters.keys.toList()..sort())
          key: shiftTypeQuarters[key],
      },
    if (carryOver) 'carryOver': true,
    'carryOverMaxDays': ?carryOverMaxDays,
    if (adjustmentDays != 0) 'adjustmentDays': adjustmentDays,
    if (sortOrder != 0) 'sortOrder': sortOrder,
    'createdAt': ?createdAt,
    'updatedAt': ?updatedAt,
  };

  @override
  List<Object?> get props => [
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
}

/// A `note_attachments` row (format v3 extension, database v6): what the
/// database knows about a file. The bytes travel next to the data in a
/// backup container (`backup_container.dart`), never inside the JSON.
class BackupNoteAttachment extends _Value {
  const BackupNoteAttachment({
    required this.id,
    required this.calendarId,
    required this.date,
    required this.kind,
    required this.relativePath,
    required this.mimeType,
    required this.sizeBytes,
    required this.sha256,
    required this.createdAt,
    this.displayName,
    this.sortOrder = 0,
  });

  factory BackupNoteAttachment.fromJson(Map<String, Object?> json) {
    final r = _JsonReader(json, 'noteAttachment');
    return BackupNoteAttachment(
      id: r.string('id'),
      calendarId: r.string('calendarId'),
      date: r.date('date'),
      kind: r.enumValue('kind', AttachmentKind.values),
      relativePath: r.string('relativePath'),
      mimeType: r.string('mimeType'),
      sizeBytes: r.integer('sizeBytes'),
      sha256: r.string('sha256'),
      displayName: r.stringOrNull('displayName'),
      sortOrder: json['sortOrder'] == null ? 0 : r.integer('sortOrder'),
      createdAt: r.integer('createdAt'),
    );
  }

  factory BackupNoteAttachment.of(NoteAttachment a) => BackupNoteAttachment(
    id: a.id,
    calendarId: a.calendarId,
    date: a.date,
    kind: a.kind,
    relativePath: a.relativePath,
    mimeType: a.mimeType,
    sizeBytes: a.sizeBytes,
    sha256: a.sha256,
    displayName: a.displayName,
    sortOrder: a.sortOrder,
    createdAt: a.createdAt,
  );

  final String id;
  final String calendarId;
  final CivilDate date;
  final AttachmentKind kind;
  final String relativePath;
  final String mimeType;
  final int sizeBytes;
  final String sha256;
  final String? displayName;
  final int sortOrder;
  final int createdAt;

  NoteAttachment toAttachment() => NoteAttachment(
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
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'calendarId': calendarId,
    'date': date.toIso(),
    'kind': kind.name,
    'relativePath': relativePath,
    'mimeType': mimeType,
    'sizeBytes': sizeBytes,
    'sha256': sha256,
    'displayName': ?displayName,
    'sortOrder': sortOrder,
    'createdAt': createdAt,
  };

  @override
  List<Object?> get props => [
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
}

/// A `day_tasks` row (format v3 extension, database v6).
class BackupDayTask extends _Value {
  const BackupDayTask({
    required this.id,
    required this.calendarId,
    required this.date,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.done = false,
    this.sortOrder = 0,
  });

  factory BackupDayTask.fromJson(Map<String, Object?> json) {
    final r = _JsonReader(json, 'dayTask');
    return BackupDayTask(
      id: r.string('id'),
      calendarId: r.string('calendarId'),
      date: r.date('date'),
      title: r.string('title'),
      done: r.boolean('done'),
      sortOrder: json['sortOrder'] == null ? 0 : r.integer('sortOrder'),
      createdAt: r.integer('createdAt'),
      updatedAt: r.integer('updatedAt'),
    );
  }

  factory BackupDayTask.of(DayTask t) => BackupDayTask(
    id: t.id,
    calendarId: t.calendarId,
    date: t.date,
    title: t.title,
    done: t.done,
    sortOrder: t.sortOrder,
    createdAt: t.createdAt,
    updatedAt: t.updatedAt,
  );

  final String id;
  final String calendarId;
  final CivilDate date;
  final String title;
  final bool done;
  final int sortOrder;
  final int createdAt;
  final int updatedAt;

  DayTask toTask() => DayTask(
    id: id,
    calendarId: calendarId,
    date: date,
    title: title,
    done: done,
    sortOrder: sortOrder,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'calendarId': calendarId,
    'date': date.toIso(),
    'title': title,
    'done': done,
    'sortOrder': sortOrder,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };

  @override
  List<Object?> get props => [
    id,
    calendarId,
    date,
    title,
    done,
    sortOrder,
    createdAt,
    updatedAt,
  ];
}

/// A `shift_swaps` row (format v3 extension, database v6).
class BackupShiftSwap extends _Value {
  const BackupShiftSwap({
    required this.id,
    required this.calendarId,
    required this.date,
    required this.colleague,
    required this.direction,
    required this.createdAt,
    required this.updatedAt,
    this.givenShiftTypeIds,
    this.receivedShiftTypeIds,
    this.returnDate,
    this.status = SwapStatus.pending,
    this.note,
    this.closedAt,
  });

  factory BackupShiftSwap.fromJson(Map<String, Object?> json) {
    final r = _JsonReader(json, 'shiftSwap');
    return BackupShiftSwap(
      id: r.string('id'),
      calendarId: r.string('calendarId'),
      date: r.date('date'),
      colleague: r.string('colleague'),
      direction: r.enumValue('direction', SwapDirection.values),
      givenShiftTypeIds: r.stringListOrNull('givenShiftTypeIds'),
      receivedShiftTypeIds: r.stringListOrNull('receivedShiftTypeIds'),
      returnDate: r.dateOrNull('returnDate'),
      status: r.enumValue('status', SwapStatus.values),
      note: r.stringOrNull('note'),
      createdAt: r.integer('createdAt'),
      updatedAt: r.integer('updatedAt'),
      closedAt: r.integerOrNull('closedAt'),
    );
  }

  factory BackupShiftSwap.of(ShiftSwap s) => BackupShiftSwap(
    id: s.id,
    calendarId: s.calendarId,
    date: s.date,
    colleague: s.colleague,
    direction: s.direction,
    givenShiftTypeIds: s.givenShiftTypeIds,
    receivedShiftTypeIds: s.receivedShiftTypeIds,
    returnDate: s.returnDate,
    status: s.status,
    note: s.note,
    createdAt: s.createdAt,
    updatedAt: s.updatedAt,
    closedAt: s.closedAt,
  );

  final String id;
  final String calendarId;
  final CivilDate date;
  final String colleague;
  final SwapDirection direction;
  final List<String>? givenShiftTypeIds;
  final List<String>? receivedShiftTypeIds;
  final CivilDate? returnDate;
  final SwapStatus status;
  final String? note;
  final int createdAt;
  final int updatedAt;
  final int? closedAt;

  ShiftSwap toSwap() => ShiftSwap(
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
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'calendarId': calendarId,
    'date': date.toIso(),
    'colleague': colleague,
    'direction': direction.name,
    'givenShiftTypeIds': ?givenShiftTypeIds,
    'receivedShiftTypeIds': ?receivedShiftTypeIds,
    'returnDate': ?returnDate?.toIso(),
    'status': status.name,
    'note': ?note,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'closedAt': ?closedAt,
  };

  @override
  List<Object?> get props => [
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
}

const _holidayScopes = {'national', 'regional', 'local'};

/// An `overtime_types` row (format version 4, database v7).
class BackupOvertimeType extends _Value {
  const BackupOvertimeType({
    required this.id,
    this.name,
    required this.colorValue,
    required this.rateMode,
    required this.multiplierBasisPoints,
    this.hourlyRateCents,
    required this.countsForGoal,
    this.archived = false,
    this.sortOrder = 0,
  });

  factory BackupOvertimeType.fromJson(Map<String, Object?> json) {
    final r = _JsonReader(json, 'overtimeType');
    return BackupOvertimeType(
      id: r.string('id'),
      name: r.stringOrNull('name'),
      colorValue: r.integer('colorValue'),
      rateMode: r.enumValue('rateMode', OvertimeRateMode.values),
      multiplierBasisPoints: r.integer('multiplierBasisPoints'),
      hourlyRateCents: r.integerOrNull('hourlyRateCents'),
      countsForGoal: r.boolean('countsForGoal'),
      archived: r.boolean('archived'),
      sortOrder: r.integer('sortOrder'),
    );
  }

  factory BackupOvertimeType.of(OvertimeType t) => BackupOvertimeType(
    id: t.id,
    name: t.name,
    colorValue: t.colorValue,
    rateMode: t.rateMode,
    multiplierBasisPoints: t.multiplierBasisPoints,
    hourlyRateCents: t.hourlyRateCents,
    countsForGoal: t.countsForGoal,
    archived: t.archived,
    sortOrder: t.sortOrder,
  );

  final String id;

  /// `null` = a built-in type the user has not renamed.
  final String? name;
  final int colorValue;
  final OvertimeRateMode rateMode;
  final int multiplierBasisPoints;
  final int? hourlyRateCents;
  final bool countsForGoal;
  final bool archived;
  final int sortOrder;

  OvertimeType toType() => OvertimeType(
    id: id,
    name: name,
    colorValue: colorValue,
    rateMode: rateMode,
    multiplierBasisPoints: multiplierBasisPoints,
    hourlyRateCents: hourlyRateCents,
    countsForGoal: countsForGoal,
    archived: archived,
    sortOrder: sortOrder,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'colorValue': colorValue,
    'rateMode': rateMode.name,
    'multiplierBasisPoints': multiplierBasisPoints,
    'hourlyRateCents': hourlyRateCents,
    'countsForGoal': countsForGoal,
    'archived': archived,
    'sortOrder': sortOrder,
  };

  @override
  List<Object?> get props => [
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
}

/// An `overtime_blocks` row (format version 4, database v7): a stretch of
/// extra hours of one day of a calendar.
class BackupOvertimeBlock extends _Value {
  const BackupOvertimeBlock({
    required this.calendarId,
    required this.date,
    required this.id,
    required this.typeId,
    required this.startMinute,
    required this.endMinute,
    this.breakMinutes = 0,
    this.note,
  });

  factory BackupOvertimeBlock.fromJson(Map<String, Object?> json) {
    final r = _JsonReader(json, 'overtimeBlock');
    return BackupOvertimeBlock(
      calendarId: r.string('calendarId'),
      date: r.date('date'),
      id: r.string('id'),
      typeId: r.string('typeId'),
      startMinute: r.integer('startMinute'),
      endMinute: r.integer('endMinute'),
      breakMinutes: r.integer('breakMinutes'),
      note: r.stringOrNull('note'),
    );
  }

  factory BackupOvertimeBlock.of(String calendarId, OvertimeBlock b) =>
      BackupOvertimeBlock(
        calendarId: calendarId,
        date: b.date,
        id: b.id,
        typeId: b.typeId,
        startMinute: b.startMinute,
        endMinute: b.endMinute,
        breakMinutes: b.breakMinutes,
        note: b.note,
      );

  final String calendarId;
  final CivilDate date;
  final String id;
  final String typeId;
  final int startMinute;
  final int endMinute;
  final int breakMinutes;
  final String? note;

  OvertimeBlock toBlock() => OvertimeBlock(
    id: id,
    date: date,
    typeId: typeId,
    startMinute: startMinute,
    endMinute: endMinute,
    breakMinutes: breakMinutes,
    note: note,
  );

  Map<String, Object?> toJson() => {
    'calendarId': calendarId,
    'date': date.toIso(),
    'id': id,
    'typeId': typeId,
    'startMinute': startMinute,
    'endMinute': endMinute,
    'breakMinutes': breakMinutes,
    'note': note,
  };

  @override
  List<Object?> get props => [
    calendarId,
    date,
    id,
    typeId,
    startMinute,
    endMinute,
    breakMinutes,
    note,
  ];
}

/// Everything the user owns in the database, as the `.cuadrante` file holds it.
///
/// The lists are normalised on construction, so equal data compares equal and
/// serialises to the same bytes: calendars and shift types by id, runs by
/// `seq`, entries by (calendar, date), holidays by (date, scope, name, ...),
/// balances by (year, type). **Patterns keep the order given** (the order of
/// the pattern list in the app is their insertion order; they have no sort
/// column).
///
/// This is the model of format version 3. Without [calendars] the data has
/// the calendar `main` (what a version 1 file means); runs and entries default
/// to it. What versions 1 and 2 do not carry (rates, icons, alarm sounds,
/// second segments, reminders, overtime, early leave) is `null`.
class BackupData {
  BackupData({
    Iterable<BackupCalendar>? calendars,
    Iterable<BackupShiftType> shiftTypes = const [],
    Iterable<BackupPattern> patterns = const [],
    Iterable<BackupPatternRun> patternRuns = const [],
    Iterable<BackupDayEntry> dayEntries = const [],
    Iterable<BackupHoliday> holidays = const [],
    Iterable<BackupAbsenceBalance> absenceBalances = const [],
    Map<String, String> settings = const {},
    Iterable<BackupNoteAttachment> noteAttachments = const [],
    Iterable<BackupDayTask> dayTasks = const [],
    Iterable<BackupShiftSwap> shiftSwaps = const [],
    Iterable<BackupOvertimeType> overtimeTypes = const [],
    Iterable<BackupOvertimeBlock> overtimeBlocks = const [],
  }) : calendars = List.unmodifiable(
         (calendars ?? const [BackupCalendar.defaultMain()]).toList()
           ..sort((a, b) => a.id.compareTo(b.id)),
       ),
       shiftTypes = List.unmodifiable(
         shiftTypes.toList()..sort((a, b) => a.id.compareTo(b.id)),
       ),
       patterns = List.unmodifiable(patterns),
       patternRuns = List.unmodifiable(
         patternRuns.toList()..sort((a, b) => a.seq.compareTo(b.seq)),
       ),
       dayEntries = List.unmodifiable(
         dayEntries.toList()..sort((a, b) {
           final byCalendar = a.calendarId.compareTo(b.calendarId);
           return byCalendar != 0 ? byCalendar : a.date.compareTo(b.date);
         }),
       ),
       holidays = List.unmodifiable(
         holidays.toList()..sort((a, b) => a._sortKey.compareTo(b._sortKey)),
       ),
       absenceBalances = List.unmodifiable(
         absenceBalances.toList()..sort((a, b) {
           final byYear = a.year.compareTo(b.year);
           return byYear != 0 ? byYear : a.type.compareTo(b.type);
         }),
       ),
       settings = Map.unmodifiable(settings),
       noteAttachments = List.unmodifiable(
         noteAttachments.toList()..sort((a, b) => a.id.compareTo(b.id)),
       ),
       dayTasks = List.unmodifiable(
         dayTasks.toList()..sort((a, b) => a.id.compareTo(b.id)),
       ),
       shiftSwaps = List.unmodifiable(
         shiftSwaps.toList()..sort((a, b) => a.id.compareTo(b.id)),
       ),
       overtimeTypes = List.unmodifiable(
         overtimeTypes.toList()..sort((a, b) => a.id.compareTo(b.id)),
       ),
       overtimeBlocks = List.unmodifiable(
         overtimeBlocks.toList()..sort((a, b) {
           final byCalendar = a.calendarId.compareTo(b.calendarId);
           if (byCalendar != 0) return byCalendar;
           final byDate = a.date.compareTo(b.date);
           return byDate != 0 ? byDate : a.id.compareTo(b.id);
         }),
       );

  /// Parses the `data` object of a **version 1** file (no calendars): every
  /// run and day goes to the calendar `main`, created here with [migratedAt]
  /// (milliseconds since the epoch) as its timestamps. Throws
  /// [FormatException] on anything unexpected. A key a version 1 file does
  /// not define (`calendars`, `calendarId`, `hourlyRateCents`) is ignored
  /// even if present: the checksum already covered the file as written.
  factory BackupData.fromJsonV1(
    Map<String, Object?> json, {
    required int migratedAt,
  }) {
    final r = _JsonReader(json, 'data');
    return BackupData(
      calendars: [
        BackupCalendar.defaultMain(
          createdAt: migratedAt,
          updatedAt: migratedAt,
        ),
      ],
      shiftTypes: r.objects(
        'shiftTypes',
        (o) => BackupShiftType.fromJson(
          o,
          readHourlyRate: false,
          readV3Fields: false,
        ),
      ),
      patterns: r.objects('patterns', BackupPattern.fromJson),
      patternRuns: r.objects(
        'patternRuns',
        (o) => BackupPatternRun.fromJson(o, calendarId: mainCalendarId),
      ),
      dayEntries: r.objects(
        'dayEntries',
        (o) => BackupDayEntry.fromJson(
          o,
          calendarId: mainCalendarId,
          readV3Fields: false,
        ),
      ),
      holidays: r.objects('holidays', BackupHoliday.fromJson),
      absenceBalances: r.objects(
        'absenceBalances',
        (o) => BackupAbsenceBalance.fromJson(o, readExtensions: false),
      ),
      settings: r.stringMap('settings'),
    );
  }

  /// Parses the `data` object of a **version 2** file (calendars, no icon,
  /// alarm sound, second segment, reminder, overtime or early leave). Throws
  /// [FormatException] on anything unexpected. A key a version 2 file does
  /// not define (the version 3 fields) is ignored even if present: the
  /// checksum already covered the file as written.
  factory BackupData.fromJsonV2(Map<String, Object?> json) {
    final r = _JsonReader(json, 'data');
    return BackupData(
      calendars: r.objects('calendars', BackupCalendar.fromJson),
      shiftTypes: r.objects(
        'shiftTypes',
        (o) => BackupShiftType.fromJson(o, readV3Fields: false),
      ),
      patterns: r.objects('patterns', BackupPattern.fromJson),
      patternRuns: r.objects('patternRuns', BackupPatternRun.fromJson),
      dayEntries: r.objects(
        'dayEntries',
        (o) => BackupDayEntry.fromJson(o, readV3Fields: false),
      ),
      holidays: r.objects('holidays', BackupHoliday.fromJson),
      absenceBalances: r.objects(
        'absenceBalances',
        (o) => BackupAbsenceBalance.fromJson(o, readExtensions: false),
      ),
      settings: r.stringMap('settings'),
    );
  }

  /// Parses the `data` object of a **version 3 or 4** file. Throws
  /// [FormatException] on anything unexpected; the codec turns that into
  /// `CorruptBackup`. Unknown keys are ignored (forward compatibility).
  /// `noteAttachments`, `dayTasks` and `shiftSwaps` (database v6) are
  /// optional: absent = none. [readOvertime] is true for version 4, which
  /// adds `overtimeTypes` and `overtimeBlocks` (database v7); the version 3
  /// reader ignores them even if present.
  factory BackupData.fromJson(
    Map<String, Object?> json, {
    bool readOvertime = false,
  }) {
    final r = _JsonReader(json, 'data');
    List<T> optional<T>(String key, T Function(Map<String, Object?>) parse) =>
        json[key] == null ? <T>[] : r.objects(key, parse);
    return BackupData(
      noteAttachments: optional(
        'noteAttachments',
        BackupNoteAttachment.fromJson,
      ),
      dayTasks: optional('dayTasks', BackupDayTask.fromJson),
      shiftSwaps: optional('shiftSwaps', BackupShiftSwap.fromJson),
      overtimeTypes: readOvertime
          ? optional('overtimeTypes', BackupOvertimeType.fromJson)
          : const [],
      overtimeBlocks: readOvertime
          ? optional('overtimeBlocks', BackupOvertimeBlock.fromJson)
          : const [],
      calendars: r.objects('calendars', BackupCalendar.fromJson),
      shiftTypes: r.objects('shiftTypes', BackupShiftType.fromJson),
      patterns: r.objects('patterns', BackupPattern.fromJson),
      patternRuns: r.objects('patternRuns', BackupPatternRun.fromJson),
      dayEntries: r.objects('dayEntries', BackupDayEntry.fromJson),
      holidays: r.objects('holidays', BackupHoliday.fromJson),
      absenceBalances: r.objects(
        'absenceBalances',
        BackupAbsenceBalance.fromJson,
      ),
      settings: r.stringMap('settings'),
    );
  }

  final List<BackupCalendar> calendars;
  final List<BackupShiftType> shiftTypes;
  final List<BackupPattern> patterns;
  final List<BackupPatternRun> patternRuns;
  final List<BackupDayEntry> dayEntries;
  final List<BackupHoliday> holidays;
  final List<BackupAbsenceBalance> absenceBalances;

  /// Setting key -> its JSON text, exactly as stored (`calendars.active` and
  /// `calendars.primary` among them).
  final Map<String, String> settings;

  /// Database v6, sorted by id. Written only when not empty, so data that
  /// never used them gives the bytes, checksum and fingerprint it always did.
  final List<BackupNoteAttachment> noteAttachments;
  final List<BackupDayTask> dayTasks;
  final List<BackupShiftSwap> shiftSwaps;

  /// Database v7 (format version 4): the overtime types, sorted by id, and
  /// the blocks of every calendar, by calendar, day and id. None of them =
  /// the two built-in types, untouched and unused (what every database
  /// starts with: `BackupRepository` leaves them out and restores them), so
  /// data that never used the extra hours gives the bytes, checksum and
  /// fingerprint it always did. Written only when there is any.
  final List<BackupOvertimeType> overtimeTypes;
  final List<BackupOvertimeBlock> overtimeBlocks;

  Map<String, Object?> toJson() => {
    'calendars': [for (final c in calendars) c.toJson()],
    'shiftTypes': [for (final t in shiftTypes) t.toJson()],
    'patterns': [for (final p in patterns) p.toJson()],
    'patternRuns': [for (final r in patternRuns) r.toJson()],
    'dayEntries': [for (final e in dayEntries) e.toJson()],
    'holidays': [for (final h in holidays) h.toJson()],
    'absenceBalances': [for (final b in absenceBalances) b.toJson()],
    'settings': settings,
    if (noteAttachments.isNotEmpty)
      'noteAttachments': [for (final a in noteAttachments) a.toJson()],
    if (dayTasks.isNotEmpty) 'dayTasks': [for (final t in dayTasks) t.toJson()],
    if (shiftSwaps.isNotEmpty)
      'shiftSwaps': [for (final s in shiftSwaps) s.toJson()],
    if (overtimeTypes.isNotEmpty || overtimeBlocks.isNotEmpty) ...{
      'overtimeTypes': [for (final t in overtimeTypes) t.toJson()],
      'overtimeBlocks': [for (final b in overtimeBlocks) b.toJson()],
    },
  };

  /// The engine view of one calendar (what it would show): the shift types,
  /// patterns and overtime types are common, the runs, days and overtime
  /// blocks are those of [calendarId]. Without overtime types (a file older
  /// than format 4) it has the built-in ones.
  Schedule toSchedule([String calendarId = mainCalendarId]) {
    final entries = <CivilDate, DayEntry>{
      for (final e in dayEntries)
        if (e.calendarId == calendarId) e.date: e.toEntry(),
    };
    final blocks = <CivilDate, List<OvertimeBlock>>{};
    for (final b in overtimeBlocks) {
      if (b.calendarId == calendarId) (blocks[b.date] ??= []).add(b.toBlock());
    }
    for (final MapEntry(key: date, value: dayBlocks) in blocks.entries) {
      entries[date] = (entries[date] ?? DayEntry(date: date)).copyWith(
        overtimeBlocks: dayBlocks..sort(compareOvertimeBlocks),
      );
    }
    final types = [...overtimeTypes]
      ..sort((a, b) {
        final byOrder = a.sortOrder.compareTo(b.sortOrder);
        return byOrder != 0 ? byOrder : a.id.compareTo(b.id);
      });
    return Schedule(
      shiftTypes: [for (final t in shiftTypes) t.toShiftType()],
      shiftTypeVersions: {
        for (final t in shiftTypes)
          if (t.pastVersions.isNotEmpty) t.id: t.toVersions(),
      },
      patterns: [for (final p in patterns) p.toPattern()],
      runs: [
        for (final r in patternRuns)
          if (r.calendarId == calendarId) r.toRun(),
      ],
      entries: entries,
      overtimeTypes: types.isEmpty
          ? defaultOvertimeTypes
          : [for (final t in types) t.toType()],
      baseHourlyRateCents: parseBaseHourlyRate(settings[baseHourlyRateKey]),
    );
  }

  /// This data in the form of database v7 (format version 4): the old
  /// overtime minutes of each day (`BackupDayEntry.overtimeMinutes`, format 3
  /// and before) become one block of «Horas extra», exactly as the step to
  /// schema v7 does with the database (`legacyOvertimeBlock`: from the end of
  /// the day's last work shift, or 00:00, for those minutes), with the
  /// built-in overtime types when there are none. Restoring and writing go
  /// through it; the readers of the old formats do not, so the golden files
  /// keep reading as they always did. Returns `this` when there is nothing to
  /// convert (no types and no blocks = the two built-in types, untouched).
  BackupData upgradedOvertime() {
    if (!dayEntries.any((e) => e.overtimeMinutes != null)) return this;
    final types = overtimeTypes.isEmpty
        ? [for (final t in defaultOvertimeTypes) BackupOvertimeType.of(t)]
        : [...overtimeTypes];
    final needsOvertimeType = dayEntries.any(
      (e) => (e.overtimeMinutes ?? 0) > 0,
    );
    if (needsOvertimeType && !types.any((t) => t.id == overtimeTypeId)) {
      final last = types.fold(-1, (n, t) => t.sortOrder > n ? t.sortOrder : n);
      types.add(
        BackupOvertimeType.of(
          defaultOvertimeTypes.first.copyWith(sortOrder: last + 1),
        ),
      );
    }
    final schedules = <String, Schedule>{};
    final taken = {
      for (final b in overtimeBlocks) (b.calendarId, b.date, b.id),
    };
    final blocks = [...overtimeBlocks];
    for (final e in dayEntries) {
      final minutes = e.overtimeMinutes ?? 0;
      if (minutes <= 0) continue;
      final schedule = schedules[e.calendarId] ??= toSchedule(e.calendarId);
      var block = legacyOvertimeBlock(
        schedule.resolve(e.date),
        minutes.clamp(1, maxDayExtraMinutes),
      );
      if (taken.contains((e.calendarId, e.date, block.id))) {
        block = OvertimeBlock(
          id: '${block.id}-old',
          date: block.date,
          typeId: block.typeId,
          startMinute: block.startMinute,
          endMinute: block.endMinute,
        );
      }
      blocks.add(BackupOvertimeBlock.of(e.calendarId, block));
    }
    return BackupData(
      calendars: calendars,
      shiftTypes: shiftTypes,
      patterns: patterns,
      patternRuns: patternRuns,
      dayEntries: [for (final e in dayEntries) e.withoutOvertimeMinutes()],
      holidays: holidays,
      absenceBalances: absenceBalances,
      settings: settings,
      noteAttachments: noteAttachments,
      dayTasks: dayTasks,
      shiftSwaps: shiftSwaps,
      overtimeTypes: types,
      overtimeBlocks: blocks,
    );
  }

  /// How many shift types carry an alarm sound that is not a system one
  /// ([isSystemAlarmSound]).
  int get foreignAlarmSoundCount => shiftTypes
      .where((t) => t.alarmSound != null && !isSystemAlarmSound(t.alarmSound!))
      .length;

  /// This data without the attachments whose ids are in [ids] (a copy that
  /// leaves out the ones whose file is lost). Everything else is the same.
  BackupData withoutAttachments(Set<String> ids) {
    if (ids.isEmpty) return this;
    return BackupData(
      calendars: calendars,
      shiftTypes: shiftTypes,
      patterns: patterns,
      patternRuns: patternRuns,
      dayEntries: dayEntries,
      holidays: holidays,
      absenceBalances: absenceBalances,
      settings: settings,
      noteAttachments: [
        for (final a in noteAttachments)
          if (!ids.contains(a.id)) a,
      ],
      dayTasks: dayTasks,
      shiftSwaps: shiftSwaps,
      overtimeTypes: overtimeTypes,
      overtimeBlocks: overtimeBlocks,
    );
  }

  /// This data with every alarm sound that is not a system one
  /// ([isSystemAlarmSound]) dropped (`null`: the shift type rings with the
  /// default sound). A file is untrusted input: a `content://` URI of the
  /// app's own FileProvider, or of any other app, must never be handed to the
  /// notification service. Dropping it is not an error, so the rest of the
  /// backup restores. Returns `this` when there is nothing to drop.
  BackupData sanitized() {
    if (foreignAlarmSoundCount == 0) return this;
    return BackupData(
      calendars: calendars,
      shiftTypes: [
        for (final t in shiftTypes)
          t.alarmSound != null && !isSystemAlarmSound(t.alarmSound!)
              ? t.withoutAlarmSound()
              : t,
      ],
      patterns: patterns,
      patternRuns: patternRuns,
      dayEntries: dayEntries,
      holidays: holidays,
      absenceBalances: absenceBalances,
      settings: settings,
      noteAttachments: noteAttachments,
      dayTasks: dayTasks,
      shiftSwaps: shiftSwaps,
      overtimeTypes: overtimeTypes,
      overtimeBlocks: overtimeBlocks,
    );
  }

  /// Checks what the database and the engine would enforce (so a restore
  /// never starts a write it cannot finish, nor writes what `Schedule` then
  /// refuses to load), foreign keys included. Throws [CorruptBackup] with the
  /// first problem found.
  ///
  /// References that the engine tolerates are **not** errors: a pattern step
  /// or a day entry naming a shift type that does not exist is skipped by
  /// `Schedule`, and a legitimate database can hold one, so refusing it would
  /// make a good backup unrestorable.
  void validate() {
    Never fail(String message) => throw CorruptBackup(message);

    final calendarIds = <String>{};
    for (final c in calendars) {
      if (c.id.isEmpty) fail('A calendar has an empty id');
      if (!calendarIds.add(c.id)) fail('Duplicate calendar id "${c.id}"');
      if (c.name.trim().isEmpty) fail('Calendar "${c.id}" has no name');
      if (c.colorValue < 0 || c.colorValue > 0xFFFFFFFF) {
        fail('Calendar "${c.id}" has a color out of range');
      }
    }
    if (calendars.every((c) => c.archived)) {
      // The app always has a calendar it can show.
      fail('There is no calendar that is not archived');
    }

    final typeIds = <String>{};
    for (final t in shiftTypes) {
      if (t.id.isEmpty) fail('A shift type has an empty id');
      if (!typeIds.add(t.id)) fail('Duplicate shift type id "${t.id}"');
      if (t.code.isEmpty || t.code.length > 3) {
        fail('Shift type "${t.id}" has a code of ${t.code.length} characters');
      }
      if (t.name.isEmpty) fail('Shift type "${t.id}" has no name');
      if (t.colorValue < 0 || t.colorValue > 0xFFFFFFFF) {
        fail('Shift type "${t.id}" has a color out of range');
      }
      if ((t.startMinute == null) != (t.endMinute == null)) {
        fail('Shift type "${t.id}" has only one of start and end');
      }
      for (final m in [t.startMinute, t.endMinute]) {
        if (m != null && (m < 0 || m > 1439)) {
          fail('Shift type "${t.id}" has a time out of range');
        }
      }
      final rate = t.hourlyRateCents;
      if (rate != null && (rate < 0 || rate > maxHourlyRateCents)) {
        fail('Shift type "${t.id}" has an hourly rate out of range');
      }
      final plus = t.fixedPlusCents;
      if (plus != null && (plus < 0 || plus > maxFixedPlusCents)) {
        fail('Shift type "${t.id}" has a fixed plus out of range');
      }
      final sound = t.alarmSound;
      if (sound != null &&
          (sound.isEmpty || sound.length > maxAlarmSoundLength)) {
        fail('Shift type "${t.id}" has an invalid alarm sound');
      }
      final segment = checkSegment2(
        startMinute: t.startMinute,
        endMinute: t.endMinute,
        segment2StartMinute: t.segment2StartMinute,
        segment2DurationMinutes: t.segment2DurationMinutes,
      );
      if (segment != null) {
        fail(
          'Shift type "${t.id}" has an invalid second segment '
          '(${segment.name})',
        );
      }
      final versions = checkShiftTypeVersions(t.toVersions());
      if (versions != null) {
        fail('Shift type "${t.id}" has an invalid past version ($versions)');
      }
      final place = t.location;
      if (place != null &&
          (place.trim().isEmpty || place.length > maxShiftLocationLength)) {
        fail('Shift type "${t.id}" has an invalid place');
      }
      for (final hourlyPlus in [
        t.nightPlusCentsPerHour,
        t.holidayPlusCentsPerHour,
      ]) {
        if (hourlyPlus != null &&
            (hourlyPlus < 0 || hourlyPlus > maxStoredMoneyCents)) {
          fail('Shift type "${t.id}" has a plus per hour out of range');
        }
      }
    }

    final patternIds = <String>{};
    for (final p in patterns) {
      if (p.id.isEmpty) fail('A pattern has an empty id');
      if (!patternIds.add(p.id)) fail('Duplicate pattern id "${p.id}"');
      if (p.name.isEmpty) fail('Pattern "${p.id}" has no name');
      if (p.steps.isEmpty) fail('Pattern "${p.id}" has no steps');
    }

    final runIds = <String>{};
    final seqs = <int>{};
    for (final r in patternRuns) {
      if (r.id.isEmpty) fail('A run has an empty id');
      if (!runIds.add(r.id)) fail('Duplicate run id "${r.id}"');
      if (!seqs.add(r.seq)) fail('Duplicate run seq ${r.seq}');
      if (!patternIds.contains(r.patternId)) {
        fail('Run "${r.id}" points at a missing pattern "${r.patternId}"');
      }
      if (!calendarIds.contains(r.calendarId)) {
        fail('Run "${r.id}" points at a missing calendar "${r.calendarId}"');
      }
      final end = r.endDate;
      if (end != null && end.isBefore(r.startDate)) {
        fail('Run "${r.id}" ends before it starts');
      }
    }

    final dates = <(String, CivilDate)>{};
    for (final e in dayEntries) {
      if (!calendarIds.contains(e.calendarId)) {
        fail('Day ${e.date} points at a missing calendar "${e.calendarId}"');
      }
      if (!dates.add((e.calendarId, e.date))) {
        fail('Duplicate day entry ${e.date} in calendar "${e.calendarId}"');
      }
      final reminder = e.noteReminderMinute;
      if (reminder != null && !DayEntry.isReminderMinute(reminder)) {
        fail('Day ${e.date} has a reminder out of the day');
      }
      for (final extra in [e.overtimeMinutes, e.earlyLeaveMinutes]) {
        if (extra != null && (extra < 0 || extra > maxDayExtraMinutes)) {
          // A day holds 24 h at most (what the editor allows): more would
          // overflow the sums of the summary into absurd hours and euros.
          fail('Day ${e.date} has overtime or early leave out of 0-1440');
        }
      }
      final extra = e.extraAmountCents;
      if (extra != null &&
          (extra < -maxStoredMoneyCents || extra > maxStoredMoneyCents)) {
        fail('Day ${e.date} has an extra amount out of range');
      }
    }

    // One own holiday per day, like `addUserHoliday` (delete-by-date, then
    // insert); the table has no unique constraint, so the file must not bring
    // two on the same date.
    final holidayDates = <CivilDate>{};
    for (final h in holidays) {
      if (!holidayDates.add(h.date)) {
        fail('Duplicate own holiday on ${h.date}');
      }
      // The repository refuses a blank name when the user adds one.
      if (h.name.trim().isEmpty) fail('A holiday has no name');
      if (!_holidayScopes.contains(h.scope)) {
        fail('Holiday "${h.name}" has an unknown scope "${h.scope}"');
      }
    }

    final balances = <(int, String)>{};
    for (final b in absenceBalances) {
      if (!balances.add((b.year, b.type))) {
        fail('Duplicate absence balance ${b.year}/${b.type}');
      }
      if (!b.allowedDays.isFinite) {
        fail('Absence balance ${b.year}/${b.type} is not a number');
      }
      // The database v6 extensions: what the table CHECKs would refuse.
      final calendar = b.calendarId;
      if (calendar != null && !calendarIds.contains(calendar)) {
        fail(
          'Absence balance ${b.year}/${b.type} points at a missing '
          'calendar "$calendar"',
        );
      }
      final name = b.name;
      if (name != null &&
          (name.trim().isEmpty || name.length > maxAbsenceBalanceNameLength)) {
        fail('Absence balance ${b.year}/${b.type} has an invalid name');
      }
      final start = b.periodStart;
      final end = b.periodEnd;
      if ((start == null) != (end == null) ||
          (start != null && end!.isBefore(start))) {
        fail('Absence balance ${b.year}/${b.type} has an invalid period');
      }
      for (final MapEntry(:key, :value) in b.shiftTypeQuarters.entries) {
        if (key.isEmpty || value < 1 || value > 4) {
          fail(
            'Absence balance ${b.year}/${b.type} counts a shift type '
            'wrongly',
          );
        }
      }
      final cap = b.carryOverMaxDays;
      if (cap != null && (cap < 0 || !isQuarterDays(cap))) {
        fail('Absence balance ${b.year}/${b.type} has an invalid carry-over');
      }
      if (!isQuarterDays(b.adjustmentDays)) {
        fail('Absence balance ${b.year}/${b.type} has an invalid adjustment');
      }
      // A balance written by v6 (it carries one of its fields) is a whole
      // number of units, never negative (`AbsenceBalance.problem`). One with
      // only the three keys of every version keeps the old rule (a finite
      // number): an older file must always restore.
      if (b.hasExtensions &&
          (b.allowedDays < 0 || !isWholeUnits(b.allowedDays, b.unit))) {
        fail(
          'Absence balance ${b.year}/${b.type} has allowed days that are '
          'not whole units',
        );
      }
    }

    final attachmentIds = <String>{};
    final attachmentPaths = <String>{};
    for (final a in noteAttachments) {
      if (!attachmentIds.add(a.id)) fail('Duplicate attachment id "${a.id}"');
      // Lowercase: APFS (iOS) does not tell `a.jpg` from `A.jpg`.
      if (!attachmentPaths.add(a.relativePath.toLowerCase())) {
        fail('Two attachments share the file "${a.relativePath}"');
      }
      if (!calendarIds.contains(a.calendarId)) {
        fail('Attachment "${a.id}" points at a missing calendar');
      }
      // Ids and paths name files: an unsafe one could reach outside the
      // attachments folder (docs/copia-de-seguridad.md).
      final problem = a.toAttachment().problem;
      if (problem != null) fail('Attachment "${a.id}" is invalid ($problem)');
    }

    final taskIds = <String>{};
    for (final t in dayTasks) {
      if (!taskIds.add(t.id)) fail('Duplicate task id "${t.id}"');
      if (!calendarIds.contains(t.calendarId)) {
        fail('Task "${t.id}" points at a missing calendar');
      }
      final problem = t.toTask().problem;
      if (problem != null) fail('Task "${t.id}" is invalid ($problem)');
    }

    final swapIds = <String>{};
    for (final s in shiftSwaps) {
      if (!swapIds.add(s.id)) fail('Duplicate swap id "${s.id}"');
      if (!calendarIds.contains(s.calendarId)) {
        fail('Swap "${s.id}" points at a missing calendar');
      }
      final problem = s.toSwap().problem;
      if (problem != null) fail('Swap "${s.id}" is invalid ($problem)');
    }

    // Database v7: the same rules as the tables (`OvertimeType.problem`,
    // `OvertimeBlock.problem`) and their foreign keys.
    final overtimeTypeIds = <String>{};
    for (final t in overtimeTypes) {
      if (!overtimeTypeIds.add(t.id)) {
        fail('Duplicate overtime type id "${t.id}"');
      }
      final problem = t.toType().problem;
      if (problem != null) {
        fail('Overtime type "${t.id}" is invalid ($problem)');
      }
    }
    final blockKeys = <(String, CivilDate, String)>{};
    for (final b in overtimeBlocks) {
      if (!blockKeys.add((b.calendarId, b.date, b.id))) {
        fail('Duplicate overtime block "${b.id}" on ${b.date}');
      }
      if (!calendarIds.contains(b.calendarId)) {
        fail('Overtime block "${b.id}" points at a missing calendar');
      }
      if (!overtimeTypeIds.contains(b.typeId)) {
        fail('Overtime block "${b.id}" points at a missing type');
      }
      final problem = b.toBlock().problem;
      if (problem != null) {
        fail('Overtime block "${b.id}" is invalid ($problem)');
      }
    }
  }

  @override
  bool operator ==(Object other) =>
      other is BackupData &&
      _deepEq.equals(calendars, other.calendars) &&
      _deepEq.equals(shiftTypes, other.shiftTypes) &&
      _deepEq.equals(patterns, other.patterns) &&
      _deepEq.equals(patternRuns, other.patternRuns) &&
      _deepEq.equals(dayEntries, other.dayEntries) &&
      _deepEq.equals(holidays, other.holidays) &&
      _deepEq.equals(absenceBalances, other.absenceBalances) &&
      _deepEq.equals(settings, other.settings) &&
      _deepEq.equals(noteAttachments, other.noteAttachments) &&
      _deepEq.equals(dayTasks, other.dayTasks) &&
      _deepEq.equals(shiftSwaps, other.shiftSwaps) &&
      _deepEq.equals(overtimeTypes, other.overtimeTypes) &&
      _deepEq.equals(overtimeBlocks, other.overtimeBlocks);

  @override
  int get hashCode => Object.hash(
    _deepEq.hash(calendars),
    _deepEq.hash(shiftTypes),
    _deepEq.hash(patterns),
    _deepEq.hash(patternRuns),
    _deepEq.hash(dayEntries),
    _deepEq.hash(holidays),
    _deepEq.hash(absenceBalances),
    _deepEq.hash(settings),
    _deepEq.hash(noteAttachments),
    _deepEq.hash(dayTasks),
    _deepEq.hash(shiftSwaps),
    _deepEq.hash(overtimeTypes),
    _deepEq.hash(overtimeBlocks),
  );
}

/// Strict typed access to a decoded JSON object. Every mismatch is a
/// [FormatException] naming the field.
class _JsonReader {
  _JsonReader(this._map, this._what);

  final Map<String, Object?> _map;
  final String _what;

  Never _bad(String key, String expected) =>
      throw FormatException('$_what.$key: expected $expected');

  String string(String key) {
    final v = _map[key];
    return v is String ? v : _bad(key, 'a string');
  }

  String? stringOrNull(String key) => _map[key] == null ? null : string(key);

  int integer(String key) {
    final v = _map[key];
    if (v is int) return v;
    // Another writer may print 3 as 3.0.
    if (v is double && v.isFinite && v == v.truncateToDouble()) {
      return v.toInt();
    }
    return _bad(key, 'an integer');
  }

  int? integerOrNull(String key) => _map[key] == null ? null : integer(key);

  double number(String key) {
    final v = _map[key];
    return v is num && v.isFinite ? v.toDouble() : _bad(key, 'a number');
  }

  bool boolean(String key) {
    final v = _map[key];
    return v is bool ? v : _bad(key, 'a boolean');
  }

  bool? boolOrNull(String key) => _map[key] == null ? null : boolean(key);

  T enumValue<T extends Enum>(String key, List<T> values) {
    final name = string(key);
    for (final v in values) {
      if (v.name == name) return v;
    }
    return _bad(key, 'one of ${values.map((v) => v.name).join('/')}');
  }

  CivilDate date(String key) {
    final text = string(key);
    try {
      return CivilDate.parse(text);
    } on FormatException {
      return _bad(key, 'an ISO date');
    }
  }

  CivilDate? dateOrNull(String key) => _map[key] == null ? null : date(key);

  List<String> _strings(Object? v, String key) {
    if (v is! List) return _bad(key, 'a list of strings');
    return List<String>.unmodifiable([
      for (final s in v) s is String ? s : _bad(key, 'a list of strings'),
    ]);
  }

  List<String>? stringListOrNull(String key) =>
      _map[key] == null ? null : _strings(_map[key], key);

  List<List<String>> stringMatrix(String key) {
    final v = _map[key];
    if (v is! List) return _bad(key, 'a list of lists');
    return List.unmodifiable([for (final row in v) _strings(row, key)]);
  }

  List<T> objects<T>(String key, T Function(Map<String, Object?>) parse) {
    final v = _map[key];
    if (v is! List) return _bad(key, 'a list');
    return [
      for (final o in v)
        o is Map<String, Object?> ? parse(o) : _bad(key, 'a list of objects'),
    ];
  }

  Map<String, int> intMap(String key) {
    final v = _map[key];
    if (v is! Map) return _bad(key, 'an object');
    return Map.unmodifiable({
      for (final e in v.entries)
        e.key as String: e.value is int
            ? e.value! as int
            : _bad(key, 'integers'),
    });
  }

  Map<String, String> stringMap(String key) {
    final v = _map[key];
    if (v is! Map) return _bad(key, 'an object');
    return {
      for (final e in v.entries)
        e.key as String: e.value is String
            ? e.value! as String
            : _bad(key, 'string values'),
    };
  }
}
