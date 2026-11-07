import 'dart:math';

import '../../schedule/domain/schedule_domain.dart';
import 'absence_balance.dart';
import 'absence_status.dart';

/// What is left of the absence balances of a calendar (P3).
///
/// Pure Dart over the stored balances and the days of the calendar:
///
/// * **Used** is never stored (docs/datos.md, «Saldos de ausencias»): it is
///   counted here from the days of the period that carry one of the types of
///   the balance (`shift_type_quarters`), and only the types of the
///   **absence** category count (a work or rest type mapped by mistake does
///   not consume the balance). A balance counted in working days
///   ([AbsenceBalance.workingDaysOnly]) only counts the days that are Monday
///   to Friday and not one of [AbsenceBalanceCalculator.holidays].
/// * **Carried** are the days left of the same series in the year before
///   (the row says whether they are carried and with what cap); the chain is
///   followed year by year (what was left in 2026 and carried into 2027 can
///   be left in 2027 and carried into 2028).
/// * **Left** is what there is minus what is used: the allowed days, the
///   carried ones still in force and the manual adjustments.
///
/// The days carried from the year before are used **first** (they are the ones
/// that expire), and the days of this year after them: what is left of the
/// carried amount on its expiry date is what is lost.
class AbsenceBalanceCalculator {
  AbsenceBalanceCalculator({
    required Iterable<AbsenceBalance> balances,
    required this.schedules,
    required this.primaryCalendarId,
    required this.today,
    this.carryOverExpiry = const {},
    this.holidays = const {},
  }) : _balances = List.unmodifiable(balances) {
    for (final balance in _balances) {
      _byKey[_keyOf(balance)] = balance;
    }
  }

  final List<AbsenceBalance> _balances;

  /// The schedules of the calendars, by calendar id.
  final Map<String, Schedule> schedules;

  /// The calendar the balances without one count (rows written before v6).
  final String primaryCalendarId;

  /// Today, the day the used days are split at.
  final CivilDate today;

  /// The day the carried days expire, by key ([absenceCarryOverExpiryKey]).
  final Map<String, CivilDate> carryOverExpiry;

  /// The holidays of the place: a balance counted in working days does not
  /// spend a day on them.
  final Set<CivilDate> holidays;

  /// The balances by year, series and calendar.
  final Map<(int, String, String), AbsenceBalance> _byKey = {};

  /// The states already computed (the carry-over chain asks for the years
  /// before).
  final Map<AbsenceBalance, AbsenceBalanceStatus> _computed = {};

  /// The state of every balance of [year], in the order the balances came.
  List<AbsenceBalanceStatus> statusesOf(int year) => [
    for (final balance in _balances)
      if (balance.year == year) statusOf(balance),
  ];

  /// The state of every balance of [year] of one calendar.
  List<AbsenceBalanceStatus> statusesOfCalendar(int year, String calendarId) =>
      [
        for (final balance in _balances)
          if (balance.year == year && calendarIdOf(balance) == calendarId)
            statusOf(balance),
      ];

  /// The state of one balance.
  AbsenceBalanceStatus statusOf(AbsenceBalance balance) =>
      _computed[balance] ??= _compute(balance);

  /// The calendar whose days count for [balance]: the one of the row, or the
  /// primary calendar when the row has none (rows written before v6).
  String calendarIdOf(AbsenceBalance balance) =>
      balance.calendarId ?? primaryCalendarId;

  (int, String, String) _keyOf(AbsenceBalance balance) =>
      (balance.year, balance.type, calendarIdOf(balance));

