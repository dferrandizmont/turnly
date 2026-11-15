import 'dart:convert';

import 'civil_date.dart';
import 'schedule.dart';
import 'shift_type.dart';

/// Id of the built-in «Horas extra» type (schema v7, docs/datos.md): the one
/// the old overtime minutes of a day become, and the default on a work day.
const String overtimeTypeId = 'overtime';

/// Id of the built-in «Otro trabajo» type: the default on a free day.
const String otherWorkTypeId = 'other-work';

/// Longest name of an overtime type, in UTF-16 units.
const int maxOvertimeTypeNameLength = 100;

/// Longest short note of an overtime block, in UTF-16 units.
const int maxOvertimeNoteLength = 200;

/// Longest id of an overtime type or block.
const int maxOvertimeIdLength = 64;

/// One in basis points: a multiplier of 1.
const int multiplierOne = 10000;

/// Largest multiplier an overtime type takes (x100), in basis points.
const int maxMultiplierBasisPoints = 1000000;

/// The setting that keeps the base hourly rate of the extra hours (schema v7,
/// docs/datos.md): a JSON integer in the minor unit of the currency, or
/// absent. It travels in the backup with the rest of `settings`.
const String baseHourlyRateKey = 'summary.baseHourlyRateCents';

/// The base hourly rate out of the JSON text of its setting; anything
/// unexpected (a hand-edited backup) reads as none.
int? parseBaseHourlyRate(String? json) {
  if (json == null) return null;
  try {
    final value = jsonDecode(json);
    return value is int && value >= 0 && value <= maxStoredMoneyCents
        ? value
        : null;
  } on FormatException {
    return null;
  }
}

/// How an overtime type prices its hours.
enum OvertimeRateMode {
  /// The hourly rate of the day's shift (without one, the base rate).
  shift,

  /// That same rate times [OvertimeType.multiplierBasisPoints].
  multiplier,

  /// Its own hourly rate ([OvertimeType.hourlyRateCents]).
  fixed,

  /// Not paid.
  none,
}

/// A kind of extra hours (schema v7): a name, a colour of the palette, how it
/// is priced and whether it counts for the hours goal. Shared by every
/// calendar, like the shift types. A type in use is archived, never deleted:
/// archived types still resolve the blocks that use them.
class OvertimeType {
  const OvertimeType({
    required this.id,
    this.name,
    required this.colorValue,
    this.rateMode = OvertimeRateMode.shift,
    this.multiplierBasisPoints = multiplierOne,
    this.hourlyRateCents,
    this.countsForGoal = true,
    this.archived = false,
    this.sortOrder = 0,
  });

  final String id;

  /// What the user called it. `null` only for the built-in types the user
  /// has not renamed: the app shows their name in its own language.
  final String? name;

  /// ARGB.
  final int colorValue;
  final OvertimeRateMode rateMode;

  /// The multiplier of [OvertimeRateMode.multiplier], in basis points
  /// (12500 = x1.25). Kept, unused, by the other modes.
  final int multiplierBasisPoints;

  /// The own hourly rate of [OvertimeRateMode.fixed], in the minor unit of
  /// the currency. Required by that mode, kept (unused) by the others.
  final int? hourlyRateCents;
  final bool countsForGoal;
  final bool archived;
  final int sortOrder;

  /// Whether it is one of the two types every database starts with.
  bool get builtIn => id == overtimeTypeId || id == otherWorkTypeId;

  /// Why it cannot be stored (the same rules as the table and the backup),
  /// or `null` when it is valid.
  String? get problem {
    if (id.isEmpty || id.length > maxOvertimeIdLength) return 'id';
    final n = name;
    if (n != null &&
        (n.trim().isEmpty || n.length > maxOvertimeTypeNameLength)) {
      return 'name';
    }
    if (colorValue < 0 || colorValue > 0xffffffff) return 'color';
    if (multiplierBasisPoints < 1 ||
        multiplierBasisPoints > maxMultiplierBasisPoints) {
      return 'multiplier';
    }
    final rate = hourlyRateCents;
    if (rate != null && (rate < 0 || rate > maxStoredMoneyCents)) {
      return 'rate';
    }
    if (rateMode == OvertimeRateMode.fixed && rate == null) return 'rate';
    return null;
  }

