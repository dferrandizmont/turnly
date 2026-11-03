// The CHECKs of start/end minute name the column being declared (the idiom
// from the Drift docs).
// ignore_for_file: recursive_getters

import 'package:drift/drift.dart';

import '../../features/absences/domain/absence_balance.dart';
import '../../features/notes/domain/note_attachment.dart';
import '../../features/schedule/domain/shift_type.dart';
import '../../features/swaps/domain/shift_swap.dart';
import 'converters.dart';

/// Schema v6 (see docs/datos.md). Calendar dates are ISO text, timestamps are
/// milliseconds since the epoch (UTC), id lists are JSON text.
///
/// The row classes are called `*Row` so they never collide with the engine
/// models (`ShiftType`, `Pattern`...) or with `dart:core`.

@DataClassName('ShiftTypeRow')
class ShiftTypes extends Table {
  TextColumn get id => text()();
  TextColumn get code => text()();
  TextColumn get name => text()();
  IntColumn get colorValue => integer()();
  TextColumn get category => textEnum<ShiftCategory>()();
  IntColumn get startMinute =>
      integer().nullable().check(startMinute.isBetweenValues(0, 1439))();
  IntColumn get endMinute =>
      integer().nullable().check(endMinute.isBetweenValues(0, 1439))();
  IntColumn get paidMinutes => integer().nullable()();
  BoolColumn get nightOverride => boolean().nullable()();

  /// Hourly rate in cents (no floating point). Added in schema v2.
  IntColumn get hourlyRateCents => integer().nullable()();

  /// Fixed payment per worked shift, in cents. Added in schema v4; the
  /// upper bound went from 999 999 to [maxStoredMoneyCents] in v6.
  IntColumn get fixedPlusCents => integer().nullable().check(
    fixedPlusCents.isBetweenValues(0, maxStoredMoneyCents),
  )();

  /// Key of the icon (`ShiftIcon.key`), or NULL. Plain text on purpose: a key
  /// this build does not know reads as no icon instead of failing. Added in
  /// schema v3.
  TextColumn get icon => text().nullable()();

  /// Opaque id of the system sound the alarm of this type uses; NULL = the
  /// default of the channel. Added in schema v3.
  TextColumn get alarmSound => text().nullable().check(
    alarmSound.isNull() | alarmSound.equals('').not(),
  )();

  /// Second segment of a split shift: clock minute where it starts and how
  /// long it lasts. Both or none, and only on a shift with times (CHECKs
  /// below). That it fits after the first segment within 24 h is checked by
  /// the domain (`checkSegment2`). Added in schema v3.
  IntColumn get segment2StartMinute => integer().nullable()();
  IntColumn get segment2DurationMinutes => integer().nullable()();

  /// Where the shift is worked, free text (not blank, at most
  /// [maxShiftLocationLength]). Added in schema v6.
  TextColumn get location => text().nullable().check(
    location.isNull() |
        (location.trim().length.isBiggerThanValue(0) &
            location.length.isSmallerOrEqualValue(maxShiftLocationLength)),
  )();

  /// Extra pay per hour at night and per hour on a holiday, in the minor
  /// unit of the currency. Added in schema v6.
  IntColumn get nightPlusCentsPerHour => integer().nullable().check(
    nightPlusCentsPerHour.isBetweenValues(0, maxStoredMoneyCents),
  )();
  IntColumn get holidayPlusCentsPerHour => integer().nullable().check(
    holidayPlusCentsPerHour.isBetweenValues(0, maxStoredMoneyCents),
  )();
  IntColumn get sortOrder => integer()();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>>? get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK ((start_minute IS NULL) = (end_minute IS NULL))',
    'CHECK ((segment2_start_minute IS NULL) = '
        '(segment2_duration_minutes IS NULL))',
    'CHECK (segment2_start_minute IS NULL OR start_minute IS NOT NULL)',
    'CHECK (segment2_start_minute IS NULL OR '
        'segment2_start_minute BETWEEN 0 AND 1439)',
    'CHECK (segment2_duration_minutes IS NULL OR '
        'segment2_duration_minutes BETWEEN 1 AND 1440)',
  ];
}

