import 'package:cuadrante/features/calendars/data/calendars_repository.dart';
import 'package:cuadrante/features/calendars/domain/calendar.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/qa_core.dart';
import '../support/qa_harness.dart';

// Comparar calendarios (docs/paridad.md A4), Q86 y Q87.
//
// Demo data around Monday 19 Oct 2026: "Mi cuadrante" works on 19 days of
// October (Noche 1, 2, 19, 20, 23; Mañana 5-9, 21, 26, 29, 30; Tarde 12-16
// and 21); the other 12 days are off (Libre, Vacaciones 27-28 and the 22nd,
// which the fixture turns from "cleared by hand" into a real Libre: a day
// with nothing annotated is not a free day).
//
// A calendar with nothing annotated shares no free day (A6: only Libre and
// absence days count), so the fixture marks "Pareja" and "Hijo" off on
// exactly the 12 days "Mi cuadrante" is off. "Pareja" also has a vacation on
// the 19th, which does not help: the other calendar works that day.
//
// The grid has one row per calendar and one column per day (P12): the codes
// of each calendar are in its own cell.

const _oct1 = CivilDate(2026, 10, 1);
const _oct19 = CivilDate(2026, 10, 19); // Noche | Vacaciones
const _oct21 = CivilDate(2026, 10, 21); // Mañana + Tarde | nothing
const _oct22 = CivilDate(2026, 10, 22); // Libre (fixture) | nothing
const _oct24 = CivilDate(2026, 10, 24); // Libre | nothing
const _oct27 = CivilDate(2026, 10, 27); // Vacaciones | nothing
const _oct31 = CivilDate(2026, 10, 31);

/// Scenarios of this file, listed by `parity.dart`.
final List<QaScenario> compareScenarios = [
  qaCompareFreeDays, // Q86
  qaCompareChoose, // Q87
];

Finder _k(String key) => find.byKey(ValueKey(key));

String _text(WidgetTester t, String key) => t.widget<Text>(_k(key)).data!;

/// The code inside the cell of [calendarId] on [date].
Finder _inCell(String calendarId, CivilDate date, String code) =>
    find.descendant(
      of: _k('compare-cell-$calendarId-${date.toIso()}'),
      matching: find.text(code),
    );

/// The id of the calendar called [name].
Future<String> _idOf(QaApp app, String name) async {
  final rows = await app.query("SELECT id FROM calendars WHERE name = '$name'");
  return rows.single['id']! as String;
}

