import 'package:cuadrante/core/router.dart';
import 'package:cuadrante/features/calendar_export/application/device_calendar_providers.dart';
import 'package:cuadrante/features/device_events/data/device_events_repository.dart';
import 'package:cuadrante/features/device_events/domain/device_events_settings.dart';
import 'package:cuadrante/features/schedule/domain/civil_date.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/fake_device_calendar.dart';

Finder _key(String key) => find.byKey(ValueKey(key));

const _oct20 = CivilDate(2026, 10, 20);
const _oct21 = CivilDate(2026, 10, 21);

void main() {
  late FakeDeviceCalendar phone;

  setUp(() {
    phone = FakeDeviceCalendar();
  });

  /// The app with a phone that has one appointment on the 20th of October
  /// and the calendar of the phone chosen.
  Future<AppUnderTest> open(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    Brightness brightness = Brightness.light,
    double textScale = 1.0,
  }) async {
    phone.addCalendar('Trabajo');
    phone.addSimpleEvent(
      'cal-1',
      'Dentista',
      DateTime(2026, 10, 20, 9),
      DateTime(2026, 10, 20, 10),
    );
    if (textScale != 1.0) {
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
    }
    return AppUnderTest.pump(
      tester,
      size: size,
      platformBrightness: brightness,
      overrides: [deviceCalendarApiProvider.overrideWithValue(phone)],
      prepare: (db) => DeviceEventsRepository(db).save(
        const DeviceEventsSettings(calendarIds: ['cal-1']),
      ),
    );
  }

  /// Scrolls until [finder] is built and on screen: on a small screen with
  /// large text the lower rows are outside the build range.
  Future<void> reveal(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 30 && finder.evaluate().isEmpty; i++) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -150));
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('the month marks the days that have appointments', (tester) async {
    await open(tester);
    await tester.pumpAndSettle();
    expect(_key('device-event-mark-2026-10-20'), findsOneWidget);
    expect(_key('device-event-mark-2026-10-21'), findsNothing);
    // The mark is inside the cell, so it never covers the code or the hours.
    expect(
      inDayCell(_oct20, _key('device-event-mark-2026-10-20')),
      findsOneWidget,
    );
  });

  testWidgets('without a calendar chosen nothing is marked', (tester) async {
    phone.addCalendar('Trabajo');
    phone.addSimpleEvent(
      'cal-1',
      'Dentista',
      DateTime(2026, 10, 20, 9),
      DateTime(2026, 10, 20, 10),
    );
    await AppUnderTest.pump(
      tester,
      overrides: [deviceCalendarApiProvider.overrideWithValue(phone)],
    );
    await tester.pumpAndSettle();
    expect(_key('device-event-mark-2026-10-20'), findsNothing);
  });

  testWidgets('the day detail lists the appointments with their hours', (
    tester,
  ) async {
    await open(tester);
    await tester.pumpAndSettle();

    await tester.tap(dayCell(_oct20));
    await tester.pumpAndSettle();

    expect(_key('day-device-events-title'), findsOneWidget);
    expect(find.text('Citas del móvil'), findsOneWidget);
    expect(find.text('Dentista'), findsOneWidget);
    expect(find.text('09:00–10:00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a day without appointments shows no section', (tester) async {
    await open(tester);
    await tester.pumpAndSettle();

    await tester.tap(dayCell(_oct21));
    await tester.pumpAndSettle();
    expect(_key('day-device-events-title'), findsNothing);
  });

  testWidgets('the agenda shows the appointments next to the notes', (
    tester,
  ) async {
    final app = await open(tester);
    app.container.read(routerProvider).go(AppRoutes.agenda);
    await tester.pumpAndSettle();

    expect(find.text('Dentista'), findsOneWidget);
    expect(find.text('09:00–10:00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('layout with appointments', () {
    for (final (size, scale, brightness) in [
      (const Size(390, 844), 1.0, Brightness.light),
      (const Size(390, 844), 2.0, Brightness.dark),
      (const Size(320, 568), 1.0, Brightness.dark),
      (const Size(320, 568), 2.0, Brightness.light),
    ]) {
      testWidgets(
        'the mark, the detail and the agenda fit at ${size.width.toInt()}x'
        '${size.height.toInt()}, text $scale, ${brightness.name}',
        (tester) async {
          final app = await open(
            tester,
            size: size,
            brightness: brightness,
            textScale: scale,
          );

          // The mark of the month, inside its cell and without overflows.
          await reveal(tester, _key('device-event-mark-2026-10-20'));
          expect(_key('device-event-mark-2026-10-20'), findsOneWidget);
          expect(tester.takeException(), isNull);

          // The detail of the day lists the appointment, without overflows.
          await tester.tap(dayCell(_oct20));
          await tester.pumpAndSettle();
          expect(_key('day-device-events-title'), findsOneWidget);
          expect(find.text('Dentista'), findsOneWidget);
          expect(tester.takeException(), isNull);

          // The agenda shows it next to the notes, without overflows.
          app.container.read(routerProvider).go(AppRoutes.agenda);
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.text('Dentista'),
            200,
            scrollable: find.byType(Scrollable).last,
          );
          expect(find.text('Dentista'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  });
}