  AbsenceBalanceStatus _compute(AbsenceBalance balance) {
    final usage = _usageOf(balance);
    final carried = _carriedInto(balance);
    final expiry = _expiryOf(balance);
    // The carried days are used first (they are the ones that expire): what
    // is left of them is what would be lost.
    final carriedLeft = max(0.0, carried - usage.total);
    // Only the carried days that were still unused on the expiry date are
    // lost; the usage up to that date counts, and, since the carried ones go
    // first, it spends them first.
    final expired = expiry != null && expiry.isBefore(today)
        ? max(0.0, carried - _usageOf(balance, until: expiry).total)
        : 0.0;
    final available =
        balance.allowedDays + (carried - expired) + balance.adjustmentDays;
    final leftBeforePlanning = available - usage.enjoyed;

    return AbsenceBalanceStatus(
      balance: balance,
      calendarId: calendarIdOf(balance),
      allowedDays: balance.allowedDays,
      carriedDays: carried,
      expiredDays: expired,
      adjustmentDays: balance.adjustmentDays,
      usedDays: usage.total,
      enjoyedDays: usage.enjoyed,
      plannedDays: usage.planned,
      carriedLeftDays: carriedLeft,
      carryOverExpiry: expiry,
      warnings: [
        if (expiry != null && !expiry.isBefore(today) && carriedLeft > 0)
          CarryOverExpiring(days: carriedLeft, expiryDate: expiry),
        if (usage.planned > leftBeforePlanning)
          PlannedExceedsAvailable(
            plannedDays: usage.planned,
            leftDays: leftBeforePlanning,
          ),
      ],
    );
  }

  /// The days of the period used by [balance]: the days that carry one of
  /// its types, split at today (the ones before are enjoyed, the others
  /// planned). With [until] only the days up to that date (both included)
  /// count, to know how much of the carried amount was still unused when it
  /// expired.
  _AbsenceUsage _usageOf(AbsenceBalance balance, {CivilDate? until}) {
    final quarters = balance.shiftTypeQuarters;
    if (quarters.isEmpty) return _AbsenceUsage.none;
    final schedule = schedules[calendarIdOf(balance)];
    if (schedule == null) return _AbsenceUsage.none;

    var enjoyed = 0.0;
    var planned = 0.0;
    for (final day in schedule.resolveRange(balance.start, balance.end)) {
      if (until != null && day.date.isAfter(until)) continue;
      if (balance.workingDaysOnly && !isWorkingDay(day.date, holidays)) {
        continue;
      }
      var dayQuarters = 0;
      for (final shift in day.shifts) {
        // Only the types of the absence category count.
        if (shift.category != ShiftCategory.absence) continue;
        final quartersOfType = quarters[shift.id];
        if (quartersOfType != null) dayQuarters += quartersOfType;
      }
      if (dayQuarters == 0) continue;
      // Two absences of the same series on one day are one day at most.
      final days = min(dayQuarters, 4) / 4;
      if (day.date.isBefore(today)) {
        enjoyed += days;
      } else {
        planned += days;
      }
    }
    return _AbsenceUsage(enjoyed: enjoyed, planned: planned);
  }

  /// The days carried into [balance] from the year before: what was left of
  /// the same series of the same calendar, with the cap of the row.
  double _carriedInto(AbsenceBalance balance) {
    if (!balance.carryOver) return 0;
    final key = (balance.year - 1, balance.type, calendarIdOf(balance));
    final previous = _byKey[key];
    if (previous == null) return 0;
    final leftover = statusOf(previous).remainingDays;
    if (leftover <= 0) return 0;
    final cap = balance.carryOverMaxDays;
    return cap == null ? leftover : min(leftover, cap);
  }

  /// The day the days carried into [balance] expire, when there is one.
  CivilDate? _expiryOf(AbsenceBalance balance) {
    final calendarId = calendarIdOf(balance);
    return carryOverExpiry[absenceCarryOverExpiryKey(
          balance.year,
          balance.type,
          calendarId,
        )] ??
        // Rows written before v6 kept the key without the calendar.
        carryOverExpiry[absenceCarryOverExpiryKey(balance.year, balance.type)];
  }
}

/// The days used by a balance, split at today.
class _AbsenceUsage {
  const _AbsenceUsage({required this.enjoyed, required this.planned});

  static const none = _AbsenceUsage(enjoyed: 0, planned: 0);

  /// The days used before today.
  final double enjoyed;

  /// The days used today and after.
  final double planned;

  /// All of them.
  double get total => enjoyed + planned;
}
