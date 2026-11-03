import 'package:cuadrante/features/absences/domain/absence_balance.dart';
import 'package:cuadrante/features/absences/domain/absence_calculator.dart';
import 'package:cuadrante/features/absences/domain/absence_status.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:flutter_test/flutter_test.dart';

const _vacation = ShiftType(
  id: 'vacation',
  code: 'V',
  name: 'Vacaciones',
  colorValue: 0xFF30A46C,
  category: ShiftCategory.absence,
);

const _half = ShiftType(
  id: 'half',
  code: 'M',
  name: 'Medio día',
  colorValue: 0xFF30A46C,
  category: ShiftCategory.absence,
);

const _work = ShiftType(
  id: 'work',
  code: 'T',
  name: 'Tarde',
  colorValue: 0xFF336699,
  category: ShiftCategory.work,
);

const _today = CivilDate(2027, 6, 15);

/// A schedule made of single-day entries (`date -> shift ids`).
Schedule _schedule(Map<CivilDate, List<String>> days) => Schedule(
  shiftTypes: const [_vacation, _half, _work],
  entries: {
    for (final entry in days.entries)
      entry.key: DayEntry(date: entry.key, shiftTypeIds: entry.value),
  },
);

AbsenceBalanceCalculator _calculator(
  List<AbsenceBalance> balances,
  Map<String, Schedule> schedules, {
  CivilDate today = _today,
  Map<String, CivilDate> expiry = const {},
}) => AbsenceBalanceCalculator(
  balances: balances,
  schedules: schedules,
  primaryCalendarId: 'main',
  today: today,
  carryOverExpiry: expiry,
);

