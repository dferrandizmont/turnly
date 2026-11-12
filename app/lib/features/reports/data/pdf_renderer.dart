import 'dart:typed_data';
import 'dart:ui' show Brightness, Color;

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/format/app_date_format.dart';
import '../../../core/theme/shift_swatch.dart';
import '../../summary/domain/period_hours.dart';
import '../domain/report_model.dart';
import '../domain/report_strings.dart';
import 'report_fonts.dart';

// The PDF is a printed page: white paper and the light swatches of the app
// (`ShiftSwatch`, the same contrast as the screen), so a shift is always a
// colour AND its code AND its time (docs/informes.md). Sizes are points
// (1/72 in) of an A4 page; the few greys and the holiday amber below are
// ink choices for paper, not UI tokens.
const double _margin = 28;
const double _cellHeight = 64;
const double _chipHeight = 11;
const int _maxChipsPerCell = 3;

const PdfColor _ink = PdfColor.fromInt(0xFF1A1A1F);
const PdfColor _muted = PdfColor.fromInt(0xFF5B5B66);
const PdfColor _line = PdfColor.fromInt(0xFFC9C9D2);
const PdfColor _outside = PdfColor.fromInt(0xFFF1F1F5);
const PdfColor _holiday = PdfColor.fromInt(0xFFB45309);

PdfColor _pdf(Color color) => PdfColor.fromInt(color.toARGB32());

/// The A4 portrait PDF of [model]: header with the calendar and the period,
/// one month grid per month (shifts as code + time over their colour,
/// holidays marked), the legend, the totals and, when the report includes
/// them, the notes. [compress] is off only in tests that search the bytes.
///
/// Absences follow the options of the model: hidden, a neutral «Ausencia»
/// or by name (see `ReportAbsenceMode`); this renderer draws what the model
/// holds and never reads the schedule, so it cannot leak what the model
/// left out.
Future<Uint8List> renderReportPdf(
  ReportModel model,
  ReportStrings strings,
  ReportFonts fonts, {
  bool compress = true,
}) async {
  final title = model.calendarName.isEmpty
      ? strings.reportTitleFallback
      : model.calendarName;
  final period = _periodText(model, strings);

  final doc = pw.Document(
    compress: compress,
    title: '$title · $period',
    creator: 'Turnly',
    producer: 'Turnly',
  );

  final body = <pw.Widget>[];
  final months = _splitByMonth(model.days);
  for (var i = 0; i < months.length; i++) {
    if (i > 0) body.add(pw.NewPage());
    body.addAll(_monthBlock(months[i], model, strings));
  }
  body
    ..add(pw.SizedBox(height: 14))
    ..addAll(_legendBlock(model, strings))
    ..add(pw.SizedBox(height: 12))
    ..addAll(_totalsBlock(model, strings));
  if (model.notedDays.isNotEmpty) {
    body
      ..add(pw.SizedBox(height: 12))
      ..addAll(_notesBlock(model, strings));
  }

  doc.addPage(
    pw.MultiPage(
      maxPages: 400,
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(_margin),
        theme: pw.ThemeData.withFont(
          base: fonts.regular,
          bold: fonts.bold,
          italic: fonts.regular,
          boldItalic: fonts.bold,
        ),
        textDirection: pw.TextDirection.ltr,
      ),
      header: (context) => _header(title, period),
      footer: (context) => _footer(context, strings),
      build: (context) => body,
    ),
  );

  return doc.save();
}

String _periodText(ReportModel model, ReportStrings s) {
  final from = model.range.from;
  final to = model.range.to;
  final isWholeMonth =
      from.day == 1 &&
      to == to.lastDayOfMonth &&
      from.year == to.year &&
      from.month == to.month;
  if (isWholeMonth) return _capitalize(s.monthYear(from.year, from.month));
  return '${s.date(from.year, from.month, from.day)} – '
      '${s.date(to.year, to.month, to.day)}';
}

String _capitalize(String text) =>
    text.isEmpty ? text : '${text[0].toUpperCase()}${text.substring(1)}';

// ---- Header and footer ------------------------------------------------------

