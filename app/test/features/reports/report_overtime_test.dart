import 'package:cuadrante/features/reports/data/csv_writer.dart';
import 'package:cuadrante/features/reports/domain/report_model.dart';
import 'package:cuadrante/features/reports/domain/report_options.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:cuadrante/features/summary/domain/summary_range.dart';
import 'package:flutter_test/flutter_test.dart';

import 'report_fixtures.dart';

// The blocks of extra hours in the reports (schema v7): the day lists them
// with their type and pay, the CSV writes them in a column of their own and
// a note only travels when the notes do.

const _day = CivilDate(2026, 10, 1);

const _shift = ShiftType(
  id: 'M',
  code: 'M',
  name: 'Mañana',
  colorValue: 0xFFF5A524,
  category: ShiftCategory.work,
  startMinute: 360,
  endMinute: 840,
  hourlyRateCents: 1000,
);

ReportModel _report(ReportOptions options) => buildReport(
  schedule: Schedule(
    shiftTypes: const [_shift],
    entries: {
      _day: const DayEntry(
        date: _day,
        shiftTypeIds: ['M'],
        overtimeBlocks: [
          OvertimeBlock(
            id: 'a',
            date: _day,
            typeId: overtimeTypeId,
            startMinute: 840,
            endMinute: 960,
            note: 'Inventario',
          ),
          OvertimeBlock(
            id: 'b',
            date: _day,
            typeId: otherWorkTypeId,
            startMinute: 1080,
            endMinute: 1200,
          ),
        ],
      ),
    },
  ),
  range: const SummaryRange(_day, _day),
  calendarName: 'Hospital',
  holidays: const {},
  today: const CivilDate(2026, 11, 1),
  options: options,
);

void main() {
  test('the day lists its blocks, priced only with the earnings', () {
    final priced = _report(const ReportOptions(includeEarnings: true));
    final day = priced.days.single;
    expect(day.workedMinutes, 8 * 60 + 4 * 60);
    expect(day.overtimeMinutes, 240);
    expect(
      [for (final o in day.overtimeBlocks) (o.type.id, o.amountCents)],
      [(overtimeTypeId, 2000), (otherWorkTypeId, null)],
    );
    // Without the notes, the note of the block stays out.
    expect(day.overtimeBlocks.first.block.note, isNull);
    final plain = _report(const ReportOptions());
    expect(plain.days.single.overtimeBlocks.first.amountCents, isNull);
  });

  test('the CSV has an overtime column with each block', () {
    final model = _report(
      const ReportOptions(includeEarnings: true, includeNotes: true),
    );
    final csv = reportCsvText(model, spanishStrings());
    final [header, row, ...] = csv.split('\r\n');
    expect(header, contains('Horas extra'));
    expect(row, contains('Horas extra 14:00–16:00 · 2 h 0 min · 20.0 EUR'));
    expect(row, contains('Inventario'));
    expect(row, contains('Otro trabajo 18:00–20:00 · 2 h 0 min'));
  });

  test('a CSV without blocks has no overtime column', () {
    final csv = reportCsvText(octoberReport(), spanishStrings());
    expect(csv.split('\r\n').first, isNot(contains('Horas extra')));
  });
}
