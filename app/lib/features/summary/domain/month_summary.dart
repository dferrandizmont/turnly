import '../../schedule/domain/schedule_domain.dart';

/// Free monthly summary (docs/roadmap.md, "Ingresos estimados"): shifts per
/// type, hours, night hours, estimated pay, rest days, absences and holiday
/// hours of ONE calendar month. Pure Dart on top of [Schedule]; the screens
/// only format what is computed here.
///
/// The definitions (also in the footnotes of the screen):
///
/// * **Day.** The calendar day a shift STARTS on. A night shift of the 31st
///   belongs to the month of the 31st in full, even if its last hours fall in
///   the next month; the one of the previous month's last day is not here.
/// * **Occurrence ("turno").** Each shift of a day counts once: a day with
///   Mañana + Tarde is two shifts and one worked day. Shifts without a
///   schedule count as shifts but add no hours.
/// * **Hours.** Paid minutes ([ShiftType.effectivePaidMinutes]: the duration
///   unless an unpaid break is set; both segments of a split shift, without
///   the gap) of the `work` shifts with a schedule. A
///   24 h guard is 24 h. Civil clock hours: a daylight-saving night is not
///   corrected to 7 or 9 h.
/// * **Night hours.** The part of each work shift inside the night window
///   (22:00-06:00 unless told otherwise, [ShiftType.nightOverride] wins),
///   never more than the paid minutes of that shift. Measured on the shift
///   as the extras of its day leave it (A4, see «Where the extras fall»).
/// * **Pay.** Paid hours x the hourly rate of the shift type, per type
///   rounded to the cent. A work type without rate adds no hourly amount and
///   is listed in [MonthSummary.unpricedTypes]. Fixed pluses add once per work shift,
///   including shifts without hours or an hourly rate. A split shift adds
///   one plus; rest and absence types add none.
/// * **Holiday hours.** Minutes of work shifts that fall on a holiday date
///   (the shift split by calendar day, [ShiftOccurrence.splitByCivilDay]), so
///   a night shift that crosses into a holiday counts the part after
///   midnight; prorated by paid/total minutes. They are a subset of the
///   hours of the shift's start month. Like the night hours, measured on the
///   shifts as the extras of their day leave them (A4).
/// * **Rest days / absences.** A day is "worked" when it has a work shift;
///   [absenceDays] counts days with any absence type; [restDays] counts days
///   with a rest shift and neither a work shift nor an absence.
/// * **Overtime and early leave** (docs/paridad.md, A6). The minutes the user
///   noted on a day ([ResolvedDay.overtimeMinutes], [ResolvedDay.earlyLeaveMinutes])
///   belong to the DAY, whatever its shifts are, and go into the month of that
///   day. Per day, with `paid` = paid minutes of its work shifts with a
///   schedule: overtime always adds, even on a day with no shift, a rest day
///   or an absence (the user said they worked); early leave subtracts at most
///   `paid + overtime` (the day never goes below 0 h) and that applied amount
///   is what [earlyLeaveMinutes] reports, so `shiftMinutes + overtime -
///   earlyLeave == workedMinutes` always holds. [workedMinutes] is therefore
///   the TOTAL; the days and shifts do not change.
/// * **Where the extras fall on the clock** (A4). So that the night and
///   holiday hours agree with the total, the extras are placed on the clock:
///   the overtime goes right after the END of the last work shift of the day
///   (the segment with a schedule that ends last; it extends that shift, so
///   the shift's [ShiftType.nightOverride] applies to it too), and the early
///   leave is cut from the end of what the day then has: first the overtime,
///   then the end of the last shift and, if it is longer than that, the
///   shift or segment before, backwards. Each minute cut is a paid minute
///   (with an unpaid break the clock keeps the unpaid part). The night and
///   holiday hours of each shift are then measured on those adjusted pieces
///   with the same rules as without extras (night window, crossing midnight,
///   both segments of a split shift, civil clock hours on daylight-saving
///   nights) and capped at what the shift still pays, so neither figure can
///   exceed the total. A day with overtime but no work shift with a
///   schedule has nowhere to place it: those minutes count as day hours and
///   never as holiday hours. The figures per type ([ShiftTypeMonth]) are the
///   shifts alone, as scheduled, without the extras.
/// * **Pay of the extras.** Both are valued at the hourly rate of the FIRST
///   work shift of that day, in the order of the day, that has a schedule
///   and a rate; the extras of a day with no such shift are not valued (the
///   euros stay as they are) and are counted in [extrasWithoutRateMinutes] so
///   the screen can say so. The deduction of a day never exceeds what its
///   priced shifts and overtime pay. Unrounded per day (cent-minutes), rounded
///   once per month: [overtimeCents] and [earlyLeaveCents]; the total is the
///   types' hourly pay + [overtimeCents] - [earlyLeaveCents], never below 0,
///   plus the fixed pluses (early leave never reduces a fixed plus).
/// * **Pluses per hour** (P9, schema v6). A work shift type can have a
///   [ShiftType.nightPlusCentsPerHour] and a [ShiftType.holidayPlusCentsPerHour]:
///   money per hour of night and per hour of holiday. They are added to the
///   estimate over the **same hours the summary already counts**: the night
///   hours (with the extras of the day on the clock, so a night shift that
///   crosses midnight and the overtime that extends it count too) and the
///   holiday hours (prorated by paid minutes, like the holiday hours
///   themselves). A type changed «only from today on» uses the pluses of the
///   terms each day had ([ShiftTerms]). The money of a type is rounded once
///   ([ShiftTypeMonth.nightPlusCents], [ShiftTypeMonth.holidayPlusCents]) and
///   the month adds up the types, so the breakdown adds up to the month.
/// * **Extra amount of the day** (P9, schema v6). The user can note an extra
///   amount on a day (diets, mileage, a bonus; negative for a deduction,
///   [DayEntry.extraAmountCents]). It belongs to the day and not to the clock:
///   it is added to the totals of the month and of the range, and it is not
///   valued by any rate.
/// * **Stopping the counting** (P9). A [ClockCutoff] stops the counting at a
///   moment of the clock: the days after it are not counted, the day of the
///   cutoff only counts the part of it that has already been worked (a cut
///   shift pays only the minutes it has been worked, like an early leave) and
///   the shifts that were still running at that moment (a night shift of the
///   day before) only count the hours worked. The extras of that day (the
///   overtime and the early leave) only count when its shift has already
///   ended; its extra amount always counts.

