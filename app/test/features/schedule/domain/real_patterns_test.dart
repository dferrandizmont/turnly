import 'package:cuadrante/features/patterns/domain/pattern_blocks.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:flutter_test/flutter_test.dart';

class _Case {
  const _Case({
    required this.id,
    required this.steps,
    required this.cycleDays,
    required this.shiftHours,
    required this.start,
    required this.expect,
  });
  final String id;
  final List<String> steps;
  final int cycleDays;
  final Map<String, String> shiftHours;
  final String start;
  // date iso -> code, or null for "none"
  final Map<String, String?> expect;
}

const _cases = <_Case>[
  _Case(
    id: 'pitman-2-2-3',
    steps: [ 'D', 'D', 'L', 'L', 'D', 'D', 'D', 'L', 'L', 'D', 'D', 'L', 'L', 'L'],
    cycleDays: 14,
    shiftHours: {'D': '08:00-20:00'},
    start: '2028-02-20',
    expect: {
      '2028-02-19': null,
      '2028-02-20': 'D',
      '2028-02-29': 'D',
      '2028-03-26': 'L',
      '2028-10-29': 'D',
    },
  ),
  _Case(
    id: 'dupont',
    steps: ['N12','N12','N12','N12','L','L','L','D','D','D','L','N12','N12','N12','L','L','L','D','D','D','D','L','L','L','L','L','L','L'],
    cycleDays: 28,
    shiftHours: {'D': '08:00-20:00', 'N12': '20:00-08:00'},
    start: '2028-02-20',
    expect: {
      '2028-02-19': null,
      '2028-02-20': 'N12',
      '2028-02-29': 'D',
      '2028-03-26': 'D',
      '2028-10-29': 'N12',
    },
  ),
  _Case(
    id: 'continental-8h',
    steps: ['M','M','T','T','N','N','N','L','L','M','M','T','T','T','N','N','L','L','M','M','M','T','T','N','N','L','L','L'],
    cycleDays: 28,
    shiftHours: {'M': '06:00-14:00', 'T': '14:00-22:00', 'N': '22:00-06:00'},
    start: '2028-02-22',
    expect: {
      '2028-02-21': null,
      '2028-02-22': 'M',
      '2028-02-29': 'L',
      '2028-03-26': 'N',
      '2028-10-29': 'L',
    },
  ),
  _Case(
    id: '4x4-dia-noche-16',
    steps: ['D','D','D','D','L','L','L','L','N12','N12','N12','N12','L','L','L','L'],
    cycleDays: 16,
    shiftHours: {'D': '08:00-20:00', 'N12': '20:00-08:00'},
    start: '2028-02-20',
    expect: {
      '2028-02-19': null,
      '2028-02-20': 'D',
      '2028-02-29': 'N12',
      '2028-03-26': 'D',
      '2028-10-29': 'L',
    },
  ),
  _Case(
    id: 'panama-28',
    steps: ['D','D','L','L','D','D','D','L','L','D','D','L','L','L','N12','N12','L','L','N12','N12','N12','L','L','N12','N12','L','L','L'],
    cycleDays: 28,
    shiftHours: {'D': '08:00-20:00', 'N12': '20:00-08:00'},
    start: '2028-02-20',
    expect: {
      '2028-02-19': null,
      '2028-02-20': 'D',
      '2028-02-29': 'D',
      '2028-03-26': 'L',
      '2028-10-29': 'D',
    },
  ),
  _Case(
    id: 'guardia-24-48',
    steps: ['G','L','L'],
    cycleDays: 3,
    shiftHours: {'G': '08:00-08:00'},
    start: '2028-02-20',
    expect: {
      '2028-02-19': null,
      '2028-02-20': 'G',
      '2028-02-29': 'G',
      '2028-03-26': 'L',
      '2028-10-29': 'G',
    },
  ),
  _Case(
    id: 'kelly-24-48-27',
    steps: ['G','L','L','G','L','L','G','L','L','G','L','L','G','L','L','G','L','L','G','L','L','G','L','L','L','L','L'],
    cycleDays: 27,
    shiftHours: {'G': '08:00-08:00'},
    start: '2028-02-20',
    expect: {
      '2028-02-19': null,
      '2028-02-20': 'G',
      '2028-02-29': 'G',
      '2028-03-26': 'L',
      '2028-10-29': 'G',
    },
  ),
  _Case(
    id: '48-96',
    steps: ['G','G','L','L','L','L'],
    cycleDays: 6,
    shiftHours: {'G': '08:00-08:00'},
    start: '2028-02-20',
    expect: {
      '2028-02-19': null,
      '2028-02-20': 'G',
      '2028-02-29': 'L',
      '2028-03-26': 'L',
      '2028-10-29': 'G',
    },
  ),
  _Case(
    id: 'uk-fire-2-2-4',
    steps: ['D','D','N','N','L','L','L','L'],
    cycleDays: 8,
    shiftHours: {'D': '09:00-18:00', 'N': '18:00-09:00'},
    start: '2028-02-20',
    expect: {
      '2028-02-19': null,
      '2028-02-20': 'D',
      '2028-02-29': 'D',
      '2028-03-26': 'N',
      '2028-10-29': 'L',
    },
  ),
  _Case(
    id: 'uk-police-6-4',
    steps: ['M','M','T','T','N','N','L','L','L','L'],
    cycleDays: 10,
    shiftHours: {'M': '06:00-14:00', 'T': '14:00-22:00', 'N': '22:00-06:00'},
    start: '2028-02-20',
    expect: {
      '2028-02-19': null,
      '2028-02-20': 'M',
      '2028-02-29': 'L',
      '2028-03-26': 'N',
      '2028-10-29': 'T',
    },
  ),
  _Case(
    id: 'ddnnoo-12h',
    steps: ['D','D','N12','N12','L','L'],
    cycleDays: 6,
    shiftHours: {'D': '08:00-20:00', 'N12': '20:00-08:00'},
    start: '2028-02-20',
    expect: {
      '2028-02-19': null,
      '2028-02-20': 'D',
      '2028-02-29': 'N12',
      '2028-03-26': 'L',
      '2028-10-29': 'D',
    },
  ),
  _Case(
    id: 'minero-7x7',
    steps: ['D','D','D','D','D','D','D','L','L','L','L','L','L','L'],
    cycleDays: 14,
    shiftHours: {'D': '08:00-20:00'},
    start: '2028-02-20',
    expect: {
      '2028-02-19': null,
      '2028-02-20': 'D',
      '2028-02-29': 'L',
      '2028-03-26': 'L',
      '2028-10-29': 'D',
    },
  ),
  _Case(
    id: 'minero-7x7-dia-noche',
    steps: ['D','D','D','D','D','D','D','L','L','L','L','L','L','L','N12','N12','N12','N12','N12','N12','N12','L','L','L','L','L','L','L'],
    cycleDays: 28,
    shiftHours: {'D': '08:00-20:00', 'N12': '20:00-08:00'},
    start: '2028-02-20',
    expect: {
      '2028-02-19': null,
      '2028-02-20': 'D',
      '2028-02-29': 'L',
      '2028-03-26': 'L',
      '2028-10-29': 'D',
    },
  ),
  _Case(
    id: 'offshore-14-14',
    steps: ['D','D','D','D','D','D','D','D','D','D','D','D','D','D','L','L','L','L','L','L','L','L','L','L','L','L','L','L'],
    cycleDays: 28,
    shiftHours: {'D': '08:00-20:00'},
    start: '2028-02-20',
    expect: {
      '2028-02-19': null,
      '2028-02-20': 'D',
      '2028-02-29': 'D',
      '2028-03-26': 'D',
      '2028-10-29': 'D',
    },
  ),
  _Case(
    id: 'offshore-21-21',
    steps: ['D','D','D','D','D','D','D','D','D','D','D','D','D','D','D','D','D','D','D','D','D','L','L','L','L','L','L','L','L','L','L','L','L','L','L','L','L','L','L','L','L','L'],
    cycleDays: 42,
    shiftHours: {'D': '08:00-20:00'},
    start: '2028-02-20',
    expect: {
      '2028-02-19': null,
      '2028-02-20': 'D',
      '2028-02-29': 'D',
      '2028-03-26': 'L',
      '2028-10-29': 'D',
    },
  ),
  _Case(
    id: '12x36',
    steps: ['D','L'],
    cycleDays: 2,
    shiftHours: {'D': '07:00-19:00'},
    start: '2028-02-20',
    expect: {
      '2028-02-19': null,
      '2028-02-20': 'D',
      '2028-02-29': 'L',
      '2028-03-26': 'L',
      '2028-10-29': 'D',
    },
  ),
  _Case(
    id: '4-10',
    steps: ['A','A','A','A','L','L','L'],
    cycleDays: 7,
    shiftHours: {'A': '06:00-16:00'},
    start: '2028-02-21',
    expect: {
      '2028-02-20': null,
      '2028-02-21': 'A',
      '2028-02-29': 'A',
      '2028-03-26': 'L',
      '2028-10-29': 'L',
    },
  ),
  _Case(
    id: '9-80',
    steps: ['A','A','A','A','B','L','L','A','A','A','A','L','L','L'],
    cycleDays: 14,
    shiftHours: {'A': '07:00-16:00', 'B': '07:00-15:00'},
    start: '2028-02-21',
    expect: {
      '2028-02-20': null,
      '2028-02-21': 'A',
      '2028-02-29': 'A',
      '2028-03-26': 'L',
      '2028-10-29': 'L',
    },
  ),
  _Case(
    id: 'baylor',
    steps: ['L','L','L','L','L','D','D'],
    cycleDays: 7,
    shiftHours: {'D': '08:00-20:00'},
    start: '2028-02-21',
    expect: {
      '2028-02-20': null,
      '2028-02-21': 'L',
      '2028-02-29': 'L',
      '2028-03-26': 'D',
      '2028-10-29': 'D',
    },
  ),
  _Case(
    id: 'southern-swing',
    steps: ['M','M','M','M','M','M','M','T','T','T','T','T','T','T','N','N','N','N','N','N','N','L','L','L','L','L','L','L'],
    cycleDays: 28,
    shiftHours: {'M': '06:00-14:00', 'T': '14:00-22:00', 'N': '22:00-06:00'},
    start: '2028-02-21',
    expect: {
      '2028-02-20': null,
      '2028-02-21': 'M',
      '2028-02-29': 'T',
      '2028-03-26': 'M',
      '2028-10-29': 'L',
    },
  ),
  _Case(
    id: 'ertzaintza-inv-5-semanas',
    steps: ['T','T','T','T','T','L','L','N','N','N','N','N','N','N','L','L','L','L','L','L','L','M','M','M','M','M','M','M','L','L','L','L','L','L','L'],
    cycleDays: 35,
    shiftHours: {'M': '07:00-15:00', 'T': '14:00-22:00', 'N': '22:00-06:00'},
    start: '2028-02-21',
    expect: {
      '2028-02-20': null,
      '2028-02-21': 'T',
      '2028-02-29': 'N',
      '2028-03-26': 'L',
      '2028-10-29': 'L',
    },
  ),
  _Case(
    id: 'ertzaintza-inv-3-semanas',
    steps: ['M','M','M','M','M','L','L','M','M','M','M','M','M','M','L','L','L','L','L','L','L'],
    cycleDays: 21,
    shiftHours: {'M': '07:00-15:00'},
    start: '2028-02-21',
    expect: {
      '2028-02-20': null,
      '2028-02-21': 'M',
      '2028-02-29': 'M',
      '2028-03-26': 'M',
      '2028-10-29': 'L',
    },
  ),
  _Case(
    id: 'mercadona-4-3-2020',
    steps: ['L','L','M','M','M','M','L','M','M','L','L','M','M','L','M','M','M','M','L','L','L'],
    cycleDays: 21,
    shiftHours: {'M': '06:00-15:30'},
    start: '2028-02-21',
    expect: {
      '2028-02-20': null,
      '2028-02-21': 'L',
      '2028-02-29': 'M',
      '2028-03-26': 'L',
      '2028-10-29': 'L',
    },
  ),
  _Case(
    id: 'policia-local-6x6',
    steps: ['M','M','M','M','M','M','L','L','L','L','L','L'],
    cycleDays: 12,
    shiftHours: {'M': '07:00-15:30'},
    start: '2028-02-20',
    expect: {
      '2028-02-19': null,
      '2028-02-20': 'M',
      '2028-02-29': 'L',
      '2028-03-26': 'L',
      '2028-10-29': 'M',
    },
  ),
  _Case(
    id: 'enaire-6-2',
    steps: ['M','M','M','M','M','M','L','L'],
    cycleDays: 8,
    shiftHours: {'M': '06:00-14:00'},
    start: '2028-02-20',
    expect: {
      '2028-02-19': null,
      '2028-02-20': 'M',
      '2028-02-29': 'M',
      '2028-03-26': 'M',
      '2028-10-29': 'M',
    },
  ),
  _Case(
    id: 'semanas-m-t-lv',
    steps: ['M','M','M','M','M','L','L','T','T','T','T','T','L','L'],
    cycleDays: 14,
    shiftHours: {'M': '06:00-14:00', 'T': '14:00-22:00'},
    start: '2028-02-21',
    expect: {
      '2028-02-20': null,
      '2028-02-21': 'M',
      '2028-02-29': 'T',
      '2028-03-26': 'L',
      '2028-10-29': 'L',
    },
  ),
];

