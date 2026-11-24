import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:cuadrante/features/summary/domain/month_summary.dart';
import 'package:cuadrante/features/summary/domain/period_hours.dart';
import 'package:flutter_test/flutter_test.dart';

// B2: «Turnos trabajados» counts only the shifts before today; today and the
// days after it are planned, like the hours of the card above.

const _guard = ShiftType(
  id: 'guard',
  code: 'G',
  name: 'Guardia',
  colorValue: 0xFFF5A524,
  category: ShiftCategory.work,
  startMinute: 8 * 60,
  endMinute: 8 * 60,
);

/// A 24 h guard every 4th day from 19 October 2026 (G, S, L, L) up to the end
/// of December: 19, 23, 27, 31 Oct, 4, 8, 12, 16, 20, 24, 28 Nov, 2, 6... Dec.
Schedule _schedule() {
  final entries = <CivilDate, DayEntry>{};
  for (
    var d = const CivilDate(2026, 10, 19);
    !d.isAfter(const CivilDate(2026, 12, 31));
    d = d.addDays(4)
  ) {
    entries[d] = DayEntry(date: d, shiftTypeIds: const ['guard']);
  }
  return Schedule(shiftTypes: const [_guard], entries: entries);
}

const _monday = CivilDate(2026, 11, 23);
const _nov1 = CivilDate(2026, 11, 1);
const _nov30 = CivilDate(2026, 11, 30);

void main() {
  test('November on Monday 23: 5 worked guards, 2 planned', () {
    final shifts = splitPeriodShifts(_schedule(), _nov1, _nov30, _monday);
    expect(shifts.tense, PeriodTense.current);
    expect(shifts.doneShifts, 5); // 4, 8, 12, 16 and 20
    expect(shifts.doneDays, 5);
    expect(shifts.plannedShifts, 2); // 24 and 28
    expect(shifts.plannedDays, 2);
    expect(shifts.totalShifts, 7);

    final hours = splitPeriodHours(_schedule(), _nov1, _nov30, _monday);
    expect(hours.doneMinutes, 120 * 60);
    expect(hours.plannedMinutes, 48 * 60);
  });

  test('a past month: everything worked, nothing planned', () {
    final shifts = splitPeriodShifts(
      _schedule(),
      const CivilDate(2026, 10, 1),
      const CivilDate(2026, 10, 31),
      _monday,
    );
    expect(shifts.tense, PeriodTense.past);
    expect(shifts.doneShifts, 4); // 19, 23, 27 and 31
    expect(shifts.plannedShifts, 0);
    expect(shifts.plannedDays, 0);
  });

  test('a future month: 0 worked, all planned', () {
    final shifts = splitPeriodShifts(
      _schedule(),
      const CivilDate(2026, 12, 1),
      const CivilDate(2026, 12, 31),
      _monday,
    );
    expect(shifts.tense, PeriodTense.future);
    expect(shifts.doneShifts, 0);
    expect(shifts.doneDays, 0);
    expect(shifts.plannedShifts, 8); // 2, 6, 10, 14, 18, 22, 26 and 30
    expect(shifts.plannedDays, 8);
  });

  test('the shift of today is planned, not worked', () {
    final today = _monday.addDays(1); // Tuesday 24: a guard day
    final shifts = splitPeriodShifts(_schedule(), _nov1, _nov30, today);
    expect(shifts.tense, PeriodTense.current);
    expect(shifts.doneShifts, 5);
    expect(shifts.plannedShifts, 2); // today (24) and 28
    expect(
      splitPeriodHours(_schedule(), _nov1, _nov30, today).plannedMinutes,
      48 * 60,
    );
  });

  test('worked and planned add up to the whole period', () {
    final schedule = _schedule();
    final whole = summarizeRange(schedule, _nov1, _nov30);
    final shifts = splitPeriodShifts(schedule, _nov1, _nov30, _monday);
    expect(shifts.totalShifts, whole.shiftsWorked);
    expect(shifts.doneDays + shifts.plannedDays, whole.workedDays);
  });
}