/// Earlier terms of a shift type changed «only from today on»: the hours and
/// money it had **up to `until_date`** (included). One row per change, never
/// one per day; the id of the type never changes. The current terms stay in
/// `shift_types` (docs/motor-de-turnos.md, «Versiones de un tipo»). Deleting
/// a type (only an unused one, after an undone import) takes its versions
/// with it. Added in schema v5.
@DataClassName('ShiftTypeVersionRow')
class ShiftTypeVersions extends Table {
  TextColumn get shiftTypeId =>
      text().references(ShiftTypes, #id, onDelete: KeyAction.cascade)();
  TextColumn get untilDate => text().map(const CivilDateConverter())();
  TextColumn get category => textEnum<ShiftCategory>()();
  IntColumn get startMinute =>
      integer().nullable().check(startMinute.isBetweenValues(0, 1439))();
  IntColumn get endMinute =>
      integer().nullable().check(endMinute.isBetweenValues(0, 1439))();
  IntColumn get paidMinutes =>
      integer().nullable().check(paidMinutes.isBiggerOrEqualValue(0))();
  BoolColumn get nightOverride => boolean().nullable()();
  // Upper bounds widened to [maxStoredMoneyCents] in schema v6.
  IntColumn get hourlyRateCents => integer().nullable().check(
    hourlyRateCents.isBetweenValues(0, maxStoredMoneyCents),
  )();
  IntColumn get fixedPlusCents => integer().nullable().check(
    fixedPlusCents.isBetweenValues(0, maxStoredMoneyCents),
  )();
  IntColumn get segment2StartMinute => integer().nullable()();
  IntColumn get segment2DurationMinutes => integer().nullable()();

  /// Night and holiday pluses per hour of these terms. Added in schema v6.
  IntColumn get nightPlusCentsPerHour => integer().nullable().check(
    nightPlusCentsPerHour.isBetweenValues(0, maxStoredMoneyCents),
  )();
  IntColumn get holidayPlusCentsPerHour => integer().nullable().check(
    holidayPlusCentsPerHour.isBetweenValues(0, maxStoredMoneyCents),
  )();
  IntColumn get createdAt => integer()();

  @override
  Set<Column<Object>>? get primaryKey => {shiftTypeId, untilDate};

  @override
  List<String> get customConstraints => [
    'CHECK ((start_minute IS NULL) = (end_minute IS NULL))',
    'CHECK ((segment2_start_minute IS NULL) = '
        '(segment2_duration_minutes IS NULL))',
    'CHECK (segment2_start_minute IS NULL OR start_minute IS NOT NULL)',
    'CHECK (segment2_start_minute IS NULL OR '
        'segment2_start_minute BETWEEN 0 AND 1439)',
    'CHECK (segment2_duration_minutes IS NULL OR '
        'segment2_duration_minutes BETWEEN 1 AND 1440)',
  ];
}

@DataClassName('PatternRow')
class Patterns extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();

  /// JSON `[[id, ...], ...]`, at least one step.
  TextColumn get steps => text().map(const StepsConverter())();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>>? get primaryKey => {id};

  @override
  List<String> get customConstraints => ["CHECK (steps <> '[]')"];
}

/// A schedule the user keeps (second job, partner...). Shift types and
/// patterns are shared by all of them; runs and days belong to one. Added in
/// schema v2; the migration (and a fresh install) creates `main`.
@DataClassName('CalendarRow')
class Calendars extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get colorValue => integer()();
  IntColumn get sortOrder => integer()();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>>? get primaryKey => {id};
}

@DataClassName('PatternRunRow')
class PatternRuns extends Table {
  TextColumn get id => text()();

