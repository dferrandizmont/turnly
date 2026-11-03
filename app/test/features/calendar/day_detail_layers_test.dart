import 'package:cuadrante/core/widgets/buttons.dart';
import 'package:cuadrante/features/calendar/application/schedule_controller.dart';
import 'package:cuadrante/features/calendar/presentation/day_extras_section.dart';
import 'package:cuadrante/features/calendar/presentation/day_more_options.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'day_sheet_finders.dart';
import 'harness.dart';

// The day detail by layers (B4, option 4A of 31 Oct) with a visible
// «Deshacer» (A7). Demo data around Monday 19 Oct 2026: Noche 19-23, Libre
// 24-25, Mañana 26-30; 21 Mañana + Tarde by hand; 12 Oct a holiday.
const _oct12 = CivilDate(2026, 10, 12);
const _oct21 = CivilDate(2026, 10, 21);
const _oct24 = CivilDate(2026, 10, 24);
const _oct26 = CivilDate(2026, 10, 26);

Finder _key(String key) => find.byKey(ValueKey(key));

Finder get _sheet => find.byType(BottomSheet);

ScheduleController _controller(WidgetTester tester) =>
    containerOf(tester).read(scheduleControllerProvider.notifier);

List<String> _ids(WidgetTester tester, CivilDate date) =>
    scheduleOf(tester).resolve(date).shiftIds;

Future<void> _open(WidgetTester tester, CivilDate date) async {
  await revealCell(tester, date);
  await tester.tap(cell(date));
  await tester.pumpAndSettle();
}

bool _undoEnabled(WidgetTester tester) =>
    tester.widget<IconButton>(_key('day-undo')).onPressed != null;

String _summary(WidgetTester tester) =>
    tester.widget<Text>(_key('day-more-summary')).data!;

Future<void> _undo(WidgetTester tester) async {
  await tester.tap(_key('day-undo'));
  await tester.pumpAndSettle();
}

