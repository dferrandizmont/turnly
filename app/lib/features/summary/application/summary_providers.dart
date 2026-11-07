import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/providers.dart';
import '../../calendar/application/schedule_controller.dart';
import '../../holidays/application/holidays_provider.dart';
import '../../schedule/domain/schedule_domain.dart';
import '../../settings/application/preferences_controller.dart';
import '../data/hours_goal_store.dart';
import '../data/pay_rules_store.dart';
import '../domain/earned_so_far.dart';
import '../domain/hours_bag.dart';
import '../domain/hours_goal.dart';
import '../domain/month_summary.dart';
import '../domain/overtime_cap.dart';
import '../domain/pay_period.dart';
import '../domain/payroll.dart';
import '../domain/period_hours.dart';
import '../domain/summary_range.dart';

/// The holiday dates of the chosen place, as the summary needs them.
final summaryHolidaysProvider = Provider<Set<CivilDate>>(
  (ref) => ref.watch(holidaysProvider.select((h) => h.keys.toSet())),
);

/// Where the closing day and the cap of the overtime are kept (tests
/// override it).
final payRulesStoreProvider = Provider<PayRulesStore>(
  (ref) => PayRulesStore(ref.watch(appDatabaseProvider)),
);

/// The payroll rules (propuesta 8): the closing day of the month and the cap
/// of the overtime. Read again each time the summary opens (auto dispose), so
/// a restored backup shows its rules.
class PayRulesController extends AsyncNotifier<PayRules> {
  @override
  Future<PayRules> build() => ref.watch(payRulesStoreProvider).load();

  PayRules get _current => state.value ?? PayRules.none;

  /// Sets the closing day (`null` = the calendar month).
  Future<void> setClosingDay(int? day) async {
    await ref.read(payRulesStoreProvider).setClosingDay(day);
    state = AsyncData(
      PayRules(closingDay: day, overtimeCap: _current.overtimeCap),
    );
  }

  /// Sets the cap of the overtime (`null` removes it).
  Future<void> setOvertimeCap(OvertimeCap? cap) async {
    await ref.read(payRulesStoreProvider).setOvertimeCap(cap);
    state = AsyncData(
      PayRules(closingDay: _current.closingDay, overtimeCap: cap),
    );
  }
}

final payRulesProvider =
    AsyncNotifierProvider.autoDispose<PayRulesController, PayRules>(
      PayRulesController.new,
    );

/// The closing day of the month, `null` for the calendar month (also while
/// the rules are read).
final summaryClosingDayProvider = Provider.autoDispose<int?>(
  (ref) => ref.watch(payRulesProvider.select((r) => r.value?.closingDay)),
);

/// The days of the month (any day of it) the summary counts: the payroll
/// month with a closing day, the calendar month without one.
final summaryMonthRangeProvider = Provider.autoDispose
    .family<SummaryRange, CivilDate>(
      (ref, month) => payPeriodOf(month, ref.watch(summaryClosingDayProvider)),
    );

/// The summary of a month (first day of the month) of the ACTIVE calendar.
/// It follows the schedule and the holidays: painting a day or choosing
/// another calendar updates it. With a closing day it is the payroll month
/// named after that month.
final monthSummaryProvider = Provider.autoDispose
    .family<MonthSummary, CivilDate>((ref, month) {
      final schedule = ref.watch(
        scheduleControllerProvider.select((s) => s.schedule),
      );
      return summarizeMonth(
        schedule,
        month,
        holidays: ref.watch(summaryHolidaysProvider),
        closingDay: ref.watch(summaryClosingDayProvider),
      );
    });

/// The summary of any period of up to 366 days of the ACTIVE calendar
/// (`docs/paridad.md` A7): the same aggregate as [monthSummaryProvider].
final rangeSummaryProvider = Provider.autoDispose
    .family<MonthSummary, SummaryRange>((ref, range) {
      final schedule = ref.watch(
        scheduleControllerProvider.select((s) => s.schedule),
      );
      return summarizeRange(
        schedule,
        range.from,
        range.to,
        holidays: ref.watch(summaryHolidaysProvider),
      );
    });