  bool get valid => problem == null;

  OvertimeType copyWith({
    String? name,
    bool clearName = false,
    int? colorValue,
    OvertimeRateMode? rateMode,
    int? multiplierBasisPoints,
    int? hourlyRateCents,
    bool clearHourlyRate = false,
    bool? countsForGoal,
    bool? archived,
    int? sortOrder,
  }) => OvertimeType(
    id: id,
    name: clearName ? null : name ?? this.name,
    colorValue: colorValue ?? this.colorValue,
    rateMode: rateMode ?? this.rateMode,
    multiplierBasisPoints: multiplierBasisPoints ?? this.multiplierBasisPoints,
    hourlyRateCents: clearHourlyRate
        ? null
        : hourlyRateCents ?? this.hourlyRateCents,
    countsForGoal: countsForGoal ?? this.countsForGoal,
    archived: archived ?? this.archived,
    sortOrder: sortOrder ?? this.sortOrder,
  );

  @override
  bool operator ==(Object other) =>
      other is OvertimeType &&
      other.id == id &&
      other.name == name &&
      other.colorValue == colorValue &&
      other.rateMode == rateMode &&
      other.multiplierBasisPoints == multiplierBasisPoints &&
      other.hourlyRateCents == hourlyRateCents &&
      other.countsForGoal == countsForGoal &&
      other.archived == archived &&
      other.sortOrder == sortOrder;

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
  String toString() =>
      'OvertimeType($id, ${name ?? '<built-in>'}, ${rateMode.name})';
}

/// The two types every database starts with (schema v7): «Horas extra»
/// (paid as the shift, x1: the old overtime minutes migrate to it and keep
/// their value; the surcharge of each agreement is set in the type) and
/// «Otro trabajo» (not paid, does not count). Their names are the app's
/// until the user renames them. The step to v7 writes them as frozen
/// literals (`migration_v6_to_v7.dart`): changing these does not change
/// what that published step creates.
const List<OvertimeType> defaultOvertimeTypes = [
  OvertimeType(id: overtimeTypeId, colorValue: 0xFF4B4FD1),
  OvertimeType(
    id: otherWorkTypeId,
    colorValue: 0xFF12A594,
    rateMode: OvertimeRateMode.none,
    countsForGoal: false,
    sortOrder: 1,
  ),
];

/// A stretch of extra hours of one day (schema v7): a type, a start and an
/// end on the clock, an unpaid break and a short note. When the end is not
/// after the start it ends the next day; the block still belongs entirely to
/// the day it starts on (it never shows on the next one).
class OvertimeBlock {
  const OvertimeBlock({
    required this.id,
    required this.date,
    required this.typeId,
    required this.startMinute,
    required this.endMinute,
    this.breakMinutes = 0,
    this.note,
  });

  final String id;
  final CivilDate date;
  final String typeId;

  /// Minutes since 00:00 of [date], 0-1439.
  final int startMinute;

  /// 0-1439; not after [startMinute] = the next day (equal = 24 h).
  final int endMinute;

  /// Unpaid minutes inside the block (less than its length).
  final int breakMinutes;
  final String? note;

  bool get crossesMidnight => endMinute <= startMinute;

  /// Clock minutes, 1-1440.
  int get durationMinutes => (endMinute - startMinute + 1439) % 1440 + 1;

  /// The minutes that count and are paid: the length minus the break.
  int get paidMinutes => durationMinutes - breakMinutes;

  /// The end in minutes since 00:00 of [date] (past 1440 the next day).
  int get endMinuteAbs => startMinute + durationMinutes;