pw.Widget _header(String title, String period) => pw.Container(
  padding: const pw.EdgeInsets.only(bottom: 8),
  margin: const pw.EdgeInsets.only(bottom: 10),
  decoration: const pw.BoxDecoration(
    border: pw.Border(bottom: pw.BorderSide(color: _line, width: 0.8)),
  ),
  child: pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.end,
    children: [
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              maxLines: 2,
              style: pw.TextStyle(
                fontSize: 17,
                fontWeight: pw.FontWeight.bold,
                color: _ink,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              period,
              style: const pw.TextStyle(fontSize: 11, color: _muted),
            ),
          ],
        ),
      ),
      pw.Text(
        'Turnly',
        style: pw.TextStyle(
          fontSize: 11,
          fontWeight: pw.FontWeight.bold,
          color: _muted,
        ),
      ),
    ],
  ),
);

pw.Widget _footer(pw.Context context, ReportStrings s) => pw.Padding(
  padding: const pw.EdgeInsets.only(top: 8),
  child: pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text(s.footer, style: const pw.TextStyle(fontSize: 8, color: _muted)),
      pw.Text(
        s.pageOf(context.pageNumber, context.pagesCount),
        style: const pw.TextStyle(fontSize: 8, color: _muted),
      ),
    ],
  ),
);

// ---- Month grid -------------------------------------------------------------

List<List<ReportDay>> _splitByMonth(List<ReportDay> days) {
  final groups = <List<ReportDay>>[];
  for (final day in days) {
    if (groups.isEmpty ||
        groups.last.first.date.month != day.date.month ||
        groups.last.first.date.year != day.date.year) {
      groups.add([]);
    }
    groups.last.add(day);
  }
  return groups;
}

List<pw.Widget> _monthBlock(
  List<ReportDay> days,
  ReportModel model,
  ReportStrings s,
) {
  final first = days.first.date;
  final weekStart = model.options.weekStart;
  final cellWidth = (PdfPageFormat.a4.width - 2 * _margin) / 7;

  final cells = <ReportDay?>[
    for (var i = 0; i < (first.weekday - weekStart) % 7; i++) null,
    ...days,
  ];
  while (cells.length % 7 != 0) {
    cells.add(null);
  }

  final widgets = <pw.Widget>[
    pw.Text(
      _capitalize(s.monthYear(first.year, first.month)),
      style: pw.TextStyle(
        fontSize: 13,
        fontWeight: pw.FontWeight.bold,
        color: _ink,
      ),
    ),
    pw.SizedBox(height: 6),
    pw.Row(
      children: [
        for (var i = 0; i < 7; i++)
          pw.Container(
            width: cellWidth,
            height: 14,
            alignment: pw.Alignment.center,
            child: pw.Text(
              _capitalize(s.weekdayShort((weekStart - 1 + i) % 7 + 1)),
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: _muted,
              ),
            ),
          ),
      ],
    ),
  ];

  for (var row = 0; row < cells.length; row += 7) {
    widgets.add(
      pw.Row(
        children: [
          for (final day in cells.sublist(row, row + 7))
            _dayCell(day, cellWidth, s),
        ],
      ),
    );
  }

  final monthHolidays = [
    for (final h in model.holidays)
      if (h.date.month == first.month && h.date.year == first.year) h,
  ];
  if (monthHolidays.isNotEmpty) {
    widgets
      ..add(pw.SizedBox(height: 6))
      ..add(
        pw.Text(
          '${s.holidaysTitle}: ${[for (final h in monthHolidays) '${s.dayMonth(h.date.month, h.date.day)} ${h.name}'].join(' · ')}',
          style: const pw.TextStyle(fontSize: 8, color: _muted),
        ),
      );
  }
  return widgets;
}

pw.Widget _dayCell(ReportDay? day, double width, ReportStrings s) {
  final border = pw.Border.all(color: _line, width: 0.5);
  if (day == null) {
    return pw.Container(
      width: width,
      height: _cellHeight,
      decoration: pw.BoxDecoration(color: _outside, border: border),
    );
  }

  final shown = day.shifts.length > _maxChipsPerCell
      ? day.shifts.take(_maxChipsPerCell - 1).toList()
      : day.shifts;
  final hidden = day.shifts.length - shown.length;

  return pw.Container(
    width: width,
    height: _cellHeight,
    padding: const pw.EdgeInsets.all(2.5),
    decoration: pw.BoxDecoration(border: border),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          children: [
            pw.Text(
              '${day.date.day}',
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: day.isHoliday ? _holiday : _ink,
              ),
            ),
            if (day.isHoliday) ...[pw.SizedBox(width: 3), _holidayDot()],
          ],
        ),
        pw.SizedBox(height: 1.5),
        for (final shift in shown) ...[
          _chip(shift, s),
          pw.SizedBox(height: 1.5),
        ],
        if (hidden > 0)
          pw.Text(
            '+$hidden',
            style: const pw.TextStyle(fontSize: 7, color: _muted),
          ),
      ],
    ),
  );
}

