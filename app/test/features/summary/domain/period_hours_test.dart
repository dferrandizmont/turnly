import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:cuadrante/features/summary/domain/month_summary.dart';
import 'package:cuadrante/features/summary/domain/period_hours.dart';
import 'package:flutter_test/flutter_test.dart';

// A3: worked hours (days before today) against planned ones (today on).

const _h = 60;
const _today = CivilDate(2026, 10, 19);

const _morning = ShiftType(
  id: 'morning',
  code: 'M',
  name: 'Mañana',
  colorValue: 0xFFF5A524,
  category: ShiftCategory.work,
  startMinute: 6 * _h,
  endMinute: 14 * _h,
);

/// A Mañana every day from 1 September to 30 November 2026, plus the
/// [extra] entries.
Schedule _schedule([Map<CivilDate, DayEntry> extra = const {}]) {
  final entries = <CivilDate, DayEntry>{};
  for (
    var d = const CivilDate(2026, 9, 1);
    !d.isAfter(const CivilDate(2026, 11, 30));
    d = d.addDays(1)
  ) {
    entries[d] = DayEntry(date: d, shiftTypeIds: const ['morning']);
  }
  return Schedule(
    shiftTypes: const [_morning],
    entries: {...entries, ...extra},
  );
}

void main() {
  group('periodTense', () {
    test('a period that ended yesterday is past', () {
      expect(
        periodTense(const CivilDate(2026, 9, 1), _today.addDays(-1), _today),
        PeriodTense.past,
      );
    });

    test('one that starts today or later is future', () {
      expect(periodTense(_today, _today, _today), PeriodTense.future);
      expect(
        periodTense(_today, const CivilDate(2026, 10, 31), _today),
        PeriodTense.future,
      );
      expect(
        periodTense(
          const CivilDate(2026, 11, 1),
          const CivilDate(2026, 11, 30),
          _today,
        ),
        PeriodTense.future,
      );
    });

    test('one that starts before today and reaches it is current', () {
      expect(
        periodTense(const CivilDate(2026, 10, 1), _today, _today),
        PeriodTense.current,
      );
      expect(
        periodTense(
          const CivilDate(2026, 10, 1),
          const CivilDate(2026, 10, 31),
          _today,
        ),
        PeriodTense.current,
      );
    });
  });

  group('splitPeriodHours', () {
    test('a past month: all worked, nothing planned', () {
      final s = splitPeriodHours(
        _schedule(),
        const CivilDate(2026, 9, 1),
        const CivilDate(2026, 9, 30),
        _today,
      );
      expect(s.tense, PeriodTense.past);
      expect(s.doneMinutes, 30 * 8 * _h);
      expect(s.plannedMinutes, 0);
      expect(s.totalMinutes, 30 * 8 * _h);
    });

    test('a future month: all planned', () {
      final s = splitPeriodHours(
        _schedule(),
        const CivilDate(2026, 11, 1),
        const CivilDate(2026, 11, 30),
        _today,
      );
      expect(s.tense, PeriodTense.future);
      expect(s.doneMinutes, 0);
      expect(s.plannedMinutes, 30 * 8 * _h);
    });

    test('the current month: worked up to yesterday, today is planned', () {
      final s = splitPeriodHours(
        _schedule(),
        const CivilDate(2026, 10, 1),
        const CivilDate(2026, 10, 31),
        _today,
      );
      expect(s.tense, PeriodTense.current);
      expect(s.doneMinutes, 18 * 8 * _h);
      expect(s.plannedMinutes, 13 * 8 * _h);
      // The two add up to the month's total.
      expect(s.totalMinutes, summarizeMonth(_schedule(), _today).workedMinutes);
    });

    test('overtime and early leave go with their day', () {
      final yesterday = _today.addDays(-1);
      final schedule = _schedule({
        yesterday: DayEntry(
          date: yesterday,
          shiftTypeIds: const ['morning'],
          overtimeMinutes: 90,
        ),
        _today: const DayEntry(
          date: _today,
          shiftTypeIds: ['morning'],
          earlyLeaveMinutes: 60,
        ),
      });
      final s = splitPeriodHours(
        schedule,
        const CivilDate(2026, 10, 1),
        const CivilDate(2026, 10, 31),
        _today,
      );
      expect(s.doneMinutes, 18 * 8 * _h + 90);
      expect(s.plannedMinutes, 13 * 8 * _h - 60);
      expect(s.totalMinutes, summarizeMonth(schedule, _today).workedMinutes);
    });

    test('a free range across today, and a year', () {
      final range = splitPeriodHours(
        _schedule(),
        const CivilDate(2026, 10, 10),
        const CivilDate(2026, 10, 25),
        _today,
      );
      expect(range.doneMinutes, 9 * 8 * _h);
      expect(range.plannedMinutes, 7 * 8 * _h);
      final year = splitPeriodHours(
        _schedule(),
        const CivilDate(2026, 1, 1),
        const CivilDate(2026, 12, 31),
        _today,
      );
      expect(year.tense, PeriodTense.current);
      // September (30) and 1-18 October.
      expect(year.doneMinutes, (30 + 18) * 8 * _h);
      // 19-31 October and November.
      expect(year.plannedMinutes, (13 + 30) * 8 * _h);
    });

    test('an empty period is 0 and 0', () {
      final s = splitPeriodHours(
        _schedule(),
        const CivilDate(2027, 1, 1),
        const CivilDate(2027, 1, 31),
        _today,
      );
      expect(
        s,
        const PeriodHours(
          tense: PeriodTense.future,
          doneMinutes: 0,
          plannedMinutes: 0,
        ),
      );
    });
  });
}
