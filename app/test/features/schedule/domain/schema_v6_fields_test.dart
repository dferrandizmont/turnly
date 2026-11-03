import 'package:cuadrante/core/database/app_database.dart';
import 'package:cuadrante/features/calendar/domain/range_editing.dart';
import 'package:cuadrante/features/schedule/data/schedule_mappers.dart';
import 'package:cuadrante/features/schedule/data/schedule_repository.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:cuadrante/features/shift_types/domain/shift_type_draft.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/test_storage.dart';

const _night = ShiftType(
  id: 'night',
  code: 'N',
  name: 'Noche',
  colorValue: 0xFF4B4FD1,
  category: ShiftCategory.work,
  startMinute: 22 * 60,
  endMinute: 6 * 60,
  hourlyRateCents: 1500,
  location: 'UCI',
  nightPlusCentsPerHour: 200,
  holidayPlusCentsPerHour: 400,
);

void main() {
  group('ShiftType and ShiftTerms', () {
    test('place and pluses take part in equality and copyWith', () {
      expect(_night.copyWith(), _night);
      expect(_night.copyWith().hashCode, _night.hashCode);
      expect(_night.copyWith(location: 'Urgencias'), isNot(_night));
      final cleared = _night.copyWith(
        clearLocation: true,
        clearNightPlus: true,
        clearHolidayPlus: true,
      );
      expect(cleared.location, isNull);
      expect(cleared.nightPlusCentsPerHour, isNull);
      expect(cleared.holidayPlusCentsPerHour, isNull);
      expect(cleared, isNot(_night));
    });

    test('the pluses are terms (versioned); the place is how the type looks', () {
      final terms = ShiftTerms.of(_night);
      expect(terms.nightPlusCentsPerHour, 200);
      expect(terms.holidayPlusCentsPerHour, 400);
      final elsewhere = _night.copyWith(
        location: 'Urgencias',
        nightPlusCentsPerHour: 1,
        holidayPlusCentsPerHour: 2,
      );
      final applied = terms.applyTo(elsewhere);
      expect(applied.location, 'Urgencias', reason: 'the current place');
      expect(applied.nightPlusCentsPerHour, 200);
      expect(applied.holidayPlusCentsPerHour, 400);
      expect(terms, isNot(ShiftTerms.of(elsewhere)));
      expect(terms.problem, isNull);
    });

    test('changing a plus asks «every day or from today on»; the place does '
        'not', () {
      expect(
        shiftTypeEditNeedsScope(
          _night,
          _night.copyWith(nightPlusCentsPerHour: 300),
        ),
        isTrue,
      );
      expect(
        shiftTypeEditNeedsScope(
          _night,
          _night.copyWith(holidayPlusCentsPerHour: 500),
        ),
        isTrue,
      );
      expect(
        shiftTypeEditNeedsScope(_night, _night.copyWith(location: 'Planta 2')),
        isFalse,
      );
      // A rest type never earns them: nothing to ask.
      const rest = ShiftType(
        id: 'r',
        code: 'L',
        name: 'Libre',
        colorValue: 1,
        category: ShiftCategory.rest,
      );
      expect(
        shiftTypeEditNeedsScope(rest, rest.copyWith(nightPlusCentsPerHour: 9)),
        isFalse,
      );
    });

    test('pluses out of range are a problem of the terms', () {
      ShiftTerms with2(int? night, int? holiday) => ShiftTerms(
        category: ShiftCategory.work,
        nightPlusCentsPerHour: night,
        holidayPlusCentsPerHour: holiday,
      );
      expect(with2(0, maxStoredMoneyCents).problem, isNull);
      expect(with2(-1, null).problem, 'hourly plus out of range');
      expect(with2(null, maxStoredMoneyCents + 1).problem, isNotNull);
    });

    test('the form draft carries place and pluses through unchanged', () {
      final draft = ShiftTypeDraft.fromShiftType(_night);
      expect(draft.toShiftType('night'), _night);
      final renamed = draft.copyWith(name: 'Noche larga');
      final saved = renamed.toShiftType('night');
      expect(saved.location, 'UCI');
      expect(saved.nightPlusCentsPerHour, 200);
      expect(saved.holidayPlusCentsPerHour, 400);
      expect(renamed, isNot(ShiftTypeDraft.fromShiftType(_night.copyWith(
        clearLocation: true,
      )).copyWith(name: 'Noche larga')));
    });
  });

  group('DayEntry extra amount', () {
    const day = CivilDate(2026, 11, 3);

    test('a day whose only content is an extra amount is not empty; 0 is '
        'none', () {
      expect(const DayEntry(date: day, extraAmountCents: -1550).isEmpty, isFalse);
      expect(const DayEntry(date: day, extraAmountCents: 0).isEmpty, isTrue);
      const entry = DayEntry(date: day, note: 'x', extraAmountCents: 900);
      expect(entry.copyWith(clearExtraAmount: true).extraAmountCents, isNull);
      expect(entry.withShiftTypeIds(const ['n']).extraAmountCents, 900);
      expect(entry, isNot(entry.copyWith(extraAmountCents: 901)));
      expect(entry.copyWith(), entry);
      expect(entry.toString(), contains('extra 900'));
    });

    test('copy and paste with notes carry it; without notes they do not', () {
      final schedule = Schedule(
        shiftTypes: const [_night],
        patterns: const [],
        runs: const [],
        entries: {
          day: const DayEntry(
            date: day,
            shiftTypeIds: ['night'],
            extraAmountCents: 4200,
          ),
        },
      );
      final clip = DayClipboard.capture(schedule, [day]);
      expect(clip.days.single.extraAmountCents, 4200);
      expect(clip.days.single.hasAnnotations, isTrue);
      final target = day.addDays(7);
      final withNotes = planPlacements(
        schedule,
        clip,
        [target],
        includeNotes: true,
      );
      expect(withNotes[target]!.extraAmountCents, 4200);
      final without = planPlacements(schedule, clip, [target]);
      expect(without[target]!.extraAmountCents, isNull);
      // A copied day without one leaves the destination's alone.
      final destination = const DayEntry(date: day, extraAmountCents: 10);
      expect(
        withAnnotationsOf(
          const ClipDay(offset: 0, shiftIds: []),
          destination,
        ).extraAmountCents,
        10,
      );
    });

    test('it is stored, read and bounded by the mapper', () async {
      final db = openMemoryDatabase();
      addTearDown(db.close);
      final repo = ScheduleRepository(db);
      await repo.saveShiftType(_night);
      await repo.apply(
        'main',
        ScheduleChange(
          patch: EntriesPatch({
            day: const EntryChange(
              null,
              DayEntry(date: day, extraAmountCents: -999),
            ),
          }),
        ),
      );
      final loaded = (await repo.load('main')).schedule;
      expect(loaded.entries[day]!.extraAmountCents, -999);
      expect(loaded.shiftTypeById('night'), _night);
      final row = DayEntryRow(
        calendarId: 'main',
        date: day,
        updatedAt: 0,
        extraAmountCents: maxStoredMoneyCents + 1,
      );
      expect(row.toEntry().extraAmountCents, isNull);
      final lowest = DayEntryRow(
        calendarId: 'main',
        date: day,
        updatedAt: 0,
        extraAmountCents: -9223372036854775807 - 1,
      );
      expect(lowest.toEntry().extraAmountCents, isNull);
    });
  });
}
