import 'dart:io';

import 'package:cuadrante/core/bootstrap/bootstrap.dart' show initializeLocale;
import 'package:cuadrante/features/calendar_export/application/ics_export.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/fake_device_calendar.dart';
import '../import/import_ui_support.dart';

/// Lets real I/O and frames take turns until [done] (or about a second).
Future<void> settle(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 50 && !done(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(initializeLocale);

  testWidgets(
    '«Guardar archivo .ics» shares a calendar file, then removes it',
    (tester) async {
      final temp = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('ics-export-test'),
      ))!;
      addTearDown(() => tester.runAsync(() => temp.delete(recursive: true)));
      final sent = <({String name, String text})>[];
      final phone = FakeDeviceCalendar();
      final app = await AppUnderTest.pump(
        tester,
        size: importTestSize,
        overrides: [
          ...importOverrides(phone: phone, picker: FakePicker()),
          icsTimeZoneProvider.overrideWithValue(
            () async => icsLocation('Europe/Madrid'),
          ),
          icsExportDirectoryProvider.overrideWithValue(() async => temp),
          icsFileSenderProvider.overrideWithValue((file) async {
            sent.add((
              name: file.uri.pathSegments.last,
              text: await file.readAsString(),
            ));
          }),
        ],
      );
      await app.openSettings();
      await tester.ensureVisible(byKey('settings-export-calendar'));
      await tester.pumpAndSettle();
      await tester.tap(byKey('settings-export-calendar'));
      await tester.pumpAndSettle();

      // Visible without the calendar permission.
      expect(byKey('ics-file-card'), findsOneWidget);
      expect(find.text('Del 19 oct 2026 al 18 ene 2027'), findsOneWidget);
      expect(phone.requests, 0);

      await tester.ensureVisible(byKey('ics-file-button'));
      await tester.tap(byKey('ics-file-button'));
      // File work needs real time between frames.
      await settle(tester, () => sent.isNotEmpty && temp.listSync().isEmpty);

      final file = sent.single;
      expect(file.name, 'turnly-2026-10-19_2027-01-18.ics');
      expect(file.text, startsWith('BEGIN:VCALENDAR\r\n'));
      expect(file.text, contains('X-WR-CALNAME:Mi cuadrante'));
      expect(file.text, contains('BEGIN:VEVENT'));
      expect(file.text, contains('DTSTART:'));
      expect(file.text.trimRight(), endsWith('END:VCALENDAR'));
      expect(byKey('ics-file-failed'), findsNothing);
      final left = (await tester.runAsync(() => temp.list().toList()))!;
      expect(left, isEmpty, reason: 'the file is deleted after sharing');
    },
  );

  testWidgets('a failure says so', (tester) async {
    final phone = FakeDeviceCalendar();
    final app = await AppUnderTest.pump(
      tester,
      size: importTestSize,
      overrides: [
        ...importOverrides(phone: phone, picker: FakePicker()),
        icsTimeZoneProvider.overrideWithValue(
          () async => icsLocation('Europe/Madrid'),
        ),
        icsExportDirectoryProvider.overrideWithValue(
          () async => throw const FileSystemException('no space'),
        ),
      ],
    );
    await app.openSettings();
    await tester.ensureVisible(byKey('settings-export-calendar'));
    await tester.pumpAndSettle();
    await tester.tap(byKey('settings-export-calendar'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(byKey('ics-file-button'));
    await tester.tap(byKey('ics-file-button'));
    await settle(tester, () => byKey('ics-file-failed').evaluate().isNotEmpty);
    expect(byKey('ics-file-failed'), findsOneWidget);
    expect(
      find.text('No se ha podido crear el archivo. Prueba otra vez.'),
      findsOneWidget,
    );
  });
}
