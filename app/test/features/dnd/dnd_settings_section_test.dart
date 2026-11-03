import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:cuadrante/core/database/app_database.dart';
import 'package:cuadrante/features/alarms/application/alarm_providers.dart';
import 'package:cuadrante/features/alarms/data/alarm_scheduler.dart';
import 'package:cuadrante/features/alarms/presentation/alarms_settings_screen.dart';
import 'package:cuadrante/features/dnd/application/dnd_providers.dart';
import 'package:cuadrante/features/dnd/data/dnd_channel.dart';
import 'package:cuadrante/features/dnd/data/dnd_settings_repository.dart';
import 'package:cuadrante/features/dnd/domain/dnd_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';

// Ajustes › Alarmas: the «No molestar durante el turno» section (P13). The
// platform channel is faked with FakeDndChannel; the alarm scheduler with
// FakeAlarmScheduler (the alarms screen needs one).

Finder _key(String key) => find.byKey(ValueKey(key));

void main() {
  setUpAll(initializeLocale);

  const tall = Size(390, 1800);
  late FakeAlarmScheduler scheduler;
  late FakeDndChannel dnd;

  setUp(() {
    scheduler = FakeAlarmScheduler();
    dnd = FakeDndChannel();
  });

  Future<AppUnderTest> openAlarms(
    WidgetTester tester, {
    Future<void> Function(AppDatabase database)? prepare,
  }) async {
    final app = await AppUnderTest.pump(
      tester,
      size: tall,
      overrides: [
        alarmSchedulerProvider.overrideWithValue(scheduler),
        dndChannelProvider.overrideWithValue(dnd),
      ],
      prepare: prepare,
    );
    await app.openSettings();
    await tester.ensureVisible(_key('settings-alarms'));
    await tester.pumpAndSettle();
    await tester.tap(_key('settings-alarms'));
    await tester.pumpAndSettle();
    expect(find.byType(AlarmsSettingsScreen), findsOneWidget);
    return app;
  }

  Future<DndSettings> stored(AppUnderTest app) =>
      app.real(() => DndSettingsRepository(app.database).load());

  Future<void> tapAndSettle(WidgetTester tester, String key) async {
    await tester.ensureVisible(_key(key));
    await tester.pumpAndSettle();
    await tester.tap(_key(key));
    await tester.pumpAndSettle();
  }

  testWidgets('the global switch silences during shifts, with the filter and '
      'the permission state', (tester) async {
    final app = await openAlarms(tester);
    // Off: only the master switch, nothing else.
    expect(find.text('NO MOLESTAR DURANTE EL TURNO'), findsOneWidget);
    expect(tester.widget<Switch>(_key('dnd-master-switch')).value, isFalse);
    expect(_key('dnd-filter'), findsNothing);
    expect(_key('dnd-permission-ok'), findsNothing);
    expect(_key('dnd-permission-denied'), findsNothing);

    await tapAndSettle(tester, 'dnd-master-switch');
    expect((await stored(app)).enabled, isTrue);
    // The filter row appears, with the default, and the permission is granted.
    expect(
      find.descendant(
        of: _key('dnd-filter'),
        matching: find.text('Solo lo prioritario'),
      ),
      findsOneWidget,
    );
    expect(_key('dnd-permission-ok'), findsOneWidget);
    expect(find.text('Todo listo'), findsOneWidget);
  });

  testWidgets('the interruption filter can be changed and is stored', (
    tester,
  ) async {
    final app = await openAlarms(tester);
    await tapAndSettle(tester, 'dnd-master-switch');
    await tapAndSettle(tester, 'dnd-filter');

    final sheet = find.byType(BottomSheet);
    for (final label in [
      'Solo lo prioritario',
      'Solo las alarmas',
      'Silencio total',
    ]) {
      expect(
        find.descendant(of: sheet, matching: find.text(label)),
        findsOneWidget,
        reason: label,
      );
    }
    await tester.tap(
      find.descendant(of: sheet, matching: find.text('Solo las alarmas')),
    );
    await tester.pumpAndSettle();

    expect((await stored(app)).filter, DndFilter.alarms);
    expect(
      find.descendant(
        of: _key('dnd-filter'),
        matching: find.text('Solo las alarmas'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a stored filter of «Todo» is offered in the list', (
    tester,
  ) async {
    await openAlarms(
      tester,
      prepare: (db) => DndSettingsRepository(db).save(
        const DndSettings(enabled: true, filter: DndFilter.all),
      ),
    );
    await tapAndSettle(tester, 'dnd-filter');
    final sheet = find.byType(BottomSheet);
    expect(
      find.descendant(of: sheet, matching: find.text('Todo')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('Silencio total')),
      findsOneWidget,
    );
  });

  testWidgets('the stored values are shown when the screen opens', (
    tester,
  ) async {
    await openAlarms(
      tester,
      prepare: (db) => DndSettingsRepository(db).save(
        const DndSettings(
          enabled: true,
          filter: DndFilter.alarms,
          byShiftType: {'night': DndTypeSettings(enabled: true)},
        ),
      ),
    );
    expect(tester.widget<Switch>(_key('dnd-master-switch')).value, isTrue);
    expect(
      find.descendant(
        of: _key('dnd-filter'),
        matching: find.text('Solo las alarmas'),
      ),
      findsOneWidget,
    );
    expect(_key('dnd-permission-ok'), findsOneWidget);
  });

  testWidgets('without the permission it explains and opens the system '
      'screen, and re-reads the state on resume', (tester) async {
    dnd.permission = DndPermission.denied;
    await openAlarms(tester);
    await tapAndSettle(tester, 'dnd-master-switch');

    expect(_key('dnd-permission-denied'), findsOneWidget);
    expect(_key('dnd-permission-ok'), findsNothing);
    expect(find.text('Falta el acceso a No molestar'), findsOneWidget);
    expect(
      find.textContaining('permite que Turnly acceda a «No molestar»'),
      findsOneWidget,
    );

    await tapAndSettle(tester, 'dnd-permission-open');
    expect(dnd.openedSettings, 1);

    // Back from «Acceso a No molestar» with it granted.
    dnd.permission = DndPermission.granted;
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pumpAndSettle();
    expect(_key('dnd-permission-ok'), findsOneWidget);
    expect(_key('dnd-permission-denied'), findsNothing);
  });

  testWidgets('a platform without silence windows hides the whole section', (
    tester,
  ) async {
    dnd.supported = false;
    await openAlarms(tester);
    expect(_key('dnd-master'), findsNothing);
    expect(_key('dnd-master-switch'), findsNothing);
    expect(find.text('NO MOLESTAR DURANTE EL TURNO'), findsNothing);
  });

  testWidgets('layout survives a narrow screen and text x2 in the dark', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    final app = await AppUnderTest.pump(
      tester,
      size: const Size(320, 900),
      platformBrightness: Brightness.dark,
      overrides: [
        alarmSchedulerProvider.overrideWithValue(scheduler),
        dndChannelProvider.overrideWithValue(dnd),
      ],
    );
    await app.openSettings();
    await tester.ensureVisible(_key('settings-alarms'));
    await tester.pumpAndSettle();
    await tester.tap(_key('settings-alarms'));
    await tester.pumpAndSettle();
    await tapAndSettle(tester, 'dnd-master-switch');
    await tester.ensureVisible(_key('dnd-permission-ok'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
