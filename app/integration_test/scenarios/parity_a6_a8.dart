import 'package:cuadrante/features/calendar/presentation/day_extras_section.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:cuadrante/features/summary/domain/month_summary.dart';
import 'package:cuadrante/features/summary/presentation/summary_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/day_sheet.dart';
import '../support/qa_core.dart';
import '../support/qa_harness.dart';

// Paridad 0.6.0: horas extra y salidas anticipadas (A6) e icono por turno
// (A8), Q96-Q98.
//
// Demo data around Monday 19 Oct 2026: rotation Noche 19-23, Libre 24-25,
// Mañana 26-30 (27 and 28 are Vacaciones). October has 160 h.

const _oct26 = CivilDate(2026, 10, 26); // Mañana by the rotation
const _oct29 = CivilDate(2026, 10, 29); // Mañana by the rotation
const _nbsp = ' ';
const _minus = '−';

/// Scenarios Q96-Q98, registered in `registry.dart`.
final List<QaScenario> parityA6A8Scenarios = [
  qaDayExtras, // Q96
  qaSummaryExtras, // Q97
  qaShiftIcon, // Q98
];

Finder _k(String key) => find.byKey(ValueKey(key));

String _text(WidgetTester t, String key) => t.widget<Text>(_k(key)).data!;

Future<void> _openDay(WidgetTester t, CivilDate date) async {
  await t.tapAndSettle(cell(date), reason: 'casilla de $date');
  expect(find.byType(BottomSheet), findsOneWidget, reason: 'detalle de $date');
  // The extras are in «Más opciones».
  await t.openDayMore();
}

/// Closes the sheet like a user: the dimmed area, or back when the sheet fills
/// the screen.
Future<void> _closeDay(WidgetTester t) async {
  final sheet = find.byType(BottomSheet);
  if (t.getTopLeft(sheet).dy > 100) {
    await t.tapAt(const Offset(20, 60));
  } else {
    await Navigator.of(t.element(sheet)).maybePop();
  }
  await t.settle();
  expect(sheet, findsNothing, reason: 'la hoja debe cerrarse');
}

/// Taps a stepper button [times] times.
Future<void> _steps(WidgetTester t, String key, int times) async {
  for (var i = 0; i < times; i++) {
    await t.ensureVisible(_k(key));
    await t.tap(_k(key));
    await t.pump(const Duration(milliseconds: 80));
  }
}

/// The quiet time after which the stepper writes the value.
Future<void> _quiet(WidgetTester t) async {
  await t.pump(DayExtrasSection.settle + const Duration(milliseconds: 300));
  await t.settle();
}

Future<List<Map<String, Object?>>> _storedExtras(QaApp app, CivilDate d) =>
    app.query(
      'SELECT date, shift_type_ids, overtime_minutes, early_leave_minutes '
      "FROM day_entries WHERE date = '${d.toIso()}'",
    );

Future<List<Map<String, Object?>>> _storedBlocks(QaApp app, CivilDate d) =>
    app.query(
      'SELECT id, type_id, start_minute, end_minute, break_minutes, note '
      "FROM overtime_blocks WHERE date = '${d.toIso()}' "
      "AND calendar_id = 'main' ORDER BY start_minute",
    );

// ---- Q96 -------------------------------------------------------------------

const qaDayExtras = QaScenario(
  'Q96',
  'Detalle: horas extra y salí antes (un paso de deshacer y marca en la casilla)',
  _dayExtras,
);