/// The twelve months of a year of the ACTIVE calendar.
final yearTotalsProvider = Provider.autoDispose.family<YearTotals, int>((
  ref,
  year,
) {
  final schedule = ref.watch(
    scheduleControllerProvider.select((s) => s.schedule),
  );
  return summarizeYearTotals(
    schedule,
    year,
    holidays: ref.watch(summaryHolidaysProvider),
    closingDay: ref.watch(summaryClosingDayProvider),
  );
});

/// The overtime of the period against the cap, or `null` without a cap or
/// when the cap is not counted on such a period. [OvertimeCapQuery.month] is
/// the month on screen (a monthly cap counts its overtime, a yearly one the
/// overtime of its year); without it the query is a whole year (only a
/// yearly cap counts).
final overtimeCapStatusProvider = Provider.autoDispose
    .family<OvertimeCapStatus?, OvertimeCapQuery>((ref, query) {
      final cap = ref.watch(payRulesProvider.select((r) => r.value?.overtimeCap));
      if (cap == null) return null;
      final month = query.month;
      final int used;
      switch (cap.period) {
        case OvertimeCapPeriod.month:
          if (month == null) return null;
          used = ref.watch(monthSummaryProvider(month)).overtimeMinutes;
        case OvertimeCapPeriod.year:
          used = ref.watch(yearTotalsProvider(query.year)).overtimeMinutes;
      }
      return OvertimeCapStatus(cap: cap, usedMinutes: used);
    });

/// What [overtimeCapStatusProvider] is asked for: a month (its first day) or
/// a whole [year].
class OvertimeCapQuery {
  OvertimeCapQuery.month(CivilDate this.month) : year = month.year;
  const OvertimeCapQuery.year(this.year) : month = null;

  final CivilDate? month;
  final int year;

  @override
  bool operator ==(Object other) =>
      other is OvertimeCapQuery && other.month == month && other.year == year;

  @override
  int get hashCode => Object.hash(month, year);
}

/// Today for the summary (A3), from [minuteClockProvider]: it changes only
/// when the day does, so the summary follows midnight without rebuilding
/// every minute.
final summaryTodayProvider = Provider<CivilDate>(
  (ref) => ref.watch(
    minuteClockProvider.select((now) => CivilDate.fromDateTime(now)),
  ),
);

/// The hours of a period of the ACTIVE calendar split at today (A3): worked
/// up to yesterday, planned from today on.
final periodHoursProvider = Provider.autoDispose
    .family<PeriodHours, SummaryRange>((ref, range) {
      final schedule = ref.watch(
        scheduleControllerProvider.select((s) => s.schedule),
      );
      return splitPeriodHours(
        schedule,
        range.from,
        range.to,
        ref.watch(summaryTodayProvider),
      );
    });

/// Where the hours goal is kept (tests override it).
final hoursGoalStoreProvider = Provider<HoursGoalStore>(
  (ref) => HoursGoalStore(ref.watch(appDatabaseProvider)),
);

/// The day the hours goal was first set (where the hours bag starts), or
/// `null` when it is not known.
final hoursGoalSinceProvider = FutureProvider.autoDispose<CivilDate?>(
  (ref) => ref.watch(hoursGoalStoreProvider).loadSince(),
);

/// The user's hours goal (C2), `null` without one. Read again each time the
/// summary opens (auto dispose), so a restored backup shows its goal.
class HoursGoalController extends AsyncNotifier<HoursGoal?> {
  @override
  Future<HoursGoal?> build() => ref.watch(hoursGoalStoreProvider).load();

