import 'dart:convert';
import 'dart:typed_data';

import 'package:cuadrante/features/holidays/domain/holiday.dart';
import 'package:cuadrante/features/reports/data/pdf_renderer.dart';
import 'package:cuadrante/features/reports/data/report_fonts.dart';
import 'package:cuadrante/features/reports/domain/report_model.dart';
import 'package:cuadrante/features/reports/domain/report_options.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:cuadrante/features/summary/domain/summary_range.dart';
import 'package:flutter_test/flutter_test.dart';

import 'report_fixtures.dart';

/// Every byte of the file as text: metadata and fonts included.
String _raw(Uint8List bytes) => latin1.decode(bytes);

final RegExp _showText = RegExp(r'\[\(((?:\\.|[^\\)])*)\)\]TJ');
final RegExp _escape = RegExp(r'\\([0-7]{1,3}|.)');
final RegExp _octal = RegExp(r'^[0-7]+$');

/// The text the PDF draws, to search it. With the standard PDF fonts and no
/// compression every word is a `[(word)]TJ` operator; the words are joined
/// with a space in drawing order.
String _asText(Uint8List bytes) {
  final out = StringBuffer();
  for (final match in _showText.allMatches(_raw(bytes))) {
    out
      ..write(
        match.group(1)!.replaceAllMapped(_escape, (m) {
          final code = m.group(1)!;
          return _octal.hasMatch(code)
              ? String.fromCharCode(int.parse(code, radix: 8))
              : code;
        }),
      )
      ..write(' ');
  }
  return out.toString();
}

int _pages(Uint8List bytes) =>
    RegExp(r'/Type\s*/Page(?![a-z])').allMatches(_raw(bytes)).length;

