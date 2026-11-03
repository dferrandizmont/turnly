import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';

/// Shift types and schedules shared by the `.ics` and share-link tests.
const morning = ShiftType(
  id: 'morning',
  code: 'M',
  name: 'Mañana',
  colorValue: 0xFFF5A524,
  category: ShiftCategory.work,
  startMinute: 6 * 60,
  endMinute: 14 * 60,
);
const night = ShiftType(
  id: 'night',
  code: 'N',
  name: 'Noche',
  colorValue: 0xFF4B4FD1,
  category: ShiftCategory.work,
  startMinute: 22 * 60,
  endMinute: 6 * 60,
);
const early = ShiftType(
  id: 'early',
  code: 'E',
  name: 'Madrugada',
  colorValue: 0xFF4B4FD1,
  category: ShiftCategory.work,
  startMinute: 2 * 60 + 30,
  endMinute: 4 * 60,
);
const split = ShiftType(
  id: 'split',
  code: 'P',
  name: 'Partido',
  colorValue: 0xFF15AABF,
  category: ShiftCategory.work,
  startMinute: 9 * 60,
  endMinute: 13 * 60,
  segment2StartMinute: 17 * 60,
  segment2DurationMinutes: 4 * 60,
);
const course = ShiftType(
  id: 'course',
  code: 'C',
  name: 'Curso',
  colorValue: 0xFF15AABF,
  category: ShiftCategory.work,
);
const rest = ShiftType(
  id: 'rest',
  code: 'L',
  name: 'Libre',
  colorValue: 0xFFE4E4E7,
  category: ShiftCategory.rest,
);
const sick = ShiftType(
  id: 'sickLeave',
  code: 'B',
  name: 'Baja médica',
  colorValue: 0xFFE5484D,
  category: ShiftCategory.absence,
);
const vacation = ShiftType(
  id: 'vacation',
  code: 'V',
  name: 'Vacaciones',
  colorValue: 0xFF30A46C,
  category: ShiftCategory.absence,
);

Schedule scheduleOf(Map<CivilDate, List<String>> days, {String? note}) =>
    Schedule(
      shiftTypes: const [
        morning,
        night,
        early,
        split,
        course,
        rest,
        sick,
        vacation,
      ],
      entries: {
        for (final e in days.entries)
          e.key: DayEntry(date: e.key, shiftTypeIds: e.value, note: note),
      },
    );
