import 'package:cuadrante/features/calendar/application/schedule_controller.dart';
import 'package:cuadrante/features/calendar/presentation/day_extras_section.dart';
import 'package:cuadrante/features/calendars/domain/calendar.dart';
import 'package:cuadrante/features/schedule/application/schedule_providers.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'day_sheet_finders.dart';
import 'harness.dart';

// «Horas extra / Salí antes» in the day detail (A6, schema v7): the blocks of
// extra hours, the total of the day, «Salí antes» and the mark of the cell.
// Demo data: Mañana 26-30 October, Libre 24-25.
const _oct24 = CivilDate(2026, 10, 24);
const _oct26 = CivilDate(2026, 10, 26);
const _oct27 = CivilDate(2026, 10, 27);

Finder _key(String key) => find.byKey(ValueKey(key));

Finder get _sheet => find.byType(BottomSheet);

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(_key(key)).data!;

DayEntry? _entry(WidgetTester tester, CivilDate date) =>
    containerOf(tester).read(scheduleControllerProvider).schedule.entries[date];

ScheduleState _state(WidgetTester tester) =>
    containerOf(tester).read(scheduleControllerProvider);

ScheduleController _controller(WidgetTester tester) =>
    containerOf(tester).read(scheduleControllerProvider.notifier);

OvertimeBlock _block(
  CivilDate date, {
  int start = 18 * 60,
  int end = 20 * 60,
  String id = 'b1',
  String type = overtimeTypeId,
}) => OvertimeBlock(
  id: id,
  date: date,
  typeId: type,
  startMinute: start,
  endMinute: end,
);

Future<void> _open(WidgetTester tester, CivilDate date) async {
  await revealCell(tester, date);
  await tester.tap(cell(date));
  await tester.pumpAndSettle();
  expect(_sheet, findsOneWidget);
  // The section is in «Más opciones».
  await openDayMore(tester);
}

