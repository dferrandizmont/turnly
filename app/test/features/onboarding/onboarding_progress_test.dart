import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'onboarding_support.dart';

/// H-T01-9: «¿Cómo es tu rotación?» and «¿Cuándo empiezas?» both said
/// «Paso 3 de 5», so pressing «Siguiente» looked like nothing had happened.
/// Each way to start counts its own screens (2A): the first question and
/// «Listo» carry no number.
void main() {
  setUpAll(initializeLocale);

  String progress(WidgetTester tester) {
    final semantics = tester.getSemantics(key('onboarding-dots'));
    return semantics.label;
  }

  int dashes(WidgetTester tester) => find
      .descendant(
        of: key('onboarding-dots'),
        matching: find.byType(AnimatedContainer),
      )
      .evaluate()
      .length;

  bool dots() => key('onboarding-dots').evaluate().isNotEmpty;

  testWidgets('every screen of a way has its own «Paso N de M»', (
    tester,
  ) async {
    final app = await FirstLaunch.open(tester);
    expect(dots(), isFalse, reason: 'the first question has no number');
    final seen = <String, String>{};

    Future<void> record() async => seen[app.title] = progress(tester);

    // With a rotation the place comes first (its country sets the week the
    // preview is drawn with).
    await app.choosePath('rotation');
    await record(); // ¿Dónde trabajas?
    expect(dashes(tester), 3);
    expect(find.text('Paso 1 de 3 · Opcional'), findsOneWidget);
    await app.tap(key('onboarding-next'));
    await record(); // ¿Cómo es tu rotación?
    await app.tap(key('onboarding-pattern-12h'));
    await app.tap(key('onboarding-next'));
    await record(); // ¿Cuándo empiezas?

    expect(seen.keys, [
      '¿Dónde trabajas?',
      '¿Cómo es tu rotación?',
      '¿Cuándo empiezas?',
    ]);
    expect(seen.values, ['Paso 1 de 3', 'Paso 2 de 3', 'Paso 3 de 3']);

    // The start step is now the last one: it writes and lands on «Listo».
    await app.tap(key('onboarding-next'));
    expect(app.title, 'Listo');
    expect(dots(), isFalse, reason: '«Listo» has no number');
  });

  testWidgets('importing: two screens', (tester) async {
    final app = await FirstLaunch.open(tester);
    await app.choosePath('import');
    expect(progress(tester), 'Paso 1 de 2');
    expect(dashes(tester), 2);
    await app.tap(key('onboarding-next'));
    expect(progress(tester), 'Paso 2 de 2');
    expect(find.text('Paso 2 de 2 · Opcional'), findsOneWidget);
  });

  testWidgets('by hand: the last step alone', (tester) async {
    final app = await FirstLaunch.open(tester);
    await app.choosePath('paint');
    expect(progress(tester), 'Paso 1 de 1');
    expect(dashes(tester), 1);
  });
}
