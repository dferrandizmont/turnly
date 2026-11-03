import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:cuadrante/features/summary/domain/hours_bag.dart';
import 'package:cuadrante/features/summary/domain/hours_goal.dart';
import 'package:flutter_test/flutter_test.dart';

// The hours bag (P9, fila 24 de `docs/paridad-pago.md`): the balance between
// the hours worked and the goal, accumulated month by month.

const _morning = ShiftType(
  id: 'M',
  code: 'M',
  name: 'Mañana',
  colorValue: 0xFFF5A524,
  category: ShiftCategory.work,
  startMinute: 480,
  endMinute: 960,
);

const _vacation = ShiftType(
  id: 'V',
  code: 'V',
  name: 'Vacaciones',
  colorValue: 0xFF30A46C,
  category: ShiftCategory.absence,
);

/// A month with [days] days of a morning shift (8 h each).
Schedule _schedule(int year, int month, {int days = 0}) => Schedule(
  shiftTypes: const [_morning],
  entries: {
    for (var day = 1; day <= days; day++)
      CivilDate(year, month, day): DayEntry(
        date: CivilDate(year, month, day),
        shiftTypeIds: const ['M'],
      ),
  },
);

void main() {
  group('the balance', () {
    test('is the hours worked minus the goal of the month', () {
      final goal = const HoursGoal(HoursGoalPeriod.month, 100);
      final schedule = _schedule(2026, 1, days: 15);
      final balance = hoursBalance(
        schedule,
        goal,
        fromMonth: const CivilDate(2026, 1, 1),
        toMonth: const CivilDate(2026, 1, 1),
      );
      // 15 days x 8 h = 120 h against a goal of 100 h.
      expect(balance.workedMinutes, 15 * 480);
      expect(balance.goalMinutes, 100 * 60);
      expect(balance.balanceMinutes, 20 * 60);
      expect(balance.isOver, isTrue);
      expect(balance.carryInMinutes, 0);
    });

    test('is negative when the hours are missing', () {
      final goal = const HoursGoal(HoursGoalPeriod.month, 100);
      final schedule = _schedule(2026, 1, days: 10);
      final balance = hoursBalance(
        schedule,
        goal,
        fromMonth: const CivilDate(2026, 1, 1),
        toMonth: const CivilDate(2026, 1, 1),
      );
      expect(balance.balanceMinutes, -20 * 60);
      expect(balance.isOver, isFalse);
    });

    test('adds up the months', () {
      final goal = const HoursGoal(HoursGoalPeriod.month, 100);
      final schedule = Schedule(
        shiftTypes: const [_morning],
        entries: {
          for (final date in [
            const CivilDate(2026, 1, 1),
            const CivilDate(2026, 1, 2),
            const CivilDate(2026, 2, 1),
          ])
            date: DayEntry(date: date, shiftTypeIds: const ['M']),
        },
      );
      final balance = hoursBalance(
        schedule,
        goal,
        fromMonth: const CivilDate(2026, 1, 1),
        toMonth: const CivilDate(2026, 2, 1),
      );
      // Three days x 8 h = 24 h against two months of 100 h.
      expect(balance.workedMinutes, 3 * 480);
      expect(balance.goalMinutes, 200 * 60);
      expect(balance.balanceMinutes, 24 * 60 - 200 * 60);
    });
  });

  group('the carry-over', () {
    test('the balance of December goes on in January', () {
      final goal = const HoursGoal(HoursGoalPeriod.month, 100);
      final schedule = Schedule(
        shiftTypes: const [_morning],
        entries: {
          for (final date in [
            const CivilDate(2025, 12, 1),
            const CivilDate(2025, 12, 2),
            const CivilDate(2026, 1, 1),
          ])
            date: DayEntry(date: date, shiftTypeIds: const ['M']),
        },
      );
      final december = hoursBalance(
        schedule,
        goal,
        fromMonth: const CivilDate(2025, 12, 1),
        toMonth: const CivilDate(2025, 12, 1),
      );
      expect(december.balanceMinutes, -84 * 60);
      // January starts with the balance of December.
      final january = hoursBalance(
        schedule,
        goal,
        fromMonth: const CivilDate(2026, 1, 1),
        toMonth: const CivilDate(2026, 1, 1),
        carryInMinutes: december.balanceMinutes,
      );
      expect(january.carryInMinutes, -84 * 60);
      expect(january.balanceMinutes, -84 * 60 - 92 * 60);
    });

    test('a bag that walks the year adds up the months', () {
      final goal = const HoursGoal(HoursGoalPeriod.month, 100);
      final schedule = _schedule(2026, 1, days: 15);
      final balance = hoursBalance(
        schedule,
        goal,
        fromMonth: const CivilDate(2026, 1, 1),
        toMonth: const CivilDate(2026, 12, 1),
      );
      // One month with hours and eleven without.
      expect(balance.workedMinutes, 15 * 480);
      expect(balance.goalMinutes, 12 * 100 * 60);
      expect(balance.balanceMinutes, 15 * 480 - 12 * 100 * 60);
    });
  });

  group('the goal of a month', () {
    test('a monthly goal is the same every month', () {
      final goal = const HoursGoal(HoursGoalPeriod.month, 100);
      expect(goalMinutesForMonthOf(goal, const CivilDate(2026, 3, 1)), 6000);
      expect(goalMinutesForMonthOf(goal, const CivilDate(2026, 12, 1)), 6000);
    });

    test('a yearly goal is a twelfth, and the year adds up exactly', () {
      // 1.642 h a year (a usual annual agreement): a twelfth a month, and
      // the twelve months add up to the yearly goal.
      final goal = const HoursGoal(HoursGoalPeriod.year, 1642);
      final minutes = [
        for (var m = 1; m <= 12; m++)
          goalMinutesForMonthOf(goal, CivilDate(2026, m, 1)),
      ];
      expect(minutes.every((m) => m == goal.yearMinutes ~/ 12), isTrue);
      expect(minutes.fold(0, (sum, m) => sum + m), goal.yearMinutes);
    });
  });

  group('where the bag starts', () {
    test('the first month with something in the schedule', () {
      final schedule = Schedule(
        shiftTypes: const [_morning],
        entries: {
          const CivilDate(2026, 3, 10): const DayEntry(
            date: CivilDate(2026, 3, 10),
            shiftTypeIds: ['M'],
          ),
        },
        runs: [
          PatternRun(
            id: 'r1',
            patternId: 'p1',
            startDate: const CivilDate(2026, 2, 1),
            seq: 1,
          ),
        ],
      );
      expect(firstMonthWithData(schedule), const CivilDate(2026, 2, 1));
      expect(firstMonthWithData(Schedule()), isNull);
    });

    test('an old note does not drag the bag back years (M3)', () {
      final schedule = Schedule(
        shiftTypes: const [_morning],
        entries: {
          // A note from years before the app was even set up.
          const CivilDate(2024, 1, 10): const DayEntry(
            date: CivilDate(2024, 1, 10),
            note: 'Cumple de Ana',
          ),
          const CivilDate(2026, 3, 10): const DayEntry(
            date: CivilDate(2026, 3, 10),
            shiftTypeIds: ['M'],
          ),
        },
      );
      // Only the day with worked minutes counts, not the note.
      expect(firstMonthWithData(schedule), const CivilDate(2026, 3, 1));
    });

    test('an absence-only day does not start the bag (M3)', () {
      final schedule = Schedule(
        shiftTypes: const [_morning, _vacation],
        entries: {
          const CivilDate(2024, 4, 1): const DayEntry(
            date: CivilDate(2024, 4, 1),
            shiftTypeIds: ['V'],
          ),
          const CivilDate(2026, 5, 10): const DayEntry(
            date: CivilDate(2026, 5, 10),
            shiftTypeIds: ['M'],
          ),
        },
      );
      expect(firstMonthWithData(schedule), const CivilDate(2026, 5, 1));
    });

    test('overtime noted by hand starts the bag (M3)', () {
      final schedule = Schedule(
        shiftTypes: const [_morning],
        entries: {
          const CivilDate(2026, 5, 2): const DayEntry(
            date: CivilDate(2026, 5, 2),
            overtimeMinutes: 60,
          ),
        },
      );
      expect(firstMonthWithData(schedule), const CivilDate(2026, 5, 1));
    });
  });
}