Future<void> _dayExtras(QaContext qa) async {
  final t = qa.tester;
  final app = await QaApp.open(qa);
  expect(await _storedExtras(app, _oct26), isEmpty);
  expect(await _storedBlocks(app, _oct26), isEmpty);
  expect(_k('extras-mark-2026-10-26'), findsNothing);

  await _openDay(t, _oct26);
  await t.ensureVisible(_k('day-extras'));
  expect(find.text('HORAS EXTRA / SALÍ ANTES'), findsOneWidget);
  expect(_text(t, 'day-early-value'), 'Ninguna');
  await t.tapAndSettle(_k('day-add-overtime'));
  expect(_k('overtime-sheet'), findsOneWidget);
  expect(find.text('Justo después del turno'), findsOneWidget);
  final shiftEnd = lastWorkEndMinute(app.schedule.resolve(_oct26))! % 1440;
  await t.tapAndSettle(_k('overtime-type-$overtimeTypeId'));
  await t.tapAndSettle(_k('overtime-quick-2'));
  expect(_text(t, 'overtime-preview'), startsWith('2 h'));
  await t.tapAndSettle(_k('overtime-save'));
  expect(_k('overtime-sheet'), findsNothing);
  final block = app.schedule.entries[_oct26]!.overtimeBlocks.single;
  expect(block.typeId, overtimeTypeId);
  expect(block.startMinute, shiftEnd);
  expect(block.endMinute, (shiftEnd + 120) % 1440);
  expect(block.paidMinutes, 120);
  expect(_text(t, 'day-overtime-duration-${block.id}'), '2 h');
  await qa.shot('seccion');

  await app.flushWrites();
  final rows = await _storedExtras(app, _oct26);
  // Blocks have their own table; the day's row has no legacy minutes or
  // shift override, so the shift still comes from the rotation.
  expect(rows, hasLength(1));
  expect(rows.single['overtime_minutes'], isNull);
  expect(rows.single['early_leave_minutes'], isNull);
  expect(rows.single['shift_type_ids'], isNull);
  expect(await _storedBlocks(app, _oct26), [
    {
      'id': block.id,
      'type_id': overtimeTypeId,
      'start_minute': shiftEnd,
      'end_minute': (shiftEnd + 120) % 1440,
      'break_minutes': 0,
      'note': null,
    },
  ]);
  expect(idsOn(app.schedule, _oct26), 'morning');

  await _closeDay(t);
  expect(_text(t, 'extras-mark-2026-10-26'), '+2 h');
  expect(inCell(_oct26, find.text('M')), findsOneWidget);
  await qa.shot('mes');

  // Everything was ONE undo step.
  await enterPaintMode(t);
  await t.tapAndSettle(_k('undo'), reason: 'deshacer');
  await exitPaintMode(t);
  await app.flushWrites();
  expect(await _storedExtras(app, _oct26), isEmpty);
  expect(await _storedBlocks(app, _oct26), isEmpty);
  expect(app.schedule.resolve(_oct26).overtimeBlocks, isEmpty);
  expect(app.scheduleState.canUndo, isFalse, reason: 'un solo paso');
  expect(idsOn(app.schedule, _oct26), 'morning');
  expect(_k('extras-mark-2026-10-26'), findsNothing);

  // Redo restores the same block and mark; deleting it is one step too.
  await enterPaintMode(t);
  await t.tapAndSettle(_k('redo'));
  await exitPaintMode(t);
  await app.flushWrites();
  expect((await _storedBlocks(app, _oct26)).single['id'], block.id);
  expect(_text(t, 'extras-mark-2026-10-26'), '+2 h');
  await _openDay(t, _oct26);
  await t.tapAndSettle(_k('day-overtime-${block.id}'));
  await t.tapAndSettle(_k('overtime-delete'));
  await app.flushWrites();
  expect(await _storedBlocks(app, _oct26), isEmpty);
  await _closeDay(t);
  expect(_k('extras-mark-2026-10-26'), findsNothing);

  // Early leave still uses the stepper: a burst is a separate undo step.
  await _openDay(t, _oct26);
  await _steps(t, 'day-early-more', 2);
  await _quiet(t);
  expect(_text(t, 'day-early-value'), '30 min');
  await app.flushWrites();
  expect((await _storedExtras(app, _oct26)).single['early_leave_minutes'], 30);
  await _closeDay(t);
  await enterPaintMode(t);
  await t.tapAndSettle(_k('undo'));
  await exitPaintMode(t);
  await app.flushWrites();
  expect(await _storedExtras(app, _oct26), isEmpty);
  expect(_k('extras-mark-2026-10-26'), findsNothing);

  // Taking the early leave away again with «−» removes the row.
  await _openDay(t, _oct26);
  await _steps(t, 'day-early-more', 4);
  await _quiet(t);
  await app.flushWrites();
  expect((await _storedExtras(app, _oct26)).single['early_leave_minutes'], 60);
  await _steps(t, 'day-early-less', 4);
  await _quiet(t);
  await app.flushWrites();
  expect(await _storedExtras(app, _oct26), isEmpty);
  await _closeDay(t);
  qa.expectNoFlutterErrors('horas extra');
}

// ---- Q97 -------------------------------------------------------------------

const qaSummaryExtras = QaScenario(
  'Q97',
  'Resumen: las horas extra suman y las salidas restan, también en el estimado',
  _summaryExtras,
);

