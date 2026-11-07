import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:cuadrante/core/database/app_database.dart';
import 'package:cuadrante/features/alarms/data/alarm_settings_repository.dart';
import 'package:cuadrante/features/alarms/domain/alarm_settings.dart';
import 'package:cuadrante/features/shift_types/domain/shift_type_draft.dart';
import 'package:cuadrante/features/shift_types/presentation/shift_type_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';

// The «Aviso de pausa» section of the shift type editor (docs/alarmas.md).
// The choice is stored with the alarm settings, not in the shift type row.

Finder _key(String key) => find.byKey(ValueKey(key));

Finder _switch(String key) =>
    find.descendant(of: _key(key), matching: find.byType(Switch));

void main() {
  setUpAll(initializeLocale);

  Future<AppUnderTest> pump(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    Brightness brightness = Brightness.light,
    Future<void> Function(AppDatabase database)? prepare,
  }) => AppUnderTest.pump(
    tester,
    size: size,
    platformBrightness: brightness,
    prepare: prepare,
  );

  Future<void> openShifts(WidgetTester tester, String id) async {
    await tester.ensureVisible(_key('settings-shifts'));
    await tester.pumpAndSettle();
    await tester.tap(_key('settings-shifts'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      _key('shift-row-$id'),
      200,
      scrollable: find.descendant(
        of: _key('shift-list'),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(_key('shift-row-$id'));
    await tester.pumpAndSettle();
    expect(find.byType(ShiftTypeFormScreen), findsOneWidget);
  }

  Future<void> reveal(WidgetTester tester, String key) async {
    await tester.ensureVisible(_key(key));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String key) async {
    await reveal(tester, key);
    await tester.tap(_key(key));
    await tester.pumpAndSettle();
  }

  Future<AlarmSettings> stored(AppUnderTest app) =>
      app.real(() => AlarmSettingsRepository(app.database).load());

  testWidgets('a long shift suggests it, the switch is off and stores on '
      'save', (tester) async {
    final app = await pump(tester);
    await app.openSettings();
    await openShifts(tester, 'night');
    await reveal(tester, 'shift-pause');

    expect(find.text('AVISO DE PAUSA'), findsOneWidget);
    expect(find.text('Avisarme para hacer una pausa'), findsOneWidget);
    expect(
      find.text('Este turno dura 8 h: suele venir bien parar un rato a mitad.'),
      findsOneWidget,
    );
    expect(tester.widget<Switch>(_switch('shift-pause')).value, isFalse);
    expect(_key('shift-pause-when'), findsNothing);

    await tap(tester, 'shift-pause');
    expect(tester.widget<Switch>(_switch('shift-pause')).value, isTrue);
    expect(find.text('A mitad del turno'), findsOneWidget);
    // Not stored until «Guardar».
    expect((await stored(app)).forShiftType('night').pause.enabled, isFalse);

    await tap(tester, 'shift-save');
    final pause = (await stored(app)).forShiftType('night').pause;
    expect(pause.enabled, isTrue);
    expect(pause.timing, PauseTiming.midShift);
  });

  testWidgets('"some time after it starts" from the list', (tester) async {
    final app = await pump(tester);
    await app.openSettings();
    await openShifts(tester, 'night');
    await tap(tester, 'shift-pause');
    await tap(tester, 'shift-pause-when');

    expect(find.text('Cuándo te avisamos'), findsOneWidget);
    await tester.tap(find.text('3 h después de empezar'));
    await tester.pumpAndSettle();
    expect(find.text('3 h después de empezar'), findsOneWidget);

    await tap(tester, 'shift-save');
    final pause = (await stored(app)).forShiftType('night').pause;
    expect(pause.enabled, isTrue);
    expect(pause.timing, PauseTiming.afterStart);
    expect(pause.afterMinutes, 180);
  });

  testWidgets('a time that does not fit inside the shift is said', (
    tester,
  ) async {
    final app = await pump(
      tester,
      prepare: (db) => AlarmSettingsRepository(db).save(
        const AlarmSettings(
          byShiftType: {
            'night': AlarmTypeSettings(
              pause: PauseAlertSettings(
                enabled: true,
                timing: PauseTiming.afterStart,
                afterMinutes: 600,
              ),
            ),
          },
        ),
      ),
    );
    await app.openSettings();
    await openShifts(tester, 'night');
    await reveal(tester, 'shift-pause');
    expect(_key('shift-pause-outside'), findsOneWidget);
    expect(
      find.text('Ese tiempo es mayor que el turno: no sonará.'),
      findsOneWidget,
    );
  });

  testWidgets('it starts on the stored value, says when the alarms are off '
      'and persists turning it off', (tester) async {
    final app = await pump(
      tester,
      prepare: (db) => AlarmSettingsRepository(db).save(
        const AlarmSettings(
          byShiftType: {
            'night': AlarmTypeSettings(
              pause: PauseAlertSettings(
                enabled: true,
                timing: PauseTiming.afterStart,
                afterMinutes: 90,
              ),
            ),
          },
        ),
      ),
    );
    await app.openSettings();
    await openShifts(tester, 'night');
    await reveal(tester, 'shift-pause');
    expect(tester.widget<Switch>(_switch('shift-pause')).value, isTrue);
    expect(find.text('1 h 30 min después de empezar'), findsOneWidget);
    // The global switch of Ajustes › Alarmas is off.
    expect(_key('shift-pause-alarms-off'), findsOneWidget);

    await tap(tester, 'shift-pause');
    expect(_key('shift-pause-when'), findsNothing);
    await tap(tester, 'shift-save');
    final pause = (await stored(app)).forShiftType('night').pause;
    expect(pause.enabled, isFalse);
    expect(pause.afterMinutes, 90, reason: 'the time is kept');
  });

  testWidgets('with the alarms on there is no warning', (tester) async {
    final app = await pump(
      tester,
      prepare: (db) => AlarmSettingsRepository(db).save(
        const AlarmSettings(
          enabled: true,
          byShiftType: {
            'night': AlarmTypeSettings(
              pause: PauseAlertSettings(enabled: true),
            ),
          },
        ),
      ),
    );
    await app.openSettings();
    await openShifts(tester, 'night');
    await reveal(tester, 'shift-pause');
    expect(tester.widget<Switch>(_switch('shift-pause')).value, isTrue);
    expect(_key('shift-pause-alarms-off'), findsNothing);
  });

  testWidgets('editing something else keeps the stored choice and the rest '
      'of the alarm settings', (tester) async {
    final app = await pump(
      tester,
      prepare: (db) => AlarmSettingsRepository(db).save(
        const AlarmSettings(
          enabled: true,
          byShiftType: {
            'night': AlarmTypeSettings(
              enabled: true,
              minutesBefore: 45,
              label: 'A currar',
              pause: PauseAlertSettings(enabled: true),
            ),
          },
        ),
      ),
    );
    await app.openSettings();
    await openShifts(tester, 'night');
    await reveal(tester, 'shift-name');
    await tester.enterText(_key('shift-name'), 'Noche larga');
    await tester.pump();
    await tap(tester, 'shift-save');
    final type = (await stored(app)).forShiftType('night');
    expect(type.pause.enabled, isTrue);
    expect(type.enabled, isTrue);
    expect(type.minutesBefore, 45);
    expect(type.label, 'A currar');
  });

  testWidgets('turning it on keeps what the alarms screen had set', (
    tester,
  ) async {
    final app = await pump(
      tester,
      prepare: (db) => AlarmSettingsRepository(db).save(
        const AlarmSettings(
          enabled: true,
          byShiftType: {
            'night': AlarmTypeSettings(
              enabled: true,
              minutesBefore: 45,
              dayBefore: true,
            ),
          },
        ),
      ),
    );
    await app.openSettings();
    await openShifts(tester, 'night');
    await tap(tester, 'shift-pause');
    await tap(tester, 'shift-save');
    final type = (await stored(app)).forShiftType('night');
    expect(type.pause.enabled, isTrue);
    expect(type.enabled, isTrue);
    expect(type.minutesBefore, 45);
    expect(type.dayBefore, isTrue);
  });

  testWidgets('a shift without times has no section', (tester) async {
    final app = await pump(tester);
    await app.openSettings();
    await openShifts(tester, 'night');
    expect(_key('shift-pause'), findsOneWidget);

    await tap(tester, 'shift-no-times');
    expect(_key('shift-pause'), findsNothing);
    await tap(tester, 'shift-no-times');
    expect(_key('shift-pause'), findsOneWidget);
  });

  testWidgets('layout survives a narrow screen and text x2 in the dark', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    final app = await pump(
      tester,
      size: const Size(320, 568),
      brightness: Brightness.dark,
    );
    await app.openSettings();
    await openShifts(tester, 'night');
    await tap(tester, 'shift-pause');
    await reveal(tester, 'shift-pause-when');
    expect(tester.takeException(), isNull);
    await tap(tester, 'shift-save');
    expect((await stored(app)).forShiftType('night').pause.enabled, isTrue);
  });

  group('ShiftTypeDraft', () {
    test('suggests the pause notice from 8 hours', () {
      expect(
        const ShiftTypeDraft(startMinute: 480, endMinute: 960).suggestsPause,
        isTrue,
      );
      expect(
        const ShiftTypeDraft(startMinute: 480, endMinute: 900).suggestsPause,
        isFalse,
      );
      expect(
        const ShiftTypeDraft(startMinute: 480, endMinute: 480).suggestsPause,
        isTrue,
        reason: '24 h',
      );
    });

    test('the pause belongs to equality, so leaving with it changed asks '
        'first', () {
      const draft = ShiftTypeDraft();
      final on = draft.copyWith(pause: const PauseAlertSettings(enabled: true));
      expect(on, isNot(draft));
      expect(on.copyWith(pause: PauseAlertSettings.off), draft);
      expect(on.hashCode, isNot(draft.hashCode));
    });

    test('the pause segment is the longest one of a split shift', () {
      final split = const ShiftTypeDraft(
        startMinute: 8 * 60,
        endMinute: 11 * 60,
      ).copyWith(segment2StartMinute: 15 * 60, segment2DurationMinutes: 300);
      expect(split.pauseSegmentMinutes, 300);
      expect(
        split
            .copyWith(
              pause: const PauseAlertSettings(
                enabled: true,
                timing: PauseTiming.afterStart,
                afterMinutes: 300,
              ),
            )
            .pauseOutsideShift,
        isTrue,
      );
      expect(
        split
            .copyWith(
              pause: const PauseAlertSettings(
                enabled: true,
                timing: PauseTiming.afterStart,
                afterMinutes: 299,
              ),
            )
            .pauseOutsideShift,
        isFalse,
      );
    });

    test('halfway never "does not fit"', () {
      expect(
        const ShiftTypeDraft(pause: PauseAlertSettings(enabled: true))
            .pauseOutsideShift,
        isFalse,
      );
    });
  });
}
