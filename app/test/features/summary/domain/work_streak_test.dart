import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:cuadrante/features/summary/domain/month_summary.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../schedule/domain/fixtures.dart';

void main() {
  const first = CivilDate(2026, 11, 3);
  Schedule calendar(List<List<String>> shifts) => Schedule(
    shiftTypes: allTypes,
    entries: {
      for (var i = 0; i < shifts.length; i++)
        first.addDays(i): DayEntry(
          date: first.addDays(i),
          shiftTypeIds: shifts[i],
          overtimeBlocks: [
            OvertimeBlock(
              id: 'extra-$i',
              date: first.addDays(i),
              typeId: overtimeTypeId,
              startMinute: 900,
              endMinute: 960,
            ),
          ],
        ),
    },
  );

  test('clips both ends to the selected period, including double days', () {
    final schedule = calendar(List.generate(8, (_) => ['morning', 'night']));
    final result = summarizeRange(schedule, first.addDays(1), first.addDays(6));
    expect(result.longestStreak!.days, 6);
    expect(result.longestStreak!.from, first.addDays(1));
    expect(result.longestStreak!.to, first.addDays(6));
    expect(result.workedDays, 6);
  });

  test('rest, absence and empty days break runs even with overtime', () {
    final schedule = calendar([
      ['morning'],
      ['rest'],
      ['morning'],
      ['vacation'],
      ['night'],
      [],
      ['morning'],
      ['morning'],
      ['night'],
    ]);
    final result = summarizeRange(schedule, first, first.addDays(8));
    expect(result.longestStreak!.days, 3);
    expect(result.longestStreak!.from, first.addDays(6));
    expect(result.longestStreak!.to, first.addDays(8));
  });

  test('ties choose the first run; work with absence still counts as work', () {
    final schedule = calendar([
      ['morning', 'vacation'],
      ['morning'],
      [],
      ['night'],
      ['night'],
    ]);
    expect(
      summarizeRange(schedule, first, first.addDays(4)).longestStreak!.from,
      first,
    );
  });

  test('empty, off and overtime-only periods have no run', () {
    final schedule = calendar([
      [],
      ['rest'],
      ['vacation'],
    ]);
    expect(
      summarizeRange(schedule, first, first.addDays(2)).longestStreak,
      isNull,
    );
    expect(summarizeRange(Schedule(), first, first).longestStreak, isNull);
  });
}
