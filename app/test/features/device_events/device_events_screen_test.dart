import 'dart:ui' show Tristate;

import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:cuadrante/core/database/database_provider.dart';
import 'package:cuadrante/core/router.dart';
import 'package:cuadrante/core/theme/app_theme.dart';
import 'package:cuadrante/features/calendar_export/application/device_calendar_providers.dart';
import 'package:cuadrante/features/calendar_export/domain/device_calendar_api.dart';
import 'package:cuadrante/features/device_events/data/device_events_repository.dart';
import 'package:cuadrante/features/device_events/domain/device_events_settings.dart';
import 'package:cuadrante/features/device_events/presentation/device_events_screen.dart';
import 'package:cuadrante/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/fake_device_calendar.dart';
import '../../support/test_storage.dart';

Finder _key(String key) => find.byKey(ValueKey(key));

/// The little line that says how many calendars are chosen.
String _chosenCount(WidgetTester tester) =>
    tester.widget<Text>(_key('device-events-chosen-count')).data!;

void main() {
  setUpAll(initializeLocale);

  late FakeDeviceCalendar phone;

  setUp(() {
    phone = FakeDeviceCalendar();
  });

  /// Opens «Citas del móvil» with the phone of the test.
  Future<AppUnderTest> open(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    Brightness platformBrightness = Brightness.light,
  }) async {
    final app = await AppUnderTest.pump(
      tester,
      size: size,
      platformBrightness: platformBrightness,
      overrides: [deviceCalendarApiProvider.overrideWithValue(phone)],
    );
    app.container.read(routerProvider).go(AppRoutes.settingsDeviceEvents);
    await tester.pumpAndSettle();
    return app;
  }

  /// Lets the write to the database finish (the tests never mix fake time
  /// with real I/O).
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pumpAndSettle();
  }

  /// The screen alone, with the phone of the test: nothing else reads the
  /// calendar of the phone, so the test decides when it fails.
  Future<void> pumpScreen(WidgetTester tester) async {
    final database = openMemoryDatabase();
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        // The app does the same (`main.dart`): a failed provider shows its
        // error instead of retrying silently.
        retry: (retryCount, error) => null,
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          deviceCalendarApiProvider.overrideWithValue(phone),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.light(),
          home: const DeviceEventsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('the permission', () {
    testWidgets('is never asked for on its own', (tester) async {
      phone.setAccess(CalendarAccess.notDetermined);
      await open(tester);
      expect(_key('device-events-permission-needed'), findsOneWidget);
      expect(find.text('Permitir acceso'), findsOneWidget);
      // Nothing was asked: the card only offers it.
      expect(phone.requests, 0);
      expect(phone.calendarListings, 0);
    });

    testWidgets('the button asks the phone and the calendars appear', (
      tester,
    ) async {
      phone.setAccess(CalendarAccess.notDetermined);
      phone.addCalendar('Trabajo', account: 'yo@ejemplo.com');
      await open(tester);

      await tester.tap(_key('device-events-permission-allow'));
      await tester.pumpAndSettle();
      expect(phone.requests, 1);
      expect(_key('device-events-calendars'), findsOneWidget);
      expect(_key('device-events-calendar-cal-1'), findsOneWidget);
      expect(find.text('Trabajo'), findsOneWidget);
    });

    testWidgets('a refusal says so and can be asked again', (tester) async {
      phone.setAccess(CalendarAccess.denied);
      await open(tester);
      expect(_key('device-events-permission-denied'), findsOneWidget);
      expect(_key('device-events-permission-settings'), findsOneWidget);
      expect(_key('device-events-permission-recheck'), findsOneWidget);
    });

    testWidgets('the settings of the system open from the card', (tester) async {
      phone.setAccess(CalendarAccess.denied);
      await open(tester);
      await tester.tap(_key('device-events-permission-settings'));
      await tester.pumpAndSettle();
      expect(phone.settingsOpened, 1);
    });

    testWidgets('checking again reads the permission again', (tester) async {
      phone.setAccess(CalendarAccess.denied);
      await open(tester);
      await tester.tap(_key('device-events-permission-recheck'));
      await tester.pumpAndSettle();
      expect(_key('device-events-permission-denied'), findsOneWidget);
    });

    testWidgets('a phone that does not let the app use the calendar says so', (
      tester,
    ) async {
      phone.setAccess(CalendarAccess.restricted);
      await open(tester);
      expect(_key('device-events-permission-restricted'), findsOneWidget);
      expect(find.text('Este móvil no deja usar el calendario'), findsOneWidget);
    });

    testWidgets('a phone without calendars of its own says so', (tester) async {
      await open(tester);
      expect(_key('device-events-no-calendars'), findsOneWidget);
      expect(_key('device-events-calendars'), findsNothing);
    });

    testWidgets('a phone that does not answer says so and can be tried again', (
      tester,
    ) async {
      phone.addCalendar('Trabajo');
      // The calendar of the phone does not answer the first time.
      phone.failNext = CalendarApiError.unavailable;
      await pumpScreen(tester);
      expect(_key('device-events-error'), findsOneWidget);
      expect(find.text('No se han podido leer tus calendarios'), findsOneWidget);

      // Trying again reads it: now it answers.
      await tester.tap(_key('device-events-error-retry'));
      await tester.pumpAndSettle();
      expect(_key('device-events-error'), findsNothing);
      expect(_key('device-events-calendars'), findsOneWidget);
    });
  });

  group('the calendars of the phone', () {
    testWidgets('are listed with the ones of Turnly left out', (tester) async {
      phone.addCalendar('Trabajo', account: 'yo@ejemplo.com');
      phone.addCalendar('Turnly');
      phone.addCalendar('Oculto', hidden: true);
      await open(tester);
      expect(_key('device-events-calendar-cal-1'), findsOneWidget);
      expect(find.text('Trabajo'), findsOneWidget);
      expect(find.text('Turnly'), findsNothing);
      expect(find.text('Oculto'), findsNothing);
    });

    testWidgets('choosing one saves it and the count says so', (tester) async {
      phone.addCalendar('Trabajo');
      phone.addCalendar('Personal');
      final app = await open(tester);
      expect(_chosenCount(tester), '0 calendarios elegidos');
      expect(_key('device-events-calendar-check'), findsNothing);

      await tester.tap(_key('device-events-calendar-cal-1'));
      await settle(tester);

      expect(_chosenCount(tester), '1 calendario elegido');
      expect(_key('device-events-calendar-check'), findsOneWidget);
      final stored = await tester.runAsync(
        () => DeviceEventsRepository(app.database).load(),
      );
      expect(stored?.calendarIds, ['cal-1']);
    });

    testWidgets('unchoosing one takes it away', (tester) async {
      phone.addCalendar('Trabajo');
      phone.addCalendar('Personal');
      final app = await open(tester);
      await tester.tap(_key('device-events-calendar-cal-1'));
      await settle(tester);
      expect(_chosenCount(tester), '1 calendario elegido');

      await tester.tap(_key('device-events-calendar-cal-1'));
      await settle(tester);
      expect(_chosenCount(tester), '0 calendarios elegidos');
      final stored = await tester.runAsync(
        () => DeviceEventsRepository(app.database).load(),
      );
      expect(stored?.calendarIds, isEmpty);
    });

    testWidgets('the chosen calendar says out loud that it is chosen', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      phone.addCalendar('Trabajo');
      await open(tester);
      // The check is not the only sign: the state is announced too (rule 5).
      var node = tester.getSemantics(find.bySemanticsLabel('Trabajo'));
      expect(
        node.getSemanticsData().flagsCollection.isSelected,
        isNot(Tristate.isTrue),
      );

      await tester.tap(_key('device-events-calendar-cal-1'));
      await settle(tester);

      node = tester.getSemantics(find.bySemanticsLabel('Trabajo'));
      expect(
        node.getSemanticsData().flagsCollection.isSelected,
        Tristate.isTrue,
      );
      handle.dispose();
    });

    testWidgets('with nothing chosen the screen says the feature is off', (
      tester,
    ) async {
      phone.addCalendar('Trabajo');
      await open(tester);
      expect(_key('device-events-off'), findsOneWidget);
      expect(find.text('Ahora no se muestran citas'), findsOneWidget);
    });

    testWidgets('the ones already chosen come marked', (tester) async {
      phone.addCalendar('Trabajo');
      phone.addCalendar('Personal');
      final app = await AppUnderTest.pump(
        tester,
        overrides: [deviceCalendarApiProvider.overrideWithValue(phone)],
        prepare: (db) => DeviceEventsRepository(db).save(
          const DeviceEventsSettings(calendarIds: ['cal-2']),
        ),
      );
      app.container.read(routerProvider).go(AppRoutes.settingsDeviceEvents);
      await tester.pumpAndSettle();
      expect(_chosenCount(tester), '1 calendario elegido');
      expect(
        find.descendant(
          of: _key('device-events-calendar-cal-2'),
          matching: _key('device-events-calendar-check'),
        ),
        findsOneWidget,
      );
    });
  });

  group('the row of Ajustes', () {
    testWidgets('opens the screen and says how many are chosen', (
      tester,
    ) async {
      phone.addCalendar('Trabajo');
      final app = await AppUnderTest.pump(
        tester,
        size: const Size(390, 2600),
        overrides: [deviceCalendarApiProvider.overrideWithValue(phone)],
        prepare: (db) => DeviceEventsRepository(db).save(
          const DeviceEventsSettings(calendarIds: ['cal-1']),
        ),
      );
      await app.openSettings();
      expect(_key('settings-device-events'), findsOneWidget);
      expect(find.text('Citas del móvil'), findsOneWidget);
      expect(
        find.descendant(of: _key('settings-device-events'), matching: find.text('1')),
        findsOneWidget,
      );

      await tester.ensureVisible(_key('settings-device-events'));
      await tester.pumpAndSettle();
      await tester.tap(_key('settings-device-events'));
      await tester.pumpAndSettle();
      expect(find.byType(DeviceEventsScreen), findsOneWidget);
      expect(AppRoutes.settingsDeviceEvents, '/ajustes/citas');
    });

    testWidgets('with nothing chosen it says nothing', (tester) async {
      final app = await AppUnderTest.pump(
        tester,
        size: const Size(390, 2600),
        overrides: [deviceCalendarApiProvider.overrideWithValue(phone)],
      );
      await app.openSettings();
      expect(_key('settings-device-events'), findsOneWidget);
      expect(
        find.descendant(
          of: _key('settings-device-events'),
          matching: find.text('1'),
        ),
        findsNothing,
      );
    });
  });

  group('the layout', () {
    for (final (size, scale) in [
      (const Size(320, 568), 1.0),
      (const Size(320, 568), 2.0),
      (const Size(390, 844), 1.0),
      (const Size(390, 844), 2.0),
      (const Size(768, 1024), 1.0),
    ]) {
      for (final brightness in Brightness.values) {
        testWidgets('fits ${size.width.toInt()}x${size.height.toInt()} '
            'x$scale in ${brightness.name} with the calendars chosen', (
          tester,
        ) async {
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          phone.addCalendar('Trabajo', account: 'yo@ejemplo.com');
          phone.addCalendar('Personal', account: 'yo@ejemplo.com');
          await open(tester, size: size, platformBrightness: brightness);
          expect(tester.takeException(), isNull);
          // The whole screen can be read without overflowing.
          await tester.scrollUntilVisible(
            _key('device-events-calendars'),
            100,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(_key('device-events-calendars'), findsOneWidget);
          expect(_key('device-events-calendar-cal-1'), findsOneWidget);
          expect(_key('device-events-calendar-cal-2'), findsOneWidget);
        });
      }
    }
  });
}
