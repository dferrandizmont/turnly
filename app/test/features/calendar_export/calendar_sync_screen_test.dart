import 'package:cuadrante/core/bootstrap/bootstrap.dart' show initializeLocale;
import 'package:cuadrante/core/database/app_database.dart';
import 'package:cuadrante/features/calendar/application/schedule_controller.dart';
import 'package:cuadrante/features/calendar_export/application/calendar_sync_providers.dart';
import 'package:cuadrante/features/calendar_export/application/export_controller.dart';
import 'package:cuadrante/features/calendar_export/data/calendar_sync_repository.dart';
import 'package:cuadrante/features/calendar_export/domain/calendar_sync_settings.dart';
import 'package:cuadrante/features/calendar_export/domain/device_calendar_api.dart';
import 'package:cuadrante/features/calendar_export/domain/export_events.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/fake_device_calendar.dart';
import '../import/import_ui_support.dart';

Future<AppUnderTest> openExport(
  WidgetTester tester,
  FakeDeviceCalendar phone, {
  Future<void> Function(AppDatabase database)? prepare,
}) async {
  final app = await AppUnderTest.pump(
    tester,
    size: importTestSize,
    overrides: importOverrides(phone: phone, picker: FakePicker()),
    prepare: prepare,
  );
  await app.openSettings();
  await tester.ensureVisible(byKey('settings-export-calendar'));
  await tester.pumpAndSettle();
  await tester.tap(byKey('settings-export-calendar'));
  await tester.pumpAndSettle();
  return app;
}

ExportState stateOf(AppUnderTest app) =>
    app.container.read(exportControllerProvider);

CalendarSyncSettings syncOf(AppUnderTest app) =>
    app.container.read(calendarSyncSettingsProvider).requireValue;

Future<CalendarSyncSettings> storedSync(AppUnderTest app) =>
    app.real(() => CalendarSyncRepository(app.database).load());