/// What one shift type adds up to in a month.
class ShiftTypeMonth {
  const ShiftTypeMonth({
    required this.type,
    required this.days,
    required this.count,
    this.paidMinutes = 0,
    this.nightMinutes = 0,
    this.earningsCents,
    this.unpricedMinutes,
    this.nightPlusCents = 0,
    this.holidayPlusCents = 0,
  });

  /// The type with its **current** terms (name, colour, the card). A type
  /// changed «only from today on» (docs/motor-de-turnos.md, «Versiones de un
  /// tipo») may have counted other terms on some days of the period: the
  /// minutes and euros above are those of each day.
  final ShiftType type;

  /// Different days of the month the type appears on.
  final int days;

  /// Times it appears (a day with it twice counts twice).
  final int count;

  /// Paid minutes (work types with a schedule only).
  final int paidMinutes;
  final int nightMinutes;

  /// Estimated pay in cents; `null` without a rate or without hours.
  final int? earningsCents;

  /// Paid minutes of days whose terms had no hourly rate; `null` = not
  /// counted (then [type] decides).
  final int? unpricedMinutes;

  /// Money of the **night plus** of this type: its
  /// [ShiftType.nightPlusCentsPerHour] over the night hours its shifts had
  /// (the hours the day had, with the extras of the day on the clock).
  /// `0` when the type has no night plus.
  final int nightPlusCents;

  /// Money of the **holiday plus** of this type: its
  /// [ShiftType.holidayPlusCentsPerHour] over the holiday hours its shifts
  /// had. `0` when the type has no holiday plus.
  final int holidayPlusCents;

  /// The whole money of this type: the hourly pay of its shifts plus the
  /// night and holiday pluses. `null` without a rate and without pluses.
  int? get totalCents {
    final pay = earningsCents ?? 0;
    final pluses = nightPlusCents + holidayPlusCents;
    if (earningsCents == null && pluses == 0) return null;
    return pay + pluses;
  }