void main() {
  group('the days used', () {
    test('come from the days with one of the types of the balance', () {
      const balance = AbsenceBalance(
        year: 2027,
        type: 'vac',
        allowedDays: 22,
        shiftTypeQuarters: {'vacation': 4},
      );
      final calculator = _calculator(
        [balance],
        {
          'main': _schedule({
            const CivilDate(2027, 3, 1): ['vacation'],
            const CivilDate(2027, 3, 2): ['vacation'],
            const CivilDate(2027, 7, 1): ['vacation'],
          }),
        },
      );
      final status = calculator.statusOf(balance);
      expect(status.usedDays, 3);
      expect(status.enjoyedDays, 2, reason: 'the past');
      expect(status.plannedDays, 1, reason: 'today and after');
      expect(status.remainingDays, 19);
      expect(status.availableDays, 22);
      expect(status.calendarId, 'main');
    });

    test('a type of half a day counts half', () {
      const balance = AbsenceBalance(
        year: 2027,
        type: 'moscosos',
        allowedDays: 6,
        unit: AbsenceUnit.half,
        shiftTypeQuarters: {'half': 2},
      );
      final calculator = _calculator(
        [balance],
        {
          'main': _schedule({
            const CivilDate(2027, 4, 1): ['half'],
            const CivilDate(2027, 4, 2): ['half'],
            const CivilDate(2027, 4, 3): ['half'],
          }),
        },
      );
      final status = calculator.statusOf(balance);
      expect(status.usedDays, 1.5);
      expect(status.remainingDays, 4.5);
    });

    test('a day with more than a whole day of absences counts one day', () {
      const balance = AbsenceBalance(
        year: 2027,
        type: 'vac',
        allowedDays: 22,
        shiftTypeQuarters: {'vacation': 4, 'half': 2},
      );
      final calculator = _calculator(
        [balance],
        {
          'main': _schedule({
            const CivilDate(2027, 4, 1): ['vacation', 'half'],
            const CivilDate(2027, 4, 2): ['vacation', 'vacation'],
          }),
        },
      );
      final status = calculator.statusOf(balance);
      // A day worth 1.5 days (vacation + half) and a day worth 2 (two
      // vacancies) count one day each: two absences of the same series on one
      // day are one day at most.
      expect(status.usedDays, 2);
    });

    test('only the types of the absence category count', () {
      const balance = AbsenceBalance(
        year: 2027,
        type: 'vac',
        allowedDays: 22,
        shiftTypeQuarters: {'work': 4},
      );
      final calculator = _calculator(
        [balance],
        {
          'main': _schedule({
            const CivilDate(2027, 4, 1): ['work'],
          }),
        },
      );
      expect(calculator.statusOf(balance).usedDays, 0);
    });

    test('a balance without types counts nothing', () {
      const balance = AbsenceBalance(year: 2027, type: 'vac', allowedDays: 22);
      final calculator = _calculator(
        [balance],
        {
          'main': _schedule({
            const CivilDate(2027, 4, 1): ['vacation'],
          }),
        },
      );
      expect(calculator.statusOf(balance).usedDays, 0);
    });

    test('a leap day counts like any other', () {
      const balance = AbsenceBalance(
        year: 2028,
        type: 'vac',
        allowedDays: 22,
        shiftTypeQuarters: {'vacation': 4},
      );
      final calculator = _calculator(
        [balance],
        {
          'main': _schedule({
            const CivilDate(2028, 2, 28): ['vacation'],
            const CivilDate(2028, 2, 29): ['vacation'],
            const CivilDate(2028, 3, 1): ['vacation'],
          }),
        },
        today: const CivilDate(2028, 1, 1),
      );
      expect(calculator.statusOf(balance).usedDays, 3);
    });

    test('the days of another year do not count', () {
      const balance = AbsenceBalance(
        year: 2028,
        type: 'vac',
        allowedDays: 22,
        shiftTypeQuarters: {'vacation': 4},
      );
      final calculator = _calculator(
        [balance],
        {
          'main': _schedule({
            const CivilDate(2027, 12, 31): ['vacation'],
            const CivilDate(2028, 1, 1): ['vacation'],
          }),
        },
        today: const CivilDate(2027, 12, 1),
      );
      final status = calculator.statusOf(balance);
      expect(status.usedDays, 1);
      expect(status.plannedDays, 1);
    });

    test('only the days of the period count', () {
      const balance = AbsenceBalance(
        year: 2026,
        type: 'vac',
        allowedDays: 22,
        periodStart: CivilDate(2026, 4, 1),
        periodEnd: CivilDate(2027, 3, 31),
        shiftTypeQuarters: {'vacation': 4},
      );
      final calculator = _calculator(
        [balance],
        {
          'main': _schedule({
            const CivilDate(2026, 3, 31): ['vacation'],
            const CivilDate(2026, 4, 1): ['vacation'],
            const CivilDate(2027, 3, 31): ['vacation'],
            const CivilDate(2027, 4, 1): ['vacation'],
          }),
        },
        today: const CivilDate(2026, 1, 1),
      );
      expect(calculator.statusOf(balance).usedDays, 2);
    });
  });

  group('the carry-over', () {
    const lastYear = AbsenceBalance(
      year: 2026,
      type: 'vac',
      allowedDays: 22,
      shiftTypeQuarters: {'vacation': 4},
    );

    test('takes what was left of the year before', () {
      const thisYear = AbsenceBalance(
        year: 2027,
        type: 'vac',
        allowedDays: 22,
        carryOver: true,
        shiftTypeQuarters: {'vacation': 4},
      );
      final calculator = _calculator(
        [lastYear, thisYear],
        {
          'main': _schedule({
            const CivilDate(2026, 5, 1): ['vacation'],
            const CivilDate(2026, 5, 2): ['vacation'],
          }),
        },
      );
      final status = calculator.statusOf(thisYear);
      expect(status.carriedDays, 20, reason: '22 allowed - 2 used');
      expect(status.availableDays, 42);
      expect(status.remainingDays, 42);
    });

    test('has a cap', () {
      const thisYear = AbsenceBalance(
        year: 2027,
        type: 'vac',
        allowedDays: 22,
        carryOver: true,
        carryOverMaxDays: 5,
      );
      final calculator = _calculator(
        [lastYear, thisYear],
        {
          'main': _schedule({
            const CivilDate(2026, 5, 1): ['vacation'],
            const CivilDate(2026, 5, 2): ['vacation'],
          }),
        },
      );
      expect(calculator.statusOf(thisYear).carriedDays, 5);
    });

    test('follows the chain year by year', () {
      const twoYearsAgo = AbsenceBalance(
        year: 2025,
        type: 'vac',
        allowedDays: 10,
      );
      const lastYear = AbsenceBalance(
        year: 2026,
        type: 'vac',
        allowedDays: 22,
        carryOver: true,
        shiftTypeQuarters: {'vacation': 4},
      );
      const thisYear = AbsenceBalance(
        year: 2027,
        type: 'vac',
        allowedDays: 22,
        carryOver: true,
      );
      final calculator = _calculator(
        [twoYearsAgo, lastYear, thisYear],
        {
          'main': _schedule({
            const CivilDate(2026, 5, 1): ['vacation'],
          }),
        },
      );
      // 2025 leaves 10; 2026 carries them and uses 1 (22 + 10 - 1 = 31);
      // 2027 carries those 31.
      expect(calculator.statusOf(lastYear).carriedDays, 10);
      expect(calculator.statusOf(thisYear).carriedDays, 31);
    });

    test('does not cross the series or the calendar', () {
      const otherSeries = AbsenceBalance(
        year: 2026,
        type: 'moscosos',
        allowedDays: 6,
      );
      const otherCalendar = AbsenceBalance(
        year: 2026,
        type: 'vac',
        allowedDays: 22,
        calendarId: 'other',
      );
      const thisYear = AbsenceBalance(
        year: 2027,
        type: 'vac',
        allowedDays: 22,
        carryOver: true,
      );
      final calculator = _calculator(
        [otherSeries, otherCalendar, thisYear],
        {'main': _schedule(const {})},
      );
      expect(calculator.statusOf(thisYear).carriedDays, 0);
    });

    test('the carried days are used before the ones of this year', () {
      const thisYear = AbsenceBalance(
        year: 2027,
        type: 'vac',
        allowedDays: 22,
        carryOver: true,
        shiftTypeQuarters: {'vacation': 4},
      );
      final calculator = _calculator(
        [lastYear, thisYear],
        {
          'main': _schedule({
            const CivilDate(2027, 5, 1): ['vacation'],
            const CivilDate(2027, 5, 2): ['vacation'],
          }),
        },
      );
      final status = calculator.statusOf(thisYear);
      expect(status.usedDays, 2);
      expect(status.carriedDays, 22);
      expect(
        status.carriedLeftDays,
        20,
        reason: 'the two days used come from the 22 carried (they go first)',
      );
      expect(status.remainingDays, 42);
    });
  });

  group('the expiry of the carried days', () {
    const lastYear = AbsenceBalance(year: 2027, type: 'vac', allowedDays: 22);
    const thisYear = AbsenceBalance(
      year: 2028,
      type: 'vac',
      allowedDays: 22,
      carryOver: true,
    );

    test('they count while they are in force', () {
      final calculator = _calculator(
        [lastYear, thisYear],
        {'main': _schedule(const {})},
        today: const CivilDate(2028, 2, 1),
        expiry: {
          absenceCarryOverExpiryKey(2028, 'vac'): const CivilDate(2028, 3, 31),
        },
      );
      final status = calculator.statusOf(thisYear);
      expect(status.carriedDays, 22);
      expect(status.expiredDays, 0);
      expect(status.remainingDays, 44);
      expect(status.warnings, [
        const CarryOverExpiring(days: 22, expiryDate: CivilDate(2028, 3, 31)),
      ]);
    });

    test('they are lost when the day passes', () {
      final calculator = _calculator(
        [lastYear, thisYear],
        {'main': _schedule(const {})},
        today: const CivilDate(2028, 5, 1),
        expiry: {
          absenceCarryOverExpiryKey(2028, 'vac'): const CivilDate(2028, 3, 31),
        },
      );
      final status = calculator.statusOf(thisYear);
      expect(status.carriedDays, 22);
      expect(status.expiredDays, 22);
      expect(status.remainingDays, 22, reason: 'the carried days are lost');
      expect(status.carryOverExpired, isTrue);
      expect(status.warnings, isEmpty);
    });

    test('the expiry of another year or series does not apply', () {
      final calculator = _calculator(
        [lastYear, thisYear],
        {'main': _schedule(const {})},
        today: const CivilDate(2028, 5, 1),
        expiry: {
          absenceCarryOverExpiryKey(2027, 'vac'): const CivilDate(2027, 3, 31),
          absenceCarryOverExpiryKey(2028, 'other'): const CivilDate(
            2027,
            3,
            31,
          ),
        },
      );
      final status = calculator.statusOf(thisYear);
      expect(status.expiredDays, 0);
      expect(status.remainingDays, 44);
    });

    test('what was spent before the expiry does not expire (H1)', () {
      const previous = AbsenceBalance(year: 2027, type: 'vac', allowedDays: 22);
      const current = AbsenceBalance(
        year: 2028,
        type: 'vac',
        allowedDays: 22,
        carryOver: true,
        shiftTypeQuarters: {'vacation': 4},
      );
      final days = <CivilDate, List<String>>{};
      var day = const CivilDate(2028, 1, 1);
      for (var i = 0; i < 30; i++) {
        days[day] = ['vacation'];
        day = day.addDays(1);
      }
      final calculator = _calculator(
        [previous, current],
        {'main': _schedule(days)},
        today: const CivilDate(2028, 5, 1),
        expiry: {
          // The key carries the calendar (L1).
          absenceCarryOverExpiryKey(2028, 'vac', 'main'): const CivilDate(
            2028,
            3,
            31,
          ),
        },
      );
      final status = calculator.statusOf(current);
      // The 22 carried are spent first by the 30 days of January, so none is
      // left to expire: 44 - 30 = 14 are left.
      expect(status.usedDays, 30);
      expect(status.expiredDays, 0);
      expect(status.carriedLeftDays, 0);
      expect(status.remainingDays, 14);
      expect(status.carryOverExpired, isFalse);
    });

    test('the old key without a calendar is still read (L1)', () {
      final calculator = _calculator(
        [lastYear, thisYear],
        {'main': _schedule(const {})},
        today: const CivilDate(2028, 2, 1),
        // A row written before v6, with no calendar in the key.
        expiry: {
          absenceCarryOverExpiryKey(2028, 'vac'): const CivilDate(2028, 3, 31),
        },
      );
      expect(
        calculator.statusOf(thisYear).carryOverExpiry,
        const CivilDate(2028, 3, 31),
      );
    });
  });

  group('the warnings', () {
    test('more planned than there are', () {
      const balance = AbsenceBalance(
        year: 2027,
        type: 'vac',
        allowedDays: 22,
        shiftTypeQuarters: {'vacation': 4},
      );
      final calculator = _calculator(
        [balance],
        {
          'main': _schedule({
            const CivilDate(2027, 8, 1): ['vacation'],
            const CivilDate(2027, 8, 2): ['vacation'],
          }),
        },
      );
      // 22 allowed, 2 planned: there is room.
      expect(calculator.statusOf(balance).warnings, isEmpty);
    });

    test('the days planned do not fit in what was left', () {
      const balance = AbsenceBalance(
        year: 2027,
        type: 'vac',
        allowedDays: 3,
        shiftTypeQuarters: {'vacation': 4},
      );
      final calculator = _calculator(
        [balance],
        {
          'main': _schedule({
            const CivilDate(2027, 8, 1): ['vacation'],
            const CivilDate(2027, 8, 2): ['vacation'],
            const CivilDate(2027, 8, 3): ['vacation'],
            const CivilDate(2027, 8, 4): ['vacation'],
          }),
        },
      );
      final status = calculator.statusOf(balance);
      expect(status.warnings, [
        const PlannedExceedsAvailable(plannedDays: 4, leftDays: 3),
      ]);
      expect(status.remainingDays, -1);
    });

    test('the days already enjoyed do not count as planned', () {
      const balance = AbsenceBalance(
        year: 2027,
        type: 'vac',
        allowedDays: 3,
        shiftTypeQuarters: {'vacation': 4},
      );
      final calculator = _calculator(
        [balance],
        {
          'main': _schedule({
            const CivilDate(2027, 5, 1): ['vacation'],
            const CivilDate(2027, 8, 1): ['vacation'],
          }),
        },
      );
      final status = calculator.statusOf(balance);
      expect(status.enjoyedDays, 1);
      expect(status.plannedDays, 1);
      expect(status.remainingDays, 1);
      expect(status.warnings, isEmpty);
    });
  });

  group('the calendars', () {
    test('each balance counts the days of its own calendar', () {
      const mine = AbsenceBalance(
        year: 2027,
        type: 'vac',
        allowedDays: 22,
        calendarId: 'other',
        shiftTypeQuarters: {'vacation': 4},
      );
      const primary = AbsenceBalance(
        year: 2027,
        type: 'vac',
        allowedDays: 22,
        shiftTypeQuarters: {'vacation': 4},
      );
      final calculator = _calculator(
        [mine, primary],
        {
          'main': _schedule({
            const CivilDate(2027, 5, 1): ['vacation'],
          }),
          'other': _schedule({
            const CivilDate(2027, 5, 1): ['vacation'],
            const CivilDate(2027, 5, 2): ['vacation'],
          }),
        },
      );
      expect(calculator.statusOf(mine).usedDays, 2);
      expect(calculator.statusOf(primary).usedDays, 1);
      expect(calculator.statusOf(mine).calendarId, 'other');
      expect(calculator.statusOf(primary).calendarId, 'main');
    });

    test('statusesOf returns the balances of the year', () {
      const balance = AbsenceBalance(year: 2027, type: 'vac', allowedDays: 22);
      const other = AbsenceBalance(year: 2026, type: 'vac', allowedDays: 22);
      final calculator = _calculator(
        [other, balance],
        {'main': _schedule(const {})},
      );
      expect(calculator.statusesOf(2027), [calculator.statusOf(balance)]);
      expect(calculator.statusesOf(2026), [calculator.statusOf(other)]);
      expect(calculator.statusesOfCalendar(2027, 'main'), hasLength(1));
      expect(calculator.statusesOfCalendar(2027, 'other'), isEmpty);
    });
  });

  test('the key of an expiry date', () {
    expect(absenceCarryOverExpiryKey(2028, 'vac'), '2028:vac');
    // With a calendar, so two calendars can hold the same series (L1).
    expect(absenceCarryOverExpiryKey(2028, 'vac', 'main'), 'main|2028:vac');
  });
}
