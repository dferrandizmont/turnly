import 'package:cuadrante/features/patterns/application/shift_run_options.dart';
import 'package:cuadrante/features/schedule/domain/presets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The pure mapping option → cycle offset used by «Tarde se repite: ¿qué día
/// de sus días te toca?»: the days of a shift as runs, each day knowing where
/// it sits and which run it belongs to.
void main() {
  test(
    'correturnos: Libre has three runs of two, each named by the shift before',
    () {
      // 5M 2L 5T 2L 5N 2L (21 days).
      final steps = patternPresetById('correturnos').steps;
      final options = shiftRunOptions(steps, 'rest');

      expect(options.map((o) => o.offset), [5, 6, 12, 13, 19, 20]);
      expect(options.map((o) => o.position), [1, 2, 1, 2, 1, 2]);
      expect(options.map((o) => o.runIndex), [0, 0, 1, 1, 2, 2]);
      expect(options.every((o) => o.count == 2), isTrue);
      expect(options.every((o) => o.runCount == 3), isTrue);
      expect(options.map((o) => o.previousShiftIds), [
        ['morning'],
        ['morning'],
        ['afternoon'],
        ['afternoon'],
        ['night'],
        ['night'],
      ]);
    },
  );

  test('correturnos: Mañana is a single run of five', () {
    final steps = patternPresetById('correturnos').steps;
    final options = shiftRunOptions(steps, 'morning');

    expect(options.map((o) => o.offset), [0, 1, 2, 3, 4]);
    expect(options.map((o) => o.position), [1, 2, 3, 4, 5]);
    expect(options.every((o) => o.count == 5), isTrue);
    expect(options.every((o) => o.runCount == 1), isTrue);
  });

  test('a run that starts the cycle takes the shift before it cyclically', () {
    // L1 M2 L1 T2 (six days): two one-day Libre runs; the first wraps to T.
    final steps = [
      ['rest'],
      ['morning'],
      ['morning'],
      ['rest'],
      ['afternoon'],
      ['afternoon'],
    ];
    final options = shiftRunOptions(steps, 'rest');

    expect(options.map((o) => o.offset), [0, 3]);
    expect(options.map((o) => o.position), [1, 1]);
    expect(options.map((o) => o.runIndex), [0, 1]);
    expect(options.every((o) => o.count == 1 && o.runCount == 2), isTrue);
    expect(options[0].previousShiftIds, ['afternoon']); // day 5, cyclically.
    expect(options[1].previousShiftIds, ['morning']); // day 2.
  });

  test('a multi-day run that wraps keeps its order from its first day', () {
    // L2 M2 L2: the Libre run is days 4, 5, 0, 1.
    final steps = [
      ['rest'],
      ['rest'],
      ['morning'],
      ['morning'],
      ['rest'],
      ['rest'],
    ];
    final options = shiftRunOptions(steps, 'rest');

    expect(options.map((o) => o.offset), [4, 5, 0, 1]);
    expect(options.map((o) => o.position), [1, 2, 3, 4]);
    expect(options.every((o) => o.count == 4 && o.runCount == 1), isTrue);
    expect(options.first.previousShiftIds, ['morning']);
  });

  test('one shift type, a one-day cycle, and a shift that is not there', () {
    final only = shiftRunOptions([
      ['morning'],
      ['morning'],
      ['morning'],
    ], 'morning');
    expect(only.map((o) => o.offset), [0, 1, 2]);
    expect(only.every((o) => o.count == 3 && o.runCount == 1), isTrue);

    final one = shiftRunOptions([
      ['rest'],
    ], 'rest');
    expect(one, hasLength(1));
    expect(one.single.offset, 0);
    expect(one.single.position, 1);
    expect(one.single.count, 1);
    expect(one.single.runCount, 1);

    expect(
      shiftRunOptions([
        ['morning'],
      ], 'night'),
      isEmpty,
    );
    expect(shiftRunOptions(const <List<String>>[], 'morning'), isEmpty);
  });

  test('a run after an empty day is not named', () {
    final steps = [
      ['morning'],
      ['morning'],
      <String>[],
      ['morning'],
      ['night'],
    ];
    final options = shiftRunOptions(steps, 'morning');

    expect(options.map((o) => o.offset), [0, 1, 3]);
    expect(options.map((o) => o.count), [2, 2, 1]);
    expect(options.map((o) => o.runIndex), [0, 0, 1]);
    expect(options.every((o) => o.runCount == 2), isTrue);
    expect(options[0].previousShiftIds, ['night']); // day 4, cyclically.
    // The day just before that run (day 2) is empty: the run is not named, so
    // the label never claims to come «después de» a shift that is actually
    // after it in the cycle (day 4, the night).
    expect(options[2].previousShiftIds, isEmpty);
  });

  test('a run is never named by its own shift', () {
    // The shift has two runs (an empty day at each side of the cycle) and no
    // other shift: neither run can be named, so neither is («Mañana, después
    // de Mañana» never happens).
    final steps = [
      <String>[],
      ['morning'],
      ['morning'],
      <String>[],
      ['morning'],
    ];
    final options = shiftRunOptions(steps, 'morning');

    expect(options.map((o) => o.offset), [1, 2, 4]);
    expect(options.every((o) => o.runCount == 2), isTrue);
    expect(options[0].previousShiftIds, isEmpty);
    expect(options[2].previousShiftIds, isEmpty);

    // The day just before a run names it by its other shift, even when that
    // day also holds the run's own shift.
    final mixed = shiftRunOptions([
      ['morning'],
      ['morning', 'night'],
    ], 'morning');
    expect(mixed.map((o) => o.offset), [0, 1]);
    expect(mixed.first.previousShiftIds, ['night']);
  });
}
