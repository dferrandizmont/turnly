import 'package:cuadrante/features/calendar/presentation/month_screen.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:device_calendar_plus/device_calendar_plus.dart' as dcp;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/qa_core.dart';
import '../support/qa_harness.dart';

// Citas del móvil (P6), Q101.
//
// The phone calendar is the real one of the emulator, through the plugin:
// `run_android.sh` grants READ_CALENDAR and WRITE_CALENDAR (the scenarios
// cannot answer the system question) and the scenario creates and deletes its
// own local calendar. The registry lists [deviceEventsScenarios].

/// Scenarios of this file, listed by `registry.dart`.
final List<QaScenario> deviceEventsScenarios = [
  qaDeviceEvents, // Q101
];

Finder _key(String k) => find.byKey(ValueKey(k));

/// The day with the appointment of the phone.
const _oct20 = CivilDate(2026, 10, 20);

/// The name of the local calendar the scenario creates.
const _calendarName = 'QA citas';

final dcp.DeviceCalendar _plugin = dcp.DeviceCalendar.instance;

/// Fails with a clear message when the QA run did not grant the permission.
Future<void> _requireCalendarAccess(QaContext qa) async {
  final status = (await qa.tester.runAsync(_plugin.hasPermissions))!;
  if (status != dcp.CalendarPermissionStatus.granted) {
    throw TestFailure(
      'Falta el permiso del calendario (estado: ${status.name}). '
      '`tool/qa/run_android.sh` lo concede con `adb shell pm grant`; si el '
      'escenario se ejecuta de otra forma, concede READ_CALENDAR y '
      'WRITE_CALENDAR a la app.',
    );
  }
}

/// Removes the calendars called [name] (left by an earlier run) now and when
/// the scenario ends.
Future<void> _cleanCalendars(QaContext qa, String name) async {
  Future<void> clean() async {
    final calendars = await _plugin.listCalendars();
    for (final c in calendars) {
      if (c.name == name) {
        try {
          await _plugin.deleteCalendar(c.id);
        } catch (_) {
          // Not ours to delete (a read-only account): leave it.
        }
      }
    }
  }

  await qa.tester.runAsync(clean);
  addTearDown(() async {
    try {
      await qa.tester.runAsync(clean);
    } catch (_) {
      // The binding may already be gone.
    }
  });
}

/// Back to the month, the way a person does it.
Future<void> _home(WidgetTester t) async {
  for (var i = 0; i < 4 && find.byType(BackButton).evaluate().isNotEmpty; i++) {
    await t.tapAndSettle(find.byType(BackButton).last, reason: 'flecha atrás');
  }
  expect(find.byType(MonthScreen), findsOneWidget);
}

// ---- Q101 ------------------------------------------------------------------

/// Q101.
const qaDeviceEvents = QaScenario(
  'Q101',
  'Citas del móvil: elegir calendario, marca en el mes, detalle del día y agenda',
  _deviceEvents,
  timeout: Duration(minutes: 5),
);

Future<void> _deviceEvents(QaContext qa) async {
  final t = qa.tester;
  await _requireCalendarAccess(qa);
  await _cleanCalendars(qa, _calendarName);

  // A local calendar of the phone with one appointment on the 20th of
  // October. It carries no tag of Turnly: it is an appointment of the person,
  // not a shift exported by the app.
  final calendarId = (await t.runAsync(() async {
    final id = await _plugin.createCalendar(
      name: _calendarName,
      platformOptions: const dcp.CreateCalendarOptionsAndroid(
        accountName: 'QA',
      ),
    );
    await _plugin.createEvent(
      calendarId: id,
      title: 'Cita con el médico',
      startDate: DateTime(2026, 10, 20, 9),
      endDate: DateTime(2026, 10, 20, 10),
    );
    return id;
  }))!;

  final app = await QaApp.open(qa);

  // Ajustes › Citas del móvil: the calendars of the phone, with the
  // permission already given (the QA script grants it).
  await t.tapAndSettle(find.byTooltip('Abrir ajustes'), reason: 'Ajustes');
  await t.tapAndSettle(
    _key('settings-device-events'),
    reason: 'Citas del móvil',
  );
  await t.waitFor(find.text(_calendarName), reason: 'calendarios del móvil');
  expect(find.text('1 calendario elegido'), findsNothing, reason: 'nada elegido');
  await qa.shot('calendarios');

  // Choosing it: the count says so and the choice is saved.
  await t.tapAndSettle(
    _key('device-events-calendar-$calendarId'),
    reason: 'elegir el calendario',
  );
  // On a real phone with many calendars the counter at the top of the list is
  // no longer built once the list scrolled down to «QA citas»: back to the top.
  await t.fling(find.byType(Scrollable).first, const Offset(0, 4000), 4000);
  await t.pumpAndSettle();
  await t.waitFor(find.text('1 calendario elegido'), reason: 'contador');
  await qa.shot('elegido');
  final stored = await app.query(
    "SELECT value FROM settings WHERE key = 'deviceEvents'",
  );
  expect(stored.single['value'], contains(calendarId));

  // In the month, the day with the appointment carries a discreet mark.
  await _home(t);
  await t.waitFor(
    _key('device-event-mark-2026-10-20'),
    reason: 'la marca de las citas en el mes',
  );
  expect(_key('device-event-mark-2026-10-21'), findsNothing);
  await qa.shot('mes');

  // In the day, the appointment with its hours.
  await t.tapAndSettle(cell(_oct20), reason: 'el día 20');
  await t.waitFor(_key('day-device-events-title'), reason: 'la sección de citas');
  expect(find.text('Cita con el médico'), findsOneWidget);
  expect(find.text('09:00–10:00'), findsOneWidget);
  await qa.shot('dia');

  // And in the agenda, next to the notes.
  await _closeDay(t);
  await t.tapAndSettle(_key('open-agenda'), reason: 'la agenda');
  await t.waitFor(find.text('Cita con el médico'), reason: 'la cita en la agenda');
  await qa.shot('agenda');

  qa.expectNoFlutterErrors();
}

/// Closes the sheet of the day the way a person does: tapping the dimmed
/// area (or going back when the sheet fills the whole screen).
Future<void> _closeDay(WidgetTester t) async {
  final sheet = find.byType(BottomSheet);
  expect(sheet, findsOneWidget);
  if (t.getTopLeft(sheet).dy > 20) {
    await t.tapAt(const Offset(10, 10));
  } else {
    await Navigator.of(t.element(sheet)).maybePop();
  }
  await t.settle();
}
