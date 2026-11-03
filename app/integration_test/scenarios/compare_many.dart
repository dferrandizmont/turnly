import 'package:cuadrante/features/calendars/data/calendars_repository.dart';
import 'package:cuadrante/features/calendars/domain/calendar.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/qa_core.dart';
import '../support/qa_harness.dart';

// Comparar varios calendarios (P12), Q100.
//
// La pantalla admite de dos a seis calendarios: la rejilla tiene una fila por
// calendario y una columna por día, y con más de tres los días se desplazan
// de lado mientras la columna de los nombres se queda quieta.
//
// Demo data around Monday 19 Oct 2026: "Mi cuadrante" works on 19 days of
// October and is off on 11 of the others (the 22nd was cleared by hand, so
// it is not a day off). "Pareja", "Hijo" and "Turno" are off on exactly those
// 11 days, but "Turno" works the 24th and the 25th: the weekends of the
// 24th and the 25th are not free in all of them.

const _oct1 = CivilDate(2026, 10, 1);
const _oct3 = CivilDate(2026, 10, 3); // Saturday
const _oct4 = CivilDate(2026, 10, 4); // Sunday
const _oct10 = CivilDate(2026, 10, 10); // Saturday
const _oct11 = CivilDate(2026, 10, 11); // Sunday
const _oct17 = CivilDate(2026, 10, 17); // Saturday
const _oct18 = CivilDate(2026, 10, 18); // Sunday
const _oct22 = CivilDate(2026, 10, 22); // cleared by hand: not a day off
const _oct24 = CivilDate(2026, 10, 24); // Saturday: "Turno" works
const _oct25 = CivilDate(2026, 10, 25); // Sunday: "Turno" works
const _oct31 = CivilDate(2026, 10, 31); // Saturday, free in the four

/// Scenarios of this file, listed by `registry.dart`.
final List<QaScenario> compareManyScenarios = [
  qaCompareManyCalendars, // Q100
];

Finder _k(String key) => find.byKey(ValueKey(key));

String _text(WidgetTester t, String key) => t.widget<Text>(_k(key)).data!;

/// The id of the calendar called [name].
Future<String> _idOf(QaApp app, String name) async {
  final rows = await app.query("SELECT id FROM calendars WHERE name = '$name'");
  return rows.single['id']! as String;
}

/// The days "Mi cuadrante" is off in October 2026 (the 22nd is not one: it
/// was cleared by hand).
Future<List<CivilDate>> _freeDaysOfMain(QaStorage storage) async {
  final main = (await storage.repository.load(mainCalendarId)).schedule;
  return [
    for (final day in main.resolveRange(_oct1, _oct31))
      if (day.kind.isOff) day.date,
  ];
}

/// Prepares the three companions of "Mi cuadrante": all of them are off on
/// the same days, but "Turno" works the weekend of the 24th.
Future<void> _prepareCompanions(QaStorage storage) async {
  final free = await _freeDaysOfMain(storage);
  for (final (name, color) in [
    ('Pareja', 0xFF30A46C),
    ('Hijo', 0xFF1C7ED6),
    ('Turno', 0xFF7048E8),
  ]) {
    final id = (await CalendarsRepository(
      storage.database,
    ).create(name: name, colorValue: color)).id;
    await storage.repository.apply(
      id,
      ScheduleChange(
        patch: EntriesPatch({
          for (final day in free)
            day: EntryChange(
              null,
              DayEntry(date: day, shiftTypeIds: const ['rest']),
            ),
        }),
      ),
    );
  }
  // "Turno" works the weekend of the 24th: it is not free in all of them.
  final turno = (await CalendarsRepository(storage.database).list())
      .firstWhere((c) => c.name == 'Turno');
  await storage.repository.apply(
    turno.id,
    ScheduleChange(
      patch: EntriesPatch({
        _oct24: EntryChange(
          null,
          DayEntry(date: _oct24, shiftTypeIds: const ['morning']),
        ),
        _oct25: EntryChange(
          null,
          DayEntry(date: _oct25, shiftTypeIds: const ['morning']),
        ),
      }),
    ),
  );
}

