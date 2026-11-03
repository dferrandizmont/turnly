import 'package:cuadrante/core/widgets/empty_illustration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import 'backup_ui_support.dart';

/// B9: the backup as a task. «Guardar una copia fuera de Turnly» is the main
/// action, the copy on the phone comes second, the last copy says it was
/// checked, and with no copy yet the card shows the drawing of design 8.1B.
Finder _key(String key) => find.byKey(ValueKey(key));

void main() {
  testWidgets('the copy outside the phone is the main action, above the copy '
      'on the phone', (tester) async {
    final h = BackupUiHarness(tester);
    await h.open();
    final export = _key('backup-export');
    expect(
      find.descendant(
        of: export,
        matching: find.text('Guardar una copia fuera de Turnly'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: export, matching: find.byType(FilledButton)),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: _key('backup-now'),
        matching: find.byType(OutlinedButton),
      ),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(export).dy,
      lessThan(tester.getTopLeft(_key('backup-now')).dy),
    );
    expect(_key('backup-export-help'), findsOneWidget);

    // It still hands the file to the share sheet.
    await tapIo(tester, export);
    expect(h.shared, hasLength(1));
  });

  testWidgets('no copy yet: the drawing, then the last copy, checked', (
    tester,
  ) async {
    final h = BackupUiHarness(tester);
    await h.open();
    expect(find.byType(EmptyIllustration), findsOneWidget);
    expect(
      find.byKey(const ValueKey('empty-illustration-backup')),
      findsOneWidget,
    );
    expect(_key('backup-status-verified'), findsNothing);

    await tapIo(
      tester,
      _key('backup-now'),
      until: find.text('Hoy a las 12:00'),
    );
    expect(find.byType(EmptyIllustration), findsNothing);
    expect(
      tester.widget<Text>(_key('backup-status-verified')).data,
      'Comprobada: se puede recuperar entera',
    );
  });

  testWidgets('while the copy is being made, the button says so', (
    tester,
  ) async {
    final h = BackupUiHarness(tester);
    await h.open();
    await tester.ensureVisible(_key('backup-now'));
    await tester.pump();
    await tester.tap(_key('backup-now'));
    await tester.pump();
    expect(
      find.descendant(
        of: _key('backup-now'),
        matching: find.text('Guardando la copia…'),
      ),
      findsOneWidget,
    );
    await pumpIo(tester, until: find.text('Hoy a las 12:00'));
    expect(
      find.descendant(
        of: _key('backup-now'),
        matching: find.text('Hacer copia ahora'),
      ),
      findsOneWidget,
    );
  });

  for (final brightness in Brightness.values) {
    testWidgets('fits 320 dp at x2 in ${brightness.name}', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      final h = BackupUiHarness(tester);
      final app = await AppUnderTest.pump(
        tester,
        size: const Size(320, 568),
        platformBrightness: brightness,
        overrides: h.overrides,
      );
      await app.openSettings();
      await tester.scrollUntilVisible(
        _key('settings-backup'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(_key('settings-backup'));
      await pumpIo(tester, until: _key('backup-status'));
      expect(tester.takeException(), isNull);
      for (final key in ['backup-export', 'backup-now', 'backup-import']) {
        await tester.ensureVisible(_key(key));
        await tester.pump();
        expect(tester.takeException(), isNull, reason: key);
      }
    });
  }
}
