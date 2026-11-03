import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:cuadrante/features/swaps/domain/shift_swap.dart';
import 'package:cuadrante/features/swaps/domain/swap_schedule_plan.dart';
import 'package:flutter_test/flutter_test.dart';

/// The rotation of the tests: a morning and a night, one of each.
const _start = CivilDate(2026, 11, 2);
const _night = CivilDate(2026, 11, 3);
const _morningAgain = CivilDate(2026, 11, 4);

ShiftType _type(String key) => shiftTemplateByKey(key).toShiftType(key);

Schedule _schedule({Map<CivilDate, DayEntry> entries = const {}}) => Schedule(
  shiftTypes: [_type('morning'), _type('night')],
  patterns: const [
    Pattern(
      id: 'p',
      name: 'P',
      steps: [
        ['morning'],
        ['night'],
      ],
    ),
  ],
  runs: const [
    PatternRun(id: 'run-1', patternId: 'p', startDate: _start, seq: 1),
  ],
  entries: entries,
);

ShiftSwap _swap({
  CivilDate date = _start,
  CivilDate? returnDate,
  SwapDirection direction = SwapDirection.theyOwe,
  List<String>? given,
  List<String>? received,
}) => ShiftSwap(
  id: 's',
  calendarId: 'main',
  date: date,
  colleague: 'Marta',
  direction: direction,
  givenShiftTypeIds: given,
  receivedShiftTypeIds: received,
  returnDate: returnDate,
  createdAt: 1,
  updatedAt: 1,
);

void main() {
  group('planSwapApplication', () {
    test('the day I gave loses the shift I gave', () {
      final plan = planSwapApplication(
        _schedule(),
        _swap(given: const ['morning']),
      );
      expect(plan.days, [_start]);
      final change = plan.change.patch.changes[_start]!;
      expect(change.after?.shiftTypeIds, isEmpty);
      expect(change.before, isNull);
    });

    test('what is left of the day stays', () {
      final schedule = _schedule(
        entries: {
          _start: DayEntry(
            date: _start,
            shiftTypeIds: const ['morning', 'night'],
          ),
        },
      );
      final plan = planSwapApplication(
        schedule,
        _swap(given: const ['morning']),
      );
      final change = plan.change.patch.changes[_start]!;
      expect(change.after?.shiftTypeIds, const ['night']);
    });

    test('the day I receive gets the shift the colleague gives me', () {
      final plan = planSwapApplication(
        _schedule(),
        _swap(
          given: const ['morning'],
          received: const ['night'],
          returnDate: _morningAgain,
        ),
      );
      expect(plan.days, [_start, _morningAgain]);
      final change = plan.change.patch.changes[_morningAgain]!;
      expect(change.after?.shiftTypeIds, const ['night']);
    });

    test('the note and the extras of the day stay', () {
      final schedule = _schedule(
        entries: {
          _start: DayEntry(
            date: _start,
            note: 'Cambio con Marta',
            overtimeMinutes: 30,
          ),
        },
      );
      final plan = planSwapApplication(
        schedule,
        _swap(given: const ['morning']),
      );
      final after = plan.change.patch.changes[_start]!.after!;
      expect(after.note, 'Cambio con Marta');
      expect(after.overtimeMinutes, 30);
      expect(after.shiftTypeIds, isEmpty);
    });

    test('a day that is already as it should be is left out', () {
      final plan = planSwapApplication(
        _schedule(),
        _swap(date: _night, given: const ['morning']),
      );
      expect(plan.isEmpty, isTrue);
      expect(plan.before, isEmpty);
    });

    test('the shift types that do not exist are ignored', () {
      final plan = planSwapApplication(
        _schedule(),
        _swap(given: const ['ghost']),
      );
      expect(plan.isEmpty, isTrue);
    });

    test('without the shifts of a side its day is left alone', () {
      final plan = planSwapApplication(_schedule(), _swap());
      expect(plan.isEmpty, isTrue);
    });

    test('a received day without shifts leaves the day free', () {
      final plan = planSwapApplication(
        _schedule(),
        _swap(received: const [], returnDate: _morningAgain),
      );
      final change = plan.change.patch.changes[_morningAgain]!;
      expect(change.after?.shiftTypeIds, isEmpty);
    });

    test('both days are one change (one undo step)', () {
      final plan = planSwapApplication(
        _schedule(),
        _swap(
          given: const ['morning'],
          received: const ['night'],
          returnDate: _morningAgain,
        ),
      );
      expect(plan.change.patch.changes, hasLength(2));
      expect(plan.before.keys, hasLength(2));
    });

    test('the same day for both sides ends with the shift received', () {
      final plan = planSwapApplication(
        _schedule(),
        _swap(
          given: const ['morning'],
          received: const ['night'],
          returnDate: _start,
        ),
      );
      final change = plan.change.patch.changes[_start]!;
      expect(change.after?.shiftTypeIds, const ['night']);
      expect(change.before, isNull);
    });
  });

  group('planSwapUndo', () {
    test('puts the days back as they were', () {
      final schedule = _schedule();
      final plan = planSwapApplication(
        schedule,
        _swap(
          given: const ['morning'],
          received: const ['night'],
          returnDate: _morningAgain,
        ),
      );
      final changed = schedule.apply(plan.change);
      final undo = planSwapUndo(changed, plan.before);
      expect(undo.days, hasLength(2));
      final back = changed.apply(undo.change);
      expect(back.entries, schedule.entries);
    });

    test('does nothing when the days already are as they were', () {
      final schedule = _schedule();
      final plan = planSwapApplication(
        schedule,
        _swap(given: const ['morning']),
      );
      final undo = planSwapUndo(schedule, plan.before);
      expect(undo.isEmpty, isTrue);
    });

    test('the note and the extras added after applying stay (H4)', () {
      final schedule = _schedule(
        entries: {
          _start: DayEntry(
            date: _start,
            shiftTypeIds: const ['morning', 'night'],
          ),
        },
      );
      final plan = planSwapApplication(
        schedule,
        _swap(given: const ['morning']),
      );
      final applied = schedule.apply(plan.change);
      // The person then writes a note, extra hours and an extra amount on the
      // day (the change never touched them).
      final withNote = applied.entries[_start]!.copyWith(
        note: 'Llevar llaves',
        overtimeMinutes: 45,
        extraAmountCents: 2500,
      );
      final edited = applied.apply(
        ScheduleChange(
          patch: EntriesPatch({
            _start: EntryChange(applied.entries[_start], withNote),
          }),
        ),
      );

      final undo = planSwapUndo(edited, plan.before);
      final after = edited.apply(undo.change).entries[_start]!;
      expect(after.shiftTypeIds, const ['morning', 'night']);
      expect(after.note, 'Llevar llaves');
      expect(after.overtimeMinutes, 45);
      expect(after.extraAmountCents, 2500);
    });

    test('the shifts come back on a day that was left with none (H4)', () {
      final schedule = _schedule(
        entries: {
          _start: DayEntry(date: _start, shiftTypeIds: const ['morning']),
        },
      );
      final plan = planSwapApplication(
        schedule,
        _swap(given: const ['morning']),
      );
      final applied = schedule.apply(plan.change);
      expect(applied.entries[_start]!.shiftTypeIds, isEmpty);

      final undo = planSwapUndo(applied, plan.before);
      final after = applied.apply(undo.change);
      expect(after.entries[_start]!.shiftTypeIds, const ['morning']);
    });
  });
}
