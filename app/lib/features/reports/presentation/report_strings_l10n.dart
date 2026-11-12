import 'package:intl/intl.dart';

import '../../../core/format/app_date_format.dart';
import '../../../core/format/money.dart';
import '../../../core/l10n/l10n.dart';
import '../../summary/presentation/summary_format.dart';
import '../domain/report_strings.dart';

/// The texts and formats of a report, from the ARB files and the formats of
/// the app: [localeName] is the language with the region of the phone,
/// [currency] the ISO code chosen in Ajustes and [hour12] the clock.
///
/// [colExtra] and [extrasAmount] are the texts of the extra money of the day
/// (P9, fila 26: the column of the CSV and the line of the PDF totals). The
/// wave 3 of the logic does not add texts to the ARB files, so they come
/// from the screen that shows the report; without them the CSV has no
/// column and the PDF no line (the money is in the estimate either way).
ReportStrings reportStringsFor(
  AppLocalizations l10n, {
  required String localeName,
  required String currency,
  required bool hour12,
  String? colExtra,
  String? extrasAmount,
}) {
  final format = AppDateFormat(localeName, hour12);
  DateTime day(int year, int month, int d) => DateTime(year, month, d);
  // 2026-10-19 was a Monday: a date for each ISO weekday.
  DateTime weekday(int isoWeekday) => DateTime(2026, 10, 18 + isoWeekday);

  String decimalMark;
  try {
    decimalMark = NumberFormat.decimalPattern(localeName).symbols.DECIMAL_SEP;
  } catch (_) {
    decimalMark = '.';
  }
  final separators = csvSeparatorsFor(decimalMark);

  return ReportStrings(
    localeName: localeName,
    hour12: hour12,
    reportTitleFallback: l10n.reportUntitled,
    legendTitle: l10n.reportLegendTitle,
    totalsTitle: l10n.reportTotalsTitle,
    notesTitle: l10n.reportNotesTitle,
    holidaysTitle: l10n.reportHolidaysTitle,
    holidayMark: l10n.reportHolidayMark,
    absenceName: l10n.reportAbsenceName,
    absenceCode: l10n.reportAbsenceCode,
    hoursTotal: l10n.reportHoursTotal,
    hoursWorked: l10n.summaryHoursWorked,
    hoursPlanned: l10n.summaryHoursPlanned,
    hoursDone: l10n.reportHoursDone,
    hoursPlannedFrom: l10n.reportHoursPlannedFrom,
    shiftsWorked: l10n.summaryShiftsWorked,
    nightHours: l10n.summaryNightHours,
    holidayHours: l10n.summaryHolidayHours,
    overtime: l10n.summaryOvertime,
    earlyLeave: l10n.summaryEarlyLeave,
    restDays: l10n.summaryRestDays,
    absences: l10n.summaryAbsences,
    earnings: l10n.summaryEstimateTitle,
    footer: l10n.reportFooter,
    colDate: l10n.reportColDate,
    colDay: l10n.reportColDay,
    colShifts: l10n.reportColShifts,
    colCode: l10n.reportColCode,
    colStart: l10n.reportColStart,
    colEnd: l10n.reportColEnd,
    colHours: l10n.reportColHours,
    colNote: l10n.reportColNote,
    colExtra: colExtra,
    extrasAmount: extrasAmount,
    overtimeTypeOvertime: l10n.overtimeTypeOvertime,
    overtimeTypeOtherWork: l10n.overtimeTypeOtherWork,
    longestStreak: l10n.summaryLongestStreak,
    streakDays: l10n.summaryStreakDays,
    weekdayShort: (w) => format.weekdayShort(weekday(w)),
    weekdayLong: (w) => format.weekdayLong(weekday(w)),
    date: (y, m, d) => format.dayMonthYear(day(y, m, d)),
    monthYear: (y, m) => format.monthYear(day(y, m, 1)),
    dayMonth: (m, d) => '$d ${format.monthShort(day(2026, m, d))}',
    hours: (minutes) => formatHours(l10n, minutes),
    money: (cents) => formatMoneyCentsFor(localeName, currency, cents),
    days: (count) => l10n.summaryDays(count),
    pageOf: (page, total) => l10n.reportPageOf(page, total),
    csvDelimiter: separators.delimiter,
    csvDecimal: separators.decimal,
  );
}
