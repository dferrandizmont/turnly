import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:cuadrante/features/summary/domain/earned_so_far.dart';
import 'package:cuadrante/features/summary/domain/hours_bag.dart';
import 'package:cuadrante/features/summary/domain/hours_goal.dart';
import 'package:cuadrante/features/summary/domain/month_summary.dart';
import 'package:cuadrante/features/summary/domain/pay_period.dart';
import 'package:cuadrante/features/summary/domain/summary_range.dart';
import 'package:flutter_test/flutter_test.dart';

const _h = 60;

const _morning = ShiftType(
  id: 'M',
  code: 'M',
  name: 'Mañana',
  colorValue: 0xFF4B4FD1,
  category: ShiftCategory.work,
  startMinute: 8 * _h,
  endMinute: 15 * _h,
  hourlyRateCents: 1000,
);

/// A morning (7 h) every day from [from] to [to].
Schedule _everyDay(CivilDate from, CivilDate to) => Schedule(
  shiftTypes: const [_morning],
  entries: {
    for (var d = from; !d.isAfter(to); d = d.addDays(1))
      d: DayEntry(date: d, shiftTypeIds: const ['M']),
  },
);

void main() {
  group('payPeriodOf', () {
    test('without a closing day it is the calendar month', () {
      expect(
        payPeriodOf(const CivilDate(2026, 11, 14), null),
        const SummaryRange(CivilDate(2026, 11, 1), CivilDate(2026, 11, 30)),
      );
    });

    test('from the 21st to the 20th: November is 21 Oct to 20 Nov', () {
      expect(
        payPeriodOf(const CivilDate(2026, 11, 1), 20),
        const SummaryRange(CivilDate(2026, 10, 21), CivilDate(2026, 11, 20)),
      );
    });

    test('January starts in the December of the year before', () {
      expect(
        payPeriodOf(const CivilDate(2027, 1, 1), 20),
        const SummaryRange(CivilDate(2026, 12, 21), CivilDate(2027, 1, 20)),
      );
    });

    test('a day February does not have is its last day', () {
      // Closing on the 30th: February 2027 ends on the 28th.
      expect(
        payPeriodOf(const CivilDate(2027, 2, 1), 30),
        const SummaryRange(CivilDate(2027, 1, 31), CivilDate(2027, 2, 28)),
      );
      // And March starts the day after.
      expect(
        payPeriodOf(const CivilDate(2027, 3, 1), 30),
        const SummaryRange(CivilDate(2027, 3, 1), CivilDate(2027, 3, 30)),
      );
      // A leap February ends on the 29th.
      expect(
        payPeriodOf(const CivilDate(2028, 2, 1), 30).to,
        const CivilDate(2028, 2, 29),
      );
    });

    test('the payroll months follow each other without gaps or overlaps', () {
      for (final closing in [1, 15, 20, 28, 29, 30]) {
        var month = const CivilDate(2026, 1, 1);
        for (var i = 0; i < 30; i++) {
          final next = month.addDays(month.daysInMonth);
          expect(
            payPeriodOf(next, closing).from,
            payPeriodOf(month, closing).to.addDays(1),
            reason: 'closing $closing, ${month.toIso()}',
          );
          month = next;
        }
      }
    });
  });

  group('payMonthOf', () {
    test('a day after the closing day belongs to the next month', () {
      expect(
        payMonthOf(const CivilDate(2026, 10, 21), 20),
        const CivilDate(2026, 11, 1),
      );
      expect(
        payMonthOf(const CivilDate(2026, 10, 20), 20),
        const CivilDate(2026, 10, 1),
      );
      expect(
        payMonthOf(const CivilDate(2026, 12, 25), 20),
        const CivilDate(2027, 1, 1),
      );
    });

    test('without a closing day it is the month of the day', () {
      expect(
        payMonthOf(const CivilDate(2026, 10, 31), null),
        const CivilDate(2026, 10, 1),
      );
    });
  });

  test('payYearOf is its twelve payroll months', () {
    expect(
      payYearOf(2027, 20),
      const SummaryRange(CivilDate(2026, 12, 21), CivilDate(2027, 12, 20)),
    );
    expect(
      payYearOf(2027, null),
      const SummaryRange(CivilDate(2027, 1, 1), CivilDate(2027, 12, 31)),
    );
  });

  group('the summary with a closing day', () {
    final schedule = _everyDay(
      const CivilDate(2026, 10, 1),
      const CivilDate(2026, 11, 30),
    );

    test('November counts 21 Oct to 20 Nov and is named November', () {
      final summary = summarizeMonth(
        schedule,
        const CivilDate(2026, 11, 1),
        closingDay: 20,
      );
      expect(summary.month, const CivilDate(2026, 11, 1));
      // 11 days of October + 20 of November.
      expect(summary.workedDays, 31);
      expect(summary.workedMinutes, 31 * 7 * _h);
      expect(summary.earningsCents, 31 * 7 * 1000);
    });

    test('without one it is the calendar month, as before', () {
      final summary = summarizeMonth(schedule, const CivilDate(2026, 11, 1));
      expect(summary.workedDays, 30);
      expect(summary.month, const CivilDate(2026, 11, 1));
    });

    test('the year adds up the payroll months', () {
      final year = summarizeYearTotals(schedule, 2026, closingDay: 20);
      // October: 1-20 Oct; November: 21 Oct-20 Nov; December: 21-30 Nov.
      expect(year.months[9].workedDays, 20);
      expect(year.months[10].workedDays, 31);
      expect(year.months[11].workedDays, 10);
      expect(year.months[11].month, const CivilDate(2026, 12, 1));
      expect(year.workedMinutes, 61 * 7 * _h);
    });

    test('the hours bag counts the payroll months', () {
      final balance = hoursBalance(
        schedule,
        const HoursGoal(HoursGoalPeriod.month, 100),
        fromMonth: const CivilDate(2026, 11, 1),
        toMonth: const CivilDate(2026, 11, 1),
        closingDay: 20,
      );
      expect(balance.workedMinutes, 31 * 7 * _h);
    });

    test('«Llevas ganado» counts from the first day of the payroll month', () {
      final earned = earnedSoFar(
        schedule,
        const CivilDate(2026, 11, 1),
        today: const CivilDate(2026, 10, 25),
        nowMinuteOfDay: 20 * _h,
        closingDay: 20,
      );
      // 21 to 25 October, all worked by 20:00.
      expect(earned.workedMinutes, 5 * 7 * _h);
      expect(earned.month, const CivilDate(2026, 11, 1));
    });
  });

  test('isValidClosingDay accepts 1 to 30', () {
    expect(isValidClosingDay(0), isFalse);
    expect(isValidClosingDay(1), isTrue);
    expect(isValidClosingDay(30), isTrue);
    expect(isValidClosingDay(31), isFalse);
  });
}