  /// Why it cannot be stored, or `null` when it is valid.
  String? get problem {
    if (id.isEmpty || id.length > maxOvertimeIdLength) return 'id';
    if (typeId.isEmpty || typeId.length > maxOvertimeIdLength) return 'type';
    if (startMinute < 0 || startMinute > 1439) return 'start';
    if (endMinute < 0 || endMinute > 1439) return 'end';
    if (breakMinutes < 0 || breakMinutes >= durationMinutes) return 'break';
    final n = note;
    if (n != null && (n.trim().isEmpty || n.length > maxOvertimeNoteLength)) {
      return 'note';
    }
    return null;
  }

  bool get valid => problem == null;

  OvertimeBlock copyWith({
    CivilDate? date,
    String? typeId,
    int? startMinute,
    int? endMinute,
    int? breakMinutes,
    String? note,
    bool clearNote = false,
  }) => OvertimeBlock(
    id: id,
    date: date ?? this.date,
    typeId: typeId ?? this.typeId,
    startMinute: startMinute ?? this.startMinute,
    endMinute: endMinute ?? this.endMinute,
    breakMinutes: breakMinutes ?? this.breakMinutes,
    note: clearNote ? null : note ?? this.note,
  );

  /// The same block on another day (copy, paste, repeat).
  OvertimeBlock onDate(CivilDate other) => copyWith(date: other);

  @override
  bool operator ==(Object other) =>
      other is OvertimeBlock &&
      other.id == id &&
      other.date == date &&
      other.typeId == typeId &&
      other.startMinute == startMinute &&
      other.endMinute == endMinute &&
      other.breakMinutes == breakMinutes &&
      other.note == note;

  @override
  int get hashCode =>
      Object.hash(id, date, typeId, startMinute, endMinute, breakMinutes, note);

  @override
  String toString() =>
      'OvertimeBlock($id, ${date.toIso()}, $typeId, $startMinute-$endMinute'
      '${breakMinutes == 0 ? '' : ', break $breakMinutes'})';
}

/// Orders blocks by day, start and id.
int compareOvertimeBlocks(OvertimeBlock a, OvertimeBlock b) {
  final byDate = a.date.compareTo(b.date);
  if (byDate != 0) return byDate;
  final byStart = a.startMinute.compareTo(b.startMinute);
  return byStart != 0 ? byStart : a.id.compareTo(b.id);
}

/// The work shift with a schedule of [day] that ends last, or `null` when it
/// has none.
ShiftType? lastWorkShift(ResolvedDay day) {
  ShiftType? last;
  int? end;
  for (final shift in day.shifts) {
    if (shift.category != ShiftCategory.work || !shift.hasTimes) continue;
    final next = shift.startMinute! + shift.spanMinutes;
    if (end == null || next >= end) {
      end = next;
      last = shift;
    }
  }
  return last;
}

/// The clock minute (since 00:00 of the day, past 1440 after midnight) the
/// last work shift with a schedule of [day] ends at, or `null` when it has
/// none.
int? lastWorkEndMinute(ResolvedDay day) {
  final shift = lastWorkShift(day);
  return shift == null ? null : shift.startMinute! + shift.spanMinutes;
}

/// Where [block] starts on the clock of its day, in minutes since 00:00 of
/// [day] (past 1440 = the next day). After a shift that ends past midnight
/// (22:00-06:00), a block that starts between that end (06:00) and the start
/// of the shift (22:00) is the morning after, and counts at D+1 (night
/// hours, holidays) like the old overtime placed after the shift, only when
/// it is closer to the end of the shift than to its start: `start - end of
/// shift <= start of shift - end of block` (06:00-08:00 is D+1, 18:00-21:00
/// stays on D, before the shift). Any other block starts on [day] itself.
int overtimeStartAbs(OvertimeBlock block, ResolvedDay day) {
  final shift = lastWorkShift(day);
  if (shift == null) return block.startMinute;
  final end = shift.startMinute! + shift.spanMinutes;
  if (end <= 1440) return block.startMinute;
  final shiftEnd = end - 1440;
  final shiftStart = shift.startMinute!;
  final start = block.startMinute;
  if (start < shiftEnd || start >= shiftStart) return start;
  final afterEnd = start - shiftEnd;
  final beforeStart = shiftStart - (start + block.durationMinutes);
  return afterEnd <= beforeStart ? start + 1440 : start;
}

