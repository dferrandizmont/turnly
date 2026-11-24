import '../../schedule/domain/schedule_domain.dart';
import 'month_summary.dart';

/// Where a period of the summary stands against today (A3).
enum PeriodTense {
  /// Every day is before today: its hours are worked.
  past,

  /// It starts before today and ends today or later: worked hours up to
  /// yesterday and planned hours from today on.
  current,

  /// It starts today or later: its hours are planned.
  future,
}

/// The tense of the days `[first, last]` on [today]. Today itself is not
/// worked yet: its shift may not have started or ended.
PeriodTense periodTense(CivilDate first, CivilDate last, CivilDate today) {
  if (last.isBefore(today)) return PeriodTense.past;
  if (first.isBefore(today)) return PeriodTense.current;
  return PeriodTense.future;
}

/// The hours of a period split at today (A3): [doneMinutes] are the days
/// before today ("trabajadas"), [plannedMinutes] today and the days after it
/// ("previstas"). Both are [MonthSummary.workedMinutes] of their days, so
/// overtime and early leave count, and they add up to the period's total.
class PeriodHours {
  const PeriodHours({
    required this.tense,
    required this.doneMinutes,
    required this.plannedMinutes,
  });

  final PeriodTense tense;
  final int doneMinutes;
  final int plannedMinutes;

  int get totalMinutes => doneMinutes + plannedMinutes;

  @override
  bool operator ==(Object other) =>
      other is PeriodHours &&
      other.tense == tense &&
      other.doneMinutes == doneMinutes &&
      other.plannedMinutes == plannedMinutes;

  @override
  int get hashCode => Object.hash(tense, doneMinutes, plannedMinutes);

  @override
  String toString() =>
      'PeriodHours($tense, done: $doneMinutes, planned: $plannedMinutes)';
}

/// [PeriodHours] of the days `[first, last]` of [schedule] on [today]. The
/// worked minutes of a period are the sum of its days' (each day's shifts
/// and extras belong to that day), so the split is two [summarizeRange]s.
/// Neither the holidays nor the night window change the hours. With
/// [forGoal] only the hours that count for the hours goal are counted: the
/// overtime types that do not count (schema v7) are left out.
PeriodHours splitPeriodHours(
  Schedule schedule,
  CivilDate first,
  CivilDate last,
  CivilDate today, {
  bool forGoal = false,
}) {
  int worked(CivilDate from, CivilDate to) {
    final summary = summarizeRange(schedule, from, to);
    return forGoal ? summary.goalCountedMinutes : summary.workedMinutes;
  }

  final tense = periodTense(first, last, today);
  return switch (tense) {
    PeriodTense.past => PeriodHours(
      tense: tense,
      doneMinutes: worked(first, last),
      plannedMinutes: 0,
    ),
    PeriodTense.future => PeriodHours(
      tense: tense,
      doneMinutes: 0,
      plannedMinutes: worked(first, last),
    ),
    PeriodTense.current => PeriodHours(
      tense: tense,
      doneMinutes: worked(first, today.addDays(-1)),
      plannedMinutes: worked(today, last),
    ),
  };
}

/// The shifts of a period split at today, like [PeriodHours]: [doneShifts]
/// and [doneDays] are those of the days before today ("trabajados"),
/// [plannedShifts] and [plannedDays] those of today and the days after it
/// ("previstos"). A shift counts on the day it starts, so the two parts add
/// up to [MonthSummary.shiftsWorked] and [MonthSummary.workedDays] of the
/// whole period.
class PeriodShifts {
  const PeriodShifts({
    required this.tense,
    required this.doneShifts,
    required this.doneDays,
    required this.plannedShifts,
    required this.plannedDays,
  });

  final PeriodTense tense;
  final int doneShifts;
  final int doneDays;
  final int plannedShifts;
  final int plannedDays;

  int get totalShifts => doneShifts + plannedShifts;

  @override
  bool operator ==(Object other) =>
      other is PeriodShifts &&
      other.tense == tense &&
      other.doneShifts == doneShifts &&
      other.doneDays == doneDays &&
      other.plannedShifts == plannedShifts &&
      other.plannedDays == plannedDays;

  @override
  int get hashCode =>
      Object.hash(tense, doneShifts, doneDays, plannedShifts, plannedDays);

  @override
  String toString() =>
      'PeriodShifts($tense, done: $doneShifts in $doneDays days, '
      'planned: $plannedShifts in $plannedDays days)';
}

/// [PeriodShifts] of the days `[first, last]` of [schedule] on [today]: the
/// same cut as [splitPeriodHours] (days before today are worked, today and
/// later are planned).
PeriodShifts splitPeriodShifts(
  Schedule schedule,
  CivilDate first,
  CivilDate last,
  CivilDate today,
) {
  (int, int) count(CivilDate from, CivilDate to) {
    final summary = summarizeRange(schedule, from, to);
    return (summary.shiftsWorked, summary.workedDays);
  }

  final tense = periodTense(first, last, today);
  final (doneShifts, doneDays) = switch (tense) {
    PeriodTense.past => count(first, last),
    PeriodTense.future => (0, 0),
    PeriodTense.current => count(first, today.addDays(-1)),
  };
  final (plannedShifts, plannedDays) = switch (tense) {
    PeriodTense.past => (0, 0),
    PeriodTense.future => count(first, last),
    PeriodTense.current => count(today, last),
  };
  return PeriodShifts(
    tense: tense,
    doneShifts: doneShifts,
    doneDays: doneDays,
    plannedShifts: plannedShifts,
    plannedDays: plannedDays,
  );
}

/// The shifts and the hours of a period split at today, together (the year
/// view shows both per month).
class PeriodSplit {
  const PeriodSplit({required this.shifts, required this.hours});

  final PeriodShifts shifts;
  final PeriodHours hours;

  @override
  bool operator ==(Object other) =>
      other is PeriodSplit && other.shifts == shifts && other.hours == hours;

  @override
  int get hashCode => Object.hash(shifts, hours);
}

/// [PeriodSplit] of the days `[first, last]` of [schedule] on [today].
PeriodSplit splitPeriod(
  Schedule schedule,
  CivilDate first,
  CivilDate last,
  CivilDate today,
) => PeriodSplit(
  shifts: splitPeriodShifts(schedule, first, last, today),
  hours: splitPeriodHours(schedule, first, last, today),
);

/// What a list of [PeriodSplit]s (the months of a year) adds up to: worked
/// before today and planned from today on.
class SplitTotals {
  SplitTotals(Iterable<PeriodSplit> splits)
    : doneShifts = splits.fold(0, (n, s) => n + s.shifts.doneShifts),
      plannedShifts = splits.fold(0, (n, s) => n + s.shifts.plannedShifts),
      doneMinutes = splits.fold(0, (n, s) => n + s.hours.doneMinutes),
      plannedMinutes = splits.fold(0, (n, s) => n + s.hours.plannedMinutes);

  final int doneShifts;
  final int plannedShifts;
  final int doneMinutes;
  final int plannedMinutes;

  bool get hasPlanned => plannedShifts > 0 || plannedMinutes > 0;
}
