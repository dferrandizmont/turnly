import 'dart:convert';

import 'package:cuadrante/features/reports/data/csv_writer.dart';
import 'package:cuadrante/features/reports/domain/report_model.dart';
import 'package:cuadrante/features/reports/domain/report_options.dart';
import 'package:cuadrante/features/reports/domain/report_strings.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:cuadrante/features/summary/domain/summary_range.dart';
import 'package:flutter_test/flutter_test.dart';

import 'report_fixtures.dart';

List<String> _lines(String csv) => csv.split('\r\n')..removeLast();

String _row(String csv, String isoDate) =>
    _lines(csv).firstWhere((l) => l.startsWith('$isoDate;'));

const _oct1 = CivilDate(2026, 10, 1);

ReportModel _oneDay(Schedule schedule, {ReportOptions? options}) => buildReport(
  schedule: schedule,
  range: const SummaryRange(_oct1, _oct1),
  calendarName: 'x',
  holidays: const {},
  today: _oct1,
  options: options ?? const ReportOptions(),
);

Schedule _withNote(String note) => Schedule(
  shiftTypes: const [morning],
  entries: {
    _oct1: DayEntry(date: _oct1, shiftTypeIds: const ['m'], note: note),
  },
);

void main() {
  final es = spanishStrings();

  group('bytes', () {
    test('UTF-8 with BOM, so Excel reads the accents', () {
      final bytes = writeReportCsv(octoberReport(), es);
      expect(bytes.take(3), utf8Bom);
      final text = utf8.decode(bytes.skip(3).toList());
      expect(text, contains('Mañana'));
      expect(text, contains('jueves'));
    });

    test('CRLF lines, a header and one row per day', () {
      final csv = reportCsvText(octoberReport(), es);
      expect(csv.endsWith('\r\n'), isTrue);
      final lines = _lines(csv);
      expect(lines, hasLength(32));
      expect(lines.first, 'Fecha;Día;Turno;Código;Inicio;Fin;Horas');
    });
  });

  group('rows', () {
    final csv = reportCsvText(octoberReport(), es);

    test('a plain shift', () {
      expect(
        _row(csv, '2026-10-01'),
        '2026-10-01;jueves;Mañana;M;06:00;14:00;8',
      );
    });

    test('a night shift ends the next morning', () {
      expect(
        _row(csv, '2026-10-02'),
        '2026-10-02;viernes;Noche;N;22:00;06:00;8',
      );
    });

    test('a split shift: start of the first, end of the second segment', () {
      expect(
        _row(csv, '2026-10-03'),
        '2026-10-03;sábado;Partido;P;09:00;21:00;8',
      );
    });

    test('a rest day has no times but a 0', () {
      expect(_row(csv, '2026-10-04'), '2026-10-04;domingo;Libre;L;;;0');
    });

    test('two shifts on one day', () {
      expect(
        _row(csv, '2026-10-13'),
        '2026-10-13;martes;Mañana + Noche;M + N;06:00;06:00;16',
      );
    });

    test('an empty day has empty cells', () {
      expect(_row(csv, '2026-10-20'), '2026-10-20;martes;;;;;');
    });

    test('the hours add up to the total', () {
      var minutes = 0.0;
      for (final line in _lines(csv).skip(1)) {
        final h = line.split(';').last;
        if (h.isNotEmpty) minutes += double.parse(h.replaceAll(',', '.')) * 60;
      }
      expect(minutes, 48 * 60);
    });
  });

  group('absences and privacy', () {
    test('by default «Ausencia» without the real name, code or note', () {
      final csv = reportCsvText(
        octoberReport(options: const ReportOptions(includeNotes: true)),
        es,
      );
      expect(csv, isNot(contains('XQZ')));
      expect(csv, isNot(contains('Vacaciones')));
      expect(csv, isNot(contains('viaje')));
      expect(
        _row(csv, '2026-10-06'),
        startsWith('2026-10-06;martes;Ausencia;AUS;;;0;'),
      );
    });

    test('hidden: the day is an empty row', () {
      final csv = reportCsvText(
        octoberReport(
          options: const ReportOptions(absences: ReportAbsenceMode.hidden),
        ),
        es,
      );
      expect(_row(csv, '2026-10-06'), '2026-10-06;martes;;;;;');
      expect(csv, isNot(contains('Ausencia')));
    });

    test('detailed: the name shows only when asked', () {
      final csv = reportCsvText(
        octoberReport(
          options: const ReportOptions(
            absences: ReportAbsenceMode.detailed,
            includeNotes: true,
          ),
        ),
        es,
      );
      expect(csv, contains(secretLeaveName));
      expect(csv, contains(secretLeaveNote));
    });
  });

  group('notes column and escaping', () {
    final csv = reportCsvText(
      octoberReport(options: const ReportOptions(includeNotes: true)),
      es,
    );

    test('only with notes', () {
      expect(_lines(csv).first, endsWith(';Nota'));
      expect(
        _lines(reportCsvText(octoberReport(), es)).first,
        isNot(contains('Nota')),
      );
    });

    test('a note with the separator, quotes and a comma is quoted', () {
      expect(
        _row(csv, '2026-10-12'),
        '2026-10-12;lunes;Mañana;M;06:00;14:00;8;'
        '"Cambio con Ana, ""urgente""; llevar llaves"',
      );
    });

    test('a line break stays inside its quoted cell', () {
      final text = reportCsvText(
        _oneDay(
          _withNote('uno\ndos'),
          options: const ReportOptions(includeNotes: true),
        ),
        es,
      );
      expect(text, contains('"uno\ndos"'));
      // Header + one record, each ended by CRLF.
      expect('\r\n'.allMatches(text), hasLength(2));
    });

    test('an equals sign, plus, minus or at sign never starts a formula', () {
      for (final bad in ['=SUMA(A1)', '+34600', '-1', '@usuario']) {
        final text = reportCsvText(
          _oneDay(
            _withNote(bad),
            options: const ReportOptions(includeNotes: true),
          ),
          es,
        );
        expect(text, contains(";'$bad"), reason: bad);
      }
    });

    test('a shift named like a formula is defused too', () {
      final schedule = Schedule(
        shiftTypes: const [
          ShiftType(
            id: 'x',
            code: '=1',
            name: '=HYPERLINK("http://x")',
            colorValue: 0xFF000000,
            category: ShiftCategory.work,
          ),
        ],
        entries: {_oct1: const DayEntry(date: _oct1, shiftTypeIds: ['x'])},
      );
      final text = reportCsvText(_oneDay(schedule), es);
      expect(text, contains('"\'=HYPERLINK(""http://x"")"'));
      expect(text, contains(";'=1;"));
    });
  });

  group('separators of the locale', () {
    test('English: comma and point', () {
      final en = spanishStrings(delimiter: ',', decimal: '.');
      final csv = reportCsvText(octoberReport(), en);
      expect(
        csv.split('\r\n').first,
        'Fecha,Día,Turno,Código,Inicio,Fin,Horas',
      );
      expect(csv, contains('2026-10-01,jueves,Mañana,M,06:00,14:00,8\r\n'));
    });

    test('the separators follow the decimal mark', () {
      expect(csvSeparatorsFor(','), (delimiter: ';', decimal: ','));
      expect(csvSeparatorsFor('.'), (delimiter: ',', decimal: '.'));
      expect(csvSeparatorsFor('٫'), (delimiter: ',', decimal: '.'));
    });

    test('a name with the delimiter is quoted', () {
      final schedule = Schedule(
        shiftTypes: const [
          ShiftType(
            id: 'x',
            code: 'X',
            name: 'Tarde; refuerzo',
            colorValue: 0xFF000000,
            category: ShiftCategory.work,
            startMinute: 900,
            endMinute: 1380,
          ),
        ],
        entries: {_oct1: const DayEntry(date: _oct1, shiftTypeIds: ['x'])},
      );
      final model = _oneDay(schedule);
      expect(reportCsvText(model, es), contains('"Tarde; refuerzo"'));
      // With a comma delimiter the semicolon needs no quotes.
      expect(
        reportCsvText(model, spanishStrings(delimiter: ',', decimal: '.')),
        contains(',Tarde; refuerzo,'),
      );
    });

    test('half hours use the decimal mark of the locale', () {
      final schedule = Schedule(
        shiftTypes: const [
          ShiftType(
            id: 'x',
            code: 'X',
            name: 'Corto',
            colorValue: 0xFF000000,
            category: ShiftCategory.work,
            startMinute: 480,
            endMinute: 930,
          ),
        ],
        entries: {_oct1: const DayEntry(date: _oct1, shiftTypeIds: ['x'])},
      );
      final model = _oneDay(schedule);
      expect(reportCsvText(model, es), endsWith(';7,5\r\n'));
      expect(
        reportCsvText(model, spanishStrings(delimiter: ',', decimal: '.')),
        endsWith(',7.5\r\n'),
      );
    });
  });

  group('decimal hours', () {
    test('at most two decimals, no trailing zeros', () {
      expect(decimalHours(0, ','), '0');
      expect(decimalHours(60, ','), '1');
      expect(decimalHours(450, ','), '7,5');
      expect(decimalHours(450, '.'), '7.5');
      expect(decimalHours(500, ','), '8,33');
      expect(decimalHours(1, ','), '0,02');
      expect(decimalHours(1440, ','), '24');
      expect(decimalHours(9 * 60 + 15, ','), '9,25');
    });

    test('clock24 wraps 24:00', () {
      expect(clock24(0), '00:00');
      expect(clock24(1440), '00:00');
      expect(clock24(1399), '23:19');
    });
  });
}
