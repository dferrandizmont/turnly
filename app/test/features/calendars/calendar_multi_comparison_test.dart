import 'package:cuadrante/features/calendars/domain/calendar.dart';
import 'package:cuadrante/features/calendars/domain/calendar_comparison.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:flutter_test/flutter_test.dart';

const _work = ShiftType(
  id: 'work',
  code: 'M',
  name: 'Mañana',
  colorValue: 0xFFF5A524,
  category: ShiftCategory.work,
  startMinute: 6 * 60,
  endMinute: 14 * 60,
);
const _night = ShiftType(
  id: 'night',
  code: 'N',
  name: 'Noche',
  colorValue: 0xFF4B4FD1,
  category: ShiftCategory.work,
  startMinute: 22 * 60,
  endMinute: 6 * 60,
);
const _rest = ShiftType(
  id: 'rest',
  code: 'L',
  name: 'Libre',
  colorValue: 0xFFE4E4E7,
  category: ShiftCategory.rest,
);
const _vacation = ShiftType(
  id: 'vacation',
  code: 'V',
  name: 'Vacaciones',
  colorValue: 0xFF30A46C,
  category: ShiftCategory.absence,
);

const _types = [_work, _night, _rest, _vacation];

/// Pairs each calendar with its schedule, as [compareCalendars] takes them.
List<({Calendar calendar, Schedule schedule})> _rows(
  List<Calendar> calendars,
  List<Schedule> schedules,
) => [
  for (var i = 0; i < calendars.length; i++)
    (calendar: calendars[i], schedule: schedules[i]),
];

/// A schedule made of single-day entries (`date -> shift ids`), every other
/// day empty.
Schedule _days(Map<CivilDate, List<String>> days) => Schedule(
  shiftTypes: _types,
  entries: {
    for (final e in days.entries)
      e.key: DayEntry(date: e.key, shiftTypeIds: e.value),
  },
);

/// October 2026: the 1st is a Thursday, so the 3rd and the 4th are a Saturday
/// and a Sunday, and the 24th and the 25th too.
CivilDate _oct(int day) => CivilDate(2026, 10, day);

const _c1 = Calendar(id: 'c1', name: 'Uno', colorValue: 1, sortOrder: 0);
const _c2 = Calendar(id: 'c2', name: 'Dos', colorValue: 2, sortOrder: 1);
const _c3 = Calendar(id: 'c3', name: 'Tres', colorValue: 3, sortOrder: 2);
const _c4 = Calendar(id: 'c4', name: 'Cuatro', colorValue: 4, sortOrder: 3);
const _c5 = Calendar(id: 'c5', name: 'Cinco', colorValue: 5, sortOrder: 4);
const _c6 = Calendar(id: 'c6', name: 'Seis', colorValue: 6, sortOrder: 5);

/// Three calendars with a story: A works the 3rd and the 5th and rests the
/// 4th, the 10th, the 11th, the 24th and the 25th; B rests the 4th, works
/// the 10th, is on vacation the 11th and rests the 17th, the 24th and the
/// 25th; C works the 4th, is on vacation the 10th, has nothing the 11th and
/// rests the 17th, the 18th, the 24th and the 25th.
final _a = _days({
  _oct(3): ['work'],
  _oct(4): ['rest'],
  _oct(5): ['work'],
  _oct(10): ['rest'],
  _oct(11): ['rest'],
  _oct(24): ['rest'],
  _oct(25): ['rest'],
});
final _b = _days({
  _oct(4): ['rest'],
  _oct(10): ['work'],
  _oct(11): ['vacation'],
  _oct(17): ['rest'],
  _oct(24): ['rest'],
  _oct(25): ['rest'],
});
final _c = _days({
  _oct(4): ['work'],
  _oct(10): ['vacation'],
  _oct(17): ['rest'],
  _oct(18): ['rest'],
  _oct(24): ['rest'],
  _oct(25): ['rest'],
});

/// The comparison of the three calendars over October 2026.
MultiComparison _three() => compareCalendarMonth(
  _rows(const [_c1, _c2, _c3], [_a, _b, _c]),
  _oct(1),
);