Future<void> _close(WidgetTester tester) async {
  Navigator.of(tester.element(_sheet.last)).pop();
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String key, {int times = 1}) async {
  await tester.ensureVisible(_key(key));
  await tester.pumpAndSettle();
  for (var i = 0; i < times; i++) {
    await tester.tap(_key(key));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Lets the quiet time pass so the early leave is written.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump(DayExtrasSection.settle + const Duration(milliseconds: 50));
  await tester.pumpAndSettle();
}

Future<void> _openAddSheet(WidgetTester tester) async {
  await _tap(tester, 'day-add-overtime');
  await tester.pumpAndSettle();
  expect(_key('overtime-sheet'), findsOneWidget);
}

void main() {
  group('the section', () {
    testWidgets('is in the day detail: «Añadir horas extra» and «Salí antes» '
        'at «Ninguna»', (tester) async {
      await pumpCalendar(tester, size: const Size(390, 1400));
      await _open(tester, _oct26);
      await tester.ensureVisible(_key('day-extras'));
      expect(find.text('HORAS EXTRA / SALÍ ANTES'), findsOneWidget);
      expect(_key('day-add-overtime'), findsOneWidget);
      expect(_text(tester, 'day-early-value'), 'Ninguna');
      expect(
        tester.widget<IconButton>(_key('day-early-less')).onPressed,
        isNull,
      );
      // The day's total: the shift alone.
      expect(_text(tester, 'day-total'), startsWith('Total del día: '));
    });

    testWidgets('lists the blocks the day has, with their schedule and '
        'length', (tester) async {
      await pumpCalendar(
        tester,
        size: const Size(390, 1400),
        prepare: (repository) async {
          await repository.apply(
            'main',
            ScheduleChange(
              patch: EntriesPatch({
                _oct27: EntryChange(
                  null,
                  DayEntry(
                    date: _oct27,
                    earlyLeaveMinutes: 45,
                    overtimeBlocks: [
                      _block(_oct27),
                      _block(
                        _oct27,
                        id: 'b2',
                        type: otherWorkTypeId,
                        start: 22 * 60,
                        end: 60,
                      ),
                    ],
                  ),
                ),
              }),
            ),
          );
        },
      );
      await _open(tester, _oct27);
      await tester.ensureVisible(_key('day-overtime-b1'));
      expect(find.text('Horas extra'), findsWidgets);
      expect(find.text('Otro trabajo'), findsOneWidget);
      expect(find.textContaining('18:00–20:00'), findsOneWidget);
      expect(_text(tester, 'day-overtime-duration-b1'), '2 h');
      expect(_text(tester, 'day-overtime-duration-b2'), '3 h');
      expect(
        find.textContaining('22:00–01:00 · Acaba al día siguiente'),
        findsOneWidget,
      );
      expect(_text(tester, 'day-early-value'), '45 min');
    });
  });

  group('adding a block', () {
    testWidgets('Q96 on the QA phone: add, show +2 h, undo and redo one step, '
        'then delete the block', (tester) async {
      const ratio = 2.625;
      await pumpCalendar(
        tester,
        size: const Size(1080 / ratio, 2400 / ratio),
        pixelRatio: ratio,
        insets: const EdgeInsets.only(top: 24, bottom: 24),
      );
      final container = containerOf(tester);
      Future<Schedule> stored() async => (await tester.runAsync(() async {
        await container.read(scheduleControllerProvider.notifier).pendingWrites;
        return container.read(scheduleRepositoryProvider).load(mainCalendarId);
      }))!.schedule;
      final original = await stored();

      await _open(tester, _oct26);
      await _openAddSheet(tester);
      await _tap(tester, 'overtime-type-$overtimeTypeId');
      await _tap(tester, 'overtime-quick-2');
      await _tap(tester, 'overtime-save');
      await tester.pumpAndSettle();
      final block = _entry(tester, _oct26)!.overtimeBlocks.single;
      expect(block.typeId, overtimeTypeId);
      expect(block.startMinute, lastWorkEndMinute(original.resolve(_oct26)));
      expect(block.paidMinutes, 120);
      expect((await stored()).entries[_oct26]!.overtimeBlocks, [block]);
      await _close(tester);
      expect(_text(tester, 'extras-mark-2026-10-26'), '+2 h');

      await enterPaintMode(tester);
      await _tap(tester, 'undo');
      await tester.pumpAndSettle();
      expect(_state(tester).canUndo, isFalse);
      expect((await stored()).entries, original.entries);
      expect(_key('extras-mark-2026-10-26'), findsNothing);
      await _tap(tester, 'redo');
      await tester.pumpAndSettle();
      expect((await stored()).entries[_oct26]!.overtimeBlocks, [block]);
      expect(_text(tester, 'extras-mark-2026-10-26'), '+2 h');
      await _tap(tester, 'paint-done');
      await tester.pumpAndSettle();

      await _open(tester, _oct26);
      await _tap(tester, 'day-overtime-${block.id}');
      await tester.pumpAndSettle();
      await _tap(tester, 'overtime-delete');
      await tester.pumpAndSettle();
      expect((await stored()).entries, original.entries);
      await _close(tester);
      expect(_key('extras-mark-2026-10-26'), findsNothing);
      expect(scheduleOf(tester).resolve(_oct26).shiftIds, ['morning']);
      expect(tester.takeException(), isNull);
    });

    testWidgets('on a work day: «Horas extra», from the end of the shift, '
        '«+2 h» sets the end; one undo step', (tester) async {
      await pumpCalendar(tester, size: const Size(390, 1400));
      await _open(tester, _oct26);
      await _openAddSheet(tester);
      final day = _state(tester).schedule.resolve(_oct26);
      final shiftEnd = lastWorkEndMinute(day)! % 1440;
      expect(find.text('Justo después del turno'), findsOneWidget);
      await _tap(tester, 'overtime-quick-2');
      await tester.pumpAndSettle();
      expect(_text(tester, 'overtime-preview'), startsWith('2 h'));
      await _tap(tester, 'overtime-save');
      await tester.pumpAndSettle();
      expect(_key('overtime-sheet'), findsNothing);

      final block = _entry(tester, _oct26)!.overtimeBlocks.single;
      expect(block.typeId, overtimeTypeId);
      expect(block.startMinute, shiftEnd);
      expect(block.durationMinutes, 120);
      expect(_state(tester).schedule.resolve(_oct26).overtimeMinutes, 120);

      _controller(tester).undo();
      await tester.pumpAndSettle();
      expect(_entry(tester, _oct26), isNull);
    });

    testWidgets('on a free day the type is «Otro trabajo» and the length '
        'does not carry over from the last block', (tester) async {
      await pumpCalendar(tester, size: const Size(390, 1400));
      await _open(tester, _oct26);
      await _openAddSheet(tester);
      await _tap(tester, 'overtime-quick-4');
      await _tap(tester, 'overtime-save');
      await tester.pumpAndSettle();
      await _close(tester);

      await _open(tester, _oct24);
      await _openAddSheet(tester);
      expect(find.text('Justo después del turno'), findsNothing);
      await _tap(tester, 'overtime-save');
      await tester.pumpAndSettle();
      final block = _entry(tester, _oct24)!.overtimeBlocks.single;
      expect(block.typeId, otherWorkTypeId);
      expect(block.durationMinutes, 60);
    });

    testWidgets('a break as long as the block is refused', (tester) async {
      await pumpCalendar(tester, size: const Size(390, 1400));
      await _open(tester, _oct26);
      await _openAddSheet(tester);
      await tester.ensureVisible(_key('overtime-break'));
      await tester.enterText(_key('overtime-break'), '60');
      await _tap(tester, 'overtime-save');
      await tester.pumpAndSettle();
      expect(
        find.text('El descanso tiene que ser más corto que el bloque.'),
        findsOneWidget,
      );
      expect(_entry(tester, _oct26), isNull);
      await tester.enterText(_key('overtime-break'), '15');
      await tester.pumpAndSettle();
      expect(_text(tester, 'overtime-preview'), startsWith('45 min'));
      await _tap(tester, 'overtime-save');
      await tester.pumpAndSettle();
      expect(_entry(tester, _oct26)!.overtimeBlocks.single.paidMinutes, 45);
    });

    testWidgets('is stored: the database has the block', (tester) async {
      await pumpCalendar(tester, size: const Size(390, 1400));
      await _open(tester, _oct26);
      await _openAddSheet(tester);
      await tester.ensureVisible(_key('overtime-note'));
      await tester.enterText(_key('overtime-note'), 'Inventario');
      await _tap(tester, 'overtime-save');
      await tester.pumpAndSettle();
      final container = containerOf(tester);
      final snapshot = (await tester.runAsync(() async {
        await container.read(scheduleControllerProvider.notifier).pendingWrites;
        return container.read(scheduleRepositoryProvider).load(mainCalendarId);
      }))!;
      final stored = snapshot.schedule.entries[_oct26]!.overtimeBlocks.single;
      expect(stored, _entry(tester, _oct26)!.overtimeBlocks.single);
      expect(stored.note, 'Inventario');
    });
  });

  group('editing a block', () {
    testWidgets('tapping it opens it; «Borrar» takes it away', (tester) async {
      await pumpCalendar(tester, size: const Size(390, 1400));
      _controller(tester).setOvertimeBlocks(_oct26, [_block(_oct26)]);
      await tester.pumpAndSettle();
      await _open(tester, _oct26);
      await _tap(tester, 'day-overtime-b1');
      await tester.pumpAndSettle();
      expect(find.text('Editar horas extra'), findsOneWidget);
      await _tap(tester, 'overtime-quick-3');
      await _tap(tester, 'overtime-save');
      await tester.pumpAndSettle();
      expect(
        _entry(tester, _oct26)!.overtimeBlocks.single.durationMinutes,
        180,
      );

      await _tap(tester, 'day-overtime-b1');
      await tester.pumpAndSettle();
      await _tap(tester, 'overtime-delete');
      await tester.pumpAndSettle();
      expect(_entry(tester, _oct26), isNull);
    });
  });

  group('«Salí antes»', () {
    testWidgets('goes up and down, and 0 clears it', (tester) async {
      await pumpCalendar(tester, size: const Size(390, 1400));
      await _open(tester, _oct26);
      await _tap(tester, 'day-early-more', times: 4);
      await _settle(tester);
      expect(_entry(tester, _oct26)!.earlyLeaveMinutes, 60);
      expect(_text(tester, 'day-early-value'), '1 h');

      await _tap(tester, 'day-early-less', times: 4);
      expect(_text(tester, 'day-early-value'), 'Ninguna');
      await _settle(tester);
      expect(_entry(tester, _oct26), isNull);
    });

    testWidgets('three taps are written ONCE after a pause: one undo step', (
      tester,
    ) async {
      await pumpCalendar(tester, size: const Size(390, 1400));
      await _open(tester, _oct26);
      await _tap(tester, 'day-early-more', times: 3);
      expect(_text(tester, 'day-early-value'), '45 min');
      expect(_entry(tester, _oct26), isNull);
      await _settle(tester);
      expect(_entry(tester, _oct26)!.earlyLeaveMinutes, 45);
      _controller(tester).undo();
      await tester.pumpAndSettle();
      expect(_entry(tester, _oct26), isNull);
      expect(_state(tester).canUndo, isFalse);
    });

    testWidgets('closing the sheet before the pause still saves', (
      tester,
    ) async {
      await pumpCalendar(tester, size: const Size(390, 1400));
      await _open(tester, _oct26);
      await _tap(tester, 'day-early-more', times: 2);
      await _close(tester);
      await tester.pumpAndSettle();
      expect(_entry(tester, _oct26)!.earlyLeaveMinutes, 30);
    });

    testWidgets('clear during debounce stays clear and undo restores it', (
      tester,
    ) async {
      await pumpCalendar(tester, size: const Size(390, 1400));
      await _open(tester, _oct26);
      await _tap(tester, 'day-early-more');
      expect(_entry(tester, _oct26), isNull);
      await tester.ensureVisible(_key('day-clear'));
      await tester.tap(_key('day-clear'));
      await tester.pumpAndSettle();
      await _settle(tester);
      expect(_entry(tester, _oct26)?.earlyLeaveMinutes, isNull);
      expect(_state(tester).schedule.resolve(_oct26).shifts, isEmpty);
      await tester.tap(find.text('Deshacer').last);
      await tester.pumpAndSettle();
      expect(_entry(tester, _oct26)!.earlyLeaveMinutes, 15);
      expect(_state(tester).schedule.resolve(_oct26).shifts, isNotEmpty);
    });
  });

  group('the cell', () {
    testWidgets('a day with extra hours shows their sum, «+2 h», and says '
        'them; a plain day has no mark', (tester) async {
      await pumpCalendar(tester);
      expect(_key('extras-mark-2026-10-26'), findsNothing);

      _controller(tester).setOvertimeBlocks(_oct26, [
        _block(_oct26),
        _block(_oct26, id: 'b2', start: 21 * 60, end: 21 * 60 + 30),
      ]);
      _controller(tester).setDayExtras(_oct26, earlyLeaveMinutes: 30);
      await tester.pumpAndSettle();

      expect(_key('extras-mark-2026-10-26'), findsOneWidget);
      expect(_text(tester, 'extras-mark-2026-10-26'), '+2,5 h');
      expect(_key('extras-mark-2026-10-27'), findsNothing);
      final label = tester.getSemantics(cell(_oct26)).label;
      expect(label, contains('horas extra: 2 h 30 min'));
      expect(label, contains('salida anticipada: 30 min'));
      expect(label, contains('Mañana'));
    });

    testWidgets('only an early leave keeps the small «+»', (tester) async {
      await pumpCalendar(tester, size: const Size(390, 1400));
      await _open(tester, _oct26);
      await _tap(tester, 'day-early-more');
      await _close(tester);
      await tester.pumpAndSettle();
      expect(_key('extras-mark-2026-10-26'), findsOneWidget);
      expect(tester.widget(_key('extras-mark-2026-10-26')), isA<Icon>());
    });
  });

  group('small screens', () {
    for (final scale in [1.0, 1.3, 1.6]) {
      testWidgets('320 dp wide, text x$scale: no overflow', (tester) async {
        await pumpCalendar(
          tester,
          size: const Size(320, 700),
          textScale: scale,
        );
        _controller(tester).setOvertimeBlocks(_oct26, [
          _block(_oct26, start: 14 * 60, end: 4 * 60 + 45),
          _block(_oct26, id: 'b2', type: otherWorkTypeId),
        ]);
        _controller(tester)
            .setDayExtras(_oct26, earlyLeaveMinutes: 13 * 60 + 30);
        await tester.pumpAndSettle();
        await _open(tester, _oct26);
        await tester.ensureVisible(_key('day-extras'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(_text(tester, 'day-early-value'), '13 h 30 min');
      });
    }
  });
}
