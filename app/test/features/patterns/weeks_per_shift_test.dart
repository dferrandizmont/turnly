import 'package:cuadrante/features/patterns/domain/weeks_per_shift.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Correturnos is M, T, N, one weekday week each', () {
    final steps = weeksPerShift(
      shiftIds: ['morning', 'afternoon', 'night'],
      weeks: [1, 1, 1],
      mode: WeeksPerShiftMode.weekdays,
      restShiftId: 'rest',
    );
    final preset = patternPresetById('correturnos');
    expect(
      steps,
      preset.materialize({for (final k in preset.templateKeys) k: k}).steps,
    );
    expect(steps, hasLength(21));
    expect(preset.suggestedStart, DateTime.monday);
  });

  for (final mode in WeeksPerShiftMode.values) {
    test('$mode: M, N, T for three weeks each is a 63-day cycle', () {
      final steps = weeksPerShift(
        shiftIds: ['morning', 'night', 'afternoon'],
        weeks: [3, 3, 3],
        mode: mode,
        restShiftId: 'rest',
      );
      expect(steps, hasLength(63));
      for (var i = 0; i < 63; i++) {
        expect(steps[i], [
          mode == WeeksPerShiftMode.weekdays && i % 7 >= 5
              ? 'rest'
              : ['morning', 'night', 'afternoon'][i ~/ 21],
        ]);
      }
    });

    test('$mode: counts, order and explicit calendar Libre', () {
      final steps = weeksPerShift(
        shiftIds: ['N', 'M', 'T'],
        weeks: [3, 2, 1],
        mode: mode,
        restShiftId: 'my-rest',
      );
      expect(steps, hasLength(42));
      for (var i = 0; i < steps.length; i++) {
        final work = i < 21 ? 'N' : (i < 35 ? 'M' : 'T');
        expect(steps[i], [
          mode == WeeksPerShiftMode.weekdays && i % 7 >= 5 ? 'my-rest' : work,
        ]);
      }
      expect(() => steps.first.clear(), throwsUnsupportedError);
      expect(() => steps.clear(), throwsUnsupportedError);
    });

    test('$mode: every start weekday stays aligned through cycle rollover', () {
      final steps = weeksPerShift(
        shiftIds: ['M', 'T'],
        weeks: [1, 1],
        mode: mode,
        restShiftId: 'L',
      );
      for (var weekday = 1; weekday <= 7; weekday++) {
        final start = const CivilDate(2026, 11, 9).addDays(weekday - 1);
        final offset = weeksPerShiftStepOffset(start);
        expect(offset, weekday - 1);
        final run = PatternRun(
          id: 'r',
          patternId: 'p',
          startDate: start,
          seq: 1,
          stepOffset: offset,
        );
        for (var day = 0; day < 35; day++) {
          final date = start.addDays(day);
          final index = run.stepIndexOn(date, steps.length);
          expect(index % 7, date.weekday - 1);
          final work = ((day + weekday - 1) ~/ 7).isEven ? 'M' : 'T';
          expect(steps[index], [
            mode == WeeksPerShiftMode.weekdays && date.weekday >= 6
                ? 'L'
                : work,
          ]);
        }
      }
    });
  }

  test(
    '1 and 8 weeks supported, mismatched/empty/out-of-range input rejected',
    () {
      List<List<String>> generate(List<String> ids, List<int> weeks) =>
          weeksPerShift(
            shiftIds: ids,
            weeks: weeks,
            mode: WeeksPerShiftMode.allDays,
            restShiftId: 'L',
          );
      expect(generate(['M', 'N'], [1, 8]), hasLength(63));
      expect(() => generate([], []), throwsArgumentError);
      expect(() => generate(['M'], []), throwsArgumentError);
      expect(() => generate(['M'], [0]), throwsArgumentError);
      expect(() => generate(['M'], [9]), throwsArgumentError);
    },
  );
}