  bool get isWork => type.category == ShiftCategory.work;

  /// A work type that has hours but no hourly rate.
  bool get missingRate =>
      isWork &&
      paidMinutes > 0 &&
      (unpricedMinutes == null
          ? type.hourlyRateCents == null
          : unpricedMinutes! > 0);
}

/// The summary of one month.
class MonthSummary {
  const MonthSummary({
    required this.month,
    required this.types,
    required this.shiftsWorked,
    required this.workedDays,
    required this.workedMinutes,
    required this.nightMinutes,
    required this.restDays,
    required this.absenceDays,
    required this.holidayShifts,
    required this.holidayMinutes,
    required this.earningsCents,
    required this.shiftsWithoutTimes,
    this.overtimeMinutes = 0,
    this.earlyLeaveMinutes = 0,
    this.overtimeCents = 0,
    this.earlyLeaveCents = 0,
    this.extrasWithoutRateMinutes = 0,
    this.fixedPlusCount = 0,
    this.fixedPlusCents = 0,
    this.nightPlusCents = 0,
    this.holidayPlusCents = 0,
    this.extraAmountCents = 0,
  });

  /// First day of the month.
  final CivilDate month;

  /// The types that appear in the month, in the order of the schedule's
  /// types.
  final List<ShiftTypeMonth> types;

  /// Work shifts (a double day counts two).
  final int shiftsWorked;

  /// Days with at least one work shift.
  final int workedDays;

  /// Total minutes worked: the shifts' paid minutes + [overtimeMinutes] -
  /// [earlyLeaveMinutes].
  final int workedMinutes;
  final int nightMinutes;

  /// Extra minutes noted on the days of the month (A6).
  final int overtimeMinutes;

  /// Minutes of early leave applied (never more than the day had), A6.
  final int earlyLeaveMinutes;

  /// Pay of [overtimeMinutes] / [earlyLeaveMinutes] in cents, included in
  /// [earningsCents] (the second one subtracted).
  final int overtimeCents;
  final int earlyLeaveCents;

  /// Extra and early-leave minutes of days with no priced work shift: not
  /// in the euros.
  final int extrasWithoutRateMinutes;

  /// Work shifts with a configured fixed plus (including an explicit zero).
  final int fixedPlusCount;

  /// Fixed pluses of the work shifts, included in [earningsCents].
  /// Neither unpaid breaks nor early leave reduce them.
  final int fixedPlusCents;

  /// Money of the **night pluses** of the work shifts (P9): the
  /// [ShiftType.nightPlusCentsPerHour] of each type over its night hours
  /// (with the extras of the day on the clock), included in [earningsCents].
  final int nightPlusCents;

  /// Money of the **holiday pluses** of the work shifts (P9): the
  /// [ShiftType.holidayPlusCentsPerHour] of each type over its holiday
  /// hours, included in [earningsCents].
  final int holidayPlusCents;

  /// Extra money of the days of the month (P9: diets, mileage, a bonus;
  /// negative for a deduction), the sum of their
  /// [DayEntry.extraAmountCents]. Included in [earningsCents].
  final int extraAmountCents;

  /// Days with a rest shift and nothing worked or absent.
  final int restDays;

  /// Days with at least one absence type.
  final int absenceDays;

  /// Work shifts with some minutes on a holiday date.
  final int holidayShifts;
  final int holidayMinutes;

  /// Total estimated pay in cents; `null` without an hourly amount, a
  /// configured fixed plus, a night or holiday plus or an extra amount on
  /// any work shift (or day) in the period.
  ///
  /// It is the hourly pay of the types + the overtime - the early leave
  /// (never below 0) + the fixed pluses + the night and holiday pluses + the
  /// extra amounts of the days.
  final int? earningsCents;

  /// Work shifts without a schedule (they add no hours).
  final int shiftsWithoutTimes;

  /// Minutes the shifts alone add up to, without the extras.
  int get shiftMinutes => workedMinutes - overtimeMinutes + earlyLeaveMinutes;