ShiftCategory _category(String code) {
  if (code == 'L' || code == 'S') return ShiftCategory.rest;
  if (code == 'V') return ShiftCategory.absence;
  return ShiftCategory.work;
}

int _min(String hhmm) {
  final p = hhmm.split(':');
  return int.parse(p[0]) * 60 + int.parse(p[1]);
}

ShiftType _makeType(String code, Map<String, String> hours) {
  final h = hours[code];
  if (h == null) {
    return ShiftType(
      id: code,
      code: code,
      name: code,
      colorValue: 0,
      category: _category(code),
    );
  }
  final parts = h.split('-');
  return ShiftType(
    id: code,
    code: code,
    name: code,
    colorValue: 0,
    category: _category(code),
    startMinute: _min(parts[0]),
    endMinute: _min(parts[1]),
  );
}

Schedule _buildSchedule(_Case c) {
  final codes = c.steps.toSet();
  final types = [for (final code in codes) _makeType(code, c.shiftHours)];
  final stepsList = [for (final s in c.steps) [s]];
  final pattern = Pattern(id: c.id, name: c.id, steps: stepsList);
  final run = PatternRun(
    id: 'r',
    patternId: c.id,
    startDate: CivilDate.parse(c.start),
    seq: 1,
  );
  return Schedule(shiftTypes: types, patterns: [pattern], runs: [run]);
}

