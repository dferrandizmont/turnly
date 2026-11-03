import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:cuadrante/features/summary/domain/month_summary.dart';
import 'package:flutter_test/flutter_test.dart';

// A4: overtime and early leave placed on the clock, so the night and holiday
// hours agree with the total (docs/motor-de-turnos.md, «Resumen del mes»).
// Early leave cuts the end of the day's last shift (backwards if longer);
// overtime goes right after the end of the last shift.

const _h = 60;

ShiftType _shift(
  String id, {
  required int start,
  required int end,
  int? start2,
  int? duration2,
  int? paid,
  bool? night,
  int? rate,
  bool times = true,
}) => ShiftType(
  id: id,
  code: id.substring(0, 1).toUpperCase(),
  name: id,
  colorValue: 0xFF336699,
  category: ShiftCategory.work,
  startMinute: times ? start : null,
  endMinute: times ? end : null,
  segment2StartMinute: start2,
  segment2DurationMinutes: duration2,
  paidMinutes: paid,
  nightOverride: night,
  hourlyRateCents: rate,
);

final _night = _shift('night', start: 22 * _h, end: 6 * _h, rate: 1000);
final _morning = _shift('morning', start: 6 * _h, end: 14 * _h);
final _afternoon = _shift('afternoon', start: 14 * _h, end: 22 * _h);
final _late = _shift('late', start: 15 * _h, end: 23 * _h);
// 18-22 + 23-03: 8 h, 4 h of them at night.
final _split = _shift(
  'split',
  start: 18 * _h,
  end: 22 * _h,
  start2: 23 * _h,
  duration2: 4 * _h,
);
// 22:00-06:30 with 30 min unpaid: 8 h paid out of 8 h 30.
final _nightBreak = _shift(
  'nightbreak',
  start: 22 * _h,
  end: 6 * _h + 30,
  paid: 8 * _h,
);
// A day guard marked as night in full, and a night marked as no night.
final _allNight = _shift('allnight', start: 8 * _h, end: 20 * _h, night: true);
final _noNight = _shift('nonight', start: 22 * _h, end: 6 * _h, night: false);
final _noTimes = _shift('untimed', start: 0, end: 0, times: false);

final _types = [
  _night,
  _morning,
  _afternoon,
  _late,
  _split,
  _nightBreak,
  _allNight,
  _noNight,
  _noTimes,
];

MonthSummary _day(
  CivilDate date,
  List<String> shifts, {
  int? overtime,
  int? early,
  Set<CivilDate> holidays = const {},
  NightWindow window = const NightWindow(),
}) => summarizeRange(
  Schedule(
    shiftTypes: _types,
    entries: {
      date: DayEntry(
        date: date,
        shiftTypeIds: shifts,
        overtimeMinutes: overtime,
        earlyLeaveMinutes: early,
      ),
    },
  ),
  date,
  date,
  holidays: holidays,
  window: window,
);

const _oct7 = CivilDate(2026, 10, 7);

/// Every partial figure stays within the total.
void _consistent(MonthSummary s) {
  expect(s.nightMinutes, lessThanOrEqualTo(s.workedMinutes), reason: 'night');
  expect(
    s.holidayMinutes,
    lessThanOrEqualTo(s.workedMinutes),
    reason: 'holiday',
  );
  expect(s.dayMinutes + s.nightMinutes, s.workedMinutes, reason: 'day+night');
  expect(
    s.shiftMinutes + s.overtimeMinutes - s.earlyLeaveMinutes,
    s.workedMinutes,
  );
}