void main() {
  group('resolveComparedCalendars', () {
    const one = Calendar(id: 'one', name: 'Uno', colorValue: 1, sortOrder: 0);
    const two = Calendar(id: 'two', name: 'Dos', colorValue: 2, sortOrder: 1);
    const three = Calendar(
      id: 'three',
      name: 'Tres',
      colorValue: 3,
      sortOrder: 2,
    );
    const all = [one, two, three];

    List<String> idsOf(List<Calendar> calendars) => [
      for (final c in calendars) c.id,
    ];

    test('with no calendars there is nothing to compare', () {
      expect(resolveComparedCalendars(const [], activeId: 'one'), isEmpty);
    });

    test('with one calendar there is only that one', () {
      expect(idsOf(resolveComparedCalendars(const [one], activeId: 'one')), [
        'one',
      ]);
    });

    test('with nothing picked it opens on the calendar on screen and the '
        'next one', () {
      expect(idsOf(resolveComparedCalendars(all, activeId: 'two')), [
        'two',
        'three',
      ]);
      expect(idsOf(resolveComparedCalendars(all, activeId: 'three')), [
        'three',
        'one',
      ]);
    });

    test('it opens on the same pair as the two-calendar comparison', () {
      for (final active in ['one', 'two', 'three']) {
        final pair = resolveComparePair(all, activeId: active)!;
        final many = resolveComparedCalendars(all, activeId: active);
        expect(idsOf(many), [pair.first.id, pair.second.id], reason: active);
      }
    });

    test('the picked calendars come first, in the order they were picked', () {
      expect(
        idsOf(
          resolveComparedCalendars(
            all,
            activeId: 'one',
            selectedIds: ['three', 'two'],
          ),
        ),
        ['three', 'two'],
      );
    });

    test('an unknown id is dropped and a repeated one is kept once', () {
      expect(
        idsOf(
          resolveComparedCalendars(
            all,
            activeId: 'one',
            selectedIds: ['gone', 'two', 'two'],
          ),
        ),
        ['two', 'one'],
        reason: 'only one valid pick: the calendar on screen joins it',
      );
    });

    test('a single pick is topped up to two calendars', () {
      expect(
        idsOf(
          resolveComparedCalendars(all, activeId: 'one', selectedIds: ['three']),
        ),
        ['three', 'one'],
      );
    });

    test('at most six calendars are compared', () {
      final many = [
        for (var i = 0; i < 8; i++)
          Calendar(id: 'c$i', name: 'C$i', colorValue: i, sortOrder: i),
      ];
      final chosen = resolveComparedCalendars(
        many,
        activeId: 'c0',
        selectedIds: [for (var i = 0; i < 8; i++) 'c$i'],
      );
      expect(chosen, hasLength(maxComparedCalendars));
      expect(idsOf(chosen), ['c0', 'c1', 'c2', 'c3', 'c4', 'c5']);
    });

    test('six calendars picked out of many keep their order', () {
      final many = [
        for (var i = 0; i < 8; i++)
          Calendar(id: 'c$i', name: 'C$i', colorValue: i, sortOrder: i),
      ];
      final chosen = resolveComparedCalendars(
        many,
        activeId: 'c0',
        selectedIds: ['c5', 'c2', 'c7', 'c1', 'c3', 'c6'],
      );
      expect(idsOf(chosen), ['c5', 'c2', 'c7', 'c1', 'c3', 'c6']);
    });
  });

  group('isWeekendDay', () {
    test('Saturday and Sunday are the weekend', () {
      expect(isWeekendDay(_oct(3)), isTrue); // Saturday
      expect(isWeekendDay(_oct(4)), isTrue); // Sunday
      expect(isWeekendDay(_oct(5)), isFalse); // Monday
      expect(isWeekendDay(_oct(9)), isFalse); // Friday
    });
  });

  group('three calendars: the days free in common', () {
    test('a day is common when everybody is free', () {
      final comparison = _three();
      // The 4th: A and B rest, C works. The 10th: B works. The 11th: C has
      // nothing annotated, so it is not free (A6).
      expect(comparison.commonFreeDays, [_oct(24), _oct(25)]);
      expect(comparison.commonFreeCount, 2);
    });

    test('an empty day is never free (A6)', () {
      final comparison = _three();
      expect(comparison.commonFreeDays, isNot(contains(_oct(11))));
      expect(comparison.unrecordedDays, contains(_oct(11)));
      expect(comparison.unrecordedDays, contains(_oct(1)));
      expect(comparison.unrecordedDays, contains(_oct(17)));
      expect(
        comparison.commonFreeDays.toSet().intersection(
          comparison.unrecordedDays.toSet(),
        ),
        isEmpty,
      );
    });

    test('the days unannotated are those where nobody works', () {
      final comparison = _three();
      // Busy days: the 3rd (A), the 4th (C), the 5th (A) and the 10th (B).
      // The 24th and the 25th are free in the three, so they are neither
      // busy nor unannotated: 31 - 4 - 2.
      expect(comparison.unrecordedCount, 31 - 4 - 2);
      expect(comparison.unrecordedDays, isNot(contains(_oct(3))));
      expect(comparison.unrecordedDays, isNot(contains(_oct(4))));
      expect(comparison.unrecordedDays, isNot(contains(_oct(5))));
      expect(comparison.unrecordedDays, isNot(contains(_oct(10))));
      expect(comparison.unrecordedDays, isNot(contains(_oct(24))));
      expect(comparison.unrecordedDays, isNot(contains(_oct(25))));
    });

    test('the order of the calendars does not change the common days', () {
      final straight = _three();
      final reversed = compareCalendarMonth(
        _rows(const [_c3, _c2, _c1], [_c, _b, _a]),
        _oct(1),
      );
      expect(reversed.commonFreeDays, straight.commonFreeDays);
      expect(reversed.commonFreeCount, straight.commonFreeCount);
      expect(reversed.unrecordedDays, straight.unrecordedDays);
    });

    test('the month has every day of it, in order', () {
      final comparison = _three();
      expect(comparison.days, hasLength(31));
      expect(comparison.days.first.date, _oct(1));
      expect(comparison.days.last.date, _oct(31));
      for (var i = 1; i < comparison.days.length; i++) {
        expect(
          comparison.days[i].date,
          comparison.days[i - 1].date.addDays(1),
        );
      }
    });
  });

  group('three calendars: who works each day', () {
    test('the day says which calendars work and which are free', () {
      final comparison = _three();
      final fourth = comparison.days[3]; // 4 October
      expect(fourth.workingIndexes, [2]);
      expect(fourth.freeIndexes, [0, 1]);
      expect(fourth.allFree, isFalse);
      expect(fourth.hasUnrecorded, isFalse);
      expect(fourth.kindOf(2), DayKind.work);
      expect(fourth.kindOf(0), DayKind.rest);
    });

    test('the days each calendar works', () {
      final comparison = _three();
      expect(comparison.busyDaysOf(0), [_oct(3), _oct(5)]);
      expect(comparison.busyDaysOf(1), [_oct(10)]);
      expect(comparison.busyDaysOf(2), [_oct(4)]);
    });

    test('the days each calendar has free', () {
      final comparison = _three();
      expect(comparison.freeDaysOf(0), [
        _oct(4),
        _oct(10),
        _oct(11),
        _oct(24),
        _oct(25),
      ]);
      expect(comparison.freeDaysOf(1), [
        _oct(4),
        _oct(11),
        _oct(17),
        _oct(24),
        _oct(25),
      ]);
      expect(comparison.freeDaysOf(2), [
        _oct(10),
        _oct(17),
        _oct(18),
        _oct(24),
        _oct(25),
      ]);
    });

    test('a day with a work shift and a rest shift is busy', () {
      final mixed = _days({
        _oct(3): ['work', 'rest'],
      });
      final comparison = compareCalendarMonth(
        _rows(const [_c1, _c2], [mixed, _b]),
        _oct(1),
      );
      final third = comparison.days[2];
      expect(third.isBusy(0), isTrue);
      expect(third.isFree(0), isFalse);
      expect(third.workingIndexes, [0]);
    });

    test('a night shift makes the day busy; the next day is not', () {
      final nights = _days({
        _oct(3): ['night'],
      });
      final comparison = compareCalendarMonth(
        _rows(const [_c1, _c2], [nights, _b]),
        _oct(1),
      );
      expect(comparison.days[2].isBusy(0), isTrue);
      expect(comparison.days[3].isBusy(0), isFalse);
      expect(comparison.days[3].isFree(0), isFalse, reason: 'nothing annotated');
    });
  });

  group('the free weekends', () {
    test('the weekend days everybody is free, of the month', () {
      final comparison = _three();
      expect(comparison.commonFreeWeekendDays, [_oct(24), _oct(25)]);
      expect(comparison.commonFreeWeekendCount, 2);
    });

    test('the complete weekends everybody is free', () {
      final comparison = _three();
      expect(comparison.commonFreeWeekends, [
        CommonFreeWeekend(saturday: _oct(24), sunday: _oct(25)),
      ]);
    });

    test('a weekend with somebody working is not a free weekend', () {
      final comparison = _three();
      // The 10th and the 11th: A and B are free but C is not (B works the
      // 10th and C has nothing the 11th).
      expect(comparison.commonFreeWeekendDays, isNot(contains(_oct(10))));
      expect(comparison.commonFreeWeekendDays, isNot(contains(_oct(11))));
      expect(
        comparison.commonFreeWeekends,
        isNot(
          contains(
            CommonFreeWeekend(saturday: _oct(10), sunday: _oct(11)),
          ),
        ),
      );
      // The weekend of the 24th and the 25th is free in the three.
      expect(comparison.commonFreeWeekends, [
        CommonFreeWeekend(saturday: _oct(24), sunday: _oct(25)),
      ]);
    });

    test('the weekend of a range is the weekend of the days of the range', () {
      final comparison = compareCalendars(
        _rows(const [_c1, _c2, _c3], [_a, _b, _c]),
        _oct(24),
        _oct(31),
      );
      // The 24th and the 25th are free in the three; the 31st is a Saturday
      // with nothing annotated.
      expect(comparison.commonFreeWeekendDays, [_oct(24), _oct(25)]);
      expect(comparison.commonFreeWeekendCount, 2);
      expect(comparison.commonFreeWeekends, [
        CommonFreeWeekend(saturday: _oct(24), sunday: _oct(25)),
      ]);
    });

    test('a Saturday whose Sunday is out of the range is half a weekend', () {
      final saturday = _days({
        _oct(31): ['rest'],
      });
      final comparison = compareCalendars(
        _rows(const [_c1, _c2], [saturday, saturday]),
        _oct(31),
        _oct(31),
      );
      expect(comparison.commonFreeWeekendDays, [_oct(31)]);
      expect(comparison.commonFreeWeekendCount, 1);
      expect(
        comparison.commonFreeWeekends,
        isEmpty,
        reason: 'the Sunday is out of the range',
      );
    });
  });

  group('six calendars', () {
    final d = _days({
      _oct(3): ['work'],
      _oct(24): ['rest'],
      _oct(25): ['rest'],
    });
    final e = _days({
      _oct(4): ['work'],
      _oct(24): ['rest'],
      _oct(25): ['rest'],
    });
    final f = _days({
      _oct(10): ['work'],
      _oct(24): ['rest'],
      _oct(25): ['rest'],
    });

    test('the days free in the six of them', () {
      final comparison = compareCalendarMonth(
        _rows(const [_c1, _c2, _c3, _c4, _c5, _c6], [_a, _b, _c, d, e, f]),
        _oct(1),
      );
      expect(comparison.calendarCount, 6);
      expect(comparison.commonFreeDays, [_oct(24), _oct(25)]);
      expect(comparison.commonFreeCount, 2);
      expect(comparison.commonFreeWeekendCount, 2);
    });

    test('one of the six working is enough to take the day out', () {
      final busy = _days({
        _oct(24): ['work'],
        _oct(25): ['rest'],
      });
      final comparison = compareCalendarMonth(
        _rows(const [_c1, _c2, _c3, _c4, _c5, _c6], [_a, _b, _c, d, e, busy]),
        _oct(1),
      );
      expect(comparison.commonFreeDays, [_oct(25)]);
      expect(comparison.commonFreeWeekendDays, [_oct(25)]);
      // The Saturday is not free, so the weekend is not free either even
      // though the Sunday is.
      expect(comparison.commonFreeWeekends, isEmpty);
    });

    test('the grid has six rows and one cell per row and day', () {
      final comparison = compareCalendarMonth(
        _rows(const [_c1, _c2, _c3, _c4, _c5, _c6], [_a, _b, _c, d, e, f]),
        _oct(1),
      );
      expect(comparison.days, hasLength(31));
      for (final day in comparison.days) {
        expect(day.calendarCount, 6);
        expect(day.days, hasLength(6));
      }
      // The 3rd: A and D work and the other four have nothing annotated,
      // which is NOT a day off (A6).
      expect(comparison.days[2].workingIndexes, [0, 3]);
      expect(comparison.days[2].freeIndexes, isEmpty);
      expect(comparison.days[2].hasUnrecorded, isFalse);
    });
  });

  group('the month inside a range', () {
    test('forMonth keeps only the days of the month', () {
      final comparison = compareCalendars(
        _rows(const [_c1, _c2, _c3], [_a, _b, _c]),
        const CivilDate(2026, 9, 28),
        const CivilDate(2026, 11, 4),
      );
      final october = comparison.forMonth(_oct(1));
      expect(october.days, hasLength(31));
      expect(october.days.first.date, _oct(1));
      expect(october.days.last.date, _oct(31));
      expect(october.commonFreeDays, [_oct(24), _oct(25)]);
      expect(october.commonFreeWeekendDays, [_oct(24), _oct(25)]);
    });

    test('the whole range counts its own common days', () {
      final comparison = compareCalendars(
        _rows(const [_c1, _c2, _c3], [_a, _b, _c]),
        const CivilDate(2026, 9, 28),
        const CivilDate(2026, 11, 4),
      );
      expect(comparison.days, hasLength(38));
      expect(comparison.commonFreeDays, [_oct(24), _oct(25)]);
      expect(comparison.commonFreeWeekendDays, [_oct(24), _oct(25)]);
    });

    test('a month the range does not reach is empty', () {
      final comparison = _three();
      final december = comparison.forMonth(const CivilDate(2026, 12, 15));
      expect(december.days, isEmpty);
      expect(december.commonFreeCount, 0);
      expect(december.commonFreeWeekendCount, 0);
      // An empty range anchored at the start of the month, never the bogus
      // span that crossed the whole month («del 1 de diciembre al 31 de
      // octubre»): no day lies between the two ends.
      expect(december.from, const CivilDate(2026, 12, 1));
      expect(december.to, const CivilDate(2026, 11, 30));
      expect(december.from.differenceInDays(december.to), 1);
    });
  });

  group('the edges', () {
    test('a range that ends before it starts is empty', () {
      final comparison = compareCalendars(
        _rows(const [_c1, _c2], [_a, _b]),
        _oct(5),
        _oct(4),
      );
      expect(comparison.days, isEmpty);
      expect(comparison.commonFreeCount, 0);
      expect(comparison.commonFreeWeekendCount, 0);
    });

    test('February of a leap year has 29 days', () {
      final comparison = compareCalendarMonth(
        _rows(const [_c1, _c2, _c3], [_a, _b, _c]),
        const CivilDate(2028, 2, 10),
      );
      expect(comparison.days, hasLength(29));
      expect(comparison.commonFreeCount, 0);
      expect(comparison.unrecordedCount, 29);
    });

    test('a calendar compared with itself is free on its own days off', () {
      final comparison = compareCalendarMonth(
        _rows(const [_c1], [_a]),
        _oct(1),
      );
      expect(comparison.commonFreeDays, [
        _oct(4),
        _oct(10),
        _oct(11),
        _oct(24),
        _oct(25),
      ]);
    });

    test('without calendars there is nothing to compare', () {
      final comparison = compareCalendars(
        const <({Calendar calendar, Schedule schedule})>[],
        _oct(1),
        _oct(31),
      );
      expect(comparison.days, isEmpty);
      expect(comparison.calendarCount, 0);
      expect(comparison.commonFreeCount, 0);
    });
  });
}
