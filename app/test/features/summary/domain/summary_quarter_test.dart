import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:cuadrante/features/summary/domain/summary_range.dart';
import 'package:flutter_test/flutter_test.dart';

// The quarter shortcut of the summary (P9, fila 18 de
// `docs/paridad-pago.md`): T1 to T4 of the civil year.

void main() {
  test('the four quarters of a year', () {
    expect(
      Quarter.first.rangeOf(2026),
      const SummaryRange(CivilDate(2026, 1, 1), CivilDate(2026, 3, 31)),
    );
    expect(
      Quarter.second.rangeOf(2026),
      const SummaryRange(CivilDate(2026, 4, 1), CivilDate(2026, 6, 30)),
    );
    expect(
      Quarter.third.rangeOf(2026),
      const SummaryRange(CivilDate(2026, 7, 1), CivilDate(2026, 9, 30)),
    );
    expect(
      Quarter.fourth.rangeOf(2026),
      const SummaryRange(CivilDate(2026, 10, 1), CivilDate(2026, 12, 31)),
    );
  });

  test('the quarters cover the year without gaps', () {
    for (final year in [2024, 2025, 2026]) {
      var expected = CivilDate(year, 1, 1);
      for (final quarter in Quarter.values) {
        final range = quarter.rangeOf(year);
        expect(range.from, expected);
        expect(range.days, range.to.differenceInDays(range.from) + 1);
        expect(range.isValid, isTrue);
        expected = range.to.addDays(1);
      }
      expect(expected, CivilDate(year + 1, 1, 1));
    }
  });

  test('the factory builds the same range', () {
    expect(
      SummaryRange.quarter(2026, Quarter.third),
      Quarter.third.rangeOf(2026),
    );
  });

  test('the days of the quarter', () {
    // T1 of a common year: 90 days; a leap year: 91.
    expect(Quarter.first.rangeOf(2026).days, 90);
    expect(Quarter.first.rangeOf(2024).days, 91);
    expect(Quarter.second.rangeOf(2026).days, 91);
    expect(Quarter.third.rangeOf(2026).days, 92);
    expect(Quarter.fourth.rangeOf(2026).days, 92);
  });
}
