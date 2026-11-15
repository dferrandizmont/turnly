import 'package:cuadrante/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

/// The chosen half of «Cuadrícula | Lista» must be told apart from the track
/// and from the other half in dark mode too (it was ~1.3:1 with the soft
/// accent), and its label must pass AA on it.
void main() {
  Color thumb(WidgetTester tester, String presentation) {
    final box = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byKey(ValueKey('month-presentation-$presentation')),
        matching: find.byType(AnimatedContainer),
      ),
    );
    return (box.decoration! as BoxDecoration).color!;
  }

  Color label(WidgetTester tester, String text) => tester
      .widget<Text>(
        find.descendant(
          of: find.byType(AnimatedContainer),
          matching: find.text(text),
        ),
      )
      .style!
      .color!;

  for (final brightness in Brightness.values) {
    testWidgets('the chosen half stands out · ${brightness.name}', (
      tester,
    ) async {
      await pumpCalendar(tester, brightness: brightness);
      final colors = brightness == Brightness.dark
          ? AppColors.dark
          : AppColors.light;
      final selected = thumb(tester, 'grid');
      expect(thumb(tester, 'list'), Colors.transparent);
      // Dark: non-text contrast against the track it sits on (WCAG 1.4.11).
      // Light keeps the soft accent with its outline, as approved.
      if (brightness == Brightness.dark) {
        expect(
          contrastRatio(selected, colors.surfaceMuted),
          greaterThanOrEqualTo(3.0),
        );
      }
      // The label on the chosen half (AA) and on the unchosen one.
      expect(
        contrastRatio(label(tester, 'Cuadrícula'), selected),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrastRatio(label(tester, 'Lista'), colors.surfaceMuted),
        greaterThanOrEqualTo(4.5),
      );
    });
  }
}