// ---- Q100 ------------------------------------------------------------------

/// Q100.
const qaCompareManyCalendars = QaScenario(
  'Q100',
  'Comparar varios calendarios: rejilla de hasta seis y fines de semana libres',
  _compareManyCalendars,
);

Future<void> _compareManyCalendars(QaContext qa) async {
  final t = qa.tester;
  addTearDown(t.platformDispatcher.clearAllTestValues);
  final app = await QaApp.open(qa, prepare: _prepareCompanions);
  final hijo = await _idOf(app, 'Hijo');
  final turno = await _idOf(app, 'Turno');

  // Ajustes › Calendarios › Comparar calendarios.
  await t.tapAndSettle(find.byTooltip('Abrir ajustes'));
  await t.tapAndSettle(_k('settings-calendars'));
  await t.tapAndSettle(_k('calendars-compare'));
  await t.waitFor(_k('compare-table'), reason: 'la rejilla');
  expect(_text(t, 'compare-month'), 'Octubre 2026');
  await qa.shot('dos');

  // The sheet takes a third and a fourth calendar into the comparison.
  await t.tapAndSettle(_k('compare-change'));
  await qa.shot('elegir');
  await t.tapAndSettle(_k('compare-sheet-row-$hijo'));
  await t.tapAndSettle(_k('compare-sheet-row-$turno'));
  await t.tapAndSettle(_k('compare-sheet-done'));

  // One row per calendar and one column per day.
  for (final id in ['main', hijo, turno]) {
    expect(_k('compare-name-$id'), findsOneWidget, reason: id);
    expect(_k('compare-cell-$id-2026-10-19'), findsOneWidget, reason: id);
  }
  await qa.shot('cuatro');

  // The same grid in the dark.
  t.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
  await t.settle();
  await qa.shot('cuatro_oscuro');
  t.platformDispatcher.platformBrightnessTestValue = Brightness.light;
  await t.settle();

  // "Turno" works the weekend of the 24th: it is not free in all of them.
  expect(
    find.descendant(
      of: _k('compare-cell-$turno-2026-10-24'),
      matching: find.text('M'),
    ),
    findsOneWidget,
  );
  for (final date in [_oct3, _oct4, _oct10, _oct11, _oct17, _oct18]) {
    expect(_k('compare-free-${date.toIso()}'), findsOneWidget, reason: '$date');
  }
  for (final date in [_oct24, _oct25]) {
    expect(_k('compare-free-${date.toIso()}'), findsNothing, reason: '$date');
  }
  // The 22nd: nobody works but "Mi cuadrante" has nothing annotated.
  expect(_k('compare-unrecorded-${_oct22.toIso()}'), findsOneWidget);

  // The days scroll sideways; the column of the names does not move.
  final namesBefore = t.getCenter(_k('compare-name-main'));
  await t.drag(_k('compare-days-scroll'), const Offset(-400, 0));
  await t.settle();
  final namesAfter = t.getCenter(_k('compare-name-main'));
  expect(namesAfter.dx, namesBefore.dx);
  expect(namesAfter.dy, namesBefore.dy);
  await qa.shot('desplazado');

  // The summary: the free days and the free weekends.
  await t.ensureVisible(_k('compare-summary'));
  await t.settle();
  expect(_text(t, 'compare-count'), '9 días libres en común este mes');
  expect(
    _text(t, 'compare-weekend-count'),
    '3 fines de semana libres en común este mes',
  );
  expect(_k('compare-weekend-2026-10-03'), findsOneWidget);
  expect(_k('compare-weekend-2026-10-24'), findsNothing);
  expect(
    _text(t, 'compare-weekend-days-count'),
    '1 día de fin de semana libre en común',
  );
  await qa.shot('resumen');

  // Read-only: the calendar on screen did not change and nothing was written.
  await app.flushWrites();
  expect(app.scheduleState.calendarId, 'main');
  expect(app.scheduleState.canUndo, isFalse);
  qa.expectNoFlutterErrors('comparar');
}