pw.Widget _holidayDot() => pw.Container(
  width: 5,
  height: 5,
  decoration: const pw.BoxDecoration(
    color: _holiday,
    shape: pw.BoxShape.circle,
  ),
);

/// The colour, the code and the time of a shift: the three at once.
pw.Widget _chip(ReportShift shift, ReportStrings s) {
  final swatch = ShiftSwatch.forColor(shift.colorValue, Brightness.light);
  final ink = _pdf(swatch.ink);
  final code = shift.genericAbsence ? s.absenceCode : shift.code;
  final time = _timeText(shift, s.hour12);
  return pw.Container(
    height: _chipHeight,
    padding: const pw.EdgeInsets.symmetric(horizontal: 2),
    decoration: pw.BoxDecoration(
      color: _pdf(swatch.tint),
      border: pw.Border(
        left: pw.BorderSide(color: _pdf(swatch.bar), width: 2.5),
      ),
    ),
    child: pw.Row(
      children: [
        pw.Text(
          code,
          maxLines: 1,
          style: pw.TextStyle(
            fontSize: 7.5,
            fontWeight: pw.FontWeight.bold,
            color: ink,
          ),
        ),
        if (time != null) ...[
          pw.SizedBox(width: 3),
          pw.Expanded(
            child: pw.Text(
              time,
              maxLines: 1,
              overflow: pw.TextOverflow.clip,
              style: pw.TextStyle(fontSize: 6.5, color: ink),
            ),
          ),
        ],
      ],
    ),
  );
}

/// «07–15», «22–06», «09–13/17–21» (minutes only when they are not :00);
/// `null` for a shift without hours or a generic absence.
String? _timeText(ReportShift shift, bool hour12) {
  if (!shift.hasTimes) return null;
  String clock(int minute) =>
      AppDateFormat.compactClock(minute, hour12: hour12);
  final first = '${clock(shift.startMinute!)}–${clock(shift.endMinute!)}';
  if (!shift.hasSegment2) return first;
  return '$first/${clock(shift.segment2StartMinute!)}–'
      '${clock(shift.segment2EndMinute!)}';
}

// ---- Legend, totals, notes ---------------------------------------------------

pw.Widget _sectionTitle(String text) => pw.Container(
  width: double.infinity,
  padding: const pw.EdgeInsets.only(bottom: 3),
  margin: const pw.EdgeInsets.only(bottom: 6),
  decoration: const pw.BoxDecoration(
    border: pw.Border(bottom: pw.BorderSide(color: _line, width: 0.5)),
  ),
  child: pw.Text(
    text,
    style: pw.TextStyle(
      fontSize: 10,
      fontWeight: pw.FontWeight.bold,
      color: _ink,
    ),
  ),
);

List<pw.Widget> _legendBlock(ReportModel model, ReportStrings s) {
  final entries = <pw.Widget>[
    for (final entry in model.legend) _legendEntry(entry, s),
    if (model.holidays.isNotEmpty)
      pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.SizedBox(width: 22, child: pw.Center(child: _holidayDot())),
          pw.SizedBox(width: 4),
          pw.Text(
            s.holidayMark,
            style: const pw.TextStyle(fontSize: 8.5, color: _ink),
          ),
        ],
      ),
  ];
  return [
    _sectionTitle(s.legendTitle),
    pw.Wrap(spacing: 14, runSpacing: 5, children: entries),
  ];
}

pw.Widget _legendEntry(ReportLegendEntry entry, ReportStrings s) {
  final shift = entry.shift;
  final name = shift.genericAbsence ? s.absenceName : shift.name;
  final time = _timeText(shift, s.hour12);
  final detail = [
    name,
    // The place of the shift type (P9): free text of the user, written as
    // it is.
    ?shift.location,
    ?time,
    s.days(entry.days),
  ].join(' · ');
  return pw.Row(
    mainAxisSize: pw.MainAxisSize.min,
    children: [
      pw.SizedBox(width: 30, child: _chipCodeOnly(shift, s)),
      pw.SizedBox(width: 4),
      pw.Text(detail, style: const pw.TextStyle(fontSize: 8.5, color: _ink)),
    ],
  );
}

