import '../../schedule/domain/schedule_domain.dart';
import 'month_summary.dart';
import 'pay_period.dart';
import 'payroll.dart';

/// What the user has earned so far this month (P9, fila 25 de
/// `docs/paridad-pago.md`): the gross and the net of the days that have
/// passed plus the part of today already worked.
///
/// The hours are the ones of [MonthSummary] with the counting stopped at
/// [nowMinuteOfDay] of [today] ([ClockCutoff]): a shift that is still running
/// only counts the minutes it has been worked, and the extras of today (the
/// overtime and the early leave) only count when its shift has already
/// ended.
class EarnedSoFar {
  const EarnedSoFar({
    required this.month,
    required this.grossCents,
    required this.netCents,
    required this.workedMinutes,
    required this.nightMinutes,
    required this.withholdingPercent,
  });

  /// The first day of the month.
  final CivilDate month;

  /// The money earned so far, before the withholding; `null` when there is
  /// nothing to show.
  final int? grossCents;

  /// The money earned so far, after the withholding; `null` without a gross.
  final int? netCents;

  /// The hours worked so far (the days that passed and the part of today
  /// already worked).
  final int workedMinutes;

  /// The night hours worked so far.
  final int nightMinutes;

  /// The percentage of the withholding (0 = none).
  final int withholdingPercent;

  /// Whether there is something to show.
  bool get hasMoney => grossCents != null;

  /// The estimate as a value the screen can show.
  EarningsEstimate get estimate => EarningsEstimate(
    grossCents: grossCents,
    withholdingPercent: withholdingPercent,
  );

  @override
  String toString() =>
      'EarnedSoFar(${month.toIso()}, ${grossCents ?? '-'} gross)';
}

/// What [schedule] has earned in [month] up to [today] at
/// [nowMinuteOfDay] (the minute of the day, 0-1439).
///
/// The month is counted whole when [today] is past it (the whole month has
/// been worked) and empty when [today] is before it. The withholding of
/// [withholdingPercent] gives the net.
///
/// [holidays] are the holiday dates of the user's place and [window] is the
/// night window, as in [summarizeMonth]. With a [closingDay] the month is
/// the payroll month named after [month].
EarnedSoFar earnedSoFar(
  Schedule schedule,
  CivilDate month, {
  required CivilDate today,
  required int nowMinuteOfDay,
  int withholdingPercent = 0,
  Set<CivilDate> holidays = const {},
  NightWindow window = const NightWindow(),
  int? closingDay,
}) {
  final period = payPeriodOf(month, closingDay);
  final first = period.from;
  final last = period.to;
  // Only the days up to today: the future of the month is not money yet.
  final end = today.isAfter(last) ? last : today;
  final summary = summarizeRange(
    schedule,
    first,
    end,
    holidays: holidays,
    window: window,
    cutoff: ClockCutoff(today, nowMinuteOfDay),
  );
  final gross = summary.earningsCents;
  return EarnedSoFar(
    month: month.firstDayOfMonth,
    grossCents: gross,
    netCents: gross == null ? null : netCentsFrom(gross, withholdingPercent),
    workedMinutes: summary.workedMinutes,
    nightMinutes: summary.nightMinutes,
    withholdingPercent: withholdingPercent,
  );
}
