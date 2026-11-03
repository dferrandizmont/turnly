import 'package:cuadrante/features/absences/presentation/absences_screen.dart';
import 'package:cuadrante/features/settings/application/preferences_controller.dart';
import 'package:cuadrante/features/settings/data/preferences_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';

// P3 and P9 in Ajustes: the row of vacation and leave and «Horas y dinero ›
// Retención (%)».
void main() {
  Finder key(String k) => find.byKey(ValueKey(k));

  Future<void> tapKey(WidgetTester tester, String k) async {
    await tester.ensureVisible(key(k));
    await tester.pumpAndSettle();
    await tester.tap(key(k));
    await tester.pumpAndSettle();
  }

  for (final (size, scale) in [
    (const Size(390, 2600), 1.0),
    (const Size(320, 2600), 2.0),
  ]) {
    testWidgets('the rows open the screen and store the withholding at '
        '${size.width.toInt()} dp, text $scale', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      final app = await AppUnderTest.pump(tester, size: size);
      await app.openSettings();

      expect(find.text('HORAS Y DINERO'), findsOneWidget);
      expect(find.text('Sin retención'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tapKey(tester, 'settings-withholding');
      await tester.enterText(key('withholding-field'), '21');
      await tapKey(tester, 'withholding-save');
      expect(find.text('21 %'), findsOneWidget);
      final stored = await app.real(
        () => PreferencesRepository(app.database).load(),
      );
      expect(stored.withholdingPercent, 21);
      expect(app.container.read(preferencesProvider).withholdingPercent, 21);

      // Empty again means none.
      await tapKey(tester, 'settings-withholding');
      await tester.enterText(key('withholding-field'), '');
      await tapKey(tester, 'withholding-save');
      expect(find.text('Sin retención'), findsOneWidget);

      await tapKey(tester, 'settings-absences');
      expect(find.byType(AbsencesScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
