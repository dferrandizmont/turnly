import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:cuadrante/core/theme/shift_palette.dart';
import 'package:cuadrante/core/theme/shift_swatch.dart';
import 'package:cuadrante/features/calendar/presentation/day_cell.dart';
import 'package:cuadrante/features/schedule/data/schedule_repository.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

/// A day with four or more shifts shows its first two bands and a neutral
/// «+N» for the rest, so its week row no longer grows with every shift. The
/// spoken label keeps naming all of them.
void main() {
  setUpAll(initializeLocale);

  const one = CivilDate(2026, 10, 5);
  const threeShifts = CivilDate(2026, 10, 6);
  const fourShifts = CivilDate(2026, 10, 13);
  const fiveShifts = CivilDate(2026, 10, 14);
  const sixShifts = CivilDate(2026, 10, 15);

  const ids1 = ['morning'];
  const ids3 = ['morning', 'afternoon', 'night'];
  const ids4 = [...ids3, 'guard24'];
  const ids5 = [...ids4, 'vacation'];
  const ids6 = [...ids5, 'day12'];

  Future<void> prepare(ScheduleRepository repository) => repository.apply(
    'main',
    ScheduleChange(
      patch: EntriesPatch({
        one: EntryChange(null, const DayEntry(date: one, shiftTypeIds: ids1)),
        threeShifts: EntryChange(
          null,
          const DayEntry(date: threeShifts, shiftTypeIds: ids3),
        ),
        fourShifts: EntryChange(
          null,
          const DayEntry(date: fourShifts, shiftTypeIds: ids4),
        ),
        fiveShifts: EntryChange(
          null,
          const DayEntry(date: fiveShifts, shiftTypeIds: ids5),
        ),
        sixShifts: EntryChange(
          null,
          const DayEntry(date: sixShifts, shiftTypeIds: ids6),
        ),
      }),
    ),
  );

  Finder inCell(CivilDate date, Finder matching) =>
      find.descendant(of: cell(date), matching: matching);

  Finder overflow(CivilDate date) =>
      find.byKey(ValueKey('cell-overflow-${date.toIso()}'));

  testWidgets('one or three shifts keep every band and show no «+N»', (
    tester,
  ) async {
    await pumpCalendar(tester, prepare: prepare);

    await revealCell(tester, one);
    expect(inCell(one, find.text('M')), findsOneWidget);
    expect(overflow(one), findsNothing);

    await revealCell(tester, threeShifts);
    for (final code in ['M', 'T', 'N']) {
      expect(inCell(threeShifts, find.text(code)), findsOneWidget);
    }
    expect(overflow(threeShifts), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('four shifts: two bands and «+2»', (tester) async {
    await pumpCalendar(tester, prepare: prepare);
    await revealCell(tester, fourShifts);

    expect(inCell(fourShifts, find.text('M')), findsOneWidget);
    expect(inCell(fourShifts, find.text('T')), findsOneWidget);
    // The third shift and the rest are only in the spoken label.
    expect(inCell(fourShifts, find.text('N')), findsNothing);
    expect(inCell(fourShifts, find.text('G')), findsNothing);
    expect(inCell(fourShifts, find.text('+2')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('five shifts say «+3»', (tester) async {
    await pumpCalendar(tester, prepare: prepare);
    await revealCell(tester, fiveShifts);

    expect(inCell(fiveShifts, find.text('M')), findsOneWidget);
    expect(inCell(fiveShifts, find.text('T')), findsOneWidget);
    expect(inCell(fiveShifts, find.text('+3')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('six shifts say «+4» and take the room of four', (tester) async {
    await pumpCalendar(tester, prepare: prepare);
    await revealCell(tester, sixShifts);

    expect(inCell(sixShifts, find.text('M')), findsOneWidget);
    expect(inCell(sixShifts, find.text('T')), findsOneWidget);
    expect(inCell(sixShifts, find.text('+4')), findsOneWidget);

    // The height of six shifts is exactly the height of four (two bands and
    // the «+N», which has no time line): the row of the week never grows
    // with the shifts that do not fit, and it is no taller than three bands.
    final context = tester.element(cell(sixShifts));
    final schedule = scheduleOf(tester);
    final six = dayCellHeightForShifts(
      context,
      schedule.resolve(sixShifts).shifts,
    );
    expect(
      six,
      dayCellHeightForShifts(context, schedule.resolve(fourShifts).shifts),
    );
    expect(
      six,
      lessThanOrEqualTo(
        dayCellHeightForShifts(context, schedule.resolve(threeShifts).shifts),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the row of a busy day takes what its bands need, no more', (
    tester,
  ) async {
    await pumpCalendar(tester, prepare: prepare);
    await revealCell(tester, one);
    await revealCell(tester, fourShifts);
    final context = tester.element(cell(fourShifts));
    final schedule = scheduleOf(tester);
    final single = dayCellHeightForShifts(
      context,
      schedule.resolve(one).shifts,
    );
    final busy = dayCellHeightForShifts(
      context,
      schedule.resolve(fourShifts).shifts,
    );
    // Three bands (two shifts and «+2») do not make a row 2.3 times taller
    // than the others: the number of the day and the bar are in the sum
    // once, not once per band.
    expect(busy, greaterThan(single));
    expect(busy, lessThan(single * 1.9));
    // The rendered row is as tall as measured (plus nothing stretched).
    final row = tester.getSize(cell(fourShifts)).height;
    expect(row, closeTo(busy, 0.6));
    expect(tester.takeException(), isNull);
  });

  for (final scale in [1.0, 1.3, 2.0]) {
    testWidgets('text x$scale: the bands of four shifts never overlap or '
        'leave the cell', (tester) async {
      await pumpCalendar(
        tester,
        size: const Size(360, 800),
        textScale: scale,
        prepare: prepare,
      );
      await revealCell(tester, fourShifts);
      final box = tester.getRect(cell(fourShifts));
      final marks = [
        for (final text in ['M', 'T', '+2'])
          tester.getRect(inCell(fourShifts, find.text(text))),
      ];
      for (final mark in marks) {
        expect(mark.top, greaterThanOrEqualTo(box.top - 0.5));
        expect(mark.bottom, lessThanOrEqualTo(box.bottom + 0.5));
      }
      for (var i = 0; i < marks.length - 1; i++) {
        expect(
          marks[i].bottom,
          lessThanOrEqualTo(marks[i + 1].top + 0.5),
          reason: 'band $i overlaps band ${i + 1}',
        );
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the label still names every shift of the day', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpCalendar(tester, prepare: prepare);
    await revealCell(tester, fiveShifts);

    final label = tester.getSemantics(cell(fiveShifts)).label;
    for (final name in [
      'Mañana',
      'Tarde',
      'Noche',
      'Guardia 24 h',
      'Vacaciones',
    ]) {
      expect(label, contains(name), reason: 'falta «$name» en la lectura');
    }
    handle.dispose();
  });

  testWidgets('the «+N» band is neutral and reaches AA', (tester) async {
    await pumpCalendar(tester, prepare: prepare);
    await revealCell(tester, fiveShifts);

    final text = tester.widget<Text>(overflow(fiveShifts));
    DecoratedBox? band;
    tester.element(overflow(fiveShifts)).visitAncestorElements((element) {
      if (element.widget case final DecoratedBox box) {
        band = box;
        return false;
      }
      return true;
    });
    expect(band, isNotNull);
    final background = (band!.decoration as BoxDecoration).color!;
    expect(
      contrastRatio(text.style!.color!, background),
      greaterThanOrEqualTo(kTextContrast),
    );
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    testWidgets('text x1.3, ${brightness.name}: the «+N» never overflows', (
      tester,
    ) async {
      await pumpCalendar(
        tester,
        size: const Size(320, 640),
        textScale: 1.3,
        brightness: brightness,
        prepare: prepare,
      );
      await revealCell(tester, fiveShifts);

      expect(inCell(fiveShifts, find.text('+3')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
