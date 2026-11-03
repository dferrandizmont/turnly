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
const _sick = ShiftType(
  id: 'sick',
  code: 'B',
  name: 'Baja',
  colorValue: 0xFFE5484D,
  category: ShiftCategory.absence,
);

void main() {
  group('dayKindOf', () {
    test('no shift is unrecorded', () {
      expect(dayKindOf(const []), DayKind.unrecorded);
    });

    test('a work shift is work', () {
      expect(dayKindOf(const [_work]), DayKind.work);
    });

    test('only rest shifts are rest', () {
      expect(dayKindOf(const [_rest]), DayKind.rest);
      expect(dayKindOf(const [_rest, _rest]), DayKind.rest);
    });

    test('only absences are absence', () {
      expect(dayKindOf(const [_vacation]), DayKind.absence);
      expect(dayKindOf(const [_sick, _vacation]), DayKind.absence);
    });

    test('work wins over everything, in any order', () {
      expect(dayKindOf(const [_rest, _work]), DayKind.work);
      expect(dayKindOf(const [_work, _vacation]), DayKind.work);
      expect(dayKindOf(const [_vacation, _rest, _work]), DayKind.work);
    });

    test('an absence wins over a rest shift', () {
      expect(dayKindOf(const [_rest, _vacation]), DayKind.absence);
      expect(dayKindOf(const [_vacation, _rest]), DayKind.absence);
    });
  });

  group('DayKind', () {
    test('only rest and absence are off', () {
      expect(DayKind.work.isOff, isFalse);
      expect(DayKind.rest.isOff, isTrue);
      expect(DayKind.absence.isOff, isTrue);
      expect(DayKind.unrecorded.isOff, isFalse);
    });

    test('everything but unrecorded is recorded', () {
      expect(DayKind.work.isRecorded, isTrue);
      expect(DayKind.rest.isRecorded, isTrue);
      expect(DayKind.absence.isRecorded, isTrue);
      expect(DayKind.unrecorded.isRecorded, isFalse);
    });
  });

  group('ResolvedDay.kind', () {
    const day = CivilDate(2026, 10, 5);
    final schedule = Schedule(
      shiftTypes: const [_work, _rest, _vacation],
      entries: {
        day: DayEntry(date: day, shiftTypeIds: const ['rest', 'vacation']),
        day.addDays(1): DayEntry(date: day.addDays(1), note: 'Cena'),
        day.addDays(2): DayEntry(date: day.addDays(2), overtimeMinutes: 30),
        day.addDays(3): DayEntry(
          date: day.addDays(3),
          shiftTypeIds: const ['work'],
        ),
      },
    );

    test('reads the shifts of the resolved day', () {
      expect(schedule.resolve(day).kind, DayKind.absence);
      expect(schedule.resolve(day.addDays(3)).kind, DayKind.work);
    });

    test('a note or an extra alone does not record a day', () {
      expect(schedule.resolve(day.addDays(1)).kind, DayKind.unrecorded);
      expect(schedule.resolve(day.addDays(2)).kind, DayKind.unrecorded);
    });

    test('a day nothing says anything about is unrecorded', () {
      expect(schedule.resolve(day.addDays(30)).kind, DayKind.unrecorded);
    });
  });
}