void main() {
  group('inventory: nothing the sheet did before is lost', () {
    testWidgets('every function of the day is reachable', (tester) async {
      await pumpCalendar(tester);
      await _open(tester, _oct21); // by hand: Mañana + Tarde
      // Always in sight: date, «Deshacer», the rows, «Volver al patrón»,
      // «Añadir turno», the note and «Más opciones».
      for (final key in [
        'day-undo',
        'day-shift-0',
        'day-shift-1',
        'day-shift-menu-0',
        'day-shift-menu-1',
        'day-reset',
        'day-pattern-gives',
        'day-add-open',
        'day-note',
        'day-more',
      ]) {
        expect(_key(key), findsOneWidget, reason: key);
      }
      // In the menu of a row: change, up, down, remove.
      for (final key in [
        'day-change-1',
        'day-up-1',
        'day-down-1',
        'day-remove-1',
      ]) {
        await revealDayControl(tester, key);
        expect(_key(key), findsOneWidget, reason: key);
      }
      await dismissMenu(tester);
      // Behind «Añadir turno»: every shift of the palette.
      final palette = containerOf(tester)
          .read(scheduleControllerProvider)
          .palette;
      for (final shift in palette) {
        await revealDayControl(tester, 'day-add-${shift.id}');
        expect(_key('day-add-${shift.id}'), findsOneWidget);
      }
      // In «Más opciones»: extras, own holiday, reminder, duplicate, clear.
      for (final key in [
        'day-extras',
        'day-overtime-more',
        'day-early-more',
        'day-holiday-switch',
        'day-reminder-add',
        'day-duplicate',
        'day-clear',
      ]) {
        await revealDayControl(tester, key);
        expect(_key(key), findsOneWidget, reason: key);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('«Más opciones» says what it holds, with what is set', (
      tester,
    ) async {
      await pumpCalendar(tester);
      await _open(tester, _oct24);
      expect(
        _summary(tester),
        'Horas extra · Importe extra · Festivo propio · Aviso · '
        'Adjuntos · Tareas · Cambio de turno · Duplicar · Borrar',
      );
      // Folded: nothing of it is built.
      expect(_key('day-more-content'), findsNothing);
      expect(_key('day-duplicate'), findsNothing);

      _controller(tester)
        ..setDayExtras(_oct24, overtimeMinutes: 90, earlyLeaveMinutes: 30)
        ..setNoteReminder(_oct24, 21 * 60);
      await tester.pumpAndSettle();
      expect(
        _summary(tester),
        'Horas extra: 1 h 30 min · Salí antes: 30 min · Importe extra · Festivo propio · '
        'Aviso: 21:00 · Adjuntos · Tareas · Cambio de turno · Duplicar · Borrar',
      );
    });

    testWidgets('a day gone by does not offer a reminder', (tester) async {
      await pumpCalendar(tester);
      await _open(tester, _oct12);
      expect(_summary(tester), isNot(contains('Aviso')));
      await openDayMore(tester);
      expect(_key('day-reminder-add'), findsNothing);
    });

    testWidgets('it unfolds and folds again', (tester) async {
      await pumpCalendar(tester);
      await _open(tester, _oct24);
      await openDayMore(tester);
      expect(_key('day-more-content'), findsOneWidget);
      expect(_key('day-clear'), findsOneWidget);
      await tester.tap(_key('day-more'));
      await tester.pumpAndSettle();
      expect(_key('day-more-content'), findsNothing);
    });
  });

  group('the hook of «Más opciones»', () {
    String name(_) => 'Adjuntos';
    Widget section(BuildContext context, CivilDate date) =>
        Text('Adjuntos de ${date.toIso()}', key: const ValueKey('probe'));

    testWidgets('a section of another feature is named and shown above '
        '«Duplicar» and «Borrar día»', (tester) async {
      await pumpCalendar(
        tester,
        overrides: [
          dayMoreSectionsProvider.overrideWithValue([
            DayMoreSection(id: 'attachments', name: name, builder: section),
          ]),
        ],
      );
      await _open(tester, _oct24);
      expect(
        _summary(tester),
        'Horas extra · Importe extra · Festivo propio · Aviso · Adjuntos · Duplicar · Borrar',
      );
      await openDayMore(tester);
      expect(_key('day-more-attachments'), findsOneWidget);
      expect(find.text('Adjuntos de 2026-10-24'), findsOneWidget);
      await tester.ensureVisible(_key('day-duplicate'));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(_key('probe')).bottom,
        lessThan(tester.getRect(_key('day-duplicate')).top),
      );
      expect(
        tester.getRect(_key('probe')).top,
        greaterThan(tester.getRect(_key('day-holiday-switch')).bottom),
      );
    });
  });

  group('A7: «Deshacer» in the header', () {
    testWidgets('off until the day changes; undoes the latest change', (
      tester,
    ) async {
      await pumpCalendar(tester);
      await _open(tester, _oct24);
      expect(_undoEnabled(tester), isFalse);

      await tapDayControl(tester, 'day-add-guard24');
      expect(_ids(tester, _oct24), ['rest', 'guard24']);
      expect(_undoEnabled(tester), isTrue);

      await _undo(tester);
      expect(_ids(tester, _oct24), ['rest']);
      expect(_key('day-shift-1'), findsNothing);
      expect(_undoEnabled(tester), isFalse);
      // Still in the sheet.
      expect(_sheet, findsOneWidget);
      // And the month can redo it.
      expect(
        containerOf(tester).read(scheduleControllerProvider).canRedo,
        isTrue,
      );
    });

    testWidgets('steps back one change at a time, only on this day', (
      tester,
    ) async {
      await pumpCalendar(tester);
      await _open(tester, _oct21);
      await tapDayControl(tester, 'day-remove-0'); // Tarde left
      await tapDayControl(tester, 'day-add-night'); // Tarde + Noche
      expect(_ids(tester, _oct21), ['afternoon', 'night']);
      await _undo(tester);
      expect(_ids(tester, _oct21), ['afternoon']);
      await _undo(tester);
      expect(_ids(tester, _oct21), ['morning', 'afternoon']);
      expect(_undoEnabled(tester), isFalse);
    });

    testWidgets('a change of another day is not undone from here', (
      tester,
    ) async {
      await pumpCalendar(tester);
      _controller(tester).setDayShifts(_oct26, const ['guard24']);
      await tester.pumpAndSettle();
      await _open(tester, _oct24);
      expect(_undoEnabled(tester), isFalse);
      await tester.tap(_key('day-undo'));
      await tester.pumpAndSettle();
      expect(_ids(tester, _oct26), ['guard24']);
    });

    testWidgets('a change made before opening the day can be undone', (
      tester,
    ) async {
      await pumpCalendar(tester);
      _controller(tester).setDayShifts(_oct24, const ['night']);
      await tester.pumpAndSettle();
      await _open(tester, _oct24);
      expect(_undoEnabled(tester), isTrue);
      await _undo(tester);
      expect(_ids(tester, _oct24), ['rest']);
    });

    testWidgets('the note being typed: on at the first key, back to the '
        'saved text', (tester) async {
      await pumpCalendar(tester);
      await _open(tester, _oct24);
      await tester.enterText(_key('day-note'), 'Cumple de Ana');
      await tester.pump();
      expect(_undoEnabled(tester), isTrue);
      await _undo(tester);
      expect(scheduleOf(tester).resolve(_oct24).note, isNull);
      expect(
        tester.widget<TextField>(_key('day-note')).controller!.text,
        isEmpty,
      );
      expect(_undoEnabled(tester), isFalse);
      // Closing now writes nothing more.
      Navigator.of(tester.element(_sheet)).pop();
      await tester.pumpAndSettle();
      expect(scheduleOf(tester).resolve(_oct24).note, isNull);
    });

    testWidgets('the extra hours, even while still settling', (tester) async {
      await pumpCalendar(tester);
      await _open(tester, _oct26);
      await tapDayControl(tester, 'day-overtime-more');
      await tester.pump(DayExtrasSection.settle + const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(scheduleOf(tester).entries[_oct26]?.overtimeMinutes, 15);
      await tester.tap(_key('day-overtime-more'));
      await tester.pump(); // not written yet
      await tester.ensureVisible(_key('day-undo'));
      await _undo(tester);
      expect(scheduleOf(tester).entries[_oct26]?.overtimeMinutes, 15);
      await _undo(tester);
      expect(scheduleOf(tester).entries[_oct26], isNull);
    });
  });

  group('the rows and the palette', () {
    testWidgets('«Cambiar» swaps that shift in its place', (tester) async {
      await pumpCalendar(tester);
      await _open(tester, _oct21);
      await tapDayControl(tester, 'day-change-0');
      expect(find.text('Cambiar Mañana por…'), findsOneWidget);
      // The ones the day has cannot be picked.
      await tester.tap(_key('day-add-afternoon'));
      await tester.pumpAndSettle();
      expect(_ids(tester, _oct21), ['morning', 'afternoon']);

      await tester.tap(_key('day-add-night'));
      await tester.pumpAndSettle();
      expect(_ids(tester, _oct21), ['night', 'afternoon']);
      expect(_key('day-palette'), findsNothing);
      await _undo(tester);
      expect(_ids(tester, _oct21), ['morning', 'afternoon']);
    });

    testWidgets('the palette closes with its button', (tester) async {
      await pumpCalendar(tester);
      await _open(tester, _oct24);
      await tapDayControl(tester, 'day-add-open');
      expect(_key('day-palette'), findsOneWidget);
      await tester.tap(_key('day-palette-close'));
      await tester.pumpAndSettle();
      expect(_key('day-palette'), findsNothing);
      expect(_key('day-add-open'), findsOneWidget);
    });

    testWidgets('removing the last shift brings the palette out', (
      tester,
    ) async {
      await pumpCalendar(tester);
      await _open(tester, _oct24);
      expect(_key('day-palette'), findsNothing);
      await tapDayControl(tester, 'day-remove-0');
      expect(_ids(tester, _oct24), isEmpty);
      expect(_key('day-palette'), findsOneWidget);
      expect(find.text('Añadir turno'), findsOneWidget);
    });

    testWidgets('each row shows times and hours', (tester) async {
      await pumpCalendar(tester);
      await _open(tester, const CivilDate(2026, 10, 20)); // Noche
      expect(
        find.descendant(
          of: _key('day-shift-0'),
          matching: find.text('22:00–06:00 · 8 h'),
        ),
        findsOneWidget,
      );
    });
  });

  testWidgets('Q99: the split shift row shows both ranges and their total', (
    tester,
  ) async {
    await pumpCalendar(tester);
    final controller = _controller(tester);
    final split = scheduleOf(tester)
        .shiftTypeById('morning')!
        .copyWith(
          name: 'Partido',
          startMinute: 9 * 60,
          endMinute: 13 * 60,
          segment2StartMinute: 17 * 60,
          segment2DurationMinutes: 4 * 60,
        );
    controller
      ..saveShiftType(split)
      ..setDayShifts(_oct24, [split.id]);
    await tester.pumpAndSettle();
    await _open(tester, _oct24);
    expect(
      find.descendant(
        of: _key('day-shift-0'),
        matching: find.byWidgetPredicate(
          (w) =>
              w is Text &&
              w.data?.replaceAll('\u2060', '') ==
                  '09:00–13:00 · 17:00–21:00 · 8 h',
        ),
      ),
      findsOneWidget,
    );
  });

  group('accessibility', () {
    testWidgets('the buttons say what they do', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpCalendar(tester);
      await _open(tester, _oct21);
      expect(
        find.byTooltip('Deshacer el último cambio de este día'),
        findsOneWidget,
      );
      expect(find.byTooltip('Opciones de Mañana'), findsOneWidget);
      expect(find.byTooltip('Opciones de Tarde'), findsOneWidget);

      final more = find.bySemanticsLabel(
        RegExp(r'^Más opciones\. Horas extra'),
      );
      expect(more, findsOneWidget);
      expect(
        tester.getSemantics(more),
        isSemantics(
          isButton: true,
          hasExpandedState: true,
          isExpanded: false,
          hasTapAction: true,
        ),
      );
      await tester.tap(_key('day-more'));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(more),
        isSemantics(hasExpandedState: true, isExpanded: true),
      );
      // The note field keeps its name for screen readers.
      expect(find.bySemanticsLabel(RegExp('Nota')), findsWidgets);
      handle.dispose();
    });
  });

  group('sizes and themes', () {
    for (final (scale, brightness, size) in [
      (2.0, Brightness.light, const Size(320, 568)),
      (2.0, Brightness.dark, const Size(320, 568)),
      (1.0, Brightness.dark, const Size(390, 844)),
    ]) {
      testWidgets('${size.width.toInt()} dp, text x$scale, '
          '${brightness.name}: all layers open, nothing overflows', (
        tester,
      ) async {
        await pumpCalendar(
          tester,
          size: size,
          textScale: scale,
          brightness: brightness,
        );
        await _open(tester, _oct21);
        await revealDayControl(tester, 'day-change-1');
        await dismissMenu(tester);
        await revealDayControl(tester, 'day-add-night');
        await openDayMore(tester);
        expect(_key('day-more-content'), findsOneWidget);
        await revealDayControl(tester, 'day-clear');
        expect(
          tester.widget<SecondaryButton>(_key('day-clear')).onPressed,
          isNotNull,
        );
        // The header with «Deshacer» stays at the top of the sheet.
        expect(
          tester.getRect(_key('day-undo')).top,
          lessThan(tester.getRect(_sheet).top + 80),
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('tablet pane', () {
    const tablet = Size(1280, 800);

    testWidgets('the same layers in the pane, with «Deshacer» next to close', (
      tester,
    ) async {
      await pumpCalendar(tester, size: tablet);
      await _open(tester, _oct24);
      expect(_sheet, findsNothing);
      expect(_key('day-pane-close'), findsOneWidget);
      expect(_undoEnabled(tester), isFalse);
      expect(_key('day-more-content'), findsNothing);

      await tapDayControl(tester, 'day-add-morning');
      expect(_ids(tester, _oct24), ['rest', 'morning']);
      expect(_undoEnabled(tester), isTrue);
      await _undo(tester);
      expect(_ids(tester, _oct24), ['rest']);

      await openDayMore(tester);
      for (final key in ['day-extras', 'day-holiday-switch', 'day-clear']) {
        await tester.ensureVisible(_key(key));
        await tester.pumpAndSettle();
        expect(_key(key).hitTestable(), findsOneWidget, reason: key);
      }
      expect(tester.takeException(), isNull);
    });
  });
}