Future<void> _summaryExtras(QaContext qa) async {
  final t = qa.tester;
  final app = await QaApp.open(
    qa,
    prepare: (storage) async {
      // Mañana 10,00 EUR/h and Tarde 11,00 EUR/h (Noche has no rate).
      for (final (key, rate) in [('morning', 1000), ('afternoon', 1100)]) {
        await storage.repository.saveShiftType(
          shiftTemplates
              .firstWhere((s) => s.key == key)
              .toShiftType(key)
              .copyWith(hourlyRateCents: rate),
        );
      }
    },
  );
  // Through the same controller the day detail uses.
  app.scheduleController
    ..setDayExtras(_oct26, overtimeMinutes: 90)
    ..setDayExtras(_oct29, earlyLeaveMinutes: 60)
    // A Noche (no rate) with overtime: hours yes, euros no.
    ..setDayExtras(const CivilDate(2026, 10, 19), overtimeMinutes: 30);
  await t.settle();

  await t.tapAndSettle(_k('open-summary'), reason: 'icono Resumen del mes');
  expect(find.byType(SummaryScreen), findsOneWidget);
  // The extras are on the 19th and later: planned 64 h + 2 h - 1 h.
  expect(_text(t, 'summary-hours'), '96 h');
  expect(_text(t, 'summary-legend-planned'), '65 h');
  expect(_text(t, 'summary-overtime-value'), '+2 h');
  expect(_text(t, 'summary-early-leave-value'), '${_minus}1 h');
  expect(find.text('+15,00$_nbsp€ en el estimado'), findsOneWidget);
  expect(find.text('${_minus}10,00$_nbsp€ en el estimado'), findsOneWidget);
  await t.ensureVisible(_k('summary-earnings'));
  await t.pump();
  // 1.248,00 + 15,00 - 10,00.
  expect(_text(t, 'summary-earnings'), '1.253,00$_nbsp€');
  expect(_k('summary-extras-no-rate'), findsOneWidget);
  await qa.shot('mes');

  // The screen shows what the engine computes.
  final summary = summarizeMonth(app.schedule, const CivilDate(2026, 10, 1));
  expect(summary.workedMinutes, 161 * 60);
  expect(summary.overtimeMinutes, 120);
  expect(summary.earlyLeaveMinutes, 60);
  expect(summary.earningsCents, 125300);
  qa.expectNoFlutterErrors('resumen con extras');
}

// ---- Q98 -------------------------------------------------------------------

const qaShiftIcon = QaScenario(
  'Q98',
  'Mis turnos: elegir icono, verlo en el mes y en el detalle, y quitarlo',
  _shiftIcon,
);

Future<void> _shiftIcon(QaContext qa) async {
  final t = qa.tester;
  final app = await QaApp.open(qa);
  Future<String?> storedIcon() async =>
      (await app.query("SELECT icon FROM shift_types WHERE id = 'morning'"))
              .single['icon']
          as String?;
  expect(await storedIcon(), isNull);

  await t.tapAndSettle(find.byTooltip('Abrir ajustes'));
  await t.tapAndSettle(_k('settings-shifts'), reason: 'Mis turnos');
  await t.tapAndSettle(_k('shift-row-morning'), reason: 'fila Mañana');
  expect(find.text('Sin icono'), findsWidgets);
  await t.tapAndSettle(_k('shift-icon'), reason: 'Icono');
  expect(_k('shift-icon-grid'), findsOneWidget);
  expect(_k('shift-icon-none'), findsOneWidget);
  for (final icon in ShiftIcon.values) {
    expect(_k('shift-icon-${icon.key}'), findsOneWidget, reason: icon.key);
  }
  await qa.shot('rejilla');
  await t.tapAndSettle(_k('shift-icon-sun'), reason: 'Sol');
  expect(find.text('Icono: Sol'), findsOneWidget);
  await t.tapAndSettle(_k('shift-save'), reason: 'Guardar');
  await app.flushWrites();
  expect(await storedIcon(), 'sun');

  // The list row shows it above the code.
  expect(
    find.descendant(of: _k('shift-row-morning'), matching: _k('badge-icon')),
    findsOneWidget,
  );
  await _backToMonth(t);

  // The month cell: before the code when it fits (a phone has room for a
  // one letter code), and the code is always there.
  expect(inCell(_oct26, find.text('M')), findsOneWidget);
  expect(inCell(_oct26, _k('cell-icon')), findsOneWidget);
  await qa.shot('mes');

  // The day detail row too.
  await _openDay(t, _oct26);
  expect(
    find.descendant(of: _k('day-shift-0'), matching: _k('badge-icon')),
    findsOneWidget,
  );
  await _closeDay(t);

  // «Sin icono» takes it away everywhere.
  await t.tapAndSettle(find.byTooltip('Abrir ajustes'));
  await t.tapAndSettle(_k('settings-shifts'), reason: 'Mis turnos');
  await t.tapAndSettle(_k('shift-row-morning'), reason: 'fila Mañana');
  expect(find.text('Icono: Sol'), findsOneWidget);
  await t.tapAndSettle(_k('shift-icon'), reason: 'Icono');
  await t.tapAndSettle(_k('shift-icon-none'), reason: 'Sin icono');
  await t.tapAndSettle(_k('shift-save'), reason: 'Guardar');
  await app.flushWrites();
  expect(await storedIcon(), isNull);
  await _backToMonth(t);
  expect(inCell(_oct26, _k('cell-icon')), findsNothing);
  expect(inCell(_oct26, find.text('M')), findsOneWidget);
  qa.expectNoFlutterErrors('icono del turno');
}

/// Back to the month screen from the list of shifts.
Future<void> _backToMonth(WidgetTester t) async {
  while (find.byType(BackButton).evaluate().isNotEmpty) {
    await t.tapAndSettle(find.byType(BackButton).last, reason: 'flecha atrás');
  }
  expect(find.text('Pintar'), findsOneWidget, reason: 'de vuelta en el mes');
}
