import 'package:cuadrante/core/router.dart';
import 'package:cuadrante/features/schedule/domain/civil_date.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/day_sheet.dart';
import '../support/qa_core.dart';
import '../support/qa_harness.dart';

/// Scenarios Q14: Ajustes › Libro de cambios (P4): the balance of every
/// colleague, the list of changes with their state, the sheet that creates
/// one, marking it returned or settled and applying it to the calendar with
/// a single undo.
///
/// Demo data around Monday 19 Oct 2026: the rotation gives Noche from the
/// 19th to the 23rd, so the change created here (which starts today) takes
/// the Noche of the 19th away when it is applied.
final List<QaScenario> swapsScenarios = [
  qaSwapsBook, // Q14
];

Finder _key(String value) => find.byKey(ValueKey(value));

/// The day the favour comes back in the picker of «Marcar como devuelto».
const _oct21 = CivilDate(2026, 10, 21);

/// Q14.
const qaSwapsBook = QaScenario(
  'Q14',
  'Libro de cambios: crear un cambio, verlo en el balance y aplicarlo al cuadrante',
  _book,
);

Future<void> _book(QaContext qa) async {
  final t = qa.tester;
  addTearDown(t.platformDispatcher.clearAllTestValues);
  final app = await QaApp.open(qa);

  // Ajustes › Libro de cambios.
  await t.tapAndSettle(
    find.byTooltip('Abrir ajustes'),
    reason: 'botón Ajustes',
  );
  await t.tapAndSettle(_key('settings-swaps'), reason: 'fila Libro de cambios');
  expect(_key('swap-empty'), findsOneWidget, reason: 'la lista vacía');
  expect(find.text('Todavía no hay cambios'), findsOneWidget);
  await qa.shot('vacio');

  // The sheet: with whom, who owes it and the shift that changes hands.
  await t.tapAndSettle(
    find.widgetWithText(FilledButton, 'Añadir cambio'),
    reason: 'acción Añadir cambio',
  );
  expect(find.text('Nuevo cambio'), findsOneWidget);
  await qa.shot('hoja');
  await t.enterText(_key('swap-field-colleague'), 'Marta');
  await t.tapAndSettle(_key('swap-direction-they-owe'), reason: 'Me lo deben');
  await t.tapAndSettle(_key('swap-given-night'), reason: 'turno Noche');
  await t.tapAndSettle(_key('swap-save'), reason: 'Guardar');

  // The change is in the list and in the balance.
  await t.waitFor(
    find.text('Marta · Me lo deben'),
    reason: 'el cambio en la lista',
  );
  expect(find.text('Me debe 1 turno'), findsOneWidget);
  expect(find.text('Pendiente'), findsOneWidget);
  final stored = await app.query(
    'SELECT id, colleague, direction, given_shift_type_ids, status '
    'FROM shift_swaps',
  );
  expect(stored, hasLength(1), reason: 'una fila en shift_swaps');
  expect(stored.single['colleague'], 'Marta');
  expect(stored.single['direction'], 'theyOwe');
  expect(stored.single['given_shift_type_ids'], '["night"]');
  expect(stored.single['status'], 'pending');
  final id = stored.single['id']! as String;
  await qa.shot('lista');

  // The same list in the dark.
  t.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
  await t.settle();
  await qa.shot('lista_oscuro');
  t.platformDispatcher.platformBrightnessTestValue = Brightness.light;
  await t.settle();

  // Applied to the calendar: the day loses the shift, in ONE undo step.
  expect(app.schedule.resolve(qaToday).shiftIds, const ['night']);
  await t.tapAndSettle(_key('swap-menu-$id'), reason: 'menú del cambio');
  await t.tapAndSettle(_key('swap-menu-apply'), reason: 'Aplicar al cuadrante');
  await t.waitFor(
    find.text('Cambio aplicado al cuadrante'),
    reason: 'el aviso de aplicado',
  );
  expect(app.schedule.resolve(qaToday).shiftIds, isEmpty);
  await app.flushWrites();
  expect((await app.storedDay(qaToday))?.shiftTypeIds, const []);
  await qa.shot('aplicado');

  // «Deshacer» takes the whole change back.
  await t.tapAndSettle(find.text('Deshacer'), reason: 'Deshacer');
  await app.flushWrites();
  expect(app.schedule.resolve(qaToday).shiftIds, const ['night']);
  expect(
    await app.storedDay(qaToday),
    isNull,
    reason: 'la excepción del día disappears',
  );
  await qa.shot('deshecho');

  // The favour comes back on the 21st: the change is no longer pending and
  // the balance is even (one shift given, one received).
  await t.tapAndSettle(_key('swap-menu-$id'), reason: 'menú del cambio');
  await t.tapAndSettle(
    _key('swap-menu-returned'),
    reason: 'Marcar como devuelto',
  );
  expect(find.text('¿Qué día te lo devuelven?'), findsOneWidget);
  await qa.shot('dia');
  await t.tapAndSettle(
    find.descendant(
      of: find.byType(DatePickerDialog),
      matching: find.text('${_oct21.day}'),
    ),
    reason: 'el 21 de octubre',
  );
  await t.tapAndSettle(find.text('Aceptar'), reason: 'Aceptar el día');
  await t.waitFor(find.text('Devuelto'), reason: 'el estado Devuelto');
  expect(find.text('Nada pendiente'), findsOneWidget, reason: 'el balance a cero');
  final returned = await app.query(
    "SELECT return_date, status FROM shift_swaps WHERE id = '$id'",
  );
  expect(returned.single['return_date'], _oct21.toIso());
  expect(returned.single['status'], 'pending', reason: 'devuelto, no saldado');
  await qa.shot('devuelto');

  // Closed: it leaves the pending list and the balance.
  await t.tapAndSettle(_key('swap-menu-$id'), reason: 'menú del cambio');
  await t.tapAndSettle(_key('swap-menu-settle'), reason: 'Marcar como saldado');
  await t.waitFor(find.text('Saldado'), reason: 'el estado Saldado');
  final settled = await app.query('SELECT status, closed_at FROM shift_swaps');
  expect(settled.single['status'], 'returned');
  expect(settled.single['closed_at'], isNotNull);
  await qa.shot('saldado');

  // The day detail has the section: it shows the change of that day.
  final router = app.container.read(routerProvider);
  while (router.canPop()) {
    router.pop();
    await t.settle();
  }
  await t.tapAndSettle(cell(qaToday), reason: 'la casilla de hoy');
  await t.openDayMore();
  expect(_key('day-swap-section'), findsOneWidget);
  expect(
    find.descendant(
      of: _key('day-swap-section'),
      matching: find.text('Marta · Me lo deben'),
    ),
    findsOneWidget,
  );
  await qa.shot('dia_detalle');
}
