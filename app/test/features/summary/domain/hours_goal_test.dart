import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:cuadrante/features/summary/domain/hours_goal.dart';
import 'package:cuadrante/features/summary/domain/period_hours.dart';
import 'package:flutter_test/flutter_test.dart';

// C2: the hours goal and its share of the period on screen.

const _yearly = HoursGoal(HoursGoalPeriod.year, 1642);
const _monthly = HoursGoal(HoursGoalPeriod.month, 140);

void main() {
  group('validity', () {
    test('1 h to every hour of a leap year, or of a 31-day month', () {
      expect(const HoursGoal(HoursGoalPeriod.year, 1).isValid, isTrue);
      expect(const HoursGoal(HoursGoalPeriod.year, 8784).isValid, isTrue);
      expect(const HoursGoal(HoursGoalPeriod.year, 8785).isValid, isFalse);
      expect(const HoursGoal(HoursGoalPeriod.year, 0).isValid, isFalse);
      expect(const HoursGoal(HoursGoalPeriod.month, 744).isValid, isTrue);
      expect(const HoursGoal(HoursGoalPeriod.month, 745).isValid, isFalse);
      expect(const HoursGoal(HoursGoalPeriod.month, -5).isValid, isFalse);
    });
  });

  group('JSON', () {
    test('round trip', () {
      for (final goal in [_yearly, _monthly]) {
        expect(HoursGoal.fromJson(goal.toJson()), goal);
      }
      expect(_yearly.toJson(), {'period': 'year', 'hours': 1642});
    });

    test('anything else is no goal', () {
      for (final bad in <Object?>[
        null,
        'year',
        42,
        <String, Object>{},
        {'period': 'week', 'hours': 10},
        {'period': 'year'},
        {'period': 'year', 'hours': '1642'},
        {'period': 'year', 'hours': 1642.5},
        {'period': 'year', 'hours': 0},
        {'period': 'month', 'hours': 800},
      ]) {
        expect(HoursGoal.fromJson(bad), isNull, reason: '$bad');
      }
    });
  });

  group('share of the period', () {
    test('a month: the monthly goal, or a twelfth of the yearly one', () {
      expect(goalMinutesForMonth(_monthly), 140 * 60);
      // 1642 h / 12 = 136 h 50 min.
      expect(goalMinutesForMonth(_yearly), 136 * 60 + 50);
      // 1000 h / 12 = 83 h 20 min.
      expect(
        goalMinutesForMonth(const HoursGoal(HoursGoalPeriod.year, 1000)),
        83 * 60 + 20,
      );
      // 1 h / 12 = 5 min.
      expect(goalMinutesForMonth(const HoursGoal(HoursGoalPeriod.year, 1)), 5);
    });

    test('a year: the yearly goal, or twelve monthly ones', () {
      expect(goalMinutesForYear(_yearly), 1642 * 60);
      expect(goalMinutesForYear(_monthly), 12 * 140 * 60);
    });

    test('a whole calendar year as a range is the yearly goal', () {
      for (final year in [2026, 2028]) {
        expect(
          goalMinutesForRange(
            _yearly,
            CivilDate(year, 1, 1),
            CivilDate(year, 12, 31),
          ),
          1642 * 60,
          reason: '$year',
        );
      }
      expect(
        goalMinutesForRange(
          _monthly,
          const CivilDate(2026, 1, 1),
          const CivilDate(2026, 12, 31),
        ),
        12 * 140 * 60,
      );
    });

    test('a range takes its days in proportion', () {
      // 10 days of 2026: 98 520 min x 10 / 365 = 2699.2 -> 2699.
      expect(
        goalMinutesForRange(
          _yearly,
          const CivilDate(2026, 10, 10),
          const CivilDate(2026, 10, 19),
        ),
        2699,
      );
      // One day of a leap year weighs 1/366.
      expect(
        goalMinutesForRange(
          _yearly,
          const CivilDate(2028, 2, 29),
          const CivilDate(2028, 2, 29),
        ),
        (1642 * 60 / 366).round(),
      );
    });

    test('a range across two years weighs each day by its own year', () {
      // 27-31 December 2027 (365) and 1-5 January 2028 (366).
      final expected = (1642 * 60 * 5 / 365 + 1642 * 60 * 5 / 366).round();
      expect(
        goalMinutesForRange(
          _yearly,
          const CivilDate(2027, 12, 27),
          const CivilDate(2028, 1, 5),
        ),
        expected,
      );
    });

    test('an end before the start is nothing', () {
      expect(
        goalMinutesForRange(
          _yearly,
          const CivilDate(2026, 10, 10),
          const CivilDate(2026, 10, 9),
        ),
        0,
      );
    });
  });

  group('progress', () {
    test('short, over and exact, with or without planned hours', () {
      const past = PeriodHours(
        tense: PeriodTense.past,
        doneMinutes: 6000,
        plannedMinutes: 0,
      );
      const current = PeriodHours(
        tense: PeriodTense.current,
        doneMinutes: 4000,
        plannedMinutes: 3000,
      );
      const future = PeriodHours(
        tense: PeriodTense.future,
        doneMinutes: 0,
        plannedMinutes: 5000,
      );
      const short = GoalProgress(targetMinutes: 8000, hours: past);
      expect(short.differenceMinutes, -2000);
      expect(short.includesPlanned, isFalse);
      const over = GoalProgress(targetMinutes: 6500, hours: current);
      expect(over.differenceMinutes, 500);
      expect(over.doneMinutes, 4000);
      expect(over.plannedMinutes, 3000);
      expect(over.includesPlanned, isTrue);
      const exact = GoalProgress(targetMinutes: 5000, hours: future);
      expect(exact.differenceMinutes, 0);
      expect(exact.includesPlanned, isTrue);
    });
  });
}
