import 'package:collection/collection.dart';

import '../../schedule/domain/civil_date.dart';

/// The smallest part of a day a balance counts in. The name is what is
/// stored.
enum AbsenceUnit {
  day(4),
  half(2),
  quarter(1);

  const AbsenceUnit(this.quarters);

  /// How many quarters of a day one unit is.
  final int quarters;

  /// One unit in days (1, 0.5 or 0.25).
  double get days => quarters / 4;
}

/// Longest name of a balance.
const int maxAbsenceBalanceNameLength = 100;

/// The key of the expiry date of the days carried into [year] of the series
/// [type] of [calendarId]. The expiry dates are kept by this key (the
/// `settings` table; the v6 schema has no column for them, see
/// `AbsenceCarryOverStore`).
///
/// Two calendars can hold a series with the same [type] (the series key is
/// only unique per calendar), so the key includes the calendar. Without
/// [calendarId] it is the key rows written before v6 used (no calendar);
/// those are still read as a fallback.
String absenceCarryOverExpiryKey(int year, String type, [String? calendarId]) =>
    calendarId == null ? '$year:$type' : '$calendarId|$year:$type';

/// Whether [days] is a whole number of quarters of a day (0.25 steps; every
/// such value is exact in floating point).
bool isQuarterDays(double days) =>
    days.isFinite && (days * 4) == (days * 4).roundToDouble();

/// Whether [days] is a whole number of [unit]s.
bool isWholeUnits(double days, AbsenceUnit unit) =>
    isQuarterDays(days) && (days * 4).round() % unit.quarters == 0;

const _quarterMapEq = MapEquality<String, int>();

/// Whether [date] is a working day («día hábil»): Monday to Friday and not
/// one of [holidays] (the holidays of the calendar's place).
bool isWorkingDay(CivilDate date, Set<CivilDate> holidays) =>
    date.weekday <= DateTime.friday && !holidays.contains(date);

/// The working days ([isWorkingDay]) from [from] to [to], both included.
int countWorkingDays(CivilDate from, CivilDate to, Set<CivilDate> holidays) {
  var count = 0;
  for (var d = from; !d.isAfter(to); d = d.addDays(1)) {
    if (isWorkingDay(d, holidays)) count++;
  }
  return count;
}

/// The days of vacation or leave available in one period (an
/// `absence_balances` row; extended in schema v6, docs/datos.md). What is used
/// is never stored: it is counted from the days of the calendar that have one
/// of the shift types of [shiftTypeQuarters].
///
/// [year] and [type] are the key, as since schema v1. [type] is the stable key
/// of the **series** (the same every year, so a balance can carry over from
/// `year - 1`); the app creates it (an id) and it must be unique across
/// calendars. The name the user sees is [name] (a row written before v6 has
/// none: show [type]).
class AbsenceBalance {
  const AbsenceBalance({
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
    this.workingDaysOnly = false,
  });

  final int year;
  final String type;

  /// Days available in the period (before carry-over and adjustment).
  final double allowedDays;

  /// The calendar whose days count; `null` (rows from before v6) = the
  /// primary calendar.
  final String? calendarId;
  final String? name;

  /// The period, both or none; none = the calendar year [year]. A period
  /// that does not follow the year (April to March) belongs to the [year] it
  /// starts in.
  final CivilDate? periodStart;
  final CivilDate? periodEnd;
  final AbsenceUnit unit;

  /// Shift type id -> quarters of a day one day with that type uses (1-4: a
  /// half-day vacation type counts 2). Types not listed do not count.
  final Map<String, int> shiftTypeQuarters;

  /// Whether what is left of the same series in `year - 1` adds to this one,
  /// at most [carryOverMaxDays] (`null` = no cap).
  final bool carryOver;
  final double? carryOverMaxDays;

  /// Days added (or, negative, taken) by hand: days already used before
  /// starting the app, an extra day granted...
  final double adjustmentDays;
  final int sortOrder;

  /// Milliseconds since the epoch (UTC); `null` on rows from before v6.
  final int? createdAt;
  final int? updatedAt;

  /// Whether only **working days** use the balance («días hábiles», propuesta
  /// 8): Monday to Friday that are not a holiday of the calendar
  /// ([isWorkingDay]). A vacation painted over a weekend or a holiday then
  /// costs nothing, as the 22 working days of vacation of the public sector
  /// count. Off = every day with one of the types counts (what the app always
  /// did). The v6 schema has no column for it: it is kept in the `settings`
  /// table (`AbsenceWorkingDaysStore`) and travels in the backup with it.
  final bool workingDaysOnly;

