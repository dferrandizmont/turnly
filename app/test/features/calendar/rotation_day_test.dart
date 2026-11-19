import 'package:cuadrante/features/calendar/domain/rotation_day.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:flutter_test/flutter_test.dart';

import '../schedule/domain/fixtures.dart';

// The rotation actions of the day detail (`rotation_day.dart`), pure: «Empezar
// la rotación aquí», «Último día de esta rotación» and «Empezar tu rotación
// aquí». Each one is ONE step that its inverse undoes exactly, the days
// before do not change and the days changed by hand stay.

// 6x4 from Monday 5 Jan 2026: M M M M M M L L L L, then again.
const _start = CivilDate(2026, 1, 5);
CivilDate _day(int offset) => _start.addDays(offset);

Schedule _sixFour({
  CivilDate? end,
  int stepOffset = 0,
  Map<CivilDate, DayEntry> entries = const {},
}) => presetSchedule(
  '6x4',
  _start,
  end: end,
  stepOffset: stepOffset,
  entries: entries,
);

PatternRun _run(
  String id,
  String patternId,
  CivilDate start, {
  CivilDate? end,
  int stepOffset = 0,
  required int seq,
}) => PatternRun(
  id: id,
  patternId: patternId,
  startDate: start,
  endDate: end,
  stepOffset: stepOffset,
  seq: seq,
);

/// 6x4 (seq 1) and 24x72 (seq 2) in the same calendar.
Schedule _two(List<PatternRun> runs, {Map<CivilDate, DayEntry>? entries}) =>
    Schedule(
      shiftTypes: allTypes,
      patterns: [presetPattern('6x4'), presetPattern('24x72')],
      runs: runs,
      entries: entries ?? const {},
    );