  /// Saves [goal]; the summary shows it at once. The day it is set for the
  /// first time is remembered: the hours bag starts there, so an old note or a
  /// rotation set up years ago does not count as debt.
  Future<void> set(HoursGoal goal) async {
    final store = ref.read(hoursGoalStoreProvider);
    final firstTime = await store.load() == null;
    await store.save(goal);
    if (firstTime) {
      await store.saveSince(CivilDate.fromDateTime(ref.read(clockProvider)()));
      ref.invalidate(hoursGoalSinceProvider);
    }
    state = AsyncData(goal);
  }

  /// Removes the goal.
  Future<void> clear() async {
    await ref.read(hoursGoalStoreProvider).clear();
    ref.invalidate(hoursGoalSinceProvider);
    state = const AsyncData(null);
  }
}

final hoursGoalProvider =
    AsyncNotifierProvider.autoDispose<HoursGoalController, HoursGoal?>(
      HoursGoalController.new,
    );

/// The percentage of the withholding of the estimated pay (P9): 0 when the
/// user has not set one.
final withholdingPercentProvider = Provider<int>(
  (ref) => ref.watch(preferencesProvider.select((p) => p.withholdingPercent)),
);

/// What a month is worth, before and after the withholding (P9).
///
/// It follows the summary, the holidays and the preference: painting a day,
/// changing the place or the withholding updates it.
final monthEarningsProvider = Provider.autoDispose
    .family<EarningsEstimate, CivilDate>((ref, month) {
      final summary = ref.watch(monthSummaryProvider(month));
      return earningsEstimate(
        summary.earningsCents,
        withholdingPercent: ref.watch(withholdingPercentProvider),
      );
    });

/// What the user has earned so far this month (P9): the gross and the net of
/// the days that have passed and the part of today already worked.
///
/// It follows the clock: the estimate grows as the hours are worked.
final earnedSoFarProvider = Provider.autoDispose.family<EarnedSoFar, CivilDate>(
  (ref, month) {
    final schedule = ref.watch(
      scheduleControllerProvider.select((s) => s.schedule),
    );
    final now = ref.watch(minuteClockProvider);
    return earnedSoFar(
      schedule,
      month,
      today: CivilDate.fromDateTime(now),
      nowMinuteOfDay: now.hour * 60 + now.minute,
      withholdingPercent: ref.watch(withholdingPercentProvider),
      holidays: ref.watch(summaryHolidaysProvider),
      closingDay: ref.watch(summaryClosingDayProvider),
    );
  },
);

/// The balance of the hours bag at the end of a month (P9): the hours worked
/// minus the goal, accumulated month by month, with the balance of December
/// carried over to January.
///
/// `null` when the user has no hours goal.
final hoursBalanceProvider = Provider.autoDispose
    .family<AsyncValue<HoursBalance?>, CivilDate>((ref, month) {
      final schedule = ref.watch(
        scheduleControllerProvider.select((s) => s.schedule),
      );
      final holidays = ref.watch(summaryHolidaysProvider);
      final goal = ref.watch(hoursGoalProvider);
      final since = ref.watch(hoursGoalSinceProvider);
      final closingDay = ref.watch(summaryClosingDayProvider);
      return goal.when(
        loading: () => const AsyncLoading(),
        error: (error, stack) => AsyncError(error, stack),
        data: (value) => since.when(
          loading: () => const AsyncLoading(),
          error: (error, stack) => AsyncError(error, stack),
          data: (sinceDate) {
            if (value == null) return const AsyncData(null);
            // The bag starts the day the goal was set (or, without that date,
            // the first month with worked minutes or a rotation) and walks
            // every month up to this one, so the balance of December carries
            // over to January on its own.
            final target = month.firstDayOfMonth;
            final first = sinceDate ?? firstMonthWithData(schedule);
            final from = first == null || first.isAfter(target)
                ? target
                : first.firstDayOfMonth;
            return AsyncData(
              hoursBalance(
                schedule,
                value,
                fromMonth: from,
                toMonth: target,
                holidays: holidays,
                closingDay: closingDay,
              ),
            );
          },
        ),
      );
    });
