import '../../schedule/domain/schedule_domain.dart';
import 'hours_goal.dart';
import 'month_summary.dart';

/// The **hours bag** (P9, fila 24 de `docs/paridad-pago.md`): the balance
/// between the hours worked and the goal ([HoursGoal]), accumulated month by
/// month.
///
/// The bag never resets: the balance of December carries over to January of
/// the next year, so a year with more hours than the goal leaves the surplus
/// for the next one.
class HoursBalance {
  const HoursBalance({
    required this.fromMonth,
    required this.toMonth,
    required this.workedMinutes,
    required this.goalMinutes,
    required this.carryInMinutes,
  });

  /// The first month of the bag (its first day).
  final CivilDate fromMonth;

  /// The month the balance is at (its first day).
  final CivilDate toMonth;

  /// The hours worked in the months of the bag (from [fromMonth] to
  /// [toMonth], both included).
  final int workedMinutes;

  /// The goal of those months.
  final int goalMinutes;

  /// The balance the bag had before [fromMonth]: the carry-over (the balance
  /// of the previous December, when the bag goes on from a previous year).
  final int carryInMinutes;

  /// The balance at the end of [toMonth]: positive = more hours than the
  /// goal, negative = fewer.
  int get balanceMinutes => carryInMinutes + workedMinutes - goalMinutes;

  /// Whether the bag is in favour.
  bool get isOver => balanceMinutes > 0;

  @override
  bool operator ==(Object other) =>
      other is HoursBalance &&
      other.fromMonth == fromMonth &&
      other.toMonth == toMonth &&
      other.workedMinutes == workedMinutes &&
      other.goalMinutes == goalMinutes &&
      other.carryInMinutes == carryInMinutes;

  @override
  int get hashCode => Object.hash(
    fromMonth,
    toMonth,
    workedMinutes,
    goalMinutes,
    carryInMinutes,
  );

  @override
  String toString() =>
      'HoursBalance(${fromMonth.toIso()} .. ${toMonth.toIso()}, '
      '$workedMinutes worked, $goalMinutes goal, $carryInMinutes carried)';
}

/// The goal of the month [month] (its first day) for [goal].
///
/// A monthly goal is the same every month. A yearly one is a twelfth of it,
/// with the remainder of the year (if there is one) in December, so the twelve
/// months of a year add up to the yearly goal exactly. The minutes of a
/// yearly goal are a multiple of twelve (an hour is sixty minutes), so in
/// practice every month takes exactly the same.
int goalMinutesForMonthOf(HoursGoal goal, CivilDate month) {
  if (goal.period == HoursGoalPeriod.month) return goalMinutesForMonth(goal);
  final perMonth = goalMinutesForMonth(goal);
  if (month.month != 12) return perMonth;
  return goal.yearMinutes - perMonth * 11;
}

/// The first month with something **worked** in [schedule]: the first month
/// with a work shift (a day with a rotation counts, a note-only, absence-only
/// or rest-only day does **not**) or with overtime noted by hand, or `null`
/// when the schedule is empty. Where the hours bag starts when the goal was
/// set before the app recorded the date.
CivilDate? firstMonthWithData(Schedule schedule) {
  CivilDate? first;
  void take(CivilDate date) {
    final current = first;
    if (current == null || date.isBefore(current)) first = date;
  }

  for (final run in schedule.runs) {
    take(run.startDate);
  }
  for (final date in schedule.entries.keys) {
    if (_hasWorkedMinutes(schedule, date)) take(date);
  }
  final earliest = first;
  return earliest?.firstDayOfMonth;
}

/// Whether [date] holds worked minutes: a work shift with a schedule, or
/// overtime noted by hand. A note-only, absence-only or rest-only day counts
/// nothing, so an old note does not drag the hours bag back years.
bool _hasWorkedMinutes(Schedule schedule, CivilDate date) {
  final day = schedule.resolve(date);
  if (day.overtimeMinutes > 0) return true;
  for (final shift in day.shifts) {
    if (shift.category == ShiftCategory.work && shift.hasTimes) return true;
  }
  return false;
}

/// The balance of the hours bag at the end of [toMonth].
///
/// The bag walks the months from [fromMonth] to [toMonth] (both included,
/// the first days of the months) and adds up the hours worked minus the goal
/// of each month. [carryInMinutes] is the balance the bag had before
/// [fromMonth] (the carry-over of the previous year).
///
/// [holidays] are the holiday dates of the user's place and [window] is the
/// night window, as in [summarizeMonth]. With a [closingDay] each month is
/// its payroll month.
HoursBalance hoursBalance(
  Schedule schedule,
  HoursGoal goal, {
  required CivilDate fromMonth,
  required CivilDate toMonth,
  int carryInMinutes = 0,
  Set<CivilDate> holidays = const {},
  NightWindow window = const NightWindow(),
  int? closingDay,
}) {
  var worked = 0;
  var target = 0;
  var month = fromMonth.firstDayOfMonth;
  final end = toMonth.firstDayOfMonth;
  while (!month.isAfter(end)) {
    worked += summarizeMonth(
      schedule,
      month,
      holidays: holidays,
      window: window,
      closingDay: closingDay,
    ).workedMinutes;
    target += goalMinutesForMonthOf(goal, month);
    month = month.addDays(month.daysInMonth);
  }
  return HoursBalance(
    fromMonth: fromMonth.firstDayOfMonth,
    toMonth: end,
    workedMinutes: worked,
    goalMinutes: target,
    carryInMinutes: carryInMinutes,
  );
}