/// Annotates [calendarId] as a day off on exactly the days "Mi cuadrante" is
/// off in October. A calendar with no shifts would otherwise share nothing:
/// with nothing annotated a day is not free (A6).
Future<void> _restOnMainFreeDays(QaStorage storage, String calendarId) async {
  final main = (await storage.repository.load(mainCalendarId)).schedule;
  final free = [
    for (final day in main.resolveRange(_oct1, _oct31))
      if (day.kind.isOff) day.date,
  ];
  await storage.repository.apply(
    calendarId,
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

/// "Pareja", with the 22nd turned into a real Libre and days off wherever
/// "Mi cuadrante" has them, plus a vacation day today, stored before the app
/// starts.
Future<void> _prepareCouple(QaStorage storage) async {
  await storage.repository.apply(
    mainCalendarId,
    ScheduleChange(
      patch: EntriesPatch({
        _oct22: EntryChange(
          null,
          DayEntry(date: _oct22, shiftTypeIds: const ['rest']),
        ),
      }),
    ),
  );
  final id = (await CalendarsRepository(
    storage.database,
  ).create(name: 'Pareja', colorValue: 0xFF30A46C)).id;
  await _restOnMainFreeDays(storage, id);
  await storage.repository.apply(
    id,
    ScheduleChange(
      patch: EntriesPatch({
        qaToday: EntryChange(
          null,
          DayEntry(date: qaToday, shiftTypeIds: const ['vacation']),
        ),
      }),
    ),
  );
}

Future<void> _back(WidgetTester t) =>
    t.tapAndSettle(find.byType(BackButton).last, reason: 'flecha atrás');

// ---- Q86 -------------------------------------------------------------------

/// Q86.
const qaCompareFreeDays = QaScenario(
  'Q86',
  'Comparar calendarios: días libres en común del mes',
  _compareFreeDays,
);

Future<void> _compareFreeDays(QaContext qa) async {
  final t = qa.tester;
  final app = await QaApp.open(qa, prepare: _prepareCouple);
  final partner = await _idOf(app, 'Pareja');

  // Ajustes › Calendarios › Comparar calendarios.
  await t.tapAndSettle(find.byTooltip('Abrir ajustes'));
  await t.tapAndSettle(_k('settings-calendars'));
  await t.tapAndSettle(_k('calendars-compare'));
  expect(find.text('Comparar calendarios'), findsWidgets);
  expect(
    find.descendant(
      of: _k('compare-calendar-main'),
      matching: find.text('Mi cuadrante'),
    ),
    findsOneWidget,
  );
  expect(
    find.descendant(
      of: _k('compare-calendar-$partner'),
      matching: find.text('Pareja'),
    ),
    findsOneWidget,
  );
  expect(_text(t, 'compare-month'), 'Octubre 2026');
  await qa.shot('mes');

  // The shifts of every calendar in the cell of its own day.
  expect(_inCell('main', _oct19, 'N'), findsOneWidget);
  expect(_inCell(partner, _oct19, 'V'), findsOneWidget);
  expect(_inCell('main', _oct21, 'M+T'), findsOneWidget);
  expect(_inCell(partner, _oct21, '–'), findsOneWidget);
  expect(_inCell('main', _oct24, 'L'), findsOneWidget);

  // Free in all of them: two Libre days and a vacation day. Busy: the Noche
  // of the 19th (the vacation of the other does not help).
  for (final date in [_oct22, _oct24, _oct27]) {
    expect(_k('compare-free-${date.toIso()}'), findsOneWidget, reason: '$date');
  }
  for (final date in [_oct19, _oct21]) {
    expect(_k('compare-free-${date.toIso()}'), findsNothing, reason: '$date');
  }

  // The count and the list of dates.
  await t.ensureVisible(_k('compare-summary'));
  await t.settle();
  expect(_text(t, 'compare-count'), '12 días libres en común este mes');
  expect(_k('compare-free-date-2026-10-22'), findsOneWidget);
  expect(_k('compare-free-date-2026-10-19'), findsNothing);
  expect(find.text('jue 22 oct'), findsOneWidget);
  // The free weekends: four whole ones and the Saturday of the 31st, whose
  // Sunday is in the next month.
  expect(
    _text(t, 'compare-weekend-count'),
    '4 fines de semana libres en común este mes',
  );
  expect(_k('compare-weekend-2026-10-24'), findsOneWidget);
  expect(
    _text(t, 'compare-weekend-days-count'),
    '1 día de fin de semana libre en común',
  );
  expect(_k('compare-weekend-day-2026-10-31'), findsOneWidget);
  await qa.shot('lista');
  qa.expectNoFlutterErrors('comparar');
  await _back(t);
  await _back(t);
  await _back(t);
}

// ---- Q87 -------------------------------------------------------------------

/// Q87.
const qaCompareChoose = QaScenario(
  'Q87',
  'Comparar: elegir los calendarios, cambiar de mes y no tocar nada',
  _compareChoose,
);

Future<void> _compareChoose(QaContext qa) async {
  final t = qa.tester;
  final app = await QaApp.open(
    qa,
    prepare: (storage) async {
      await _prepareCouple(storage);
      final hijo = (await CalendarsRepository(storage.database).create(
        name: 'Hijo',
        colorValue: 0xFF1C7ED6,
      )).id;
      await _restOnMainFreeDays(storage, hijo);
    },
  );
  final dump = await app.dumpSchedule();
  final partner = await _idOf(app, 'Pareja');
  final hijo = await _idOf(app, 'Hijo');

  // From the calendar pill of the month screen.
  // The calendars are loaded from disk by an AsyncNotifier; settling frames
  // does not wait for that I/O. Keep checking the real selector and route.
  await t.waitFor(_k('calendar-switcher'));
  await t.tapAndSettle(_k('calendar-switcher'));
  await t.tapAndSettle(_k('calendar-switcher-compare'));
  expect(_text(t, 'compare-month'), 'Octubre 2026');

  // The sheet takes "Hijo" into the comparison: a third row in the grid.
  await t.tapAndSettle(_k('compare-change'));
  await qa.shot('elegir');
  await t.tapAndSettle(_k('compare-sheet-row-$hijo'));
  await t.tapAndSettle(_k('compare-sheet-done'));
  expect(_k('compare-name-$hijo'), findsOneWidget);
  expect(_k('compare-cell-$hijo-2026-10-19'), findsOneWidget);
  await t.ensureVisible(_k('compare-summary'));
  expect(_text(t, 'compare-count'), '12 días libres en común este mes');

  // Taking one out puts the comparison back to two.
  await t.tapAndSettle(_k('compare-change'));
  await t.tapAndSettle(_k('compare-sheet-row-$hijo'));
  await t.tapAndSettle(_k('compare-sheet-done'));
  expect(_k('compare-name-$hijo'), findsNothing);
  expect(_k('compare-name-$partner'), findsOneWidget);

  // The months: the arrows (the days of the grid scroll sideways, so a
  // swipe does not change the month any more).
  await t.tapAndSettle(_k('compare-next'));
  expect(_text(t, 'compare-month'), 'Noviembre 2026');
  await t.tapAndSettle(_k('compare-previous'));
  await t.tapAndSettle(_k('compare-previous'));
  expect(_text(t, 'compare-month'), 'Septiembre 2026');
  await qa.shot('mes_cambiado');

  // Read-only: the stored schedule is exactly as it was, and the calendar on
  // screen did not change.
  await app.flushWrites();
  expect(await app.dumpSchedule(), dump);
  expect(app.scheduleState.calendarId, 'main');
  expect(app.scheduleState.canUndo, isFalse);
  qa.expectNoFlutterErrors('comparar');
}
