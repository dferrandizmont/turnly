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
/// Neither the holidays nor the night window change the hours.
PeriodHours splitPeriodHours(
  Schedule schedule,
  CivilDate first,
  CivilDate last,
  CivilDate today,
) {
  int worked(CivilDate from, CivilDate to) =>
      summarizeRange(schedule, from, to).workedMinutes;
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
