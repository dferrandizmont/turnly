import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:cuadrante/core/theme/app_typography.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:cuadrante/features/settings/application/preferences_controller.dart';
import 'package:cuadrante/features/settings/data/preferences_repository.dart';
import 'package:cuadrante/features/settings/domain/preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/real_font.dart';

/// Ajustes › Apariencia › Formato de hora y Moneda (docs/formatos.md).
void main() {
  setUpAll(() async {
    await initializeLocale();
    // The month cell's time needs the room of a real font to fit.
    expect(await loadRoboto(), isTrue, reason: 'Roboto from the Flutter SDK');
  });
  tearDownAll(() => AppTypography.debugFamily = null);

  const tall = Size(390, 2600);

  Future<Preferences> stored(AppUnderTest app) =>
      app.real(() => PreferencesRepository(app.database).load());

  Finder rowValue(String key, String text) =>
      find.descendant(of: find.byKey(ValueKey(key)), matching: find.text(text));

  Finder inSheet(Finder what) =>
      find.descendant(of: find.byType(BottomSheet), matching: what);

  group('Formato de hora', () {
    testWidgets('an installation without the preference shows 24 h', (
      tester,
    ) async {
      final app = await AppUnderTest.pump(tester, size: tall);
      await app.openSettings();
      expect(find.text('Formato de hora'), findsOneWidget);
      expect(rowValue('settings-time-format', '24 h (22:00)'), findsOneWidget);
    });

    testWidgets('the three options, the automatic one says what it gives', (
      tester,
    ) async {
      final app = await AppUnderTest.pump(tester, size: tall);
      await app.openSettings();
      await tester.tap(find.byKey(const ValueKey('settings-time-format')));
      await tester.pumpAndSettle();
      expect(inSheet(find.text('Automático (24 h)')), findsOneWidget);
      expect(inSheet(find.text('24 h (22:00)')), findsOneWidget);
      expect(inSheet(find.text('12 h (10:00 p. m.)')), findsOneWidget);
    });

    testWidgets('12 h applies at once, is stored, and the month shows it', (
      tester,
    ) async {
      final app = await AppUnderTest.pump(tester, size: tall);
      // The night shift of the 20th reads "22–06" on the 24 h clock.
      expect(
        find.descendant(
          of: dayCell(const CivilDate(2026, 10, 20)),
          matching: find.text('22–06'),
        ),
        findsOneWidget,
      );
      await app.openSettings();
      await tester.tap(find.byKey(const ValueKey('settings-time-format')));
      await tester.pumpAndSettle();
      await tester.tap(inSheet(find.text('12 h (10:00 p. m.)')));
      await tester.pumpAndSettle();

      expect(
        rowValue('settings-time-format', '12 h (10:00 p. m.)'),
        findsOneWidget,
      );
      expect((await stored(app)).timeFormat, TimeFormatPreference.h12);

      await app.back();
      expect(
        find.descendant(
          of: dayCell(const CivilDate(2026, 10, 20)),
          matching: find.text('10p–6a'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('and back to 24 h', (tester) async {
      final app = await AppUnderTest.pump(
        tester,
        size: tall,
        prepare: (db) =>
            PreferencesRepository(db).setTimeFormat(TimeFormatPreference.h12),
      );
      await app.openSettings();
      expect(
        rowValue('settings-time-format', '12 h (10:00 p. m.)'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('settings-time-format')));
      await tester.pumpAndSettle();
      await tester.tap(inSheet(find.text('24 h (22:00)')));
      await tester.pumpAndSettle();
      expect(rowValue('settings-time-format', '24 h (22:00)'), findsOneWidget);
      expect((await stored(app)).timeFormat, TimeFormatPreference.h24);
    });

    testWidgets('automatic follows the phone: its 24 h switch wins', (
      tester,
    ) async {
      final app = await AppUnderTest.pump(
        tester,
        size: tall,
        prepare: (db) =>
            PreferencesRepository(db).setTimeFormat(TimeFormatPreference.auto),
      );
      await app.openSettings();
      // A Spanish phone in Spain: 24 h.
      expect(
        rowValue('settings-time-format', 'Automático (24 h)'),
        findsOneWidget,
      );
    });
  });

  group('Moneda', () {
    testWidgets('an installation without the preference shows the euro', (
      tester,
    ) async {
      final app = await AppUnderTest.pump(tester, size: tall);
      await app.openSettings();
      expect(rowValue('settings-currency', 'EUR (€)'), findsOneWidget);
    });

    testWidgets('the sheet: the note, the common ones first, a search', (
      tester,
    ) async {
      final app = await AppUnderTest.pump(tester, size: tall);
      await app.openSettings();
      await tester.tap(find.byKey(const ValueKey('settings-currency')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('currency-note')), findsOneWidget);
      expect(find.byKey(const ValueKey('currency-search')), findsOneWidget);
      expect(inSheet(find.text('HABITUALES')), findsOneWidget);
      expect(find.byKey(const ValueKey('currency-option-EUR')), findsOneWidget);
      expect(find.byKey(const ValueKey('currency-option-USD')), findsOneWidget);
    });

    testWidgets('searching by code or symbol; nothing found says so', (
      tester,
    ) async {
      final app = await AppUnderTest.pump(tester, size: tall);
      await app.openSettings();
      await tester.tap(find.byKey(const ValueKey('settings-currency')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('currency-search')),
        'jp',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('currency-option-JPY')), findsOneWidget);
      expect(find.byKey(const ValueKey('currency-option-EUR')), findsNothing);
      // A search is one list, without headings.
      expect(inSheet(find.text('HABITUALES')), findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey('currency-search')),
        '£',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('currency-option-GBP')), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('currency-search')),
        'qqq',
      );
      await tester.pumpAndSettle();
      expect(find.text('Ninguna moneda coincide'), findsOneWidget);
    });

    testWidgets('a currency applies at once and is stored', (tester) async {
      final app = await AppUnderTest.pump(tester, size: tall);
      await app.openSettings();
      await tester.tap(find.byKey(const ValueKey('settings-currency')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('currency-option-USD')));
      await tester.pumpAndSettle();
      expect(rowValue('settings-currency', r'USD ($)'), findsOneWidget);
      expect((await stored(app)).currency, 'USD');
      expect(find.byType(BottomSheet), findsNothing);
    });

    testWidgets('a stored currency that is not on the list stays on it', (
      tester,
    ) async {
      final app = await AppUnderTest.pump(
        tester,
        size: tall,
        prepare: (db) => PreferencesRepository(db).setCurrency('XYZ'),
      );
      await app.openSettings();
      expect(rowValue('settings-currency', 'XYZ'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('settings-currency')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('currency-option-XYZ')), findsOneWidget);
    });
  });

  testWidgets('the controller is the one the screen writes to', (tester) async {
    final app = await AppUnderTest.pump(tester, size: tall);
    final container = app.container;
    await app.real(
      () => container.read(preferencesProvider.notifier).setCurrency('GBP'),
    );
    await app.openSettings();
    expect(rowValue('settings-currency', 'GBP (£)'), findsOneWidget);
  });
}