Future<Uint8List> _plainPdf(ReportModel model) => renderReportPdf(
  model,
  spanishStrings(),
  ReportFonts.standard(),
  compress: false,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('a month', () {
    test('is a PDF of one A4 portrait page', () async {
      final bytes = await _plainPdf(octoberReport());
      final raw = _raw(bytes);
      expect(raw.startsWith('%PDF-'), isTrue);
      expect(raw.trimRight().endsWith('%%EOF'), isTrue);
      expect(_pages(bytes), 1);
      // A4 in points, portrait: 595.28 x 841.89.
      final box = RegExp(r'/MediaBox\[0 0 ([\d.]+) ([\d.]+)\]')
          .firstMatch(raw)!;
      expect(double.parse(box.group(1)!), closeTo(595.28, 0.01));
      expect(double.parse(box.group(2)!), closeTo(841.89, 0.01));
    });

    test('has the calendar, the period, the legend and the totals', () async {
      final text = _asText(await _plainPdf(octoberReport()));
      for (final word in [
        'Hospital',
        'Octubre 2026',
        'Leyenda',
        'Totales',
        'Festivo',
        'Fiesta Nacional de España',
        'Creado con Turnly',
        'Página 1 de 1',
        'Turnos trabajados',
        'Días libres',
      ]) {
        expect(text, contains(word), reason: word);
      }
    });

    test('includes the longest work streak and its clipped dates', () async {
      final model = octoberReport();
      final streak = model.summary.longestStreak!;
      final text = _asText(await _plainPdf(model));
      expect(text, contains('Racha más larga: ${streak.days} días seguidos'));
      expect(
        text,
        contains('${streak.from.day}/${streak.from.month}/${streak.from.year}'),
      );
      expect(
        text,
        contains('${streak.to.day}/${streak.to.month}/${streak.to.year}'),
      );
    });

    test('draws the codes of the shifts and the days of the month', () async {
      final text = _asText(await _plainPdf(octoberReport()));
      // Codes in the cells and in the legend; day numbers 1..31.
      expect(text, contains(' M '));
      expect(text, contains(' N '));
      expect(text, contains(' P '));
      expect(text, contains(' L '));
      for (final day in ['1', '15', '31']) {
        expect(text, contains(' $day '), reason: day);
      }
    });

    test('shows the weekday names starting on Monday or Sunday', () async {
      final monday = _asText(await _plainPdf(octoberReport()));
      expect(monday.indexOf('Lun'), lessThan(monday.indexOf('Dom')));
      final sunday = _asText(
        await _plainPdf(
          octoberReport(options: const ReportOptions(weekStart: 7)),
        ),
      );
      expect(sunday.indexOf('Dom'), lessThan(sunday.indexOf('Lun')));
    });
  });

  group('privacy', () {
    test('a medical leave is not in the PDF by default', () async {
      final bytes = await _plainPdf(octoberReport());
      for (final text in [_asText(bytes), _raw(bytes)]) {
        expect(text, isNot(contains('XQZ')));
        expect(text, isNot(contains('Baja')));
        expect(text, isNot(contains('oncologo')));
        expect(text, isNot(contains('Vacaciones')));
      }
      // It is there as a plain «Ausencia».
      expect(_asText(bytes), contains('Ausencia'));
      expect(_asText(bytes), contains('AUS'));
    });

    test('also with notes on: the note of a leave day stays out', () async {
      final bytes = await _plainPdf(
        octoberReport(options: const ReportOptions(includeNotes: true)),
      );
      for (final text in [_asText(bytes), _raw(bytes)]) {
        expect(text, isNot(contains('XQZ')));
        expect(text, isNot(contains('viaje')));
      }
      expect(_asText(bytes), contains('Cambio con Ana'));
    });

    test('hidden absences leave no trace', () async {
      final bytes = await _plainPdf(
        octoberReport(
          options: const ReportOptions(absences: ReportAbsenceMode.hidden),
        ),
      );
      expect(_asText(bytes), isNot(contains('Ausencia')));
      expect(_raw(bytes), isNot(contains('XQZ')));
    });

    test('detailed absences show their name when asked', () async {
      final text = _asText(
        await _plainPdf(
          octoberReport(
            options: const ReportOptions(
              absences: ReportAbsenceMode.detailed,
              includeNotes: true,
            ),
          ),
        ),
      );
      expect(text, contains(secretLeaveName));
      expect(text, contains(secretLeaveNote));
    });

    test('notes and earnings are off by default', () async {
      final text = _asText(await _plainPdf(octoberReport()));
      expect(text, isNot(contains('Notas')));
      expect(text, isNot(contains('Cambio con Ana')));
      expect(text, isNot(contains('Ingresos estimados')));
    });

    test('earnings appear when asked', () async {
      final text = _asText(
        await _plainPdf(
          octoberReport(options: const ReportOptions(includeEarnings: true)),
        ),
      );
      expect(text, contains('Ingresos estimados'));
      expect(text, contains('240.0'));
    });
  });

  group('periods', () {
    test('a free range across months has a page per month', () async {
      final model = octoberReport(
        range: const SummaryRange(
          CivilDate(2026, 10, 20),
          CivilDate(2026, 12, 10),
        ),
      );
      final bytes = await _plainPdf(model);
      expect(_pages(bytes), 3);
      final text = _asText(bytes);
      expect(text, contains('Página 3 de 3'));
      // Not a whole month: the title is the range.
      expect(text, contains('20/10/2026'));
      expect(text, contains('10/12/2026'));
    });

    test('a single day', () async {
      final bytes = await _plainPdf(
        octoberReport(
          range: const SummaryRange(
            CivilDate(2026, 10, 12),
            CivilDate(2026, 10, 12),
          ),
        ),
      );
      expect(_pages(bytes), 1);
    });

    test('a whole year of 366 days renders, one page per month', () async {
      final model = octoberReport(
        range: const SummaryRange(CivilDate(2026, 1, 1), CivilDate(2027, 1, 1)),
        options: const ReportOptions(includeNotes: true),
      );
      expect(model.days, hasLength(366));
      final bytes = await _plainPdf(model);
      // 12 months + January 2027 (one day); the totals go on the last page.
      expect(_pages(bytes), 13);
    });

    test('an empty calendar still gives a clean page', () async {
      final model = buildReport(
        schedule: Schedule(),
        range: october,
        calendarName: '',
        holidays: const <CivilDate, Holiday>{},
        today: const CivilDate(2026, 10, 1),
      );
      final bytes = await _plainPdf(model);
      expect(_asText(bytes), contains('Mis turnos'));
      expect(_pages(bytes), 1);
    });

    test('a day with more shifts than fit says how many are left', () async {
      final schedule = Schedule(
        shiftTypes: const [morning, night, split, off, vacation],
        entries: {
          const CivilDate(2026, 10, 1): const DayEntry(
            date: CivilDate(2026, 10, 1),
            shiftTypeIds: ['m', 'n', 'l', 'v'],
          ),
        },
      );
      final model = buildReport(
        schedule: schedule,
        range: october,
        calendarName: 'x',
        holidays: const {},
        today: const CivilDate(2026, 10, 1),
      );
      expect(_asText(await _plainPdf(model)), contains('+2'));
    });
  });

  group('embedded fonts', () {
    test('Roboto draws accents, ç, ñ and the Catalan l·l', () async {
      final fonts = await loadReportFonts();
      final schedule = Schedule(
        shiftTypes: const [
          ShiftType(
            id: 'x',
            code: 'N',
            name: 'Nit — col·laboració',
            colorValue: 0xFF4B4FD1,
            category: ShiftCategory.work,
            startMinute: 1320,
            endMinute: 360,
          ),
        ],
        entries: {
          const CivilDate(2026, 10, 1): const DayEntry(
            date: CivilDate(2026, 10, 1),
            shiftTypeIds: ['x'],
            note: 'Gaua, garçon, niño, ŀ, Ibañez, ü',
          ),
        },
      );
      final model = buildReport(
        schedule: schedule,
        range: october,
        calendarName: 'Hospital Sant Joan d’Alacant · Núñez',
        holidays: const {},
        today: const CivilDate(2026, 10, 1),
        options: const ReportOptions(includeNotes: true),
      );
      final bytes = await renderReportPdf(model, spanishStrings(), fonts);
      expect(_raw(bytes).startsWith('%PDF-'), isTrue);
      expect(bytes.length, greaterThan(5000));
      // The fonts are embedded (subset TrueType), not referenced by name.
      expect(_raw(bytes), contains('/FontFile2'));
      expect(_pages(bytes), 1);
    });

    test('the real (compressed) PDF is smaller than the plain one', () async {
      final fonts = await loadReportFonts();
      final packed = await renderReportPdf(
        octoberReport(),
        spanishStrings(),
        fonts,
      );
      final plain = await renderReportPdf(
        octoberReport(),
        spanishStrings(),
        fonts,
        compress: false,
      );
      expect(packed.length, lessThan(plain.length));
    });
  });
}