void main() {
  setUpAll(initializeLocale);

  testWidgets('the switch is there, off, and nothing is written until used', (
    tester,
  ) async {
    final phone = FakeDeviceCalendar();
    final app = await openExport(tester, phone);
    expect(byKey('export-keep-updated'), findsOneWidget);
    expect(find.text('Mantener al día'), findsOneWidget);
    expect(
      tester.widget<Switch>(byKey('export-keep-updated-switch')).value,
      isFalse,
    );
    expect(syncOf(app).enabled, isFalse);
    expect(phone.createdCalendars, 0);
    expect(phone.createdEvents, 0);
  });

  testWidgets('turning it on creates «Turnly», writes now and locks the rows', (
    tester,
  ) async {
    final phone = FakeDeviceCalendar();
    final other = phone.addCalendar('Personal');
    final app = await openExport(tester, phone);
    expect(stateOf(app).targetId, isNull);

    await tapKey(tester, 'export-keep-updated-switch');

    expect(phone.createdCalendars, 1);
    final id = phone.allCalendars.firstWhere((c) => c.name == 'Turnly').id;
    expect(phone.eventsOf(id), isNotEmpty);
    for (final e in phone.eventsOf(id)) {
      expect(ExportTag.parse(e.description)?.calendarId, 'main');
    }
    final stored = await storedSync(app);
    expect(stored.enabled, isTrue);
    expect(stored.deviceCalendarId, id);
    expect(stored.deviceCalendarName, 'Turnly');
    expect(stored.appCalendarId, 'main');
    expect(stored.includeRest, isFalse);
    expect(stored.includeAbsences, isFalse);
    expect(stored.lastSyncAt, isNotNull);

    expect(
      tester.widget<Switch>(byKey('export-keep-updated-switch')).value,
      isTrue,
    );
    expect(stateOf(app).targetId, id);
    expect(byKey('export-sync-locked'), findsOneWidget);
    expect(byKey('export-sync-last'), findsOneWidget);

    // The calendar cannot be changed while it is on.
    await tester.ensureVisible(byKey('export-calendar-$other'));
    await tester.tap(byKey('export-calendar-$other'));
    await tester.pumpAndSettle();
    expect(stateOf(app).targetId, id);
  });

  testWidgets('it keeps an existing calendar the user chose', (tester) async {
    final phone = FakeDeviceCalendar();
    final id = phone.addCalendar('Personal');
    phone.addSimpleEvent(
      id,
      'Dentista',
      DateTime(2026, 10, 20, 9),
      DateTime(2026, 10, 20, 10),
    );
    final app = await openExport(tester, phone);
    await tapKey(tester, 'export-calendar-$id');
    await tapKey(tester, 'export-keep-updated-switch');

    expect(phone.createdCalendars, 0);
    final stored = await storedSync(app);
    expect(stored.deviceCalendarId, id);
    expect(stored.deviceCalendarName, 'Personal');
    expect(
      phone.eventsOf(id).where((e) => e.title == 'Dentista'),
      hasLength(1),
    );
    expect(phone.eventsOf(id).length, greaterThan(1));
  });

  testWidgets('turning it off leaves the events and stops following', (
    tester,
  ) async {
    final phone = FakeDeviceCalendar();
    final app = await openExport(tester, phone);
    await tapKey(tester, 'export-keep-updated-switch');
    final id = phone.allCalendars.single.id;
    final written = phone.eventsOf(id).length;

    await tapKey(tester, 'export-keep-updated-switch');
    expect((await storedSync(app)).enabled, isFalse);
    expect(phone.eventsOf(id), hasLength(written));
    expect(phone.deletedEvents, 0);
    expect(byKey('export-sync-locked'), findsNothing);

    // A change of the schedule no longer reaches the phone.
    app.container.read(scheduleControllerProvider.notifier).setDayShifts(
      const CivilDate(2026, 10, 21),
      const ['night'],
    );
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(phone.eventsOf(id), hasLength(written));
  });

  testWidgets('a change in the calendar reaches the phone, grouped', (
    tester,
  ) async {
    final phone = FakeDeviceCalendar();
    final app = await openExport(tester, phone);
    await tapKey(tester, 'export-keep-updated-switch');
    final id = phone.allCalendars.single.id;
    const day = CivilDate(2026, 10, 21);

    String? titleOn() => phone
        .eventsOf(id)
        .where((e) => ExportTag.parse(e.description)?.date == day)
        .map((e) => e.title)
        .singleOrNull;

    final original = titleOn();
    // A shift that is not the one on that day now.
    final (finalId, finalTitle) = original == 'Tarde · T'
        ? ('morning', 'Mañana · M')
        : ('afternoon', 'Tarde · T');

    final notifier = app.container.read(scheduleControllerProvider.notifier);
    // Several quick touches: one pass, after the quiet.
    notifier.setDayShifts(day, const ['night']);
    await tester.pump(const Duration(seconds: 1));
    notifier.setDayShifts(day, [finalId]);
    await tester.pump(const Duration(seconds: 1));
    final before = phone.eventListings;
    expect(titleOn(), original, reason: 'still inside the quiet time');
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    expect(titleOn(), finalTitle);
    expect(phone.eventListings - before, 1, reason: 'one pass');
    final tags = phone.eventsOf(id).map((e) => e.description).toList();
    expect(tags.toSet().length, tags.length, reason: 'no duplicated tags');
  });

  testWidgets('the options of the screen are followed while it is on', (
    tester,
  ) async {
    final phone = FakeDeviceCalendar();
    final app = await openExport(tester, phone);
    await tapKey(tester, 'export-keep-updated-switch');
    final id = phone.allCalendars.single.id;
    final before = phone.eventsOf(id).length;

    await tapKey(tester, 'export-include-rest-switch');
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect((await storedSync(app)).includeRest, isTrue);
    expect(phone.eventsOf(id).length, greaterThan(before));
    expect((await storedSync(app)).includeAbsences, isFalse);
  });

  testWidgets('opening the screen again shows what is being kept', (
    tester,
  ) async {
    final phone = FakeDeviceCalendar();
    final app = await openExport(tester, phone);
    await tapKey(tester, 'export-include-rest-switch');
    await tapKey(tester, 'export-keep-updated-switch');
    final id = phone.allCalendars.single.id;

    await app.back();
    app.container.invalidate(exportControllerProvider);
    await tester.ensureVisible(byKey('settings-export-calendar'));
    await tester.pumpAndSettle();
    await tester.tap(byKey('settings-export-calendar'));
    await tester.pumpAndSettle();

    expect(stateOf(app).targetId, id);
    expect(stateOf(app).includeRest, isTrue);
    expect(
      tester.widget<Switch>(byKey('export-keep-updated-switch')).value,
      isTrue,
    );
  });

  testWidgets('a manual export and the continuous one do not duplicate', (
    tester,
  ) async {
    final phone = FakeDeviceCalendar();
    final app = await openExport(tester, phone);
    await tapKey(tester, 'export-keep-updated-switch');
    final id = phone.allCalendars.single.id;
    final first = phone.eventsOf(id).length;

    await app.container.read(exportControllerProvider.notifier).start();
    await tester.pumpAndSettle();
    await app.container.read(calendarSyncProvider).sync();
    await tester.pumpAndSettle();

    final tags = phone.eventsOf(id).map((e) => e.description).toList();
    expect(tags.toSet().length, tags.length, reason: 'no duplicated tags');
    expect(tags.length, greaterThanOrEqualTo(first));
  });

  group('it turns itself off', () {
    testWidgets('when the permission is revoked, with a notice', (
      tester,
    ) async {
      final phone = FakeDeviceCalendar();
      final app = await openExport(tester, phone);
      await tapKey(tester, 'export-keep-updated-switch');
      final id = phone.allCalendars.single.id;
      final written = phone.eventsOf(id).length;

      // The user takes the permission away in the system settings; the next
      // change finds out.
      phone.setAccess(CalendarAccess.denied);
      app.container.read(scheduleControllerProvider.notifier).setDayShifts(
        const CivilDate(2026, 10, 21),
        const ['night'],
      );
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      final stored = await storedSync(app);
      expect(stored.enabled, isFalse);
      expect(stored.notice, CalendarSyncNotice.permission);
      expect(phone.eventsOf(id), hasLength(written));
      // Said once at the time (a notice on screen)...
      expect(find.textContaining('Turnly ya no tiene permiso'), findsWidgets);
    });

    testWidgets('the notice stays on the screen until it is dismissed', (
      tester,
    ) async {
      final phone = FakeDeviceCalendar();
      final app = await openExport(tester, phone);
      await tapKey(tester, 'export-keep-updated-switch');
      phone.setAccess(CalendarAccess.denied);
      await app.container.read(calendarSyncProvider).sync();
      await tester.pumpAndSettle(const Duration(seconds: 7));

      expect(byKey('export-sync-notice'), findsOneWidget);
      await tapKey(tester, 'export-sync-notice-dismiss');
      expect(byKey('export-sync-notice'), findsNothing);
      expect((await storedSync(app)).notice, isNull);
    });

    testWidgets('when the phone calendar is gone, found at the start', (
      tester,
    ) async {
      final phone = FakeDeviceCalendar();
      phone.addCalendar('Personal');
      final app = await AppUnderTest.pump(
        tester,
        size: importTestSize,
        overrides: importOverrides(phone: phone, picker: FakePicker()),
        prepare: (database) => CalendarSyncRepository(database).save(
          const CalendarSyncSettings(
            enabled: true,
            deviceCalendarId: 'cal-999',
            deviceCalendarName: 'Turnly',
            appCalendarId: 'main',
          ),
        ),
      );
      // The notice of the moment, then it goes away by itself.
      expect(find.textContaining('ya no está o ha cambiado'), findsOneWidget);
      await tester.pump(const Duration(seconds: 8));
      await tester.pumpAndSettle();

      final stored = await storedSync(app);
      expect(stored.enabled, isFalse);
      expect(stored.notice, CalendarSyncNotice.calendarGone);
      expect(phone.createdCalendars, 0, reason: 'no new calendar is made');
      expect(phone.createdEvents, 0);

      // And it waits on the export screen until it is dismissed.
      await app.openSettings();
      await tester.ensureVisible(byKey('settings-export-calendar'));
      await tester.pumpAndSettle();
      await tester.tap(byKey('settings-export-calendar'));
      await tester.pumpAndSettle();
      expect(byKey('export-sync-notice'), findsOneWidget);
    });
  });

  testWidgets('a pass runs when the app opens with it on', (tester) async {
    final phone = FakeDeviceCalendar();
    final id = phone.addCalendar('Turnly');
    await openExport(
      tester,
      phone,
      prepare: (database) => CalendarSyncRepository(database).save(
        CalendarSyncSettings(
          enabled: true,
          deviceCalendarId: id,
          deviceCalendarName: 'Turnly',
          appCalendarId: 'main',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(phone.eventsOf(id), isNotEmpty, reason: 'filled at the start');
    for (final e in phone.eventsOf(id)) {
      expect(ExportTag.parse(e.description)?.calendarId, 'main');
    }
  });
}