/// Whether [block] happens the day after [day] (see [overtimeStartAbs]).
bool overtimeOnNextDay(OvertimeBlock block, ResolvedDay day) =>
    overtimeStartAbs(block, day) >= 1440;

/// The hourly rate of the first work shift with a schedule of [day] that has
/// one (the one the old overtime minutes were paid at).
int? dayShiftRateCents(ResolvedDay day) {
  for (final shift in day.shifts) {
    if (shift.category == ShiftCategory.work &&
        shift.hasTimes &&
        shift.hourlyRateCents != null) {
      return shift.hourlyRateCents;
    }
  }
  return null;
}

/// Whether [type] takes the pluses per hour (night, holiday) and the night
/// override of the day's last shift, as the old overtime did: the types paid
/// «as the shift» or as a multiple of it. A fixed rate or no rate is a job
/// of its own.
bool overtimeFollowsShift(OvertimeType type) =>
    type.rateMode == OvertimeRateMode.shift ||
    type.rateMode == OvertimeRateMode.multiplier;

/// The hourly rate of [type] on [day] in basis points of the minor unit
/// (cents x 10000), so a fractional multiplier never goes through a double;
/// `null` when it is not paid or there is no rate to start from. A type «as
/// the shift» on a day without a priced shift takes [baseRateCents].
int? overtimeRateUnits(OvertimeType type, ResolvedDay day, int? baseRateCents) {
  switch (type.rateMode) {
    case OvertimeRateMode.none:
      return null;
    case OvertimeRateMode.fixed:
      final rate = type.hourlyRateCents;
      return rate == null ? null : rate * multiplierOne;
    case OvertimeRateMode.shift:
    case OvertimeRateMode.multiplier:
      final rate = dayShiftRateCents(day) ?? baseRateCents;
      if (rate == null) return null;
      return rate *
          (type.rateMode == OvertimeRateMode.multiplier
              ? type.multiplierBasisPoints
              : multiplierOne);
  }
}

/// Minor units for [minutes] at [rateUnits] (from [overtimeRateUnits]),
/// rounded half up.
int overtimeCentsFor(int minutes, int rateUnits) =>
    (minutes * rateUnits + 300000) ~/ 600000;

/// What [block] earns on [day], or `null` when it is not paid.
int? overtimeAmountCents(
  OvertimeBlock block,
  OvertimeType type,
  ResolvedDay day,
  int? baseRateCents,
) {
  final units = overtimeRateUnits(type, day, baseRateCents);
  return units == null ? null : overtimeCentsFor(block.paidMinutes, units);
}

/// Where the old overtime of a day without a work shift with a schedule
/// starts once it is a block: 08:00, so it adds no night hours it never had.
const int legacyFreeDayOvertimeStart = 8 * 60;

/// The block the old overtime [minutes] of [day] become (schema v7 and old
/// backups): type «Horas extra», starting when the last work shift with a
/// schedule ends (08:00 without one, [legacyFreeDayOvertimeStart]) and
/// lasting exactly those minutes (1-1440). After a night shift ending the
/// next morning it starts at that time of day, still on [day], and
/// [overtimeStartAbs] puts it the morning after: the minutes, the price,
/// the night hours and the day they count on stay what they were.
OvertimeBlock legacyOvertimeBlock(ResolvedDay day, int minutes) {
  if (minutes < 1 || minutes > 1440) {
    throw ArgumentError.value(minutes, 'minutes', 'must be 1-1440');
  }
  final start = (lastWorkEndMinute(day) ?? legacyFreeDayOvertimeStart) % 1440;
  return OvertimeBlock(
    id: legacyOvertimeBlockId(day.date),
    date: day.date,
    typeId: overtimeTypeId,
    startMinute: start,
    endMinute: (start + minutes) % 1440,
  );
}

/// The id of the block converted from the old overtime of [date].
String legacyOvertimeBlockId(CivilDate date) => 'legacy-${date.toIso()}';
