import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:cuadrante/core/format/app_date_format.dart';
import 'package:cuadrante/core/theme/app_theme.dart';
import 'package:cuadrante/features/device_events/domain/device_event_day.dart';
import 'package:cuadrante/features/device_events/presentation/device_event_row.dart';
import 'package:cuadrante/features/device_events/presentation/device_events_format.dart';
import 'package:cuadrante/features/schedule/domain/civil_date.dart';
import 'package:cuadrante/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _day = CivilDate(2026, 10, 20);

DeviceDayEvent _event({
  String instanceId = 'ev-1',
  String title = 'Dentista',
  bool allDay = false,
  String calendarName = 'Trabajo',
  int? colorValue,
  DateTime? start,
  DateTime? end,
}) => DeviceDayEvent(
  instanceId: instanceId,
  calendarId: 'cal-1',
  calendarName: calendarName,
  title: title,
  allDay: allDay,
  start: start ?? DateTime(2026, 10, 20, 9),
  end: end ?? DateTime(2026, 10, 20, 10),
  colorValue: colorValue,
);

Widget _app(Widget child, {Brightness brightness = Brightness.light}) =>
    MaterialApp(
      theme: brightness == Brightness.light
          ? AppTheme.light()
          : AppTheme.dark(),
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

void main() {
  setUpAll(initializeLocale);

  group('the texts of an appointment', () {
    late AppLocalizations l10n;

    setUpAll(() async {
      l10n = await AppLocalizations.delegate.load(const Locale('es'));
    });

    test('a timed one shows its range of hours', () {
      final format = AppDateFormat('es');
      expect(
        deviceEventTimeText(l10n, format, _event()),
        '09:00–10:00',
      );
      expect(
        deviceEventTimeText(
          l10n,
          format,
          _event(start: DateTime(2026, 10, 20, 22), end: DateTime(2026, 10, 21, 6)),
        ),
        '22:00–06:00',
      );
    });

    test('one that lasts the whole day has no hours to show', () {
      expect(
        deviceEventTimeText(l10n, AppDateFormat('es'), _event(allDay: true)),
        'Todo el día',
      );
    });

    test('the count of appointments is said in singular and plural', () {
      expect(deviceEventCountText(l10n, 0), '0 citas');
      expect(deviceEventCountText(l10n, 1), '1 cita');
      expect(deviceEventCountText(l10n, 3), '3 citas');
    });

    test('the label says the time, the title and the calendar', () {
      final format = AppDateFormat('es');
      expect(
        deviceEventSemantics(l10n, format, _event()),
        '09:00–10:00, Dentista, Trabajo',
      );
      // A calendar with no name is not said out loud.
      expect(
        deviceEventSemantics(l10n, format, _event(calendarName: '  ')),
        '09:00–10:00, Dentista',
      );
    });
  });

  group('the row of an appointment', () {
    testWidgets('shows the title, the hours and the calendar', (tester) async {
      await tester.pumpWidget(_app(DeviceEventRow(event: _event())));
      expect(find.text('Dentista'), findsOneWidget);
      expect(find.text('09:00–10:00'), findsOneWidget);
      expect(find.text(' · Trabajo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('says it all out loud, so the colour is never alone', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(DeviceEventRow(event: _event())));
      expect(find.bySemanticsLabel('09:00–10:00, Dentista, Trabajo'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('the whole-day one says so instead of an hour', (tester) async {
      await tester.pumpWidget(
        _app(DeviceEventRow(event: _event(allDay: true, title: 'Vacaciones'))),
      );
      expect(find.text('Todo el día'), findsOneWidget);
      expect(find.text('09:00–10:00'), findsNothing);
      expect(find.text('Vacaciones'), findsOneWidget);
    });

  });

  group('layout', () {
    for (final (size, scale, brightness) in [
      (const Size(390, 844), 1.0, Brightness.light),
      (const Size(390, 844), 2.0, Brightness.dark),
      (const Size(320, 568), 1.0, Brightness.dark),
      (const Size(320, 568), 2.0, Brightness.light),
    ]) {
      testWidgets(
        'the row and the list fit at ${size.width.toInt()}x'
        '${size.height.toInt()}, text $scale, ${brightness.name}',
        (tester) async {
          tester.view.physicalSize = size * 3;
          tester.view.devicePixelRatio = 3;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
            tester.platformDispatcher.clearAllTestValues();
          });
          final day = DeviceEventDay(
            date: _day,
            allDay: [
              _event(instanceId: 'ev-allday', title: 'Vacaciones', allDay: true),
            ],
            timed: [
              _event(
                instanceId: 'ev-2',
                title: 'Cena',
                start: DateTime(2026, 10, 20, 21),
                end: DateTime(2026, 10, 20, 22),
              ),
              _event(instanceId: 'ev-1', title: 'Dentista'),
            ],
          );
          await tester.pumpWidget(
            _app(DeviceEventList(day: day), brightness: brightness),
          );
          expect(tester.takeException(), isNull);
          expect(find.text('Dentista'), findsOneWidget);
          expect(find.text('Todo el día'), findsOneWidget);
        },
      );
    }
  });

  group('the list of a day', () {
    testWidgets('shows the all-day ones first and the timed ones in order', (
      tester,
    ) async {
      final day = DeviceEventDay(
        date: _day,
        allDay: [_event(instanceId: 'ev-3', title: 'Conferencia', allDay: true)],
        timed: [
          _event(instanceId: 'ev-2', title: 'Cena', start: DateTime(2026, 10, 20, 21), end: DateTime(2026, 10, 20, 22)),
          _event(instanceId: 'ev-1', title: 'Dentista'),
        ],
      );
      await tester.pumpWidget(_app(DeviceEventList(day: day)));
      final titles = [
        for (final row in tester.widgetList<DeviceEventRow>(
          find.byType(DeviceEventRow),
        ))
          row.event.title,
      ];
      expect(titles, ['Conferencia', 'Cena', 'Dentista']);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an empty day shows nothing at all', (tester) async {
      await tester.pumpWidget(
        _app(DeviceEventList(day: DeviceEventDay.empty(_day))),
      );
      expect(find.byType(DeviceEventRow), findsNothing);
    });
  });
}
