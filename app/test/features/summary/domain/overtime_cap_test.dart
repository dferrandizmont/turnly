import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:cuadrante/features/summary/domain/month_summary.dart';
import 'package:cuadrante/features/summary/domain/overtime_cap.dart';
import 'package:flutter_test/flutter_test.dart';

const _h = 60;

OvertimeCapStatus _status(int usedHours, {int cap = 80}) => OvertimeCapStatus(
  cap: OvertimeCap(OvertimeCapPeriod.year, cap),
  usedMinutes: usedHours * _h,
);

void main() {
  group('the level against the cap', () {
    test('below 80 % it does not warn', () {
      final status = _status(63);
      expect(status.level, OvertimeCapLevel.ok);
      expect(status.warns, isFalse);
      expect(status.leftMinutes, 17 * _h);
      expect(status.excessMinutes, 0);
    });

    test('from 80 % it is near', () {
      expect(_status(64).level, OvertimeCapLevel.near);
      expect(_status(79).level, OvertimeCapLevel.near);
      expect(_status(64).warns, isTrue);
    });

    test('exactly the cap is reached, nothing left', () {
      final status = _status(80);
      expect(status.level, OvertimeCapLevel.reached);
      expect(status.leftMinutes, 0);
      expect(status.excessMinutes, 0);
    });

    test('more than the cap is over, by how much', () {
      final status = OvertimeCapStatus(
        cap: const OvertimeCap(OvertimeCapPeriod.month, 10),
        usedMinutes: 10 * _h + 30,
      );
      expect(status.level, OvertimeCapLevel.over);
      expect(status.excessMinutes, 30);
      expect(status.leftMinutes, 0);
    });

    test('the 80 % works on minutes, not rounded hours', () {
      // 80 % of 10 h is 8 h: 7 h 59 min is still fine.
      const cap = OvertimeCap(OvertimeCapPeriod.month, 10);
      expect(
        const OvertimeCapStatus(cap: cap, usedMinutes: 8 * _h - 1).level,
        OvertimeCapLevel.ok,
      );
      expect(
        const OvertimeCapStatus(cap: cap, usedMinutes: 8 * _h).level,
        OvertimeCapLevel.near,
      );
    });
  });

  group('the stored cap', () {
    test('goes to JSON and back', () {
      const cap = OvertimeCap(OvertimeCapPeriod.year, 80);
      expect(OvertimeCap.fromJson(cap.toJson()), cap);
    });

    test('a bad value is no cap', () {
      expect(OvertimeCap.fromJson(null), isNull);
      expect(OvertimeCap.fromJson({'period': 'week', 'hours': 5}), isNull);
      expect(OvertimeCap.fromJson({'period': 'year', 'hours': '80'}), isNull);
      expect(OvertimeCap.fromJson({'period': 'year', 'hours': 0}), isNull);
      expect(
        OvertimeCap.fromJson({'period': 'month', 'hours': 31 * 24 + 1}),
        isNull,
      );
    });
  });

  test('the overtime counted is the one noted on the days of the period', () {
    const morning = ShiftType(
      id: 'M',
      code: 'M',
      name: 'Mañana',
      colorValue: 0xFF4B4FD1,
      category: ShiftCategory.work,
      startMinute: 8 * _h,
      endMinute: 15 * _h,
    );
    final schedule = Schedule(
      shiftTypes: const [morning],
      entries: {
        const CivilDate(2026, 10, 20): const DayEntry(
          date: CivilDate(2026, 10, 20),
          shiftTypeIds: ['M'],
          overtimeMinutes: 3 * _h,
        ),
        const CivilDate(2026, 10, 25): const DayEntry(
          date: CivilDate(2026, 10, 25),
          shiftTypeIds: ['M'],
          overtimeMinutes: 2 * _h,
        ),
      },
    );
    // With a closing day of 20 the 25th belongs to November.
    final october = summarizeMonth(
      schedule,
      const CivilDate(2026, 10, 1),
      closingDay: 20,
    );
    final november = summarizeMonth(
      schedule,
      const CivilDate(2026, 11, 1),
      closingDay: 20,
    );
    expect(october.overtimeMinutes, 3 * _h);
    expect(november.overtimeMinutes, 2 * _h);
    final year = summarizeYearTotals(schedule, 2026, closingDay: 20);
    final status = OvertimeCapStatus(
      cap: const OvertimeCap(OvertimeCapPeriod.year, 5),
      usedMinutes: year.overtimeMinutes,
    );
    expect(status.level, OvertimeCapLevel.reached);
  });
}
