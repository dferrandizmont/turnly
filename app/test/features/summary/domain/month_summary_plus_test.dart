import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:cuadrante/features/summary/domain/month_summary.dart';
import 'package:flutter_test/flutter_test.dart';

const _first = CivilDate(2026, 10, 1);

ShiftType _type(
  String id, {
  int? start,
  int? end,
  int? rate,
  int? nightPlus,
  int? holidayPlus,
  int? paidMinutes,
  int? segment2Start,
  int? segment2Duration,
  ShiftCategory category = ShiftCategory.work,
}) => ShiftType(
  id: id,
  code: id,
  name: id,
  colorValue: 0xFF4B4FD1,
  category: category,
  startMinute: start,
  endMinute: end,
  paidMinutes: paidMinutes,
  hourlyRateCents: rate,
  nightPlusCentsPerHour: nightPlus,
  holidayPlusCentsPerHour: holidayPlus,
  segment2StartMinute: segment2Start,
  segment2DurationMinutes: segment2Duration,
);

/// A night shift of 8 h (22:00-06:00).
ShiftType _night({int? rate, int? nightPlus, int? holidayPlus}) => _type(
  'N',
  start: 22 * 60,
  end: 6 * 60,
  rate: rate,
  nightPlus: nightPlus,
  holidayPlus: holidayPlus,
);

Schedule _schedule(
  List<ShiftType> types,
  List<DayEntry> entries, {
  Map<String, List<ShiftTypeVersion>> versions = const {},
}) => Schedule(
  shiftTypes: types,
  entries: {for (final entry in entries) entry.date: entry},
  shiftTypeVersions: versions,
);

DayEntry _day(
  int day, [
  List<String> ids = const ['N'],
  Map<String, Object?> extra = const {},
]) => DayEntry(
  date: CivilDate(2026, 10, day),
  shiftTypeIds: ids,
  extraAmountCents: extra['extra'] as int?,
);