  /// The month has overtime or early leave to show.
  bool get hasExtras => overtimeMinutes > 0 || earlyLeaveMinutes > 0;

  int get dayMinutes =>
      workedMinutes > nightMinutes ? workedMinutes - nightMinutes : 0;

  /// No shift of any kind this month and no overtime either.
  bool get isEmpty => types.isEmpty && overtimeMinutes == 0;

  List<ShiftTypeMonth> get workTypes => [
    for (final t in types)
      if (t.isWork) t,
  ];

  List<ShiftTypeMonth> get restTypes => [
    for (final t in types)
      if (t.type.category == ShiftCategory.rest) t,
  ];

  List<ShiftTypeMonth> get absenceTypes => [
    for (final t in types)
      if (t.type.category == ShiftCategory.absence) t,
  ];

  /// Work types with hours but no rate: their pay is not in the total.
  List<ShiftType> get unpricedTypes => [
    for (final t in types)
      if (t.missingRate) t.type,
  ];

  /// Whether the total pay has something to show.
  bool get hasEarnings => earningsCents != null;
}

/// Mutable tally of one type while walking the days.
class _Tally {
  _Tally(this.type);

  final ShiftType type;
  int days = 0;
  int count = 0;
  int paidMinutes = 0;
  int nightMinutes = 0;

  /// Paid minutes x the rate each day had (a type changed «only from today
  /// on» can have two rates in one period); `priced` once any had one.
  int pricedCentMinutes = 0;
  bool priced = false;
  int unpricedMinutes = 0;

  /// Night minutes x the night plus of the day (cents x minutes; divided by
  /// 60 at the end).
  int nightPlusCentMinutes = 0;

  /// Holiday minutes x the holiday plus of the day (cents x minutes).
  int holidayPlusCentMinutes = 0;
}

/// A stretch of work on the clock of one day (minutes from 00:00 of the
/// day it belongs to; past 1440 after midnight) and the paid minutes in it.
class _Piece {
  _Piece(this.start, this.end, this.paid);

  final int start;
  int end;
  int paid;

  /// The early leave cut this piece.
  bool trimmed = false;

  int get length => end - start;
}

/// The pieces of one work shift of a day (two for a split shift), or the
/// overtime that extends the last shift of the day ([owner]).
class _Group {
  _Group(this.date, this.type, {this.owner});

  final CivilDate date;

  /// Gives the night override (the overtime takes its shift's).
  final ShiftType type;

  /// For overtime: the shift it extends (a holiday shift counts once).
  final _Group? owner;
  final List<_Piece> pieces = [];

  int get paid => pieces.fold(0, (sum, p) => sum + p.paid);
  int get length => pieces.fold(0, (sum, p) => sum + p.length);
  bool get trimmed => pieces.any((p) => p.trimmed);

  Iterable<ShiftOccurrence> get _occurrences => [
    for (final p in pieces)
      if (p.length > 0)
        ShiftOccurrence(
          date: date,
          shiftType: type,
          startMinuteAbs: p.start,
          endMinuteAbs: p.end,
        ),
  ];

  /// Night minutes of the pieces, never more than they pay.
  int nightMinutes(NightWindow window) {
    var night = 0;
    for (final o in _occurrences) {
      night += window.nightMinutes(o);
    }
    return _min(night, paid);
  }

  /// Minutes on a holiday date, prorated by paid/clock minutes, and whether
  /// the shift counts as worked on a holiday.
  ({int minutes, bool touches}) holidayMinutes(Set<CivilDate> holidays) {
    var onHoliday = 0;
    for (final o in _occurrences) {
      for (final part in o.splitByCivilDay().entries) {
        if (holidays.contains(part.key)) onHoliday += part.value;
      }
    }
    final total = length;
    if (onHoliday == 0 || total == 0) return (minutes: 0, touches: false);
    final paidNow = paid;
    return (
      // Prorated when an unpaid break makes paid < total.
      minutes: (onHoliday * paidNow + total ~/ 2) ~/ total,
      // A shift whose paid part on the holiday was all cut by the early
      // leave was not worked on the holiday.
      touches: paidNow > 0 || !trimmed,
    );
  }
}

