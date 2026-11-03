/// The words and formats of a report, resolved before it is rendered, so the
/// PDF and CSV writers need neither a `BuildContext` nor the localizations
/// (and a test builds them without a widget tree). `reportStringsFor`
/// (presentation) fills them from the ARB files and the formats of the app.
class ReportStrings {
  const ReportStrings({
    required this.localeName,
    required this.hour12,
    required this.reportTitleFallback,
    required this.legendTitle,
    required this.totalsTitle,
    required this.notesTitle,
    required this.holidaysTitle,
    required this.holidayMark,
    required this.absenceName,
    required this.absenceCode,
    required this.hoursTotal,
    required this.hoursWorked,
    required this.hoursPlanned,
    required this.hoursDone,
    required this.hoursPlannedFrom,
    required this.shiftsWorked,
    required this.nightHours,
    required this.holidayHours,
    required this.overtime,
    required this.earlyLeave,
    required this.restDays,
    required this.absences,
    required this.earnings,
    required this.footer,
    required this.colDate,
    required this.colDay,
    required this.colShifts,
    required this.colCode,
    required this.colStart,
    required this.colEnd,
    required this.colHours,
    required this.colNote,
    this.colExtra,
    this.extrasAmount,
    required this.weekdayShort,
    required this.weekdayLong,
    required this.date,
    required this.monthYear,
    required this.dayMonth,
    required this.hours,
    required this.money,
    required this.days,
    required this.pageOf,
    required this.csvDelimiter,
    required this.csvDecimal,
  });

  /// Language (and region) of the texts, such as `es` or `en_US`.
  final String localeName;

  /// Whether the PDF writes the clock as 10p-6a (12 h) or 22-06.
  final bool hour12;

  /// Title when the calendar has no name.
  final String reportTitleFallback;

  final String legendTitle;
  final String totalsTitle;
  final String notesTitle;
  final String holidaysTitle;

  /// Name of the mark of a public holiday in the legend.
  final String holidayMark;

  /// The generic absence: «Ausencia» and its short code.
  final String absenceName;
  final String absenceCode;

  final String hoursTotal;
  final String hoursWorked;
  final String hoursPlanned;
  final String hoursDone;
  final String hoursPlannedFrom;
  final String shiftsWorked;
  final String nightHours;
  final String holidayHours;
  final String overtime;
  final String earlyLeave;
  final String restDays;
  final String absences;
  final String earnings;

  /// «Creado con Turnly».
  final String footer;

  final String colDate;
  final String colDay;
  final String colShifts;
  final String colCode;
  final String colStart;
  final String colEnd;
  final String colHours;
  final String colNote;

  /// Header of the CSV column with the extra money of the day (P9, fila 26:
  /// diets, mileage, a bonus). `null` = the column is not written.
  ///
  /// The wave 3 of the logic does not add texts to the ARB files: the label
  /// comes with the screen that shows the report. Until then the column is
  /// not written (the money is in the totals of the PDF).
  final String? colExtra;

  /// Label of the line of the PDF totals with the extra money of the days
  /// (P9). `null` = the line is not written.
  final String? extrasAmount;

  /// ISO weekday (1 = Monday .. 7 = Sunday) as «lun» / «lunes».
  final String Function(int weekday) weekdayShort;
  final String Function(int weekday) weekdayLong;

  /// «19 oct 2026».
  final String Function(int year, int month, int day) date;

  /// «Octubre 2026».
  final String Function(int year, int month) monthYear;

  /// «19 oct» (the year is on the title).
  final String Function(int month, int day) dayMonth;

  /// «152 h 30 min».
  final String Function(int minutes) hours;

  /// A stored amount in the money of the app.
  final String Function(int cents) money;

  /// «3 días».
  final String Function(int count) days;

  /// «Página 1 de 2».
  final String Function(int page, int total) pageOf;

  /// Field separator of the CSV and decimal mark of its hours: `;` and `,`
  /// where the language writes decimals with a comma (the list separator of
  /// Excel in those regions), `,` and `.` otherwise.
  final String csvDelimiter;
  final String csvDecimal;
}

/// The CSV separators of a locale: the decimal mark `intl` knows for it
/// decides the field separator, which is what Excel does with the regional
/// settings of the computer (semicolon where the decimal mark is a comma).
({String delimiter, String decimal}) csvSeparatorsFor(String decimalMark) =>
    decimalMark == ','
    ? (delimiter: ';', decimal: ',')
    : (delimiter: ',', decimal: '.');