void main() {
  group('the night plus', () {
    test('is added over the night hours of the shift', () {
      final schedule = _schedule(
        [_night(rate: 1000, nightPlus: 150)],
        [_day(1)],
      );
      final summary = summarizeMonth(schedule, _first);
      expect(summary.workedMinutes, 480);
      expect(summary.nightMinutes, 480);
      // 8 h x 1,50 = 12,00.
      expect(summary.nightPlusCents, 1200);
      // 8 h x 10,00 = 80,00, plus the night plus.
      expect(summary.earningsCents, 8000 + 1200);
      expect(summary.types.single.earningsCents, 8000);
      expect(summary.types.single.nightPlusCents, 1200);
      expect(summary.types.single.totalCents, 9200);
    });

    test('counts the night after midnight of a shift that crosses it', () {
      // 23:00-07:00: seven of its eight hours are inside the night window.
      final schedule = _schedule(
        [_type('N', start: 23 * 60, end: 7 * 60, rate: 1000, nightPlus: 150)],
        [_day(1)],
      );
      final summary = summarizeMonth(schedule, _first);
      expect(summary.workedMinutes, 480);
      expect(summary.nightMinutes, 420);
      expect(summary.nightPlusCents, 1050);
    });

    test('counts the night of a 24 h guard', () {
      final schedule = _schedule(
        [_type('N', start: 0, end: 0, rate: 1000, nightPlus: 150)],
        [_day(1)],
      );
      final summary = summarizeMonth(schedule, _first);
      expect(summary.workedMinutes, 1440);
      expect(summary.nightMinutes, 480);
      expect(summary.nightPlusCents, 1200);
    });

    test('counts the night of both segments of a split shift', () {
      // 20:00-23:00 (an hour of night) and 01:00-04:00 (three hours of
      // night): four night hours in all.
      final schedule = _schedule(
        [
          _type(
            'N',
            start: 20 * 60,
            end: 23 * 60,
            rate: 1000,
            nightPlus: 150,
            segment2Start: 60,
            segment2Duration: 180,
          ),
        ],
        [_day(1)],
      );
      final summary = summarizeMonth(schedule, _first);
      expect(summary.workedMinutes, 360);
      expect(summary.nightMinutes, 240);
      expect(summary.nightPlusCents, 600);
    });

    test('is not paid on the hours outside the night window', () {
      final schedule = _schedule(
        [_type('N', start: 8 * 60, end: 16 * 60, rate: 1000, nightPlus: 150)],
        [_day(1)],
      );
      final summary = summarizeMonth(schedule, _first);
      expect(summary.nightMinutes, 0);
      expect(summary.nightPlusCents, 0);
      expect(summary.earningsCents, 8000);
    });

    test('counts less when the shift ends early', () {
      // The early leave cuts the end of the shift (A4), so the night hours
      // (and the money of them) are those of the hours really worked.
      final schedule = _schedule(
        [_night(rate: 1000, nightPlus: 150)],
        [
          DayEntry(
            date: const CivilDate(2026, 10, 1),
            shiftTypeIds: const ['N'],
            earlyLeaveMinutes: 120,
          ),
        ],
      );
      final summary = summarizeMonth(schedule, _first);
      expect(summary.workedMinutes, 360);
      expect(summary.nightMinutes, 360);
      expect(summary.nightPlusCents, 900);
      expect(summary.earningsCents, 6000 + 900);
    });

    test('counts the night of the hours extra of the day', () {
      // The overtime goes right after the end of the last shift (A4), so it
      // is night too when the shift ends inside the night window.
      final schedule = _schedule(
        [_type('N', start: 20 * 60, end: 23 * 60, rate: 1000, nightPlus: 150)],
        [
          DayEntry(
            date: const CivilDate(2026, 10, 1),
            shiftTypeIds: const ['N'],
            overtimeMinutes: 120,
          ),
        ],
      );
      final summary = summarizeMonth(schedule, _first);
      expect(summary.workedMinutes, 300);
      expect(summary.nightMinutes, 180);
      expect(summary.nightPlusCents, 450);
    });

    test('is not paid on a rest or an absence', () {
      final schedule = _schedule(
        [
          _type(
            'L',
            start: 22 * 60,
            end: 6 * 60,
            nightPlus: 150,
            category: ShiftCategory.rest,
          ),
        ],
        [
          _day(1, ['L']),
        ],
      );
      final summary = summarizeMonth(schedule, _first);
      expect(summary.nightPlusCents, 0);
      expect(summary.earningsCents, isNull);
    });
  });

  group('the holiday plus', () {
    test('is added over the holiday hours of the shift', () {
      final schedule = _schedule(
        [_type('M', start: 8 * 60, end: 16 * 60, rate: 1000, holidayPlus: 200)],
        [
          _day(12, ['M']),
        ],
      );
      final summary = summarizeMonth(
        schedule,
        _first,
        holidays: {const CivilDate(2026, 10, 12)},
      );
      expect(summary.holidayMinutes, 480);
      expect(summary.holidayPlusCents, 1600);
      expect(summary.earningsCents, 8000 + 1600);
    });

    test('only counts the part of the shift on the holiday', () {
      // A night shift of the 12th: two of its eight hours are on the
      // holiday, the other six on the 13th.
      final schedule = _schedule(
        [_night(rate: 1000, holidayPlus: 200)],
        [_day(12)],
      );
      final summary = summarizeMonth(
        schedule,
        _first,
        holidays: {const CivilDate(2026, 10, 12)},
      );
      expect(summary.holidayMinutes, 120);
      expect(summary.holidayPlusCents, 400);
    });

    test('is not paid on a day that is not a holiday', () {
      final schedule = _schedule(
        [_type('M', start: 8 * 60, end: 16 * 60, rate: 1000, holidayPlus: 200)],
        [
          _day(12, ['M']),
        ],
      );
      final summary = summarizeMonth(schedule, _first);
      expect(summary.holidayMinutes, 0);
      expect(summary.holidayPlusCents, 0);
      expect(summary.earningsCents, 8000);
    });
  });

  group('the history of the type', () {
    test('each day uses the pluses of the terms it had', () {
      final current = _night(rate: 1000, nightPlus: 300);
      final schedule = _schedule(
        [current],
        [_day(1), _day(15)],
        versions: {
          'N': [
            ShiftTypeVersion(
              until: const CivilDate(2026, 10, 10),
              terms: ShiftTerms(
                category: ShiftCategory.work,
                startMinute: 22 * 60,
                endMinute: 6 * 60,
                hourlyRateCents: 1000,
                nightPlusCentsPerHour: 150,
              ),
            ),
          ],
        },
      );
      final summary = summarizeMonth(schedule, _first);
      // The 1st at 1,50 (1.200) and the 15th at 3,00 (2.400).
      expect(summary.nightPlusCents, 1200 + 2400);
      expect(summary.earningsCents, 2 * 8000 + 3600);
    });
  });

  group('the extra amount of the day', () {
    test('is added to the totals of the month and of the range', () {
      final schedule = _schedule(
        [_night(rate: 1000)],
        [
          _day(1),
          _day(5, ['N'], {'extra': 2500}),
        ],
      );
      final summary = summarizeMonth(schedule, _first);
      expect(summary.extraAmountCents, 2500);
      expect(summary.earningsCents, 2 * 8000 + 2500);
      final range = summarizeRange(
        schedule,
        const CivilDate(2026, 10, 5),
        const CivilDate(2026, 10, 5),
      );
      expect(range.extraAmountCents, 2500);
      expect(range.earningsCents, 8000 + 2500);
      expect(summarizeYearTotals(schedule, 2026).extraAmountCents, 2500);
    });

    test('can be a deduction', () {
      final schedule = _schedule(
        [_night(rate: 1000)],
        [
          _day(1, ['N'], {'extra': -1000}),
        ],
      );
      final summary = summarizeMonth(schedule, _first);
      expect(summary.extraAmountCents, -1000);
      expect(summary.earningsCents, 8000 - 1000);
    });

    test('is nothing without an extra amount', () {
      final schedule = _schedule([_night(rate: 1000)], [_day(1)]);
      final summary = summarizeMonth(schedule, _first);
      expect(summary.extraAmountCents, 0);
      expect(summary.earningsCents, 8000);
    });
  });

  test('the pluses of the types add up to the month (without day extras)', () {
    final schedule = _schedule(
      [
        _night(rate: 1000, nightPlus: 150, holidayPlus: 200),
        _type('M', start: 8 * 60, end: 16 * 60, rate: 1000, nightPlus: 100),
      ],
      [
        _day(1),
        _day(12, ['M']),
      ],
    );
    final summary = summarizeMonth(
      schedule,
      _first,
      holidays: {const CivilDate(2026, 10, 12)},
    );
    final types = summary.types;
    expect(
      types.fold(0, (sum, t) => sum + t.nightPlusCents),
      summary.nightPlusCents,
    );
    expect(
      types.fold(0, (sum, t) => sum + t.holidayPlusCents),
      summary.holidayPlusCents,
    );
    expect(
      types.fold<int>(0, (sum, t) => sum + (t.totalCents ?? 0)) +
          summary.fixedPlusCents,
      summary.earningsCents,
    );
  });
}