/// Places the day's extras on the clock (A4): [overtime] right after the end
/// of the segment that ends last, then [early] (already capped at what the
/// day pays) cut from the end backwards, piece by piece. Without a work
/// shift with a schedule the overtime has no place and stays off the clock.
void _placeExtras(List<_Group> groups, int overtime, int early) {
  if (groups.isEmpty) return;
  if (overtime > 0) {
    var lastGroup = groups.first;
    var last = lastGroup.pieces.first;
    for (final group in groups) {
      for (final piece in group.pieces) {
        if (piece.end >= last.end) {
          last = piece;
          lastGroup = group;
        }
      }
    }
    groups.add(
      _Group(lastGroup.date, lastGroup.type, owner: lastGroup)
        ..pieces.add(_Piece(last.end, last.end + overtime, overtime)),
    );
  }
  var left = early;
  if (left <= 0) return;
  final pieces = [for (final group in groups) ...group.pieces]
    ..sort((a, b) => b.end.compareTo(a.end));
  for (final piece in pieces) {
    if (left == 0) break;
    final cut = _min(left, piece.paid);
    if (cut == 0) continue;
    piece
      ..paid -= cut
      ..end = _max(piece.start, piece.end - cut)
      ..trimmed = true;
    left -= cut;
  }
}

/// A moment of the clock: a day and the minute of it (0-1439). The summary
/// can stop counting at it ([summarizeRange] with a `cutoff`), so only the
/// hours and the money already worked are counted: the days after it are not
/// counted at all, the day of the cutoff only counts the part of it that has
/// already happened and the shifts that were still running at that moment
/// (a night shift of the day before) only count the hours worked.
class ClockCutoff {
  const ClockCutoff(this.date, this.minuteOfDay)
    : assert(minuteOfDay >= 0 && minuteOfDay < 1440);

  /// The day the counting stops on.
  final CivilDate date;

  /// The minute of [date] (0-1439) the counting stops at.
  final int minuteOfDay;

  @override
  bool operator ==(Object other) =>
      other is ClockCutoff &&
      other.date == date &&
      other.minuteOfDay == minuteOfDay;

  @override
  int get hashCode => Object.hash(date, minuteOfDay);

  @override
  String toString() =>
      'ClockCutoff(${date.toIso()} ${minuteOfDay ~/ 60}:'
      '${(minuteOfDay % 60).toString().padLeft(2, '0')})';
}

/// The piece of [occurrence] that has been worked when the counting stops at
/// [cutMinute] (minutes since 00:00 of the day, the same clock the
/// occurrence uses; `null` = the whole occurrence). A piece cut short pays
/// only the minutes it has been worked: the same rule as an early leave.
/// `null` when the piece has not started.
_Piece? _pieceOf(ShiftOccurrence occurrence, int? cutMinute) {
  final start = occurrence.startMinuteAbs;
  var end = occurrence.endMinuteAbs;
  var paid = occurrence.paidMinutes;
  if (cutMinute != null) {
    if (start >= cutMinute) return null;
    if (end > cutMinute) {
      end = cutMinute;
      paid = _min(paid, cutMinute - start);
    }
  }
  return _Piece(start, end, paid);
}

