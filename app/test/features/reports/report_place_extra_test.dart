import 'dart:convert';
import 'dart:typed_data';

import 'package:cuadrante/features/reports/data/csv_writer.dart';
import 'package:cuadrante/features/reports/data/pdf_renderer.dart';
import 'package:cuadrante/features/reports/data/report_fonts.dart';
import 'package:cuadrante/features/reports/domain/report_model.dart';
import 'package:cuadrante/features/reports/domain/report_options.dart';
import 'package:cuadrante/features/reports/domain/report_strings.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:cuadrante/features/summary/domain/summary_range.dart';
import 'package:flutter_test/flutter_test.dart';

import 'report_fixtures.dart';

// The place of the shift type and the extra money of the day in the reports
// (P9, filas 16 and 26 de `docs/paridad-pago.md`).

const _day1 = CivilDate(2026, 10, 1);

const _morningAtHospital = ShiftType(
  id: 'M',
  code: 'M',
  name: 'Mañana',
  colorValue: 0xFFF5A524,
  category: ShiftCategory.work,
  startMinute: 360,
  endMinute: 840,
  hourlyRateCents: 1000,
  location: 'Hospital General',
);

Schedule _schedule() => Schedule(
  shiftTypes: const [_morningAtHospital],
  entries: {
    _day1: const DayEntry(
      date: _day1,
      shiftTypeIds: ['M'],
      extraAmountCents: 1250,
    ),
  },
);

ReportModel _report({ReportOptions options = const ReportOptions()}) =>
    buildReport(
      schedule: _schedule(),
      range: const SummaryRange(_day1, _day1),
      calendarName: 'x',
      holidays: const {},
      today: _day1,
      options: options,
    );

/// The text the PDF draws, to search it.
String _pdfText(Uint8List bytes) {
  final raw = latin1.decode(bytes);
  final showText = RegExp(r'\[\(((?:\\.|[^\\)])*)\)\]TJ');
  final escape = RegExp(r'\\([0-7]{1,3}|.)');
  final octal = RegExp(r'^[0-7]+$');
  final out = StringBuffer();
  for (final match in showText.allMatches(raw)) {
    out
      ..write(
        match.group(1)!.replaceAllMapped(escape, (m) {
          final code = m.group(1)!;
          return octal.hasMatch(code)
              ? String.fromCharCode(int.parse(code, radix: 8))
              : code;
        }),
      )
      ..write(' ');
  }
  return out.toString();
}

Future<String> _pdfTextOf(ReportModel model, ReportStrings strings) async {
  final bytes = await renderReportPdf(
    model,
    strings,
    ReportFonts.standard(),
    compress: false,
  );
  return _pdfText(bytes);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the model', () {
    test('carries the place of the shift and the money of the day', () {
      final model = _report();
      expect(model.days.single.shifts.single.location, 'Hospital General');
      expect(model.days.single.extraAmountCents, 1250);
      expect(model.extraAmountCents, 1250);
    });

    test('the money of the day is inside the estimate', () {
      final model = _report(
        options: const ReportOptions(includeEarnings: true),
      );
      // 8 h x 10,00 = 80,00 plus 12,50 of the day.
      expect(model.summary.earningsCents, 8000 + 1250);
      expect(model.earningsCents, 8000 + 1250);
    });

    test('a shift without a place has none', () {
      final model = buildReport(
        schedule: Schedule(
          shiftTypes: const [
            ShiftType(
              id: 'M',
              code: 'M',
              name: 'Mañana',
              colorValue: 0xFFF5A524,
              category: ShiftCategory.work,
              startMinute: 360,
              endMinute: 840,
            ),
          ],
          entries: {
            _day1: const DayEntry(date: _day1, shiftTypeIds: ['M']),
          },
        ),
        range: const SummaryRange(_day1, _day1),
        calendarName: 'x',
        holidays: const {},
        today: _day1,
      );
      expect(model.days.single.shifts.single.location, isNull);
      expect(model.days.single.extraAmountCents, 0);
    });
  });

  group('the CSV', () {
    test('writes the place with the name of the shift', () {
      final csv = reportCsvText(_report(), spanishStrings());
      expect(csv, contains('Mañana (Hospital General)'));
    });

    test('writes the money of the day when it has a header', () {
      final withHeader = spanishStrings(colExtra: 'Importe');
      final csv = reportCsvText(_report(), withHeader);
      expect(csv.split('\r\n').first, contains('Importe'));
      expect(csv, contains('12.5 EUR'));
    });

    test('without a header there is no column', () {
      final csv = reportCsvText(_report(), spanishStrings());
      expect(csv.split('\r\n').first, isNot(contains('Importe')));
      expect(csv, isNot(contains('12.5 EUR')));
    });
  });

  group('the PDF', () {
    test('the legend writes the place', () async {
      final text = await _pdfTextOf(_report(), spanishStrings());
      expect(text, contains('Hospital General'));
    });

    test(
      'the totals write the money of the days when they have a label',
      () async {
        final text = await _pdfTextOf(
          _report(options: const ReportOptions(includeEarnings: true)),
          spanishStrings(extrasAmount: 'Otros importes'),
        );
        expect(text, contains('Otros importes'));
        expect(text, contains('12.5 EUR'));
      },
    );

    test('without a label there is no line', () async {
      final text = await _pdfTextOf(
        _report(options: const ReportOptions(includeEarnings: true)),
        spanishStrings(),
      );
      expect(text, isNot(contains('Otros importes')));
    });
  });
}