void main() {
  group('early leave cuts the end of the last shift', () {
    test('Noche 22-06 with 1 h of early leave: 7 h, 7 of them at night', () {
      final s = _day(_oct7, ['night'], early: 60);
      expect(s.workedMinutes, 7 * _h);
      expect(s.nightMinutes, 7 * _h);
      expect(s.dayMinutes, 0);
      _consistent(s);
    });

    test('a 15-23 shift that leaves 1 h early loses its night hour', () {
      final s = _day(_oct7, ['late'], early: 60);
      expect(s.workedMinutes, 7 * _h);
      expect(s.nightMinutes, 0);
      final plain = _day(_oct7, ['late']);
      expect(plain.nightMinutes, 1 * _h);
    });

    test('more than the shift is capped: 0 h and 0 night hours', () {
      final s = _day(_oct7, ['night'], early: 9 * _h);
      expect(s.earlyLeaveMinutes, 8 * _h);
      expect(s.workedMinutes, 0);
      expect(s.nightMinutes, 0);
      _consistent(s);
    });

    test('longer than the last shift: goes on into the one before', () {
      // Tarde 14-22 and Noche 22-06 the same day; left 9 h early: the night
      // goes in full and the afternoon ends at 21:00.
      final s = _day(_oct7, ['afternoon', 'night'], early: 9 * _h);
      expect(s.workedMinutes, 7 * _h);
      expect(s.nightMinutes, 0);
      _consistent(s);
      // Before A4 this day said 7 h worked and 8 h at night.
    });

    test('the last shift is the one that ends last, whatever the order', () {
      // Noche listed first, Mañana second: the night still ends last.
      final s = _day(_oct7, ['night', 'morning'], early: 2 * _h);
      expect(s.workedMinutes, 14 * _h);
      expect(s.nightMinutes, 6 * _h);
      _consistent(s);
    });

    test('a split shift loses the end of its second segment first', () {
      // 18-22 + 23-03; 1 h early: 23-02, so 3 h at night.
      final one = _day(_oct7, ['split'], early: 60);
      expect(one.workedMinutes, 7 * _h);
      expect(one.nightMinutes, 3 * _h);
      _consistent(one);
      // 5 h early: the second segment goes and the first ends at 21:00.
      final five = _day(_oct7, ['split'], early: 5 * _h);
      expect(five.workedMinutes, 3 * _h);
      expect(five.nightMinutes, 0);
      _consistent(five);
    });

    test('with an unpaid break the cut minutes are paid minutes', () {
      // 22:00-06:30 paying 8 h; 1 h early: 22:00-05:30 paying 7 h.
      final s = _day(_oct7, ['nightbreak'], early: 60);
      expect(s.workedMinutes, 7 * _h);
      expect(s.nightMinutes, 7 * _h);
      _consistent(s);
      // All of it: nothing paid, nothing at night.
      final all = _day(_oct7, ['nightbreak'], early: 8 * _h);
      expect(all.workedMinutes, 0);
      expect(all.nightMinutes, 0);
    });

    test('the figures per type are the shift as scheduled', () {
      final s = _day(_oct7, ['night'], early: 60);
      final night = s.types.single;
      expect(night.paidMinutes, 8 * _h);
      expect(night.nightMinutes, 8 * _h);
    });
  });

  group('overtime goes right after the last shift', () {
    test('after Noche 22-06 it is 06-07: a day hour', () {
      final s = _day(_oct7, ['night'], overtime: 60);
      expect(s.workedMinutes, 9 * _h);
      expect(s.nightMinutes, 8 * _h);
      expect(s.dayMinutes, 1 * _h);
      _consistent(s);
    });

    test('after Tarde 14-22 it is night', () {
      final s = _day(_oct7, ['afternoon'], overtime: 2 * _h);
      expect(s.workedMinutes, 10 * _h);
      expect(s.nightMinutes, 2 * _h);
      _consistent(s);
    });

    test('after the shift that ends last, not after the first one listed', () {
      // Tarde listed before Mañana: the overtime follows the Tarde (22-23).
      final s = _day(_oct7, ['afternoon', 'morning'], overtime: 60);
      expect(s.nightMinutes, 1 * _h);
    });

    test('after the second segment of a split shift (03-04, night)', () {
      final s = _day(_oct7, ['split'], overtime: 60);
      expect(s.workedMinutes, 9 * _h);
      expect(s.nightMinutes, 5 * _h);
      _consistent(s);
    });

    test('takes the night override of the shift it extends', () {
      final all = _day(_oct7, ['allnight'], overtime: 60);
      expect(all.nightMinutes, 13 * _h);
      final none = _day(_oct7, ['nonight'], overtime: 60);
      expect(none.nightMinutes, 0);
      _consistent(all);
      _consistent(none);
    });

    test('with no work shift with a schedule it stays as day hours', () {
      final untimed = _day(_oct7, ['untimed'], overtime: 2 * _h);
      expect(untimed.workedMinutes, 2 * _h);
      expect(untimed.nightMinutes, 0);
      final empty = _day(_oct7, const [], overtime: 2 * _h, holidays: {_oct7});
      expect(empty.workedMinutes, 2 * _h);
      expect(empty.holidayMinutes, 0);
      expect(empty.holidayShifts, 0);
    });
  });

  group('overtime and early leave on the same day', () {
    test('the early leave takes the overtime first', () {
      // Noche + 1 h overtime (22-07) - 2 h early: 22-05.
      final s = _day(_oct7, ['night'], overtime: 60, early: 2 * _h);
      expect(s.workedMinutes, 7 * _h);
      expect(s.nightMinutes, 7 * _h);
      _consistent(s);
    });

    test('equal amounts leave the shift as it was', () {
      final s = _day(_oct7, ['afternoon'], overtime: 90, early: 90);
      expect(s.workedMinutes, 8 * _h);
      expect(s.nightMinutes, 0);
    });

    test('with no shift the early leave only takes the overtime', () {
      final s = _day(_oct7, const [], overtime: 60, early: 90);
      expect(s.earlyLeaveMinutes, 60);
      expect(s.workedMinutes, 0);
      expect(s.nightMinutes, 0);
      _consistent(s);
    });
  });

  group('holidays', () {
    const eve = CivilDate(2026, 12, 24);
    const christmas = CivilDate(2026, 12, 25);

    test('a night into a holiday loses the holiday part it did not work', () {
      final plain = _day(eve, ['night'], holidays: {christmas});
      expect(plain.holidayMinutes, 6 * _h);
      expect(plain.holidayShifts, 1);
      final one = _day(eve, ['night'], early: 60, holidays: {christmas});
      expect(one.holidayMinutes, 5 * _h);
      expect(one.holidayShifts, 1);
      _consistent(one);
      // Leaving at midnight: nothing worked on the holiday.
      final six = _day(eve, ['night'], early: 6 * _h, holidays: {christmas});
      expect(six.workedMinutes, 2 * _h);
      expect(six.holidayMinutes, 0);
      expect(six.holidayShifts, 0);
    });

    test('overtime on the holiday counts, the shift still counts once', () {
      final s = _day(eve, ['night'], overtime: 60, holidays: {christmas});
      expect(s.holidayMinutes, 7 * _h);
      expect(s.holidayShifts, 1);
      _consistent(s);
    });

    test('overtime that runs past midnight into a holiday', () {
      // Tarde 14-22 on the 24th + 3 h: 22-01, one hour on the 25th.
      final s = _day(
        eve,
        ['afternoon'],
        overtime: 3 * _h,
        holidays: {christmas},
      );
      expect(s.holidayMinutes, 1 * _h);
      expect(s.holidayShifts, 1);
      expect(s.nightMinutes, 3 * _h);
      _consistent(s);
    });

    test('a holiday shift that leaves early has fewer holiday hours', () {
      final s = _day(christmas, ['morning'], early: 90, holidays: {christmas});
      expect(s.holidayMinutes, 6 * _h + 30);
      expect(s.workedMinutes, 6 * _h + 30);
    });

    test('a split shift into a holiday, cut and extended', () {
      // 18-22 + 23-03 on the 24th: 3 h on the 25th.
      final cut = _day(eve, ['split'], early: 2 * _h, holidays: {christmas});
      expect(cut.holidayMinutes, 1 * _h);
      final longer = _day(eve, ['split'], overtime: 60, holidays: {christmas});
      expect(longer.holidayMinutes, 4 * _h);
      expect(longer.holidayShifts, 1);
      _consistent(cut);
      _consistent(longer);
    });
  });

  group('the night window', () {
    test('a custom window is used for the adjusted pieces', () {
      const window = NightWindow(startMinute: 23 * _h, endMinute: 7 * _h);
      final early = _day(_oct7, ['night'], early: 60, window: window);
      // 22-05 against 23-07: 6 h.
      expect(early.nightMinutes, 6 * _h);
      final overtime = _day(_oct7, ['night'], overtime: 60, window: window);
      // 22-07 against 23-07: 8 h.
      expect(overtime.nightMinutes, 8 * _h);
      _consistent(early);
      _consistent(overtime);
    });
  });

  group('daylight saving nights (civil clock hours)', () {
    test('October: the night of the change is not corrected', () {
      const saturday = CivilDate(2026, 10, 24);
      final early = _day(saturday, ['night'], early: 60);
      expect(early.workedMinutes, 7 * _h);
      expect(early.nightMinutes, 7 * _h);
      final overtime = _day(saturday, ['night'], overtime: 60);
      expect(overtime.workedMinutes, 9 * _h);
      expect(overtime.nightMinutes, 8 * _h);
    });

    test('March: the same, on clock hours', () {
      const saturday = CivilDate(2026, 3, 28);
      final early = _day(saturday, ['night'], early: 60);
      expect(early.workedMinutes, 7 * _h);
      expect(early.nightMinutes, 7 * _h);
      final overtime = _day(saturday, ['afternoon'], overtime: 60);
      expect(overtime.nightMinutes, 1 * _h);
    });
  });

  group('no figure exceeds the total', () {
    const christmas = CivilDate(2026, 12, 25);
    final days = <List<String>>[
      ['night'],
      ['late'],
      ['split'],
      ['nightbreak'],
      ['allnight'],
      ['afternoon', 'night'],
      ['morning', 'afternoon'],
      ['untimed', 'night'],
      [],
    ];
    for (final shifts in days) {
      for (final overtime in [0, 30, 120, 600]) {
        for (final early in [0, 45, 300, 1200]) {
          test('$shifts +$overtime -$early', () {
            for (final date in [const CivilDate(2026, 12, 24), christmas]) {
              _consistent(
                _day(
                  date,
                  shifts,
                  overtime: overtime,
                  early: early,
                  holidays: {christmas},
                ),
              );
            }
          });
        }
      }
    }
  });

  test('a month adds up its days', () {
    final schedule = Schedule(
      shiftTypes: _types,
      entries: {
        const CivilDate(2026, 10, 5): const DayEntry(
          date: CivilDate(2026, 10, 5),
          shiftTypeIds: ['night'],
          earlyLeaveMinutes: 60,
        ),
        const CivilDate(2026, 10, 6): const DayEntry(
          date: CivilDate(2026, 10, 6),
          shiftTypeIds: ['afternoon'],
          overtimeMinutes: 120,
        ),
      },
    );
    final month = summarizeMonth(schedule, const CivilDate(2026, 10, 1));
    expect(month.workedMinutes, 7 * _h + 10 * _h);
    expect(month.nightMinutes, 7 * _h + 2 * _h);
    expect(month.overtimeMinutes, 120);
    expect(month.earlyLeaveMinutes, 60);
    // 7 h of Noche at 10 EUR/h: the euros follow the hours as before.
    expect(month.earningsCents, 8000 - 1000);
    _consistent(month);
  });
}
