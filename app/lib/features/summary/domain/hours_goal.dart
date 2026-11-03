import '../../schedule/domain/schedule_domain.dart';
import 'period_hours.dart';

/// What the hours goal is counted against (C2).
enum HoursGoalPeriod {
  /// Hours per year: the "jornada anual" of an agreement (e.g. 1642 h).
  year('year'),

  /// Hours per month.
  month('month');

  const HoursGoalPeriod(this.stored);

  /// The value written in the settings table.
  final String stored;

  /// The most hours the goal accepts: every hour of a leap year, or of a
  /// 31-day month.
  int get maxHours => this == year ? 366 * 24 : 31 * 24;

  static HoursGoalPeriod? fromStored(Object? value) {
    for (final period in values) {
      if (period.stored == value) return period;
    }
    return null;
  }
}

/// The user's optional hours goal (C2): whole [hours] per [period]. Turned
/// into the period on screen by [goalMinutesForMonth], [goalMinutesForYear]
/// and [goalMinutesForRange]:
///
/// * a **month** takes a monthly goal as it is and a twelfth of a yearly one
///   (1642 h a year: 136 h 50 min a month);
/// * a **year** takes a yearly goal as it is and twelve times a monthly one;
/// * a **free range** takes the yearly goal (or twelve times the monthly
///   one) in proportion to its days, each day a 365th (366th in a leap year)
///   of its own year, so a whole calendar year as a range gives the yearly
///   goal exactly.
///
/// Rounded once, to the minute (half up).
class HoursGoal {
  const HoursGoal(this.period, this.hours);

  final HoursGoalPeriod period;
  final int hours;

  bool get isValid => hours >= 1 && hours <= period.maxHours;

  /// The goal of a whole year, in minutes.
  int get yearMinutes =>
      period == HoursGoalPeriod.year ? hours * 60 : hours * 60 * 12;

  Map<String, Object> toJson() => {'period': period.stored, 'hours': hours};

  /// `null` for anything that is not a valid goal: a bad value never blocks
  /// the summary, it just shows no goal.
  static HoursGoal? fromJson(Object? json) {
    if (json is! Map) return null;
    final period = HoursGoalPeriod.fromStored(json['period']);
    final hours = json['hours'];
    if (period == null || hours is! int) return null;
    final goal = HoursGoal(period, hours);
    return goal.isValid ? goal : null;
  }

  @override
  bool operator ==(Object other) =>
      other is HoursGoal && other.period == period && other.hours == hours;

  @override
  int get hashCode => Object.hash(period, hours);

  @override
  String toString() => 'HoursGoal(${period.stored}, $hours h)';
}

/// The goal of one calendar month, in minutes.
int goalMinutesForMonth(HoursGoal goal) => goal.period == HoursGoalPeriod.month
    ? goal.hours * 60
    : (goal.yearMinutes + 6) ~/ 12;

/// The goal of one calendar year, in minutes.
int goalMinutesForYear(HoursGoal goal) => goal.yearMinutes;

/// The goal of the days `[from, to]` (both included), in minutes: the
/// yearly goal in proportion to the days, each day weighed by the length of
/// its own year.
int goalMinutesForRange(HoursGoal goal, CivilDate from, CivilDate to) {
  if (to.isBefore(from)) return 0;
  var total = 0.0;
  var year = from.year;
  var start = from;
  while (true) {
    final yearEnd = CivilDate(year, 12, 31);
    final end = to.isBefore(yearEnd) ? to : yearEnd;
    final days = end.differenceInDays(start) + 1;
    total += goal.yearMinutes * days / _daysInYear(year);
    if (end == to) break;
    year++;
    start = CivilDate(year, 1, 1);
  }
  return total.round();
}

int _daysInYear(int year) =>
    CivilDate(year, 12, 31).differenceInDays(CivilDate(year, 1, 1)) + 1;

/// The goal of a period next to its hours (C2): [differenceMinutes] is the
/// worked plus the planned hours minus the goal, so it is "te faltan" when
/// negative and "de más" when positive. In a period that has not ended the
/// planned hours count: it is where the schedule leaves you.
class GoalProgress {
  const GoalProgress({required this.targetMinutes, required this.hours});

  final int targetMinutes;
  final PeriodHours hours;

  int get doneMinutes => hours.doneMinutes;
  int get plannedMinutes => hours.plannedMinutes;
  int get differenceMinutes => hours.totalMinutes - targetMinutes;

  /// The difference relies on planned hours (the period has not ended).
  bool get includesPlanned => hours.tense != PeriodTense.past;
}
