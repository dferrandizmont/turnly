/// The cap of the overtime (propuesta 8 de `docs/competencia-2026-11.md`):
/// the most hours of overtime the user wants (or may) work in a month or a
/// year. The Estatuto de los Trabajadores (art. 35.2) caps them at 80 a year;
/// an agreement can set another number, so the user types it.
///
/// The overtime counted is the one noted on the days
/// ([MonthSummary.cappedOvertimeMinutes]: without the overtime types that
/// do not count for the goal, schema v7): the minutes the user wrote down as
/// «horas extra», not the hours above the goal.
library;

/// What the cap is counted against.
enum OvertimeCapPeriod {
  month('month'),
  year('year');

  const OvertimeCapPeriod(this.stored);

  /// The value written in the settings table.
  final String stored;

  /// The most hours the cap accepts: every hour of a 31-day month or of a
  /// leap year.
  int get maxHours => this == year ? 366 * 24 : 31 * 24;

  static OvertimeCapPeriod? fromStored(Object? value) {
    for (final period in values) {
      if (period.stored == value) return period;
    }
    return null;
  }
}

/// The hours of overtime the legal maximum allows in a year (ET art. 35.2),
/// offered as the starting value of a new cap.
const int legalOvertimeHoursPerYear = 80;

/// The share of the cap from which the summary warns (80 %).
const int overtimeCapWarningPercent = 80;

/// The user's cap of the overtime: whole [hours] per [period].
class OvertimeCap {
  const OvertimeCap(this.period, this.hours);

  final OvertimeCapPeriod period;
  final int hours;

  bool get isValid => hours >= 1 && hours <= period.maxHours;

  int get minutes => hours * 60;

  Map<String, Object> toJson() => {'period': period.stored, 'hours': hours};

  /// `null` for anything that is not a valid cap: a bad value never blocks the
  /// summary, it just shows no cap.
  static OvertimeCap? fromJson(Object? json) {
    if (json is! Map) return null;
    final period = OvertimeCapPeriod.fromStored(json['period']);
    final hours = json['hours'];
    if (period == null || hours is! int) return null;
    final cap = OvertimeCap(period, hours);
    return cap.isValid ? cap : null;
  }

  @override
  bool operator ==(Object other) =>
      other is OvertimeCap && other.period == period && other.hours == hours;

  @override
  int get hashCode => Object.hash(period, hours);

  @override
  String toString() => 'OvertimeCap(${period.stored}, $hours h)';
}

/// Where the overtime of a period stands against the cap.
enum OvertimeCapLevel {
  /// Below [overtimeCapWarningPercent] of the cap.
  ok,

  /// From [overtimeCapWarningPercent] of the cap up to the cap (not over it).
  near,

  /// Exactly the cap.
  reached,

  /// More than the cap.
  over,
}

/// The overtime of a period against the cap.
class OvertimeCapStatus {
  const OvertimeCapStatus({required this.cap, required this.usedMinutes});

  final OvertimeCap cap;

  /// The overtime noted in the period the cap is counted on.
  final int usedMinutes;

  int get capMinutes => cap.minutes;

  /// What is left before the cap (0 once it is reached or passed).
  int get leftMinutes =>
      usedMinutes >= capMinutes ? 0 : capMinutes - usedMinutes;

  /// How much the cap is passed by (0 when it is not).
  int get excessMinutes =>
      usedMinutes > capMinutes ? usedMinutes - capMinutes : 0;

  OvertimeCapLevel get level {
    if (usedMinutes > capMinutes) return OvertimeCapLevel.over;
    if (usedMinutes == capMinutes) return OvertimeCapLevel.reached;
    // used / cap >= 80 %, in whole numbers.
    if (usedMinutes * 100 >= capMinutes * overtimeCapWarningPercent) {
      return OvertimeCapLevel.near;
    }
    return OvertimeCapLevel.ok;
  }

  /// Whether the summary warns (near, reached or over).
  bool get warns => level != OvertimeCapLevel.ok;

  @override
  bool operator ==(Object other) =>
      other is OvertimeCapStatus &&
      other.cap == cap &&
      other.usedMinutes == usedMinutes;

  @override
  int get hashCode => Object.hash(cap, usedMinutes);

  @override
  String toString() => 'OvertimeCapStatus($cap, $usedMinutes min used)';
}
