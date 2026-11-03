import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:cuadrante/features/summary/domain/month_summary.dart';
import 'package:flutter_test/flutter_test.dart';

// Noche 22-06 (8 h) at 10 EUR/h; from 1 Nov it becomes 22-08 (10 h) at
// 12 EUR/h with a 20 EUR plus.
const _night = ShiftType(
  id: 'night',
  code: 'N',
  name: 'Noche',
  colorValue: 0xFF4B4FD1,
  category: ShiftCategory.work,
  startMinute: 22 * 60,
  endMinute: 6 * 60,
  hourlyRateCents: 1000,
);
final _night10 = _night.copyWith(endMinute: 8 * 60, hourlyRateCents: 1200);
const _morning = ShiftType(
  id: 'morning',
  code: 'M',
  name: 'Mañana',
  colorValue: 0xFFF5A524,
  category: ShiftCategory.work,
  startMinute: 6 * 60,
  endMinute: 14 * 60,
  hourlyRateCents: 1000,
);
const _rest = ShiftType(
  id: 'rest',
  code: 'L',
  name: 'Libre',
  colorValue: 0xFFE4E4E7,
  category: ShiftCategory.rest,
);

const _today = CivilDate(2026, 11, 1);
final _oldTerms = ShiftTerms.of(_night);
final _newTerms = ShiftTerms.of(_night10);

/// N L, from 1 Sep, open-ended.
const _pattern = Pattern(
  id: 'nl',
  name: 'N L',
  steps: [
    ['night'],
    ['rest'],
  ],
);
const _run = PatternRun(
  id: 'r1',
  patternId: 'nl',
  startDate: CivilDate(2026, 9, 1),
  seq: 1,
);

Schedule _schedule({
  Map<String, List<ShiftTypeVersion>> versions = const {},
  ShiftType night = _night,
  Iterable<PatternRun> runs = const [_run],
  Map<CivilDate, DayEntry> entries = const {},
}) => Schedule(
  shiftTypes: [night, _morning, _rest],
  patterns: const [_pattern],
  runs: runs,
  entries: entries,
  shiftTypeVersions: versions,
);

/// The schedule after «Solo a partir de hoy» on [before].
Schedule _changedFromToday(Schedule before) => before.copyWith(
  shiftTypes: [
    for (final t in before.shiftTypes) t.id == 'night' ? _night10 : t,
  ],
  shiftTypeVersions: {
    ...before.shiftTypeVersions,
    'night': historyForChangeFrom(
      before.versionsOf('night'),
      before: ShiftTerms.of(before.shiftTypeById('night')!),
      after: _newTerms,
      from: _today,
    ),
  },
);

