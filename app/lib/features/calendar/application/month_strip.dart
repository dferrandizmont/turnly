import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../schedule/domain/schedule_domain.dart';
import '../../summary/application/summary_providers.dart';
import '../../summary/domain/hours_goal.dart';
import '../../summary/domain/month_summary.dart';
import '../../summary/domain/pay_period.dart';
import '../../summary/domain/period_hours.dart';
import 'off_outlook.dart';
import 'schedule_controller.dart';
import 'today_status.dart';

/// The day off the strip under the month names.
class MonthStripOff {
  const MonthStripOff({
    required this.date,
    this.daysAway,
    this.inferred = false,
  });

  final CivilDate date;

  /// Days from today (0 = today) in the current month: «Próximo libre».
  /// `null` in a month to come: the first day off of that month.
  final int? daysAway;
  final bool inferred;

  @override
  bool operator ==(Object other) =>
      other is MonthStripOff &&
      other.date == date &&
      other.daysAway == daysAway &&
      other.inferred == inferred;

  @override
  int get hashCode => Object.hash(date, daysAway, inferred);

  @override
  String toString() => 'MonthStripOff($date, $daysAway)';
}

/// The day off of [month] (its first day) for the strip, with the rules of
/// [computeOffOutlook] (a day with nothing annotated only counts between
/// annotated days):
///
/// - the month of [today]: the next day off from today, today included (it
///   may fall in the following month);
/// - a month to come: its first day off, or `null` when it has none;
/// - a month gone by: `null`.
MonthStripOff? monthStripOff(
  Schedule schedule,
  CivilDate month,
  CivilDate today,
) {
  final first = month.firstDayOfMonth;
  final current = today.firstDayOfMonth;
  if (first == current) {
    final next = computeOffOutlook(schedule, today).nextOff;
    return next == null
        ? null
        : MonthStripOff(
            date: next.date,
            daysAway: next.daysAway,
            inferred: next.inferred,
          );
  }
  if (first.isBefore(current)) return null;
  final next = computeOffOutlook(schedule, first, lookBack: 0).nextOff;
  if (next == null || next.date.firstDayOfMonth != first) return null;
  return MonthStripOff(date: next.date, inferred: next.inferred);
}

/// The three facts of the strip under the month (`docs/diseno.md`, «Tira del
/// mes»), with the same numbers as the summary it opens.
class MonthStripData {
  const MonthStripData({
    required this.shifts,
    required this.workedMinutes,
    this.goal,
    this.off,
  });

  /// Shifts worked in the month (`MonthSummary.shiftsWorked`).
  final int shifts;

  /// Hours of the month, worked and planned (`MonthSummary.workedMinutes`).
  final int workedMinutes;

  /// The hours against the hours goal, when there is one: the hours that
  /// count for it, the goal of the month and what is missing or left over.
  final GoalProgress? goal;

  final MonthStripOff? off;

  @override
  bool operator ==(Object other) =>
      other is MonthStripData &&
      other.shifts == shifts &&
      other.workedMinutes == workedMinutes &&
      other.goal?.targetMinutes == goal?.targetMinutes &&
      other.goal?.hours == goal?.hours &&
      other.off == off;

  @override
  int get hashCode =>
      Object.hash(shifts, workedMinutes, goal?.targetMinutes, goal?.hours, off);
}

/// [MonthStripData] of a month (its first day) of the ACTIVE calendar. The
/// shifts and the hours are those of the summary of that month (the payroll
/// month when there is a closing day) and the goal is shared out like there
/// (`summarizeMonth`, `splitPeriodHours`, `goalMinutesForMonth`). While the
/// goal and the closing day are being read, or if reading them fails, the
/// strip shows the calendar month without a goal.
final monthStripProvider = Provider.autoDispose
    .family<MonthStripData, CivilDate>((ref, month) {
      final schedule = ref.watch(
        scheduleControllerProvider.select((s) => s.schedule),
      );
      final today = ref.watch(summaryTodayProvider);
      final goal = ref.watch(monthStripGoalProvider).value;
      final closingDay = ref.watch(monthStripClosingDayProvider).value;
      final summary = summarizeMonth(
        schedule,
        month,
        holidays: ref.watch(summaryHolidaysProvider),
        closingDay: closingDay,
      );
      final period = payPeriodOf(month, closingDay);
      final off = month.firstDayOfMonth == today.firstDayOfMonth
          ? switch (ref.watch(offOutlookProvider).nextOff) {
              final next?
                  when !ref.watch(
                    todayStatusProvider.select(
                      (status) => status.activeShiftOverlaps(next.date),
                    ),
                  ) =>
                MonthStripOff(
                  date: next.date,
                  daysAway: next.daysAway,
                  inferred: next.inferred,
                ),
              _ => null,
            }
          : monthStripOff(schedule, month, today);
      return MonthStripData(
        shifts: summary.shiftsWorked,
        workedMinutes: summary.workedMinutes,
        goal: goal == null
            ? null
            : GoalProgress(
                targetMinutes: goalMinutesForMonth(goal),
                hours: splitPeriodHours(
                  schedule,
                  period.from,
                  period.to,
                  today,
                  forGoal: true,
                ),
              ),
        off: off,
      );
    });