/// The code over the colour, without time (the legend writes the time next
/// to the name).
pw.Widget _chipCodeOnly(ReportShift shift, ReportStrings s) => _chip(
  ReportShift(
    code: shift.code,
    name: shift.name,
    colorValue: shift.colorValue,
    category: shift.category,
    genericAbsence: shift.genericAbsence,
  ),
  s,
);

List<pw.Widget> _totalsBlock(ReportModel model, ReportStrings s) {
  final summary = model.summary;
  final rows = <(String, String)>[];

  final tense = model.hours;
  rows.add((
    switch (tense.tense) {
      PeriodTense.past => s.hoursWorked,
      PeriodTense.future => s.hoursPlanned,
      PeriodTense.current => s.hoursTotal,
    },
    s.hours(summary.workedMinutes),
  ));
  if (tense.doneMinutes > 0 && tense.plannedMinutes > 0) {
    rows
      ..add((s.hoursDone, s.hours(tense.doneMinutes)))
      ..add((s.hoursPlannedFrom, s.hours(tense.plannedMinutes)));
  }
  rows.add((s.shiftsWorked, '${summary.shiftsWorked}'));
  if (summary.nightMinutes > 0) {
    rows.add((s.nightHours, s.hours(summary.nightMinutes)));
  }
  if (summary.holidayMinutes > 0) {
    rows.add((s.holidayHours, s.hours(summary.holidayMinutes)));
  }
  if (summary.overtimeMinutes > 0) {
    rows.add((s.overtime, s.hours(summary.overtimeMinutes)));
  }
  // By overtime type (schema v7), when there is more than one kind.
  if (summary.overtimeTypes.length > 1 ||
      (summary.overtimeTypes.length == 1 &&
          summary.overtimeTypes.single.minutes != summary.overtimeMinutes)) {
    for (final t in summary.overtimeTypes) {
      final money = model.options.includeEarnings ? t.amountCents : null;
      rows.add((
        s.overtimeTypeName(t.type),
        [s.hours(t.minutes), if (money != null) s.money(money)].join(' · '),
      ));
    }
  }
  if (summary.earlyLeaveMinutes > 0) {
    rows.add((s.earlyLeave, s.hours(summary.earlyLeaveMinutes)));
  }
  rows.add((s.restDays, '${summary.restDays}'));
  if (model.showsAbsences) {
    rows.add((s.absences, '${summary.absenceDays}'));
  }
  final earnings = model.earningsCents;
  if (earnings != null) rows.add((s.earnings, s.money(earnings)));
  // The extra money of the days (P9): its own line when the report has a
  // label for it. It is already inside the estimate above.
  final extrasLabel = s.extrasAmount;
  if (extrasLabel != null && model.extraAmountCents != 0) {
    rows.add((extrasLabel, s.money(model.extraAmountCents)));
  }

  final columnWidth = (PdfPageFormat.a4.width - 2 * _margin - 24) / 2;
  final streak = summary.longestStreak;
  return [
    _sectionTitle(s.totalsTitle),
    if (streak != null)
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Text(
          '${s.longestStreak}: ${s.streakDays(streak.days)} '
          '(${s.date(streak.from.year, streak.from.month, streak.from.day)} – '
          '${s.date(streak.to.year, streak.to.month, streak.to.day)})',
          style: const pw.TextStyle(fontSize: 9, color: _ink),
        ),
      ),
    pw.Wrap(
      spacing: 24,
      runSpacing: 4,
      children: [
        for (final (label, value) in rows)
          pw.SizedBox(
            width: columnWidth,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Text(
                    label,
                    style: const pw.TextStyle(fontSize: 9, color: _muted),
                  ),
                ),
                pw.Text(
                  value,
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: _ink,
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  ];
}

List<pw.Widget> _notesBlock(ReportModel model, ReportStrings s) => [
  _sectionTitle(s.notesTitle),
  for (final day in model.notedDays)
    pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 70,
            child: pw.Text(
              '${s.weekdayShort(day.date.weekday)} '
              '${s.dayMonth(day.date.month, day.date.day)}',
              style: pw.TextStyle(
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
                color: _ink,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              day.note!,
              style: const pw.TextStyle(fontSize: 8.5, color: _ink),
            ),
          ),
        ],
      ),
    ),
];