  /// First and last day (both included) of the period.
  CivilDate get start => periodStart ?? CivilDate(year, 1, 1);
  CivilDate get end => periodEnd ?? CivilDate(year, 12, 31);

  /// Whether [date] falls in the period.
  bool contains(CivilDate date) => !date.isBefore(start) && !date.isAfter(end);

  /// The name to show.
  String get displayName => name ?? type;

  /// The same balance with some fields changed. The [clear...] flags empty a
  /// field that would otherwise keep its value.
  AbsenceBalance copyWith({
    int? year,
    String? type,
    double? allowedDays,
    String? calendarId,
    String? name,
    CivilDate? periodStart,
    CivilDate? periodEnd,
    AbsenceUnit? unit,
    Map<String, int>? shiftTypeQuarters,
    bool? carryOver,
    double? carryOverMaxDays,
    double? adjustmentDays,
    int? sortOrder,
    int? createdAt,
    int? updatedAt,
    bool? workingDaysOnly,
    bool clearCalendarId = false,
    bool clearName = false,
    bool clearPeriod = false,
    bool clearCarryOverMaxDays = false,
    bool clearCreatedAt = false,
    bool clearUpdatedAt = false,
  }) => AbsenceBalance(
    year: year ?? this.year,
    type: type ?? this.type,
    allowedDays: allowedDays ?? this.allowedDays,
    calendarId: clearCalendarId ? null : calendarId ?? this.calendarId,
    name: clearName ? null : name ?? this.name,
    periodStart: clearPeriod ? null : periodStart ?? this.periodStart,
    periodEnd: clearPeriod ? null : periodEnd ?? this.periodEnd,
    unit: unit ?? this.unit,
    shiftTypeQuarters: shiftTypeQuarters ?? this.shiftTypeQuarters,
    carryOver: carryOver ?? this.carryOver,
    carryOverMaxDays: clearCarryOverMaxDays
        ? null
        : carryOverMaxDays ?? this.carryOverMaxDays,
    adjustmentDays: adjustmentDays ?? this.adjustmentDays,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: clearCreatedAt ? null : createdAt ?? this.createdAt,
    updatedAt: clearUpdatedAt ? null : updatedAt ?? this.updatedAt,
    workingDaysOnly: workingDaysOnly ?? this.workingDaysOnly,
  );

  /// Why this balance cannot be written by the app, or `null` when it is
  /// valid. (Rows from before v6 are read as they are, whatever they hold.)
  String? get problem {
    if (type.isEmpty) return 'empty type';
    final label = name;
    if (label != null &&
        (label.trim().isEmpty || label.length > maxAbsenceBalanceNameLength)) {
      return 'invalid name';
    }
    if (allowedDays < 0 || !isWholeUnits(allowedDays, unit)) {
      return 'allowed days are not whole units';
    }
    if ((periodStart == null) != (periodEnd == null)) {
      return 'period start and end must be both set or both null';
    }
    if (periodStart != null && periodEnd!.isBefore(periodStart!)) {
      return 'period ends before it starts';
    }
    for (final MapEntry(:key, :value) in shiftTypeQuarters.entries) {
      if (key.isEmpty) return 'empty shift type id';
      if (value < 1 || value > 4 || value % unit.quarters != 0) {
        return 'shift type "$key" counts $value quarters';
      }
    }
    final cap = carryOverMaxDays;
    if (cap != null && (cap < 0 || !isQuarterDays(cap))) {
      return 'invalid carry-over cap';
    }
    if (!isQuarterDays(adjustmentDays)) return 'invalid adjustment';
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is AbsenceBalance &&
      other.year == year &&
      other.type == type &&
      other.allowedDays == allowedDays &&
      other.calendarId == calendarId &&
      other.name == name &&
      other.periodStart == periodStart &&
      other.periodEnd == periodEnd &&
      other.unit == unit &&
      _quarterMapEq.equals(other.shiftTypeQuarters, shiftTypeQuarters) &&
      other.carryOver == carryOver &&
      other.carryOverMaxDays == carryOverMaxDays &&
      other.adjustmentDays == adjustmentDays &&
      other.sortOrder == sortOrder &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.workingDaysOnly == workingDaysOnly;

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
    _quarterMapEq.hash(shiftTypeQuarters),
    carryOver,
    carryOverMaxDays,
    adjustmentDays,
    sortOrder,
    createdAt,
    updatedAt,
    workingDaysOnly,
  );

  @override
  String toString() => 'AbsenceBalance($year/$type, $allowedDays ${unit.name})';
}
