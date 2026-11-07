import 'package:cuadrante/features/absences/domain/absence_balance.dart';
import 'package:cuadrante/features/absences/domain/absence_calculator.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:flutter_test/flutter_test.dart';

const _vacation = ShiftType(
  id: 'vacation',
  code: 'V',
  name: 'Vacaciones',
  colorValue: 0xFF30A46C,
  category: ShiftCategory.absence,
);

/// Vacation every day from [from] to [to].
Schedule _vacationBetween(CivilDate from, CivilDate to) => Schedule(
  shiftTypes: const [_vacation],
  entries: {
    for (var d = from; !d.isAfter(to); d = d.addDays(1))
      d: DayEntry(date: d, shiftTypeIds: const ['vacation']),
  },
);

// Monday 7 December to Sunday 13 December 2026; Tuesday 8 is a holiday
// (Inmaculada Concepción).
const _monday = CivilDate(2026, 12, 7);
const _sunday = CivilDate(2026, 12, 13);
const _holiday = CivilDate(2026, 12, 8);

AbsenceBalance _balance({required bool workingDays}) => AbsenceBalance(
  year: 2026,
  type: 'vac',
  allowedDays: 22,
  shiftTypeQuarters: const {'vacation': 4},
  workingDaysOnly: workingDays,
);

double _used(AbsenceBalance balance, {Set<CivilDate> holidays = const {}}) =>
    AbsenceBalanceCalculator(
      balances: [balance],
      schedules: {'main': _vacationBetween(_monday, _sunday)},
      primaryCalendarId: 'main',
      today: const CivilDate(2026, 12, 1),
      holidays: holidays,
    ).statusOf(balance).usedDays;

void main() {
  group('working days', () {
    test('Monday to Friday that are not a holiday', () {
      expect(isWorkingDay(_monday, const {}), isTrue);
      expect(isWorkingDay(_holiday, {_holiday}), isFalse);
      expect(isWorkingDay(const CivilDate(2026, 12, 12), const {}), isFalse);
      expect(isWorkingDay(_sunday, const {}), isFalse);
    });

    test('a week with a holiday has four', () {
      expect(countWorkingDays(_monday, _sunday, {_holiday}), 4);
      expect(countWorkingDays(_monday, _sunday, const {}), 5);
      // December 2026: 23 weekdays, 2 of them holidays (8 and 25).
      expect(
        countWorkingDays(
          const CivilDate(2026, 12, 1),
          const CivilDate(2026, 12, 31),
          {_holiday, const CivilDate(2026, 12, 25)},
        ),
        21,
      );
    });
  });

  group('a balance in working days', () {
    test('a week of vacation over a holiday spends four days', () {
      final balance = _balance(workingDays: true);
      expect(_used(balance, holidays: {_holiday}), 4);
      final status = AbsenceBalanceCalculator(
        balances: [balance],
        schedules: {'main': _vacationBetween(_monday, _sunday)},
        primaryCalendarId: 'main',
        today: const CivilDate(2026, 12, 1),
        holidays: {_holiday},
      ).statusOf(balance);
      expect(status.remainingDays, 18);
    });

    test('without holidays it spends the five weekdays', () {
      expect(_used(_balance(workingDays: true)), 5);
    });

    test('a balance in calendar days spends all seven, as before', () {
      expect(_used(_balance(workingDays: false), holidays: {_holiday}), 7);
    });
  });
}
