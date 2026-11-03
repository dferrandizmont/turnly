import 'dart:io';

import 'package:cuadrante/features/notes/presentation/sketch_screen.dart';
import 'package:cuadrante/features/schedule/domain/civil_date.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../support/day_sheet.dart';
import '../support/qa_core.dart';
import '../support/qa_harness.dart';

/// Scenarios Q103: the notes of a day with a drawing and its tasks (P2).
///
/// The photo and the file leave the app (the gallery and the file browser of
/// the system are the ones that choose them), so the battery checks the two
/// things that are made inside the app: the drawing (saved as an attachment
/// of the day, with its file in the store) and the checklist of the day.
final List<QaScenario> notesScenarios = [
  qaDayNotes, // Q103
];

Finder _key(String value) => find.byKey(ValueKey(value));

/// A free day of the demo rotation (the data of the battery).
const _oct24 = CivilDate(2026, 10, 24);

/// Q103.
const qaDayNotes = QaScenario(
  'Q103',
  'Detalle del día: dibujo guardado como adjunto y tareas del día',
  _notes,
);

Future<void> _notes(QaContext qa) async {
  final t = qa.tester;
  addTearDown(t.platformDispatcher.clearAllTestValues);
  final app = await QaApp.open(qa);

  // The detail of the day, with «Más opciones» open: the two sections of the
  // notes are there.
  await t.tapAndSettle(cell(_oct24), reason: 'casilla del 24 de octubre');
  expect(find.byType(BottomSheet), findsOneWidget, reason: 'detalle del día');
  await t.openDayMore();
  expect(_key('day-attachments-section'), findsOneWidget);
  expect(_key('day-tasks-section'), findsOneWidget);
  expect(find.text('Todavía no hay fotos ni archivos'), findsOneWidget);
  expect(find.text('Este día no tiene tareas.'), findsOneWidget);
  await qa.shot('secciones');

  // The same sections in the dark.
  t.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
  await t.settle();
  await qa.shot('secciones_oscuro');
  t.platformDispatcher.platformBrightnessTestValue = Brightness.light;
  await t.settle();

  // A drawing: a stroke on the canvas and «Guardar».
  await t.tapAndSettle(
    _key('day-attachments-add-empty'),
    reason: 'Añadir un adjunto',
  );
  expect(find.text('Hacer una foto'), findsOneWidget);
  expect(find.text('Elegir un archivo'), findsOneWidget);
  await t.tapAndSettle(find.text('Dibujar'), reason: 'Dibujar');
  expect(find.byType(SketchScreen), findsOneWidget);
  final canvas = t.getRect(_key('sketch-canvas'));
  await t.dragFrom(
    Offset(canvas.left + 40, canvas.top + 40),
    const Offset(120, 90),
  );
  await t.pumpAndSettle();
  expect(_key('sketch-empty-hint'), findsNothing, reason: 'el trazo está');
  await qa.shot('dibujo');
  await t.tapAndSettle(_key('sketch-save'), reason: 'Guardar el dibujo');

  // The drawing is an attachment of the day: the row and the file.
  final rows = await app.query(
    'SELECT id, kind, mime_type, relative_path FROM note_attachments '
    "WHERE date = '${_oct24.toIso()}'",
  );
  expect(rows, hasLength(1), reason: 'una fila en note_attachments');
  expect(rows.single['kind'], 'sketch');
  expect(rows.single['mime_type'], 'image/png');
  final support = (await t.runAsync(() => getApplicationSupportDirectory()))!;
  final file = File(
    p.join(support.path, 'attachments', rows.single['relative_path'] as String),
  );
  expect(
    await t.runAsync(() => file.exists()),
    isTrue,
    reason: 'el archivo del dibujo está en el almacén de adjuntos',
  );
  expect(_key('day-attachments-strip'), findsOneWidget);
  await qa.shot('adjunto');

  // A long press on the thumbnail takes it off the day; the undo brings it
  // back (the file too).
  final thumb = _key('attachment-${rows.single['id']}');
  await t.ensureVisible(thumb);
  await t.pumpAndSettle();
  await t.longPress(thumb);
  await t.settle();
  expect(
    await app.query(
      "SELECT id FROM note_attachments WHERE date = '${_oct24.toIso()}'",
    ),
    isEmpty,
    reason: 'la fila se va con el adjunto',
  );
  expect(_key('day-attachments-undo'), findsOneWidget);
  expect(find.text('Se quitó Dibujo'), findsOneWidget);
  await qa.shot('deshacer');
  await t.tapAndSettle(
    _key('day-attachments-undo-button'),
    reason: 'Deshacer el adjunto quitado',
  );
  final back = await app.query(
    'SELECT kind, relative_path FROM note_attachments '
    "WHERE date = '${_oct24.toIso()}'",
  );
  expect(back, hasLength(1), reason: 'el adjunto vuelve');
  expect(back.single['kind'], 'sketch');

  // The checklist of the day: two tasks, one ticked, one moved and one
  // removed (with the undo of the section).
  await t.enterText(_key('day-task-field'), 'Comprar pan');
  await t.tapAndSettle(_key('day-task-add'), reason: 'Añadir tarea');
  await t.enterText(_key('day-task-field'), 'Llamar al hospital');
  await t.tapAndSettle(_key('day-task-add'), reason: 'Añadir tarea');
  var tasks = await app.query(
    'SELECT id, title, done, sort_order FROM day_tasks '
    "WHERE date = '${_oct24.toIso()}' ORDER BY sort_order",
  );
  expect(tasks, hasLength(2), reason: 'dos tareas en day_tasks');
  expect(tasks.first['title'], 'Comprar pan');
  expect(tasks.last['title'], 'Llamar al hospital');
  expect(find.text('Comprar pan'), findsOneWidget);
  await qa.shot('tareas');

  // Ticking one keeps it in the list.
  await t.tapAndSettle(
    _key('task-check-${tasks.first['id']}'),
    reason: 'marcar la tarea',
  );
  tasks = await app.query(
    "SELECT id, title, done FROM day_tasks WHERE date = '${_oct24.toIso()}' "
    'ORDER BY sort_order',
  );
  expect(tasks.first['done'], 1, reason: 'la tarea está marcada');

  // Moving it down puts it after the other one.
  await t.tapAndSettle(
    _key('task-menu-${tasks.first['id']}'),
    reason: 'menú de la tarea',
  );
  await t.tapAndSettle(
    _key('task-menu-down-${tasks.first['id']}'),
    reason: 'Bajar la tarea',
  );
  tasks = await app.query(
    "SELECT title FROM day_tasks WHERE date = '${_oct24.toIso()}' "
    'ORDER BY sort_order',
  );
  expect(tasks.first['title'], 'Llamar al hospital');
  expect(tasks.last['title'], 'Comprar pan');

  // The undo of the section puts the order back.
  await t.tapAndSettle(_key('day-tasks-undo'), reason: 'Deshacer');
  tasks = await app.query(
    "SELECT id, title FROM day_tasks WHERE date = '${_oct24.toIso()}' "
    'ORDER BY sort_order',
  );
  expect(tasks.first['title'], 'Comprar pan');

  // And removing a task takes it out of the list.
  await t.tapAndSettle(
    _key('task-menu-${tasks.first['id']}'),
    reason: 'menú de la tarea',
  );
  await t.tapAndSettle(
    _key('task-menu-remove-${tasks.first['id']}'),
    reason: 'Quitar la tarea',
  );
  tasks = await app.query(
    "SELECT title FROM day_tasks WHERE date = '${_oct24.toIso()}' "
    'ORDER BY sort_order',
  );
  expect(tasks, hasLength(1));
  expect(tasks.single['title'], 'Llamar al hospital');
  expect(find.text('Comprar pan'), findsNothing);
  await qa.shot('sin_tarea');
}