void main() {
  group('automatic Saliente in day rotation actions', () {
    const pattern = Pattern(
      id: 'night-rest',
      name: 'Night and rest',
      steps: [
        ['night'],
        ['rest'],
      ],
    );
    for (final resume in [false, true]) {
      final action = resume ? 'resume' : 'restart';
      test('$action protects original overrides, bounds Saliente and undoes '
          'a real automatic patch', () {
        final date = _day(4);
        final end = _day(12); // The last day becomes a night.
        final next = end.addDays(1);
        final entries = {
          _day(5): DayEntry(
            date: _day(5),
            shiftTypeIds: const [],
            note: 'Empty',
          ),
          _day(7): DayEntry(date: _day(7), shiftTypeIds: const ['rest']),
          _day(9): DayEntry(date: _day(9), shiftTypeIds: const ['vacation']),
          _day(11): DayEntry(date: _day(11), note: 'Note without override'),
          next: DayEntry(date: next, note: 'Next rotation'),
        };
        final future = _run('future', '6x4', next, stepOffset: 6, seq: 2);
        final schedule = Schedule(
          shiftTypes: allTypes,
          patterns: [pattern, presetPattern('6x4')],
          runs: [
            _run(
              'old',
              pattern.id,
              _start,
              end: resume ? _day(1) : end,
              stepOffset: 1,
              seq: 1,
            ),
            future,
          ],
          entries: entries,
        );
        final plan = resume
            ? planResumeRun(schedule, date, seq: 3, postNightAuto: true)!
            : planRestartRun(schedule, date, seq: 3, postNightAuto: true)!;
        final after = plan.schedule;

        expect(plan.postNightDays, {_day(11)});
        expect(plan.change.patch.changes.keys, [_day(11)]);
        for (final day in [_day(5), _day(7), _day(9)]) {
          expect(after.entries[day], entries[day]);
          expect(after.resolve(day).source, DaySource.override);
        }
        expect(after.resolve(_day(11)).shiftIds, ['postNight']);
        expect(after.entries[_day(11)]?.note, 'Note without override');
        expect(after.resolve(end).shiftIds, ['night']);
        // Not just its shifts: the next day's origin, cycle step and entry
        // all stay exactly as before, even though the preceding day is night.
        expect(after.resolve(next).shiftIds, schedule.resolve(next).shiftIds);
        expect(after.resolve(next).source, schedule.resolve(next).source);
        expect(after.resolve(next).runId, schedule.resolve(next).runId);
        expect(after.resolve(next).stepIndex, schedule.resolve(next).stepIndex);
        expect(after.entries[next], entries[next]);
        expect(after.runs.firstWhere((r) => r.id == 'future'), future);
        expect(codesOf(after, _start, 4), codesOf(schedule, _start, 4));

        final undone = after.apply(plan.change.inverse());
        expect(undone.runs, schedule.runs);
        expect(undone.entries, schedule.entries);
        expect(codesOf(undone, _start, 20), codesOf(schedule, _start, 20));
      });
    }

    test('a bounded restart leaves the empty day after its end untouched', () {
      final schedule = Schedule(
        shiftTypes: allTypes,
        patterns: [pattern],
        runs: [
          _run('old', pattern.id, _start, end: _day(4), stepOffset: 1, seq: 1),
        ],
      );
      final plan = planRestartRun(
        schedule,
        _day(2),
        seq: 2,
        postNightAuto: true,
      )!;
      expect(plan.schedule.resolve(_day(4)).shiftIds, ['night']);
      expect(plan.schedule.resolve(_day(5)).shiftIds, isEmpty);
      expect(plan.schedule.resolve(_day(5)).source, DaySource.none);
      expect(plan.schedule.entries.containsKey(_day(5)), isFalse);
      expect(plan.postNightDays, {_day(3)});
    });
  });

  group('rotationDayOf', () {
    test('a day of the rotation: restart and end, never resume', () {
      final day = rotationDayOf(_sixFour(), _day(3));
      expect(day.run?.id, 'r1');
      expect(day.pattern?.id, '6x4');
      expect(day.stepIndex, 3);
      expect(day.canRestart, isTrue);
      expect(day.canEndHere, isTrue);
      expect(day.canResume, isFalse);
    });

    test('the cycle can restart even on its first step', () {
      expect(rotationDayOf(_sixFour(), _start).canRestart, isTrue);
      // The cycle comes round: day 10 is the first day again.
      final again = rotationDayOf(_sixFour(), _day(10));
      expect(again.stepIndex, 0);
      expect(again.canRestart, isTrue);
      expect(again.canEndHere, isTrue);
      expect(again.hasActions, isTrue);
    });

    test('a one-step cycle cannot restart', () {
      const pattern = Pattern(
        id: 'daily',
        name: 'Daily',
        steps: [
          ['morning'],
        ],
      );
      final schedule = Schedule(
        shiftTypes: allTypes,
        patterns: [pattern],
        runs: [_run('r1', pattern.id, _start, seq: 1)],
      );
      final date = _day(3);
      final day = rotationDayOf(schedule, date);
      expect(day.run?.id, 'r1');
      expect(day.canRestart, isFalse);
      expect(planRestartRun(schedule, date, seq: 2, stepOffset: 2), isNull);
    });

    test('the last day of a rotation cannot end there again', () {
      final day = rotationDayOf(_sixFour(end: _day(7)), _day(7));
      expect(day.canEndHere, isFalse);
      expect(day.canRestart, isTrue);
    });

    test('a day changed by hand still belongs to its rotation', () {
      final date = _day(2);
      final schedule = _sixFour(
        entries: {
          date: DayEntry(date: date, shiftTypeIds: const ['vacation']),
        },
      );
      expect(schedule.resolve(date).source, DaySource.override);
      final day = rotationDayOf(schedule, date);
      expect(day.run?.id, 'r1');
      expect(day.canRestart, isTrue);
      expect(day.canEndHere, isTrue);
    });

    test('after the rotation ended: resume, with no end', () {
      final day = rotationDayOf(_sixFour(end: _day(7)), _day(12));
      expect(day.run, isNull);
      expect(day.canRestart, isFalse);
      expect(day.canEndHere, isFalse);
      expect(day.ended?.id, 'r1');
      expect(day.endedPattern?.id, '6x4');
      expect(day.resumeUntil, isNull);
      expect(day.canResume, isTrue);
    });

    test('a calendar without rotations, or a day before the first one, has '
        'no action', () {
      expect(
        rotationDayOf(Schedule(shiftTypes: allTypes), _start).hasActions,
        isFalse,
      );
      final before = rotationDayOf(_sixFour(), _day(-3));
      expect(before.run, isNull);
      expect(before.ended, isNull);
      expect(before.hasActions, isFalse);
    });

    test('between two rotations: the one that ended last, until the day '
        'before the next one starts', () {
      final schedule = _two([
        _run('a', '6x4', _start, end: _day(7), seq: 1),
        _run('b', '24x72', _day(1), end: _day(9), seq: 2),
        _run('c', '6x4', _day(30), seq: 3),
      ]);
      final day = rotationDayOf(schedule, _day(15));
      expect(day.ended?.id, 'b');
      expect(day.endedPattern?.id, '24x72');
      expect(day.resumeUntil, _day(29));
    });

    test('two rotations that ended the same day: the newest one', () {
      final schedule = _two([
        _run('a', '6x4', _start, end: _day(7), seq: 1),
        _run('b', '24x72', _day(4), end: _day(7), seq: 2),
      ]);
      expect(rotationDayOf(schedule, _day(8)).ended?.id, 'b');
    });
  });

  group('planRestartRun («Empezar la rotación aquí»)', () {
    test('the rotation is cut the day before and starts over that day', () {
      final schedule = _sixFour();
      final date = _day(3);
      final plan = planRestartRun(schedule, date, seq: 2)!;
      final after = plan.schedule;

      expect(after.runs, hasLength(2));
      final old = after.runs.firstWhere((r) => r.id == 'r1');
      expect(old.startDate, _start);
      expect(old.endDate, _day(2));
      final fresh = after.runs.firstWhere((r) => r.id != 'r1');
      expect(fresh.patternId, '6x4');
      expect(fresh.startDate, date);
      expect(fresh.endDate, isNull);
      expect(fresh.stepOffset, 0);
      expect(fresh.seq, 2);

      // The days before are what they were; from that day the cycle starts.
      expect(codesOf(after, _start, 3), codesOf(schedule, _start, 3));
      expect(codesOf(after, date, 12), 'M M M M M M L L L L M M');
      expect(after.resolve(date).stepIndex, 0);
      expect(schedule.apply(plan.change).runs, after.runs);
    });

    test('the chosen step falls on that day and the cycle continues', () {
      final date = _day(3);
      final plan = planRestartRun(_sixFour(), date, seq: 2, stepOffset: 6)!;
      expect(plan.schedule.runs.last.stepOffset, 6);
      expect(plan.schedule.resolve(date).stepIndex, 6);
      expect(codesOf(plan.schedule, date, 5), 'L L L L M');
    });

    test('an offset beyond the length of the cycle wraps around', () {
      final date = _day(3);
      final plan = planRestartRun(_sixFour(), date, seq: 2, stepOffset: 16)!;
      expect(plan.schedule.runs.last.stepOffset, 6);
      expect(plan.schedule.resolve(date).stepIndex, 6);
    });

    test('the days changed by hand stay before, on and after the restart', () {
      final before = _day(1);
      final date = _day(3);
      final later = _day(8);
      final noted = _day(5);
      final entries = {
        before: DayEntry(date: before, shiftTypeIds: const ['vacation']),
        date: DayEntry(date: date, shiftTypeIds: const []),
        later: DayEntry(date: later, shiftTypeIds: const ['night']),
        noted: DayEntry(date: noted, note: 'Dentista'),
      };
      final schedule = _sixFour(entries: entries);
      final plan = planRestartRun(schedule, date, seq: 2, stepOffset: 6)!;

      expect(plan.change.patch.isEmpty, isTrue);
      expect(plan.schedule.entries, entries);
      expect(plan.schedule.resolve(before).shiftIds, ['vacation']);
      expect(plan.schedule.resolve(date).source, DaySource.override);
      expect(plan.schedule.resolve(date).shiftIds, isEmpty);
      expect(plan.schedule.resolve(later).shiftIds, ['night']);
      expect(plan.schedule.resolve(later).source, DaySource.override);
      expect(plan.schedule.resolve(noted).note, 'Dentista');
    });

    test('undoing it gives back the rotation exactly as it was', () {
      final date = _day(8);
      final schedule = _sixFour(
        entries: {
          date: DayEntry(date: date, shiftTypeIds: const ['night']),
        },
      );
      final plan = planRestartRun(schedule, _day(3), seq: 2)!;
      final undone = plan.schedule.apply(plan.change.inverse());
      expect(undone.runs, schedule.runs);
      expect(undone.entries, schedule.entries);
      expect(codesOf(undone, _start, 30), codesOf(schedule, _start, 30));
    });

    test('nothing to do without a rotation', () {
      expect(planRestartRun(_sixFour(), _day(-1), seq: 2, stepOffset: 2), isNull);
      expect(
        planRestartRun(_sixFour(end: _day(7)), _day(9), seq: 2, stepOffset: 2),
        isNull,
      );
    });

    test('the current step is a no-op even with a wrapped offset', () {
      final schedule = _sixFour(stepOffset: 2);
      final date = _day(3);
      expect(schedule.resolve(date).stepIndex, 5);
      expect(planRestartRun(schedule, date, seq: 2, stepOffset: 5), isNull);
      expect(planRestartRun(schedule, date, seq: 2, stepOffset: 15), isNull);
    });

    test('on the first day, the restart needs a different step', () {
      final schedule = _sixFour();
      final date = _day(10);
      expect(planRestartRun(schedule, _start, seq: 2), isNull);
      expect(planRestartRun(schedule, date, seq: 2, stepOffset: 0), isNull);
      final plan = planRestartRun(schedule, date, seq: 2, stepOffset: 2)!;
      expect(plan.schedule.resolve(date).stepIndex, 2);
    });

    test('a rotation that starts that day on another day of the cycle is '
        'replaced', () {
      final schedule = _sixFour(stepOffset: 7);
      final plan = planRestartRun(schedule, _start, seq: 2)!;
      expect(plan.schedule.runs, hasLength(1));
      final fresh = plan.schedule.runs.single;
      expect(fresh.startDate, _start);
      expect(fresh.stepOffset, 0);
      expect(codesOf(plan.schedule, _start, 7), 'M M M M M M L');
      expect(plan.schedule.apply(plan.change.inverse()).runs, schedule.runs);
    });

    test('a rotation with an end keeps it, and the earlier rotation still '
        'follows after it', () {
      // 24x72 without end underneath; 6x4 on top from day 4 to day 23.
      final schedule = _two([
        _run('base', '24x72', _start, seq: 1),
        _run('top', '6x4', _day(4), end: _day(23), seq: 2),
      ]);
      final date = _day(9);
      expect(schedule.resolve(date).stepIndex, 5);
      final plan = planRestartRun(schedule, date, seq: 3, stepOffset: 6)!;
      final after = plan.schedule;

      final top = after.runs.firstWhere((r) => r.id == 'top');
      expect(top.endDate, _day(8));
      final fresh = after.runs.firstWhere((r) => r.seq == 3);
      expect(fresh.patternId, '6x4');
      expect(fresh.startDate, date);
      expect(fresh.endDate, _day(23));
      expect(fresh.stepOffset, 6);
      expect(after.runs.firstWhere((r) => r.id == 'base'), schedule.runs.first);

      expect(codesOf(after, _start, 9), codesOf(schedule, _start, 9));
      expect(codesOf(after, date, 10), 'L L L L M M M M M M');
      // After its end the earlier rotation rules, as before.
      expect(codesOf(after, _day(24), 8), codesOf(schedule, _day(24), 8));
      expect(after.resolve(_day(24)).runId, 'base');
      expect(after.apply(plan.change.inverse()).runs, schedule.runs);
    });

    test('with automatic saliente the nights of the new cycle get theirs, in '
        'the same step', () {
      // 12h: D N12 S L. Restarting on the S day makes that day D.
      final schedule = presetSchedule('12h', _start);
      final date = _day(2);
      final plan = planRestartRun(schedule, date, seq: 2, postNightAuto: true)!;
      expect(codesOf(plan.schedule, date, 4), 'D N12 S L');
      final undone = plan.schedule.apply(plan.change.inverse());
      expect(undone.runs, schedule.runs);
      expect(undone.entries, schedule.entries);
    });
  });

  group('restartCoversOtherRuns', () {
    test('false with a single rotation or with older ones underneath', () {
      expect(restartCoversOtherRuns(_sixFour(), _day(3)), isFalse);
      final schedule = _two([
        _run('base', '24x72', _start, seq: 1),
        _run('top', '6x4', _day(4), seq: 2),
      ]);
      expect(restartCoversOtherRuns(schedule, _day(9)), isFalse);
    });

    test('true when a newer rotation starts later on top of it', () {
      final schedule = _two([
        _run('base', '6x4', _start, seq: 1),
        _run('later', '24x72', _day(20), end: _day(27), seq: 2),
      ]);
      expect(restartCoversOtherRuns(schedule, _day(3)), isTrue);
      // The restarted rotation is the newest one: it takes those days.
      final plan = planRestartRun(schedule, _day(3), seq: 3)!;
      expect(plan.schedule.resolve(_day(20)).runId, 'run-3');
    });

    test('false when the newer rotation starts after this one ends', () {
      final schedule = _two([
        _run('base', '6x4', _start, end: _day(15), seq: 1),
        _run('later', '24x72', _day(20), seq: 2),
      ]);
      expect(restartCoversOtherRuns(schedule, _day(3)), isFalse);
      final plan = planRestartRun(schedule, _day(3), seq: 3)!;
      expect(
        plan.schedule.runs.firstWhere((r) => r.id == 'later'),
        schedule.runs.last,
      );
    });
  });

  group('planEndRunOn («Último día de esta rotación»)', () {
    test('the rotation ends that day and the days after have none', () {
      final schedule = _sixFour();
      final date = _day(3);
      final plan = planEndRunOn(schedule, date)!;
      expect(plan.run.id, 'r1');
      expect(plan.next, isNull);

      final after = schedule.apply(plan.change);
      expect(after.runs.single.endDate, date);
      expect(codesOf(after, _start, 4), codesOf(schedule, _start, 4));
      expect(after.resolve(_day(4)).source, DaySource.none);
      expect(codesOf(after, _day(4), 5), '- - - - -');
    });

    test('the days changed by hand stay, after the end too', () {
      final later = _day(8);
      final entries = {
        _day(1): DayEntry(date: _day(1), shiftTypeIds: const ['vacation']),
        later: DayEntry(date: later, shiftTypeIds: const ['night'], note: 'X'),
      };
      final schedule = _sixFour(entries: entries);
      final plan = planEndRunOn(schedule, _day(3))!;
      final after = schedule.apply(plan.change);
      expect(plan.change.patch.isEmpty, isTrue);
      expect(after.entries, entries);
      expect(after.resolve(later).shiftIds, ['night']);
      expect(after.resolve(later).note, 'X');
    });

    test('the earlier rotation that was still running underneath takes '
        'over', () {
      final schedule = _two([
        _run('base', '24x72', _start, seq: 1),
        _run('top', '6x4', _day(4), seq: 2),
      ]);
      final date = _day(9);
      final plan = planEndRunOn(schedule, date)!;
      expect(plan.run.id, 'top');
      expect(plan.next?.id, 'base');

      final after = schedule.apply(plan.change);
      expect(after.resolve(date).runId, 'top');
      expect(after.resolve(_day(10)).runId, 'base');
      // 24x72 (G L L L) from 5 Jan: day 10 is its third day, day 12 a guard.
      expect(codesOf(after, _day(10), 4), 'L L G L');
      expect(after.runs.firstWhere((r) => r.id == 'base'), schedule.runs.first);
    });

    test('undoing it gives the rotation back with its seq', () {
      final schedule = _sixFour();
      final plan = planEndRunOn(schedule, _day(3))!;
      final undone = schedule.apply(plan.change).apply(plan.change.inverse());
      expect(undone.runs, schedule.runs);
      expect(undone.runs.single.seq, 1);
      expect(codesOf(undone, _start, 20), codesOf(schedule, _start, 20));
    });

    test('nothing to do without a rotation or on its last day', () {
      expect(planEndRunOn(_sixFour(), _day(-1)), isNull);
      expect(planEndRunOn(_sixFour(end: _day(7)), _day(7)), isNull);
      expect(planEndRunOn(_sixFour(end: _day(7)), _day(9)), isNull);
    });

    test('a rotation can end on its first day', () {
      final schedule = _sixFour();
      final plan = planEndRunOn(schedule, _start)!;
      final after = schedule.apply(plan.change);
      expect(after.runs.single.endDate, _start);
      expect(codesOf(after, _start, 3), 'M - -');
    });
  });

  group('planResumeRun («Empezar tu rotación aquí»)', () {
    test('the last rotation applies again from that day, with no end', () {
      final schedule = _sixFour(end: _day(7));
      final date = _day(12);
      final plan = planResumeRun(schedule, date, seq: 2)!;
      final after = plan.schedule;

      expect(after.runs, hasLength(2));
      expect(after.runs.firstWhere((r) => r.id == 'r1'), schedule.runs.single);
      final fresh = after.runs.firstWhere((r) => r.id != 'r1');
      expect(fresh.patternId, '6x4');
      expect(fresh.startDate, date);
      expect(fresh.endDate, isNull);
      expect(fresh.stepOffset, 0);
      // Before: untouched, the gap included.
      expect(codesOf(after, _start, 12), codesOf(schedule, _start, 12));
      expect(codesOf(after, _day(8), 4), '- - - -');
      expect(codesOf(after, date, 11), 'M M M M M M L L L L M');
    });

    test('with the day of the cycle that falls on that day', () {
      final schedule = _sixFour(end: _day(7));
      final plan = planResumeRun(schedule, _day(12), seq: 2, stepOffset: 5)!;
      expect(plan.schedule.runs.last.stepOffset, 5);
      expect(codesOf(plan.schedule, _day(12), 6), 'M L L L L M');
      // Past the end of the cycle it wraps round.
      final wrapped = planResumeRun(
        schedule,
        _day(12),
        seq: 2,
        stepOffset: 16,
      )!;
      expect(wrapped.schedule.runs.last.stepOffset, 6);
    });

    test('the days changed by hand stay', () {
      final date = _day(12);
      final later = _day(14);
      final entries = {
        _day(2): DayEntry(date: _day(2), shiftTypeIds: const ['vacation']),
        date: DayEntry(date: date, note: 'Vuelta'),
        later: DayEntry(date: later, shiftTypeIds: const ['night']),
      };
      final schedule = _sixFour(end: _day(7), entries: entries);
      final plan = planResumeRun(schedule, date, seq: 2)!;
      expect(plan.change.patch.isEmpty, isTrue);
      expect(plan.schedule.entries, entries);
      expect(plan.schedule.resolve(date).note, 'Vuelta');
      expect(plan.schedule.resolve(date).shiftIds, ['morning']);
      expect(plan.schedule.resolve(later).shiftIds, ['night']);
    });

    test('before another rotation: it lasts until the day before, and that '
        'rotation is not touched', () {
      final schedule = _two([
        _run('old', '6x4', _start, end: _day(7), seq: 1),
        _run('next', '24x72', _day(30), seq: 2),
      ]);
      final date = _day(12);
      final plan = planResumeRun(schedule, date, seq: 3)!;
      final after = plan.schedule;

      final fresh = after.runs.firstWhere((r) => r.seq == 3);
      expect(fresh.startDate, date);
      expect(fresh.endDate, _day(29));
      expect(after.runs.firstWhere((r) => r.id == 'next'), schedule.runs.last);
      expect(after.runs.firstWhere((r) => r.id == 'old'), schedule.runs.first);
      expect(after.resolve(_day(29)).runId, 'run-3');
      expect(after.resolve(_day(30)).runId, 'next');
      expect(codesOf(after, _day(30), 4), codesOf(schedule, _day(30), 4));
    });

    test('undoing it leaves the calendar as it was', () {
      final schedule = _sixFour(end: _day(7));
      final plan = planResumeRun(schedule, _day(12), seq: 2, stepOffset: 3)!;
      final undone = plan.schedule.apply(plan.change.inverse());
      expect(undone.runs, schedule.runs);
      expect(undone.entries, schedule.entries);
      expect(codesOf(undone, _start, 30), codesOf(schedule, _start, 30));
    });

    test('nothing to do on a day with rotation or with none before it', () {
      expect(planResumeRun(_sixFour(), _day(3), seq: 2), isNull);
      expect(planResumeRun(_sixFour(), _day(-2), seq: 2), isNull);
      expect(
        planResumeRun(Schedule(shiftTypes: allTypes), _start, seq: 1),
        isNull,
      );
    });
  });
}