/// Summarizes the days `[first, last]` (both included) for [schedule], with
/// the same definitions as a month: it is the one aggregate behind the month
/// summary ([summarizeMonth]) and the free date range of the summary screen,
/// so `summarizeRange(first of month, last of month)` equals the month.
/// [MonthSummary.month] is [first]. Shifts count on the day they START: a
/// night shift of [last] belongs to the range in full.
///
/// [holidays] are the holiday dates of the user's place (the neighbouring
/// months' too: the day after the last one may be a holiday a night shift
/// runs into). [window] is the night window.
///
/// [cutoff] stops the counting at a moment of the clock (P9, «llevas
/// ganado»): the days after it are not counted, the day of the cutoff only
/// counts what has already been worked and the shifts that were still
/// running at that moment only count the hours worked. The extras of that day
/// (the overtime and the early leave) only count when the shift they belong
/// to has already ended; the extra amount of the day always counts, since it
/// belongs to the day and not to the clock.
MonthSummary summarizeRange(
  Schedule schedule,
  CivilDate first,
  CivilDate last, {
  Set<CivilDate> holidays = const {},
  NightWindow window = const NightWindow(),
  ClockCutoff? cutoff,
}) {
  final days = schedule.resolveRange(first, last);

  final tallies = <String, _Tally>{};
  var shiftsWorked = 0;
  var shiftsWithoutTimes = 0;
  var workedDays = 0;
  var restDays = 0;
  var absenceDays = 0;
  var workedMinutes = 0;
  var nightMinutes = 0;
  var holidayShifts = 0;
  var holidayMinutes = 0;
  var overtimeMinutes = 0;
  var earlyLeaveMinutes = 0;
  var overtimeCentMinutes = 0;
  var earlyLeaveCentMinutes = 0;
  var extrasWithoutRate = 0;
  var fixedPlusCount = 0;
  var fixedPlusCents = 0;
  var extraAmountCents = 0;

  for (final day in days) {
    // The cutoff stops the counting: the days after it are not counted and
    // the shifts that are still running at that moment only count the part
    // of them already worked.
    if (cutoff != null && day.date.isAfter(cutoff.date)) continue;
    // The cutoff in minutes since 00:00 of the day (the days before it are
    // further away, so nothing of them is cut).
    final cutMinute = cutoff == null
        ? null
        : (cutoff.date.epochDay - day.date.epochDay) * 1440 +
              cutoff.minuteOfDay;

    var dayPaid = 0;
    var dayPricedCentMinutes = 0;
    int? dayRate;
    // The clock minute the day's work ends at (before the cutoff cuts it).
    var dayLastEnd = -1;
    final seen = <String>{};
    var hasWork = false;
    var hasRest = false;
    var hasAbsence = false;
    // The day's work on the clock, one group per work shift with a schedule;
    // the extras are placed on it below (A4).
    final groups = <_Group>[];
    for (final shift in day.shifts) {
      final tally = tallies.putIfAbsent(shift.id, () => _Tally(shift));
      tally.count++;
      if (seen.add(shift.id)) tally.days++;
      switch (shift.category) {
        case ShiftCategory.rest:
          hasRest = true;
        case ShiftCategory.absence:
          hasAbsence = true;
        case ShiftCategory.work:
          hasWork = true;
          shiftsWorked++;
          if (!shift.hasTimes) {
            // No hours: nothing to add to the holiday hours, so it is not
            // counted as a holiday shift either («0 h · 1 turno»).
            shiftsWithoutTimes++;
            // A shift without a schedule has no clock: on the day of a
            // cutoff there is no way to know whether it has been worked, so
            // it does not earn its fixed plus yet. The days before the cutoff
            // are already worked, so they do earn it.
            if (cutoff == null || day.date.isBefore(cutoff.date)) {
              if (shift.fixedPlusCents case final plus?) {
                fixedPlusCount++;
                fixedPlusCents += plus;
              }
            }
            break;
          }
          // A split shift (A12) has two segments; the gap between them is
          // not worked. The night hours and the holiday split are computed
          // per segment and added up per shift.
          final group = _Group(day.date, shift);
          for (final occurrence in ShiftOccurrence.allOf(day.date, shift)) {
            if (occurrence.endMinuteAbs > dayLastEnd) {
              dayLastEnd = occurrence.endMinuteAbs;
            }
            final piece = _pieceOf(occurrence, cutMinute);
            if (piece != null) group.pieces.add(piece);
          }
          groups.add(group);
          // The minutes worked so far: the whole shift, or the part of it
          // that has already happened when the counting stops.
          final paid = group.paid;
          // Per type: the shift alone, as scheduled (no extras).
          tally.paidMinutes += paid;
          tally.nightMinutes += group.nightMinutes(window);
          workedMinutes += paid;
          dayPaid += paid;
          // The fixed plus is earned by working the shift: it only counts
          // when the shift has started.
          final fixedPlus = shift.fixedPlusCents;
          if (group.pieces.isNotEmpty && fixedPlus != null) {
            fixedPlusCount++;
            fixedPlusCents += fixedPlus;
          }
          final rate = shift.hourlyRateCents;
          if (rate != null) {
            dayRate ??= rate;
            dayPricedCentMinutes += paid * rate;
            tally.pricedCentMinutes += paid * rate;
            if (paid > 0) tally.priced = true;
          } else {
            tally.unpricedMinutes += paid;
          }
      }
    }
    if (hasWork) workedDays++;
    if (hasAbsence) absenceDays++;
    if (hasRest && !hasWork && !hasAbsence) restDays++;

    // The extra amount of the day (P9): it belongs to the day, not to the
    // clock, so it counts even on the day of a cutoff.
    extraAmountCents += schedule.entries[day.date]?.extraAmountCents ?? 0;

    // The extras of the day (A6) only count when the shift they belong to
    // has already ended; on a day still in progress they are not known yet.
    final dayEnded = cutMinute == null || dayLastEnd <= cutMinute;
    final overtime = dayEnded ? day.overtimeMinutes : 0;
    final early = dayEnded
        ? _min(day.earlyLeaveMinutes, dayPaid + overtime)
        : 0;
    _placeExtras(groups, overtime, early);

    // Night and holiday hours of the day, on the adjusted pieces, and the
    // pluses per hour of the type (P9).
    final holidayRoots = <_Group>{};
    for (final group in groups) {
      final groupNight = group.nightMinutes(window);
      nightMinutes += groupNight;
      final (:minutes, :touches) = group.holidayMinutes(holidays);
      holidayMinutes += minutes;
      if (touches) holidayRoots.add(group.owner ?? group);
      final tally = tallies[group.type.id];
      final nightPlus = group.type.nightPlusCentsPerHour;
      if (nightPlus != null && nightPlus > 0) {
        final cents = groupNight * nightPlus;
        tally?.nightPlusCentMinutes += cents;
      }
      final holidayPlus = group.type.holidayPlusCentsPerHour;
      if (holidayPlus != null && holidayPlus > 0) {
        final cents = minutes * holidayPlus;
        tally?.holidayPlusCentMinutes += cents;
      }
    }
    holidayShifts += holidayRoots.length;

    if (overtime > 0 || early > 0) {
      overtimeMinutes += overtime;
      earlyLeaveMinutes += early;
      workedMinutes += overtime - early;
      if (dayRate == null) {
        extrasWithoutRate += overtime + early;
      } else {
        final overtimePay = overtime * dayRate;
        overtimeCentMinutes += overtimePay;
        earlyLeaveCentMinutes += _min(
          early * dayRate,
          dayPricedCentMinutes + overtimePay,
        );
      }
    }
  }

  final types = <ShiftTypeMonth>[
    for (final type in schedule.shiftTypes)
      if (tallies[type.id] case final t?)
        ShiftTypeMonth(
          type: type,
          days: t.days,
          count: t.count,
          paidMinutes: t.paidMinutes,
          nightMinutes: t.nightMinutes,
          earningsCents: t.priced ? (t.pricedCentMinutes + 30) ~/ 60 : null,
          unpricedMinutes: t.unpricedMinutes,
          nightPlusCents: (t.nightPlusCentMinutes + 30) ~/ 60,
          holidayPlusCents: (t.holidayPlusCentMinutes + 30) ~/ 60,
        ),
  ];
  int? earnings;
  var nightPlusCents = 0;
  var holidayPlusCents = 0;
  for (final t in types) {
    if (t.earningsCents != null) earnings = (earnings ?? 0) + t.earningsCents!;
    // The pluses of the types add up to the total, and the per-type earnings
    // cover the month except for the extras that belong to the day and not to
    // a type (overtime, early leave, extra amounts), added below.
    nightPlusCents += t.nightPlusCents;
    holidayPlusCents += t.holidayPlusCents;
  }
  final overtimeCents = (overtimeCentMinutes + 30) ~/ 60;
  final earlyLeaveCents = (earlyLeaveCentMinutes + 30) ~/ 60;
  if (overtimeCents != 0 || earlyLeaveCents != 0) {
    earnings = _max(0, (earnings ?? 0) + overtimeCents - earlyLeaveCents);
  }
  if (fixedPlusCount > 0) earnings = (earnings ?? 0) + fixedPlusCents;
  if (nightPlusCents > 0 || holidayPlusCents > 0) {
    earnings = (earnings ?? 0) + nightPlusCents + holidayPlusCents;
  }
  // The extra amounts of the days (P9): they can be negative (a deduction).
  if (extraAmountCents != 0) earnings = (earnings ?? 0) + extraAmountCents;

  return MonthSummary(
    month: first,
    types: types,
    shiftsWorked: shiftsWorked,
    workedDays: workedDays,
    workedMinutes: workedMinutes,
    nightMinutes: nightMinutes,
    restDays: restDays,
    absenceDays: absenceDays,
    holidayShifts: holidayShifts,
    holidayMinutes: holidayMinutes,
    earningsCents: earnings,
    shiftsWithoutTimes: shiftsWithoutTimes,
    overtimeMinutes: overtimeMinutes,
    earlyLeaveMinutes: earlyLeaveMinutes,
    overtimeCents: overtimeCents,
    earlyLeaveCents: earlyLeaveCents,
    extrasWithoutRateMinutes: extrasWithoutRate,
    fixedPlusCount: fixedPlusCount,
    fixedPlusCents: fixedPlusCents,
    nightPlusCents: nightPlusCents,
    holidayPlusCents: holidayPlusCents,
    extraAmountCents: extraAmountCents,
  );
}