  /// Calendar the run belongs to (schema v2).
  TextColumn get calendarId => text().references(Calendars, #id)();
  TextColumn get patternId => text().references(Patterns, #id)();
  TextColumn get startDate => text().map(const CivilDateConverter())();
  TextColumn get endDate => text().map(const CivilDateConverter()).nullable()();
  IntColumn get stepOffset => integer().withDefault(const Constant(0))();
  IntColumn get seq => integer().unique()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column<Object>>? get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (end_date IS NULL OR end_date >= start_date)',
  ];
}

@DataClassName('DayEntryRow')
class DayEntries extends Table {
  /// Calendar the day belongs to (schema v2: the key is calendar + date).
  TextColumn get calendarId => text().references(Calendars, #id)();
  TextColumn get date => text().map(const CivilDateConverter())();

  /// JSON list. NULL = does not replace the pattern; `[]` = empty day. A row
  /// exists only if the day holds something (override, note, reminder,
  /// overtime or early leave).
  TextColumn get shiftTypeIds =>
      text().map(const StringListConverter()).nullable()();
  TextColumn get note => text().nullable()();
  IntColumn get updatedAt => integer()();

  /// Minute of this civil day (0-1439) at which the note rings. Added in
  /// schema v3.
  IntColumn get noteReminderMinute =>
      integer().nullable().check(noteReminderMinute.isBetweenValues(0, 1439))();

  /// Extra minutes worked this day (>= 0). Added in schema v3.
  IntColumn get overtimeMinutes =>
      integer().nullable().check(overtimeMinutes.isBiggerOrEqualValue(0))();

  /// Minutes left before the end of the shift (>= 0). Added in schema v3.
  IntColumn get earlyLeaveMinutes =>
      integer().nullable().check(earlyLeaveMinutes.isBiggerOrEqualValue(0))();

  /// Extra money of the day (allowances, bonus; negative for a deduction),
  /// in the minor unit of the currency. Added in schema v6.
  IntColumn get extraAmountCents => integer().nullable().check(
    extraAmountCents.isBetweenValues(-maxStoredMoneyCents, maxStoredMoneyCents),
  )();

  @override
  Set<Column<Object>>? get primaryKey => {calendarId, date};
}

/// A file attached to the note of a day (photo, file or drawing). The bytes
/// are a file of the app; the row says where and what. Keyed by its own id,
/// not by the day row, which comes and goes with the engine. Added in schema
/// v6.
@DataClassName('NoteAttachmentRow')
@TableIndex(name: 'idx_note_attachments_day', columns: {#calendarId, #date})
class NoteAttachments extends Table {
  TextColumn get id => text()();
  TextColumn get calendarId =>
      text().references(Calendars, #id, onDelete: KeyAction.cascade)();
  TextColumn get date => text().map(const CivilDateConverter())();
  TextColumn get kind => textEnum<AttachmentKind>()();

  /// Relative to `<Application Support>/attachments/`. Unique ignoring
  /// case (constraint below): APFS does not tell `a.jpg` from `A.jpg`.
  TextColumn get relativePath => text()();
  TextColumn get mimeType => text()();
  IntColumn get sizeBytes => integer()();

  /// Lowercase hex SHA-256 of the file.
  TextColumn get sha256 => text()();
  TextColumn get displayName => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();

  @override
  Set<Column<Object>>? get primaryKey => {id};

  // Literal numbers in the CHECKs on purpose: make-migrations cannot read an
  // interpolated constant, and the schema must not move with one. They are
  // [maxAttachmentPathLength], [maxAttachmentMimeLength], [maxAttachmentBytes]
  // and [maxAttachmentNameLength] (a test keeps them equal).
  @override
  List<String> get customConstraints => [
    "CHECK (kind IN ('photo', 'file', 'sketch'))",
    'UNIQUE (relative_path COLLATE NOCASE)',
    'CHECK (length(id) BETWEEN 1 AND 64)',
    'CHECK (length(relative_path) BETWEEN 1 AND 512 '
        "AND substr(relative_path, 1, 1) NOT IN ('/', '.') "
        "AND instr(relative_path, '..') = 0 "
        'AND instr(relative_path, char(92)) = 0)',
    'CHECK (length(mime_type) BETWEEN 1 AND 255)',
    'CHECK (size_bytes BETWEEN 0 AND 52428800)',
    'CHECK (length(sha256) = 64)',
    'CHECK (display_name IS NULL OR '
        'length(display_name) BETWEEN 1 AND 255)',
  ];
}

/// One checkbox of the task list of a day. Its own table (not JSON in
/// `day_entries`) so that ticking a box is a one-row write and the list never
/// depends on whether the day row exists (docs/datos.md, «Esquema v6»).
/// Added in schema v6.
@DataClassName('DayTaskRow')
@TableIndex(name: 'idx_day_tasks_day', columns: {#calendarId, #date})
class DayTasks extends Table {
  TextColumn get id => text()();
  TextColumn get calendarId =>
      text().references(Calendars, #id, onDelete: KeyAction.cascade)();
  TextColumn get date => text().map(const CivilDateConverter())();
  TextColumn get title => text()();
  BoolColumn get done => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>>? get primaryKey => {id};

  // 500 = `maxDayTaskTitleLength` (literal: see `NoteAttachments`).
  @override
  List<String> get customConstraints => [
    "CHECK (id <> '')",
    "CHECK (trim(title) <> '' AND length(title) <= 500)",
  ];
}

/// The swap ledger: a shift that changed hands with a colleague, and whether
/// the favour is still owed. Added in schema v6.
@DataClassName('ShiftSwapRow')
@TableIndex(name: 'idx_shift_swaps_day', columns: {#calendarId, #date})
class ShiftSwaps extends Table {
  TextColumn get id => text()();
  TextColumn get calendarId =>
      text().references(Calendars, #id, onDelete: KeyAction.cascade)();
  TextColumn get date => text().map(const CivilDateConverter())();
  TextColumn get colleague => text()();
  TextColumn get direction => textEnum<SwapDirection>()();

  /// JSON lists of shift type ids; `NULL` = not recorded.
  TextColumn get givenShiftTypeIds =>
      text().map(const StringListConverter()).nullable()();
  TextColumn get receivedShiftTypeIds =>
      text().map(const StringListConverter()).nullable()();
  TextColumn get returnDate =>
      text().map(const CivilDateConverter()).nullable()();
  TextColumn get status =>
      textEnum<SwapStatus>().withDefault(const Constant('pending'))();
  TextColumn get note => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get closedAt => integer().nullable()();

  @override
  Set<Column<Object>>? get primaryKey => {id};

  // 200 and 2000 = [maxSwapColleagueLength] and [maxSwapNoteLength]
  // (literal: see `NoteAttachments`).
  @override
  List<String> get customConstraints => [
    "CHECK (id <> '')",
    "CHECK (direction IN ('theyOwe', 'iOwe'))",
    "CHECK (status IN ('pending', 'returned'))",
    "CHECK (trim(colleague) <> '' AND "
        'length(colleague) <= 200)',
    'CHECK (note IS NULL OR length(note) <= 2000)',
    "CHECK ((status = 'returned') = (closed_at IS NOT NULL))",
  ];
}

@DataClassName('HolidayRow')
@TableIndex(name: 'idx_holidays_date', columns: {#date})
class Holidays extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// ISO `YYYY-MM-DD`.
  TextColumn get date => text()();

  /// `national` / `regional` / `local`.
  TextColumn get scope => text()();
  TextColumn get name => text()();
  TextColumn get regionCode => text().nullable()();
  TextColumn get municipalityCode => text().nullable()();

  /// `bundled` / `remote` / `user`.
  TextColumn get source => text()();
}

/// Days of vacation or leave available per period (P3). The key and the
/// first three columns are those of schema v1 (rows written then keep their
/// values); schema v6 rebuilt the table adding the rest, all empty or at
/// their default on the old rows. `type` is the stable key of a series of
/// balances (the same every year, for the carry-over); see
/// `AbsenceBalance`.
@DataClassName('AbsenceBalanceRow')
class AbsenceBalances extends Table {
  IntColumn get year => integer()();
  TextColumn get type => text()();
  RealColumn get allowedDays => real()();

  /// Calendar whose days count; NULL = the primary one. Schema v6.
  TextColumn get calendarId => text().nullable().references(
    Calendars,
    #id,
    onDelete: KeyAction.cascade,
  )();
  TextColumn get name => text().nullable()();

  /// Both or none; none = the calendar year `year`. Schema v6.
  TextColumn get periodStart =>
      text().map(const CivilDateConverter()).nullable()();
  TextColumn get periodEnd =>
      text().map(const CivilDateConverter()).nullable()();
  TextColumn get unit =>
      textEnum<AbsenceUnit>().withDefault(const Constant('day'))();

  /// JSON object shift type id -> quarters of a day it uses (1-4).
  TextColumn get shiftTypeQuarters =>
      text().map(const StringIntMapConverter()).nullable()();
  BoolColumn get carryOver => boolean().withDefault(const Constant(false))();
  RealColumn get carryOverMaxDays => real().nullable()();
  RealColumn get adjustmentDays => real().withDefault(const Constant(0.0))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer().nullable()();
  IntColumn get updatedAt => integer().nullable()();

  @override
  Set<Column<Object>>? get primaryKey => {year, type};

  // 100 = [maxAbsenceBalanceNameLength] (literal: see `NoteAttachments`).
  @override
  List<String> get customConstraints => [
    "CHECK (unit IN ('day', 'half', 'quarter'))",
    "CHECK (name IS NULL OR (trim(name) <> '' AND length(name) <= 100))",
    'CHECK ((period_start IS NULL) = (period_end IS NULL))',
    'CHECK (period_end IS NULL OR period_end >= period_start)',
    'CHECK (carry_over_max_days IS NULL OR (carry_over_max_days >= 0 AND '
        'carry_over_max_days * 4 = CAST(carry_over_max_days * 4 AS INTEGER)))',
    'CHECK (adjustment_days * 4 = CAST(adjustment_days * 4 AS INTEGER))',
  ];
}

@DataClassName('SettingRow')
class Settings extends Table {
  TextColumn get key => text()();

  /// JSON.
  TextColumn get value => text()();

  @override
  Set<Column<Object>>? get primaryKey => {key};
}
