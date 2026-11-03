import 'dart:convert';
import 'dart:typed_data';

import '../domain/report_model.dart';
import '../domain/report_strings.dart';

/// UTF-8 byte order mark: what makes Excel read the accents of a CSV
/// (Mañana, Nit, Gaua) instead of guessing Windows-1252.
const List<int> utf8Bom = [0xEF, 0xBB, 0xBF];

/// The CSV of [model] as bytes: UTF-8 with BOM, CRLF lines, one row per day.
Uint8List writeReportCsv(ReportModel model, ReportStrings strings) =>
    Uint8List.fromList([
      ...utf8Bom,
      ...utf8.encode(reportCsvText(model, strings)),
    ]);

/// The text of the CSV (no BOM).
///
/// Columns: date (ISO `2026-10-19`, which Excel and Sheets read in any
/// regional setting), weekday, shifts (names joined by « + »), codes, start,
/// end, hours, the extra money of the day (when the report has a header for
/// it) and, only when the report includes notes, the note.
///
/// * **One row per day of the period**, also the empty ones (so the file has
///   every date and can be matched against a payslip).
/// * **Start / end:** the 24 h clock of the first shift with times and the
///   end of the last one (a split shift: the end of its second segment; a
///   night shift ends the next day).
/// * **Hours:** the paid hours of the day as a decimal number with at most
///   two decimals, using [ReportStrings.csvDecimal]; empty for a day with
///   nothing. They add up to the total of the report.
/// * **Place:** the place of the shift type (P9) is written with its name
///   («Mañana (Hospital)»): it is free text of the user, so it needs no
///   header of its own.
/// * **Separator:** [ReportStrings.csvDelimiter] (`;` where decimals use a
///   comma, `,` elsewhere). A field with the separator, a quote or a line
///   break is quoted, and quotes are doubled.
/// * **Formulas:** a text that starts with `=`, `+`, `-`, `@` is written
///   with a leading apostrophe so a spreadsheet never runs it.
String reportCsvText(ReportModel model, ReportStrings strings) {
  final d = strings.csvDelimiter;
  final withNotes = model.options.includeNotes;
  final withExtra = strings.colExtra != null;
  final out = StringBuffer();

  void row(List<String> cells) {
    out
      ..write(cells.map((c) => _quote(c, d)).join(d))
      ..write('\r\n');
  }

  row([
    strings.colDate,
    strings.colDay,
    strings.colShifts,
    strings.colCode,
    strings.colStart,
    strings.colEnd,
    strings.colHours,
    if (withExtra) strings.colExtra!,
    if (withNotes) strings.colNote,
  ]);

  for (final day in model.days) {
    final names = <String>[];
    final codes = <String>[];
    int? start;
    int? end;
    for (final shift in day.shifts) {
      final name = shift.genericAbsence ? strings.absenceName : shift.name;
      names.add(_withLocation(name, shift.location));
      codes.add(shift.genericAbsence ? strings.absenceCode : shift.code);
      if (shift.hasTimes) {
        start ??= shift.firstStart;
        end = shift.lastEnd;
      }
    }
    row([
      day.date.toIso(),
      strings.weekdayLong(day.date.weekday),
      _guard(names.join(' + ')),
      _guard(codes.join(' + ')),
      start == null ? '' : clock24(start),
      end == null ? '' : clock24(end),
      day.isEmpty ? '' : decimalHours(day.workedMinutes, strings.csvDecimal),
      if (withExtra)
        day.extraAmountCents == 0 ? '' : strings.money(day.extraAmountCents),
      if (withNotes) _guard(day.note ?? ''),
    ]);
  }
  return out.toString();
}

/// The name of a shift with its place (P9): «Mañana (Hospital)». The place is
/// free text of the user, so it is written as it is.
String _withLocation(String name, String? location) {
  if (location == null || location.trim().isEmpty) return name;
  return '$name ($location)';
}

/// "07:30" from minutes since midnight (1440 wraps to 00:00).
String clock24(int minute) {
  final h = (minute ~/ 60) % 24;
  final m = minute % 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

/// Hours as a decimal with at most two decimals and no trailing zeros:
/// 450 min -> "7,5" (or "7.5"), 480 -> "8", 500 -> "8,33".
String decimalHours(int minutes, String decimalMark) {
  final cents = (minutes * 100 / 60).round(); // hundredths of an hour
  final whole = cents ~/ 100;
  final frac = cents % 100;
  if (frac == 0) return '$whole';
  final digits = frac.toString().padLeft(2, '0').replaceFirst(RegExp('0\$'), '');
  return '$whole$decimalMark$digits';
}

/// Defuses a text a spreadsheet would read as a formula.
String _guard(String text) {
  if (text.isEmpty) return text;
  final first = text.codeUnitAt(0);
  // = + - @ TAB CR
  if (first == 0x3d ||
      first == 0x2b ||
      first == 0x2d ||
      first == 0x40 ||
      first == 0x09 ||
      first == 0x0d) {
    return "'$text";
  }
  return text;
}

String _quote(String cell, String delimiter) {
  final needs =
      cell.contains(delimiter) ||
      cell.contains('"') ||
      cell.contains('\n') ||
      cell.contains('\r') ||
      cell.startsWith(' ') ||
      cell.endsWith(' ');
  if (!needs) return cell;
  return '"${cell.replaceAll('"', '""')}"';
}