/// Summarizes the month that contains [anyDay] for [schedule]
/// ([summarizeRange] over its first to its last day).
MonthSummary summarizeMonth(
  Schedule schedule,
  CivilDate anyDay, {
  Set<CivilDate> holidays = const {},
  NightWindow window = const NightWindow(),
  ClockCutoff? cutoff,
}) {
  final first = anyDay.firstDayOfMonth;
  return summarizeRange(
    schedule,
    first,
    first.lastDayOfMonth,
    holidays: holidays,
    window: window,
    cutoff: cutoff,
  );
}

int _min(int a, int b) => a < b ? a : b;
int _max(int a, int b) => a > b ? a : b;

/// The twelve months of a year and their sums.
class YearTotals {
  const YearTotals({required this.year, required this.months});

  final int year;

  /// January to December.
  final List<MonthSummary> months;

  int get shiftsWorked => _sum((m) => m.shiftsWorked);
  int get workedMinutes => _sum((m) => m.workedMinutes);
  int get nightMinutes => _sum((m) => m.nightMinutes);
  int get restDays => _sum((m) => m.restDays);
  int get absenceDays => _sum((m) => m.absenceDays);
  int get holidayMinutes => _sum((m) => m.holidayMinutes);
  int get overtimeMinutes => _sum((m) => m.overtimeMinutes);
  int get earlyLeaveMinutes => _sum((m) => m.earlyLeaveMinutes);
  bool get hasExtras => overtimeMinutes > 0 || earlyLeaveMinutes > 0;

  /// Money of the night pluses of the year (P9).
  int get nightPlusCents => _sum((m) => m.nightPlusCents);

  /// Money of the holiday pluses of the year (P9).
  int get holidayPlusCents => _sum((m) => m.holidayPlusCents);

  /// Extra money of the days of the year (P9).
  int get extraAmountCents => _sum((m) => m.extraAmountCents);

  /// `null` when no month has pay to show.
  int? get earningsCents {
    int? total;
    for (final m in months) {
      if (m.earningsCents != null) total = (total ?? 0) + m.earningsCents!;
    }
    return total;
  }

  bool get isEmpty => months.every((m) => m.isEmpty);

  int _sum(int Function(MonthSummary m) pick) =>
      months.fold(0, (sum, m) => sum + pick(m));
}

/// The twelve [summarizeMonth]s of [year].
YearTotals summarizeYearTotals(
  Schedule schedule,
  int year, {
  Set<CivilDate> holidays = const {},
  NightWindow window = const NightWindow(),
}) => YearTotals(
  year: year,
  months: [
    for (var m = 1; m <= 12; m++)
      summarizeMonth(
        schedule,
        CivilDate(year, m, 1),
        holidays: holidays,
        window: window,
      ),
  ],
);
