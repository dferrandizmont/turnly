import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:cuadrante/core/router.dart';
import 'package:cuadrante/features/alarms/application/alarm_providers.dart';
import 'package:cuadrante/features/alarms/data/alarm_scheduler.dart';
import 'package:cuadrante/features/alarms/data/alarm_settings_repository.dart';
import 'package:cuadrante/features/alarms/domain/alarm_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../backup/backup_ui_support.dart';
import '../calendar/harness.dart';

/// Design 6A (B6): Ajustes in five groups, each row in its group, with the
/// state at the right. No row is lost on the way (the inventory below is
/// every row the screen had before the regrouping).
Finder _key(String key) => find.byKey(ValueKey(key));

/// The rows of each group, top to bottom.
const _groups = {
  'MI CALENDARIO': [
    'settings-shifts',
    'settings-calendars',
    'settings-runs',
    'settings-post-night',
    'settings-import',
  ],
  'AVISOS Y WIDGET': [
    'settings-alarms',
    'settings-widget',
    'settings-export-calendar',
  ],
  'COPIAS Y CAMBIO DE MÓVIL': ['settings-backup'],
  'APARIENCIA': [
    'settings-theme',
    'settings-language',
    'settings-time-format',
    'settings-week-start',
    'settings-week-numbers',
    'settings-currency',
    'settings-holidays',
  ],
  'AYUDA': [
    'settings-faq',
    'settings-help',
    'settings-privacy',
    'settings-about',
  ],
};

/// The row of [key]: the week numbers switch has its key on the switch.
Finder _row(String key) => key == 'settings-week-numbers'
    ? find.ancestor(of: _key(key), matching: find.byType(InkWell)).first
    : _key(key);

void main() {
  setUpAll(initializeLocale);

  testWidgets('every row is in its group, in order, and none is lost', (
    tester,
  ) async {
    final app = await AppUnderTest.pump(tester, size: const Size(390, 3600));
    await app.openSettings();
    final headings = _groups.keys.toList();
    for (var g = 0; g < headings.length; g++) {
      final top = tester.getTopLeft(find.text(headings[g])).dy;
      final bottom = g + 1 < headings.length
          ? tester.getTopLeft(find.text(headings[g + 1])).dy
          : double.infinity;
      var previous = top;
      for (final key in _groups[headings[g]]!) {
        expect(_row(key), findsOneWidget, reason: key);
        final y = tester.getTopLeft(_row(key)).dy;
        expect(y, greaterThan(previous), reason: '$key in ${headings[g]}');
        expect(y, lessThan(bottom), reason: '$key in ${headings[g]}');
        previous = y;
      }
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Mis turnos says how many there are', (tester) async {
    final app = await AppUnderTest.pump(tester, size: const Size(390, 3600));
    await app.openSettings();
    final count = app.schedule.palette.length;
    expect(
      find.descendant(
        of: _key('settings-shifts'),
        matching: find.text('$count'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Alarmas says until when the alerts are scheduled', (
    tester,
  ) async {
    final app = await AppUnderTest.pump(
      tester,
      size: const Size(390, 3600),
      overrides: [
        alarmSchedulerProvider.overrideWithValue(FakeAlarmScheduler()),
      ],
      prepare: (db) => AlarmSettingsRepository(db).save(
        const AlarmSettings(
          enabled: true,
          byShiftType: {'night': AlarmTypeSettings(enabled: true)},
        ),
      ),
    );
    await tester.runAsync(() => app.container.read(alarmSyncProvider).resync());
    await tester.pumpAndSettle();
    await app.openSettings();
    expect(
      find.descendant(
        of: _key('settings-alarms'),
        matching: find.textContaining('Avisos hasta el '),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: _key('settings-alarms'),
        matching: find.text('Activadas'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('without alarms there is no «hasta» line', (tester) async {
    final app = await AppUnderTest.pump(tester, size: const Size(390, 3600));
    await app.openSettings();
    expect(find.textContaining('Avisos hasta el '), findsNothing);
  });

  testWidgets('Copia de seguridad: none yet, then the last one, checked', (
    tester,
  ) async {
    final h = BackupUiHarness(tester);
    final app = await AppUnderTest.pump(
      tester,
      size: const Size(390, 3600),
      overrides: h.overrides,
    );
    await app.openSettings();
    await pumpIo(tester, until: find.text('Todavía no hay ninguna copia'));
    await tester.tap(_key('settings-backup'));
    await pumpIo(tester, until: _key('backup-status'));
    await tapIo(
      tester,
      _key('backup-now'),
      until: find.text('Hoy a las 12:00'),
    );
    await app.back();
    await pumpIo(tester, until: find.textContaining('comprobada'));
    expect(
      find.descendant(
        of: _key('settings-backup'),
        matching: find.text('Última: hoy a las 12:00, comprobada'),
      ),
      findsOneWidget,
    );
  });

  for (final brightness in Brightness.values) {
    testWidgets('fits 320 dp at x2 in ${brightness.name}', (tester) async {
      await pumpCalendar(
        tester,
        size: const Size(320, 568),
        textScale: 2,
        brightness: brightness,
      );
      containerOf(tester).read(routerProvider).go(AppRoutes.settings);
      await tester.pumpAndSettle();
      for (final heading in _groups.keys) {
        await tester.scrollUntilVisible(
          find.text(heading),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        expect(tester.takeException(), isNull, reason: heading);
      }
      await tester.scrollUntilVisible(
        _key('settings-about'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('each group heading is a header for screen readers', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final app = await AppUnderTest.pump(tester, size: const Size(390, 3600));
    await app.openSettings();
    for (final heading in _groups.keys) {
      expect(
        tester.getSemantics(find.text(heading)),
        matchesSemantics(label: heading, isHeader: true),
        reason: heading,
      );
    }
    handle.dispose();
  });
}