void main() {
  group('real patterns catalogue', () {
    for (final c in _cases) {
      test(c.id, () {
        final schedule = _buildSchedule(c);
        final pattern = schedule.patternById(c.id)!;

        // 1. resolve expected
        for (final entry in c.expect.entries) {
          final date = CivilDate.parse(entry.key);
          final resolved = schedule.resolve(date);
          if (entry.value == null) {
            expect(resolved.isEmpty, isTrue,
                reason: '${c.id} ${entry.key} expected none');
          } else {
            expect(resolved.shifts.map((t) => t.code).join('+'), entry.value,
                reason: '${c.id} ${entry.key}');
          }
        }

        // 2. cycle length + periodicity
        expect(pattern.lengthDays, c.cycleDays,
            reason: '${c.id} cycle_days');
        final start = CivilDate.parse(c.start);
        final startIds = schedule.resolve(start).shiftIds;
        for (final k in [1, 5, 20]) {
          final d = start.addDays(c.cycleDays * k);
          expect(schedule.resolve(d).shiftIds, startIds,
              reason: '${c.id} periodicity k=$k');
        }

        // 3. round-trip through builder
        final stepsList = [for (final s in c.steps) [s]];
        final blocks = compressSteps(stepsList);
        expect(expandBlocks(blocks), stepsList,
            reason: '${c.id} round-trip');
        expect(patternCycleDays(blocks) <= maxPatternCycleDays, isTrue,
            reason: '${c.id} maxPatternCycleDays');

        // 4. DST occurrence durations (civil/wall-clock) for crossing-midnight shifts
        for (final dd in [CivilDate(2028, 3, 26), CivilDate(2028, 10, 29)]) {
          final resolved = schedule.resolve(dd);
          final crossing = resolved.shifts.where((t) => t.crossesMidnight).toList();
          if (crossing.isEmpty) continue;
          final occs = schedule.occurrences(dd, dd);
          for (final t in crossing) {
            final o = occs.firstWhere((o) => o.shiftType.id == t.id);
            expect(o.durationMinutes, t.durationMinutes,
                reason: '${c.id} ${dd.toIso()} ${t.code} DST duration');
          }
        }
      });
    }
  });

  test('stepOffset 3 on pitman-2-2-3 (2-2-3)', () {
    final c = _cases.firstWhere((c) => c.id == 'pitman-2-2-3');
    final schedule0 = _buildSchedule(c);
    // rebuild with stepOffset 3
    final stepsList = [for (final s in c.steps) [s]];
    final pattern = Pattern(id: c.id, name: c.id, steps: stepsList);
    final run = PatternRun(
      id: 'r',
      patternId: c.id,
      startDate: CivilDate.parse(c.start),
      stepOffset: 3,
      seq: 1,
    );
    final types = [for (final code in c.steps.toSet()) _makeType(code, c.shiftHours)];
    final schedule = Schedule(shiftTypes: types, patterns: [pattern], runs: [run]);
    // first days: step 3 = L, 4 = D, 5 = D, 6 = D, 7 = L, 8 = L
    final codes = [
      for (var i = 0; i < 6; i++)
        schedule.resolve(CivilDate.parse(c.start).addDays(i)).shifts.map((t) => t.code).join('+'),
    ];
    expect(codes, ['L', 'D', 'D', 'D', 'L', 'L']);
    // sanity: schedule0 unused? keep reference to avoid lint
    expect(schedule0.patternById(c.id)!.lengthDays, 14);
  });

  test('continental stepOffset 7 gives L on start day', () {
    final c = _cases.firstWhere((c) => c.id == 'continental-8h');
    final stepsList = [for (final s in c.steps) [s]];
    final pattern = Pattern(id: c.id, name: c.id, steps: stepsList);
    final run = PatternRun(
      id: 'r',
      patternId: c.id,
      startDate: CivilDate.parse(c.start),
      stepOffset: 7,
      seq: 1,
    );
    final types = [for (final code in c.steps.toSet()) _makeType(code, c.shiftHours)];
    final schedule = Schedule(shiftTypes: types, patterns: [pattern], runs: [run]);
    expect(schedule.resolve(CivilDate.parse(c.start)).shifts.map((t) => t.code).join('+'), 'L');
  });

  test('DayEntry with empty shiftTypeIds overrides a G day to empty', () {
    final c = _cases.firstWhere((c) => c.id == 'guardia-24-48');
    final schedule0 = _buildSchedule(c);
    final day = CivilDate.parse(c.start); // G
    expect(schedule0.resolve(day).shifts.map((t) => t.code).join('+'), 'G');
    final schedule = Schedule(
      shiftTypes: schedule0.shiftTypes,
      patterns: schedule0.patterns,
      runs: schedule0.runs,
      entries: {day: DayEntry(date: day, shiftTypeIds: const [])},
    );
    expect(schedule.resolve(day).isEmpty, isTrue);
  });
}
