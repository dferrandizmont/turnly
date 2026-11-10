import 'dart:ui' show CheckedState, Tristate;

import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'onboarding_support.dart';

/// T18 (accesibilidad): what TalkBack can read and touch in the first-use
/// flow.
Future<void> _next(FirstLaunch app) => app.tap(key('onboarding-next'));

/// Whether the node that speaks [label] says «seleccionado».
bool _selected(WidgetTester tester, Pattern label) {
  final node = tester.getSemantics(find.bySemanticsLabel(label));
  return node.getSemanticsData().flagsCollection.isSelected == Tristate.isTrue;
}

void main() {
  setUpAll(initializeLocale);

  testWidgets('H-T18-2: the chosen profession and rotation say they are '
      'selected', (tester) async {
    final handle = tester.ensureSemantics();
    final app = await FirstLaunch.open(tester);

    await app.chooseRotation();
    // ChoiceRow announces the choice through `checked`, not `selected`.
    bool checked(Pattern label) {
      final node = tester.getSemantics(find.bySemanticsLabel(label));
      return node.getSemanticsData().flagsCollection.isChecked ==
          CheckedState.isTrue;
    }

    expect(checked(RegExp('^Enfermería')), isFalse);
    await app.tap(key('onboarding-profession-nursing'));
    expect(checked(RegExp('^Enfermería')), isTrue);
    expect(checked(RegExp('^Medicina')), isFalse);

    final preset = RegExp('^12 horas');
    expect(_selected(tester, preset), isFalse);
    await app.tap(key('onboarding-pattern-12h'));
    expect(_selected(tester, preset), isTrue);
    handle.dispose();
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('H-T18-1: the cells «Día N» of the start step are at least '
        '48 x 48 dp (text x$scale)', (tester) async {
      final app = await FirstLaunch.open(tester, textScale: scale);
      await app.chooseRotation();
      await app.tap(key('onboarding-pattern-12h'));
      await _next(app);
      expect(app.title, '¿Cuándo empiezas?');
      await app.tap(key('onboarding-cycle-toggle'));

      for (var i = 0; i < 4; i++) {
        final cell = find.descendant(
          of: key('onboarding-offset-$i'),
          matching: find.byType(InkWell),
        );
        final size = tester.getSize(cell);
        expect(size.width, greaterThanOrEqualTo(48), reason: 'cell $i');
        expect(size.height, greaterThanOrEqualTo(48), reason: 'cell $i');
      }
    });
  }

  testWidgets('H-T18-1: the shift and «which of its days» pills are at least '
      '48 x 48 dp (text x2.0)', (tester) async {
    final app = await FirstLaunch.open(tester, textScale: 2.0);
    await app.chooseRotation();
    await app.tap(key('onboarding-pattern-continental'));
    await _next(app);
    expect(app.title, '¿Cuándo empiezas?');
    // «Mañana» repeats in the cycle: picking it shows one pill per its day.
    await app.tap(key('onboarding-shift-morning'));

    // The pills the person actually taps on the main path of the step.
    final keys = <ValueKey<String>>[
      for (final w in tester.widgetList<Widget>(
        find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              ((w.key! as ValueKey<String>).value.startsWith(
                    'onboarding-shift-',
                  ) ||
                  (w.key! as ValueKey<String>).value.startsWith(
                    'onboarding-occurrence-',
                  )),
        ),
      ))
        w.key! as ValueKey<String>,
    ];
    expect(keys, isNotEmpty);
    for (final k in keys) {
      final size = tester.getSize(find.byKey(k));
      expect(size.width, greaterThanOrEqualTo(48), reason: k.value);
      expect(size.height, greaterThanOrEqualTo(48), reason: k.value);
    }
  });
}
