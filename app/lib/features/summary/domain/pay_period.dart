import '../../schedule/domain/schedule_domain.dart';
import 'summary_range.dart';

/// The «día de cierre» of the month (propuesta 8 de
/// `docs/competencia-2026-11.md`): the payroll month of many people is not
/// the calendar month. Who is paid «del 21 al 20» has a closing day of 20.
///
/// The closing day is the **last** day of the payroll month; the payroll
/// month is named after the month it **ends** in: with a closing day of 20,
/// «noviembre» is 21 October to 20 November. A closing day the month does not
/// have (30 in February) is its last day. No closing day (`null`) is the
/// calendar month, as before.
///
/// The summary of a month, its year table, the hours bag and «Llevas ganado»
/// use the payroll month; the free dates and the quarters stay as they are
/// (they are dates the user picks).

/// The lowest and highest closing day the app offers. 31 would be the
/// calendar month: that is no closing day.
const int minClosingDay = 1;
const int maxClosingDay = 30;

/// Whether [day] is a closing day the app stores.
bool isValidClosingDay(int day) => day >= minClosingDay && day <= maxClosingDay;

/// The closing day of [month] (its first day, or any day of it): [closingDay]
/// or, when the month is shorter, its last day.
CivilDate closingDateOf(CivilDate month, int closingDay) {
  final first = month.firstDayOfMonth;
  final day = closingDay < first.daysInMonth ? closingDay : first.daysInMonth;
  return CivilDate(first.year, first.month, day);
}

/// The payroll month named after [month] (any day of it): from the day after
/// the closing day of the month before to the closing day of [month], both
/// included. Without [closingDay] it is the calendar month.
SummaryRange payPeriodOf(CivilDate month, int? closingDay) {
  final first = month.firstDayOfMonth;
  if (closingDay == null) return SummaryRange.month(first);
  final previous = first.addDays(-1).firstDayOfMonth;
  return SummaryRange(
    closingDateOf(previous, closingDay).addDays(1),
    closingDateOf(first, closingDay),
  );
}

/// The payroll month [day] falls in, as the first day of the month it is
/// named after: with a closing day of 20, the 21st of October belongs to
/// November. Without [closingDay] it is the month of [day].
CivilDate payMonthOf(CivilDate day, int? closingDay) {
  final first = day.firstDayOfMonth;
  if (closingDay == null) return first;
  return day.isAfter(closingDateOf(first, closingDay))
      ? first.addDays(first.daysInMonth)
      : first;
}

/// The payroll year [year]: its twelve payroll months, from the day after the
/// closing day of the December before to the closing day of December.
/// Without [closingDay] it is the calendar year.
SummaryRange payYearOf(int year, int? closingDay) => SummaryRange(
  payPeriodOf(CivilDate(year, 1, 1), closingDay).from,
  payPeriodOf(CivilDate(year, 12, 1), closingDay).to,
);
