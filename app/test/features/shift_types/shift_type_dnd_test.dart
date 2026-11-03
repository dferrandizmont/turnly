import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:cuadrante/core/database/app_database.dart';
import 'package:cuadrante/features/dnd/application/dnd_providers.dart';
import 'package:cuadrante/features/dnd/data/dnd_channel.dart';
import 'package:cuadrante/features/dnd/data/dnd_settings_repository.dart';
import 'package:cuadrante/features/dnd/domain/dnd_settings.dart';
import 'package:cuadrante/features/shift_types/presentation/shift_type_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';

// The «Activar No molestar durante este turno» switch of the shift type editor
// (P13, Android only). The choice is stored with the silence settings, not in
// the shift type row.

Finder _key(String key) => find.byKey(ValueKey(key));

Finder _switch(String key) =>
    find.descendant(of: _key(key), matching: find.byType(Switch));

void main() {
  setUpAll(initializeLocale);

  late FakeDndChannel dnd;

  setUp(() => dnd = FakeDndChannel());

  Future<AppUnderTest> pump(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    Brightness brightness = Brightness.light,
    Future<void> Function(AppDatabase database)? prepare,
  }) => AppUnderTest.pump(
    tester,
    size: size,
    platformBrightness: brightness,
    overrides: [dndChannelProvider.overrideWithValue(dnd)],
    prepare: prepare,
  );

  Future<void> openShifts(WidgetTester tester, String id) async {
    await tester.ensureVisible(_key('settings-shifts'));
    await tester.pumpAndSettle();
    await tester.tap(_key('settings-shifts'));
    await tester.pumpAndSettle();
    // The list builds its rows lazily.
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

  Future<DndSettings> stored(AppUnderTest app) =>
      app.real(() => DndSettingsRepository(app.database).load());

  testWidgets('a working shift with times has the switch, and it is stored on '
      'save', (tester) async {
    final app = await pump(tester);
    await app.openSettings();
    await openShifts(tester, 'night');
    await reveal(tester, 'shift-dnd');

    expect(find.text('NO MOLESTAR'), findsOneWidget);
    expect(
      find.text('Activar No molestar durante este turno'),
      findsOneWidget,
    );
    expect(tester.widget<Switch>(_switch('shift-dnd')).value, isFalse);
    expect((await stored(app)).forShiftType('night').enabled, isFalse);

    await tap(tester, 'shift-dnd');
    // Not stored until «Guardar».
    expect((await stored(app)).forShiftType('night').enabled, isFalse);
    await tap(tester, 'shift-save');
    expect((await stored(app)).forShiftType('night').enabled, isTrue);
  });

  testWidgets('it starts on the stored value and persists turning it off', (
    tester,
  ) async {
    final app = await pump(
      tester,
      prepare: (db) => DndSettingsRepository(db).save(
        const DndSettings(
          enabled: true,
          byShiftType: {'night': DndTypeSettings(enabled: true)},
        ),
      ),
    );
    await app.openSettings();
    await openShifts(tester, 'night');
    await reveal(tester, 'shift-dnd');
    expect(tester.widget<Switch>(_switch('shift-dnd')).value, isTrue);

    await tap(tester, 'shift-dnd');
    await tap(tester, 'shift-save');
    expect((await stored(app)).forShiftType('night').enabled, isFalse);
  });

  testWidgets('a day off or a shift without times has no switch', (
    tester,
  ) async {
    final app = await pump(tester);
    await app.openSettings();
    await openShifts(tester, 'night');
    expect(_key('shift-dnd'), findsOneWidget);

    await tap(tester, 'category-rest');
    expect(_key('shift-dnd'), findsNothing);
    await tap(tester, 'category-work');
    expect(_key('shift-dnd'), findsOneWidget);

    await tap(tester, 'shift-no-times');
    expect(_key('shift-dnd'), findsNothing);
  });

  testWidgets('editing something else keeps the stored choice', (tester) async {
    final app = await pump(
      tester,
      prepare: (db) => DndSettingsRepository(db).save(
        const DndSettings(byShiftType: {'night': DndTypeSettings(enabled: true)}),
      ),
    );
    await app.openSettings();
    await openShifts(tester, 'night');
    await reveal(tester, 'shift-name');
    await tester.enterText(_key('shift-name'), 'Noche larga');
    await tester.pump();
    await tap(tester, 'shift-save');
    expect((await stored(app)).forShiftType('night').enabled, isTrue);
  });

  testWidgets('a platform without silence windows has no switch, and a stored '
      'value is kept', (tester) async {
    dnd.supported = false;
    final app = await pump(
      tester,
      prepare: (db) => DndSettingsRepository(db).save(
        const DndSettings(byShiftType: {'night': DndTypeSettings(enabled: true)}),
      ),
    );
    await app.openSettings();
    await openShifts(tester, 'night');
    await reveal(tester, 'shift-save');
    expect(_key('shift-dnd'), findsNothing);
    await tap(tester, 'shift-save');
    expect((await stored(app)).forShiftType('night').enabled, isTrue);
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
    await reveal(tester, 'shift-dnd');
    await tap(tester, 'shift-dnd');
    expect(tester.takeException(), isNull);
    await tap(tester, 'shift-save');
    expect((await stored(app)).forShiftType('night').enabled, isTrue);
  });
}