void main() {
  group('shiftTypeEditNeedsScope', () {
    test('cosmetic fields never ask', () {
      for (final after in [
        _night.copyWith(name: 'Nocturno'),
        _night.copyWith(code: 'NN'),
        _night.copyWith(colorValue: 0xFF000000),
        _night.copyWith(icon: ShiftIcon.values.first),
        _night.copyWith(alarmSound: 'content://media/internal/audio/1'),
      ]) {
        expect(
          shiftTypeEditNeedsScope(_night, after),
          isFalse,
          reason: '$after',
        );
      }
    });

    test('every field of hours or money asks', () {
      for (final after in [
        _night.copyWith(startMinute: 21 * 60),
        _night.copyWith(endMinute: 7 * 60),
        _night.copyWith(clearTimes: true),
        _night.copyWith(paidMinutes: 450),
        _night.copyWith(nightOverride: true),
        _night.copyWith(nightOverride: false),
        _night.copyWith(hourlyRateCents: 1100),
        _night.copyWith(clearHourlyRate: true),
        _night.copyWith(fixedPlusCents: 2000),
        _night.copyWith(category: ShiftCategory.absence),
        _morning.copyWith(
          id: 'night',
          segment2StartMinute: 17 * 60,
          segment2DurationMinutes: 120,
        ),
      ]) {
        expect(
          shiftTypeEditNeedsScope(_night, after),
          isTrue,
          reason: '$after',
        );
      }
      final split = _morning.copyWith(
        segment2StartMinute: 17 * 60,
        segment2DurationMinutes: 120,
      );
      expect(
        shiftTypeEditNeedsScope(
          split,
          split.copyWith(segment2DurationMinutes: 180),
        ),
        isTrue,
      );
    });

    test('compares paid minutes and pay fields as they count', () {
      // 480 stored on an 8 h shift is the same as nothing stored.
      expect(
        shiftTypeEditNeedsScope(_night.copyWith(paidMinutes: 480), _night),
        isFalse,
      );
      // A rate or a night override on a rest type counts for nothing.
      final restWithRate = _rest.copyWith(
        hourlyRateCents: 1000,
        nightOverride: true,
        fixedPlusCents: 500,
      );
      expect(shiftTypeEditNeedsScope(restWithRate, _rest), isFalse);
      // A plus on a worked shift without times does count.
      final noTimes = _night.copyWith(clearTimes: true);
      expect(
        shiftTypeEditNeedsScope(noTimes, noTimes.copyWith(fixedPlusCents: 1)),
        isTrue,
      );
      // A rate on a worked shift without times is never read.
      expect(
        shiftTypeEditNeedsScope(
          noTimes,
          noTimes.copyWith(hourlyRateCents: 999),
        ),
        isFalse,
      );
    });
  });

  group('ShiftTerms', () {
    test('applyTo keeps the look and takes every term', () {
      final styled = _night10.copyWith(
        name: 'Nocturno',
        icon: ShiftIcon.values.first,
        alarmSound: 'content://media/x',
      );
      final back = _oldTerms.applyTo(styled);
      expect(back.name, 'Nocturno');
      expect(back.icon, ShiftIcon.values.first);
      expect(back.alarmSound, 'content://media/x');
      expect(ShiftTerms.of(back), _oldTerms);
      expect(
        back.copyWith(name: 'Noche', clearIcon: true, clearAlarmSound: true),
        _night,
      );
    });

    test('problem mirrors the rules of a stored type', () {
      expect(_oldTerms.problem, isNull);
      expect(
        const ShiftTerms(category: ShiftCategory.work, startMinute: 60).problem,
        isNotNull,
      );
      expect(
        const ShiftTerms(
          category: ShiftCategory.work,
          startMinute: 0,
          endMinute: 1440,
        ).problem,
        isNotNull,
      );
      expect(
        const ShiftTerms(
          category: ShiftCategory.work,
          hourlyRateCents: maxHourlyRateCents + 1,
        ).problem,
        isNotNull,
      );
      expect(
        const ShiftTerms(
          category: ShiftCategory.work,
          fixedPlusCents: -1,
        ).problem,
        isNotNull,
      );
      expect(
        const ShiftTerms(category: ShiftCategory.work, paidMinutes: -1).problem,
        isNotNull,
      );
      expect(
        const ShiftTerms(
          category: ShiftCategory.work,
          startMinute: 9 * 60,
          endMinute: 13 * 60,
          segment2StartMinute: 13 * 60,
          segment2DurationMinutes: 60,
        ).problem,
        isNotNull,
      );
    });
  });

  group('historyForChangeFrom', () {
    test('the first change keeps the old terms up to yesterday', () {
      final history = historyForChangeFrom(
        const [],
        before: _oldTerms,
        after: _newTerms,
        from: _today,
      );
      expect(history, [
        ShiftTypeVersion(
          until: const CivilDate(2026, 10, 31),
          terms: _oldTerms,
        ),
      ]);
      expect(currentTermsSince(history), _today);
    });

    test('a later change adds a period; earlier ones stay', () {
      final first = historyForChangeFrom(
        const [],
        before: _oldTerms,
        after: _newTerms,
        from: _today,
      );
      final third = ShiftTerms.of(_night10.copyWith(hourlyRateCents: 1500));
      final second = historyForChangeFrom(
        first,
        before: _newTerms,
        after: third,
        from: const CivilDate(2027, 1, 1),
      );
      expect(second, [
        ShiftTypeVersion(
          until: const CivilDate(2026, 10, 31),
          terms: _oldTerms,
        ),
        ShiftTypeVersion(
          until: const CivilDate(2026, 12, 31),
          terms: _newTerms,
        ),
      ]);
      expect(currentTermsSince(second), const CivilDate(2027, 1, 1));
    });

    test('changing twice on the same day keeps one version', () {
      final first = historyForChangeFrom(
        const [],
        before: _oldTerms,
        after: _newTerms,
        from: _today,
      );
      final again = historyForChangeFrom(
        first,
        before: _newTerms,
        after: ShiftTerms.of(_night10.copyWith(hourlyRateCents: 1300)),
        from: _today,
      );
      expect(again, first);
    });

    test('going back to the old terms from today needs no version', () {
      final first = historyForChangeFrom(
        const [],
        before: _oldTerms,
        after: _newTerms,
        from: _today,
      );
      expect(
        historyForChangeFrom(
          first,
          before: _newTerms,
          after: _oldTerms,
          from: _today,
        ),
        isEmpty,
      );
    });

    test('a clock moved back cuts the version that governs yesterday', () {
      final first = historyForChangeFrom(
        const [],
        before: _oldTerms,
        after: _newTerms,
        from: _today,
      );
      // «Today» is now 10 Oct: days before keep the old terms, 10 Oct on get
      // the newest ones; the version up to 31 Oct only governed later days.
      final third = ShiftTerms.of(_night10.copyWith(hourlyRateCents: 1500));
      final back = historyForChangeFrom(
        first,
        before: _newTerms,
        after: third,
        from: const CivilDate(2026, 10, 10),
      );
      expect(back, [
        ShiftTypeVersion(until: const CivilDate(2026, 10, 9), terms: _oldTerms),
      ]);
    });

    test(
      'unsorted input is sorted and duplicates are refused by the check',
      () {
        final a = ShiftTypeVersion(
          until: const CivilDate(2026, 3, 1),
          terms: _oldTerms,
        );
        final b = ShiftTypeVersion(
          until: const CivilDate(2026, 1, 1),
          terms: _newTerms,
        );
        expect(sortedVersions([a, b]), [b, a]);
        expect(checkShiftTypeVersions([a, b]), isNull);
        expect(checkShiftTypeVersions([a, a]), isNotNull);
        expect(
          checkShiftTypeVersions([
            ShiftTypeVersion(
              until: _today,
              terms: const ShiftTerms(
                category: ShiftCategory.work,
                startMinute: 1,
              ),
            ),
          ]),
          isNotNull,
        );
      },
    );
  });

  group('Schedule with versions', () {
    test('without versions every day resolves the very same object', () {
      final s = _schedule();
      expect(
        identical(s.resolve(const CivilDate(2026, 9, 1)).shifts.single, _night),
        isTrue,
      );
      expect(s.shiftTypeOn('night', const CivilDate(2020, 1, 1)), same(_night));
      expect(s.shiftTypeOn('ghost', _today), isNull);
    });

    test('the past keeps the old hours, today and after get the new', () {
      final s = _changedFromToday(_schedule());
      // 31 Oct and 2 Nov are night days (even distance from 1 Sep); 1 Nov
      // is a rest day.
      final past = s.resolve(const CivilDate(2026, 10, 31)).shifts.single;
      final now = s.resolve(const CivilDate(2026, 11, 2)).shifts.single;
      expect(past.id, 'night');
      expect(past.endMinute, 6 * 60);
      expect(past.hourlyRateCents, 1000);
      expect(now.endMinute, 8 * 60);
      expect(now.hourlyRateCents, 1200);
      expect(s.shiftTypeById('night'), _night10);
      // The look is one for every day.
      final renamed = s.copyWith(
        shiftTypes: [
          for (final t in s.shiftTypes)
            t.id == 'night' ? t.copyWith(name: 'Nocturno') : t,
        ],
      );
      expect(
        renamed.resolve(const CivilDate(2026, 10, 31)).shifts.single.name,
        'Nocturno',
      );
    });

    test('a past month summary does not change; the next one is new', () {
      final before = _schedule();
      final after = _changedFromToday(before);
      final october = summarizeMonth(before, const CivilDate(2026, 10, 1));
      final octoberAfter = summarizeMonth(after, const CivilDate(2026, 10, 1));
      expect(octoberAfter.workedMinutes, october.workedMinutes);
      expect(octoberAfter.nightMinutes, october.nightMinutes);
      expect(octoberAfter.earningsCents, october.earningsCents);
      expect(octoberAfter.shiftsWorked, october.shiftsWorked);
      // October: nights on the odd days 1..31 → 16 nights of 8 h at 10 EUR.
      expect(october.shiftsWorked, 16);
      expect(october.workedMinutes, 16 * 480);
      expect(october.earningsCents, 16 * 8000);

      final november = summarizeMonth(after, _today);
      // November: 1 Nov is a rest day (61 days after 1 Sep), so the nights
      // are 2, 4, ... 30: 15 nights of 10 h at 12 EUR.
      expect(november.shiftsWorked, 15);
      expect(november.workedMinutes, 15 * 600);
      expect(november.earningsCents, 15 * 12000);
      final novNight = november.types.firstWhere((t) => t.type.id == 'night');
      expect(novNight.earningsCents, 15 * 12000);
      expect(novNight.missingRate, isFalse);
    });

    test('a period across the change adds each day at its own rate', () {
      final after = _changedFromToday(_schedule());
      // 25 Oct-8 Nov: nights 25, 27, 29, 31 Oct (8 h at 10 EUR) and 2, 4, 6,
      // 8 Nov (10 h at 12 EUR).
      final range = summarizeRange(
        after,
        const CivilDate(2026, 10, 25),
        const CivilDate(2026, 11, 8),
      );
      expect(range.workedMinutes, 4 * 480 + 4 * 600);
      expect(range.earningsCents, 4 * 8000 + 4 * 12000);
      final night = range.types.firstWhere((t) => t.type.id == 'night');
      expect(night.paidMinutes, 4 * 480 + 4 * 600);
      expect(night.earningsCents, 4 * 8000 + 4 * 12000);
      // Without a rate before the change, the old nights are «sin precio».
      final unpriced = _changedFromToday(
        _schedule(night: _night.copyWith(clearHourlyRate: true)),
      );
      final mixed = summarizeRange(
        unpriced,
        const CivilDate(2026, 10, 25),
        const CivilDate(2026, 11, 8),
      ).types.firstWhere((t) => t.type.id == 'night');
      expect(mixed.earningsCents, 4 * 12000);
      expect(mixed.missingRate, isTrue);
    });

    test('overrides before and after today follow their date', () {
      final s = _changedFromToday(
        _schedule(
          entries: {
            // An off day turned into a night, before and after today.
            const CivilDate(2026, 10, 2): const DayEntry(
              date: CivilDate(2026, 10, 2),
              shiftTypeIds: ['night'],
            ),
            const CivilDate(2026, 11, 2): const DayEntry(
              date: CivilDate(2026, 11, 2),
              shiftTypeIds: ['morning', 'night'],
            ),
          },
        ),
      );
      expect(
        s.resolve(const CivilDate(2026, 10, 2)).shifts.single.endMinute,
        6 * 60,
      );
      final doubled = s.resolve(const CivilDate(2026, 11, 2));
      expect(doubled.shiftIds, ['morning', 'night']);
      expect(doubled.shifts.last.endMinute, 8 * 60);
      expect(doubled.shifts.first, same(_morning));
    });

    test('several rotations: the newest rotation still wins', () {
      const pattern2 = Pattern(
        id: 'n',
        name: 'N',
        steps: [
          ['night'],
        ],
      );
      const week = PatternRun(
        id: 'r2',
        patternId: 'n',
        startDate: CivilDate(2026, 10, 26),
        endDate: CivilDate(2026, 11, 8),
        seq: 2,
      );
      final s = _changedFromToday(
        _schedule(runs: const [_run, week])
            .copyWith(patterns: const [_pattern, pattern2]),
      );
      final oct31 = s.resolve(const CivilDate(2026, 10, 31));
      expect(oct31.runId, 'r2');
      expect(oct31.shifts.single.endMinute, 6 * 60);
      final nov2 = s.resolve(const CivilDate(2026, 11, 2));
      expect(nov2.runId, 'r2');
      expect(nov2.shifts.single.endMinute, 8 * 60);
      final nov9 = s.resolve(const CivilDate(2026, 11, 9));
      expect(nov9.runId, 'r1');
      expect(nov9.shiftIds, ['rest']);
    });

    test('two changes: each period has its own terms', () {
      final once = _changedFromToday(_schedule());
      final third = _night10.copyWith(hourlyRateCents: 1500);
      final twice = once.copyWith(
        shiftTypes: [
          for (final t in once.shiftTypes) t.id == 'night' ? third : t,
        ],
        shiftTypeVersions: {
          'night': historyForChangeFrom(
            once.versionsOf('night'),
            before: _newTerms,
            after: ShiftTerms.of(third),
            from: const CivilDate(2027, 1, 1),
          ),
        },
      );
      int? rate(CivilDate d) => twice.resolve(d).shifts.single.hourlyRateCents;
      expect(rate(const CivilDate(2026, 10, 30)), isNull); // a rest day
      expect(rate(const CivilDate(2026, 10, 31)), 1000);
      expect(rate(const CivilDate(2026, 12, 30)), 1200);
      expect(rate(const CivilDate(2027, 1, 1)), 1500);
    });

    test('copyWith and apply keep the versions; empty lists are dropped', () {
      final s = _changedFromToday(_schedule());
      final painted = s.apply(
        ScheduleChange(
          patch: s.paint(const PaintTool.replace('morning'), [
            const CivilDate(2026, 10, 30),
          ]),
        ),
      );
      expect(painted.versionsOf('night'), s.versionsOf('night'));
      expect(
        s.copyWith(shiftTypeVersions: {'night': const []}).shiftTypeVersions,
        isEmpty,
      );
    });

    test('occurrences of a past night end at 06:00, today at 08:00', () {
      final s = _changedFromToday(_schedule());
      final list = s.occurrences(
        const CivilDate(2026, 10, 30),
        const CivilDate(2026, 11, 2),
      );
      expect([for (final o in list) o.endMinuteAbs], [1440 + 360, 1440 + 480]);
    });
  });

  group('showsShiftTypeBetween', () {
    test('a rotation day gone counts; one that never came does not', () {
      final s = _schedule();
      expect(s.showsShiftTypeBetween('night', before: _today), isTrue);
      expect(
        s.showsShiftTypeBetween('night', before: const CivilDate(2026, 9, 1)),
        isFalse,
      );
      // Only the first day (a night) is gone.
      expect(
        s.showsShiftTypeBetween('night', before: const CivilDate(2026, 9, 2)),
        isTrue,
      );
      // The rest step falls on 2 Sep: before 2 Sep there is no rest day.
      expect(
        s.showsShiftTypeBetween('rest', before: const CivilDate(2026, 9, 2)),
        isFalse,
      );
      expect(s.showsShiftTypeBetween('morning', before: _today), isFalse);
    });

    test('a rotation that only starts today is not in the past', () {
      final s = _schedule(
        runs: const [
          PatternRun(id: 'r', patternId: 'nl', startDate: _today, seq: 1),
        ],
      );
      expect(s.showsShiftTypeBetween('night', before: _today), isFalse);
      expect(
        s.showsShiftTypeBetween('night', before: _today.addDays(1)),
        isTrue,
      );
    });

    test('an override hides the rotation and a past override counts', () {
      final s = _schedule(
        runs: const [
          PatternRun(
            id: 'r',
            patternId: 'nl',
            startDate: CivilDate(2026, 10, 30),
            endDate: CivilDate(2026, 10, 30),
            seq: 1,
          ),
        ],
        entries: {
          const CivilDate(2026, 10, 30): const DayEntry(
            date: CivilDate(2026, 10, 30),
            shiftTypeIds: [],
          ),
          const CivilDate(2026, 10, 5): const DayEntry(
            date: CivilDate(2026, 10, 5),
            shiftTypeIds: ['morning'],
          ),
          const CivilDate(2026, 11, 5): const DayEntry(
            date: CivilDate(2026, 11, 5),
            shiftTypeIds: ['rest'],
          ),
        },
      );
      expect(s.showsShiftTypeBetween('night', before: _today), isFalse);
      expect(s.showsShiftTypeBetween('morning', before: _today), isTrue);
      expect(s.showsShiftTypeBetween('rest', before: _today), isFalse);
    });

    test('a newer rotation that covers the past hides the older one', () {
      const restOnly = Pattern(
        id: 'l',
        name: 'L',
        steps: [
          ['rest'],
        ],
      );
      final s = _schedule(
        runs: const [
          _run,
          PatternRun(
            id: 'r2',
            patternId: 'l',
            startDate: CivilDate(2026, 9, 1),
            seq: 2,
          ),
        ],
      ).copyWith(patterns: const [_pattern, restOnly]);
      expect(s.showsShiftTypeBetween('night', before: _today), isFalse);
    });

    test('from limits the search to the current terms', () {
      final s = _changedFromToday(_schedule());
      final since = currentTermsSince(s.versionsOf('night'));
      expect(since, _today);
      expect(
        s.showsShiftTypeBetween('night', from: since, before: _today),
        isFalse,
      );
      expect(
        s.showsShiftTypeBetween(
          'night',
          from: since,
          before: const CivilDate(2026, 11, 2),
        ),
        isFalse, // 1 Nov is a rest day
      );
      expect(
        s.showsShiftTypeBetween(
          'night',
          from: since,
          before: const CivilDate(2026, 11, 3),
        ),
        isTrue,
      );
    });
  });
}
