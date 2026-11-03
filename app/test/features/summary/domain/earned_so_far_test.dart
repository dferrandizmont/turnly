import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:cuadrante/features/summary/domain/earned_so_far.dart';
import 'package:cuadrante/features/summary/domain/month_summary.dart';
import 'package:flutter_test/flutter_test.dart';

// What the user has earned so far this month (P9, fila 25 de
// `docs/paridad-pago.md`).

const _october = CivilDate(2026, 10, 1);
const _today = CivilDate(2026, 10, 15);

const _morning = ShiftType(
  id: 'M',
  code: 'M',
  name: 'Mañana',
  colorValue: 0xFFF5A524,
  category: ShiftCategory.work,
  startMinute: 480,
  endMinute: 960,
  hourlyRateCents: 1000,
);

const _night = ShiftType(
  id: 'N',
  code: 'N',
  name: 'Noche',
  colorValue: 0xFF4B4FD1,
  category: ShiftCategory.work,
  startMinute: 1320,
  endMinute: 360,
  hourlyRateCents: 1000,
);

Schedule _schedule(
  List<DayEntry> entries, {
  List<ShiftType> types = const [_morning],
}) =>
    Schedule(shiftTypes: types, entries: {for (final e in entries) e.date: e});

DayEntry _entry(int day, [List<String> ids = const ['M'], int? overtime]) =>
    DayEntry(
      date: CivilDate(2026, 10, day),
      shiftTypeIds: ids,
      overtimeMinutes: overtime,
    );

void main() {
  group('the gross', () {
    test('adds the days that passed and the part of today already worked', () {
      final schedule = _schedule([_entry(14), _entry(15)]);
      // At 10:00 the shift of today has been worked two hours.
      final earned = earnedSoFar(
        schedule,
        _october,
        today: _today,
        nowMinuteOfDay: 10 * 60,
      );
      // The 14th (8 h x 10,00) and two hours of the 15th.
      expect(earned.grossCents, 8000 + 2000);
      expect(earned.workedMinutes, 480 + 120);
      expect(earned.netCents, 10000);
      expect(earned.hasMoney, isTrue);
    });

    test('adds the whole day when it has already ended', () {
      final schedule = _schedule([_entry(14), _entry(15)]);
      final earned = earnedSoFar(
        schedule,
        _october,
        today: _today,
        nowMinuteOfDay: 16 * 60,
      );
      expect(earned.grossCents, 16000);
      expect(earned.workedMinutes, 960);
    });

    test('does not count the days that are still to come', () {
      final schedule = _schedule([_entry(14), _entry(15), _entry(20)]);
      final earned = earnedSoFar(
        schedule,
        _october,
        today: _today,
        nowMinuteOfDay: 16 * 60,
      );
      expect(earned.grossCents, 16000);
      expect(earned.workedMinutes, 960);
    });

    test('counts the night hours worked so far', () {
      // The night shift of the 14th is still running at 02:00 of the 15th:
      // only the four hours worked (22:00-02:00) count.
      final schedule = _schedule(
        [
          _entry(14, ['N']),
        ],
        types: const [_night],
      );
      final earned = earnedSoFar(
        schedule,
        _october,
        today: _today,
        nowMinuteOfDay: 2 * 60,
      );
      expect(earned.workedMinutes, 240);
      expect(earned.nightMinutes, 240);
      expect(earned.grossCents, 4000);
    });

    test('is nothing without rates', () {
      final schedule = Schedule(
        shiftTypes: const [
          ShiftType(
            id: 'M',
            code: 'M',
            name: 'Mañana',
            colorValue: 0xFFF5A524,
            category: ShiftCategory.work,
            startMinute: 480,
            endMinute: 960,
          ),
        ],
        entries: {_entry(14).date: _entry(14)},
      );
      final earned = earnedSoFar(
        schedule,
        _october,
        today: _today,
        nowMinuteOfDay: 16 * 60,
      );
      expect(earned.grossCents, isNull);
      expect(earned.netCents, isNull);
      expect(earned.hasMoney, isFalse);
      expect(earned.workedMinutes, 480);
    });

    test(
      'counts the fixed plus of days without a schedule before the cutoff',
      () {
        const plusType = ShiftType(
          id: 'P',
          code: 'P',
          name: 'Plus',
          colorValue: 0xFF4B4FD1,
          category: ShiftCategory.work,
          fixedPlusCents: 3000,
        );
        final schedule = _schedule(
          [
            _entry(14, ['P']),
          ],
          types: const [plusType],
        );
        final earned = earnedSoFar(
          schedule,
          _october,
          today: _today,
          nowMinuteOfDay: 16 * 60,
        );
        // The 14th is before the cutoff: the shift without a schedule has
        // already been worked and earns its fixed plus.
        expect(earned.grossCents, 3000);
        expect(earned.hasMoney, isTrue);
        // At the end of the month «llevas ganado» matches the month estimate.
        expect(
          earned.grossCents,
          summarizeMonth(schedule, _october).earningsCents,
        );
        final atMonthEnd = earnedSoFar(
          schedule,
          _october,
          today: const CivilDate(2026, 11, 1),
          nowMinuteOfDay: 0,
        );
        expect(
          atMonthEnd.grossCents,
          summarizeMonth(schedule, _october).earningsCents,
        );
      },
    );
  });

  group('the net', () {
    test('is the gross without the withholding', () {
      final schedule = _schedule([_entry(14), _entry(15)]);
      final earned = earnedSoFar(
        schedule,
        _october,
        today: _today,
        nowMinuteOfDay: 10 * 60,
        withholdingPercent: 15,
      );
      expect(earned.grossCents, 10000);
      expect(earned.netCents, 8500);
      expect(earned.withholdingPercent, 15);
      expect(earned.estimate.netCents, 8500);
    });
  });

  group('the extras of today', () {
    test('count only when the shift has already ended', () {
      final schedule = _schedule([
        _entry(15, ['M'], 60),
      ]);
      // At 10:00 the shift is still running: the overtime is not known yet.
      final running = earnedSoFar(
        schedule,
        _october,
        today: _today,
        nowMinuteOfDay: 10 * 60,
      );
      expect(running.workedMinutes, 120);
      expect(running.grossCents, 2000);

      // At 17:00 the shift ended an hour ago: the overtime counts.
      final ended = earnedSoFar(
        schedule,
        _october,
        today: _today,
        nowMinuteOfDay: 17 * 60,
      );
      expect(ended.workedMinutes, 540);
      expect(ended.grossCents, 8000 + 1000);
    });
  });

  group('other months', () {
    test('a month that passed is counted whole', () {
      final schedule = _schedule([
        DayEntry(date: const CivilDate(2026, 9, 10), shiftTypeIds: const ['M']),
        _entry(14),
        _entry(15),
      ]);
      final past = earnedSoFar(
        schedule,
        const CivilDate(2026, 9, 1),
        today: _today,
        nowMinuteOfDay: 10 * 60,
      );
      expect(past.month, const CivilDate(2026, 9, 1));
      expect(past.workedMinutes, 480);
      expect(past.grossCents, 8000);
    });

    test('a month that is still to come is nothing', () {
      final schedule = _schedule([_entry(14), _entry(15)]);
      final future = earnedSoFar(
        schedule,
        const CivilDate(2026, 11, 1),
        today: _today,
        nowMinuteOfDay: 10 * 60,
      );
      expect(future.workedMinutes, 0);
      expect(future.grossCents, isNull);
    });
  });
}
