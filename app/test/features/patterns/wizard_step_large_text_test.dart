import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/real_font.dart';
import '../../support/text_lines.dart';
import '../calendar/harness.dart';

/// iOS 1.2.2 QA, F2: at AX3 (about x3.1) on a portrait phone the title of the
/// second step of the rotation wizard broke in the middle of a word
/// («¿Cuándo empieza / s?») and so did the date card («19 de no / viembre»).
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeLocale();
    expect(await loadRoboto(), isTrue, reason: 'Roboto from the Flutter SDK');
  });

  Finder key(String k) => find.byKey(ValueKey(k));

  Future<void> tap(WidgetTester tester, String k) async {
    await tester.ensureVisible(key(k));
    await tester.pumpAndSettle();
    await tester.tap(key(k));
    await tester.pumpAndSettle();
  }

  for (final size in const [Size(393, 852), Size(320, 640)]) {
    testWidgets('${size.width.toInt()} dp, text x3.1: step 2 of the wizard '
        'keeps its words whole', (tester) async {
      await pumpCalendar(tester, size: size, textScale: 3.1);
      await enterPaintMode(tester);
      await tap(tester, 'paint-pattern');
      await tap(tester, 'pattern-card-6x4');
      await tap(tester, 'pattern-next');

      expect(find.textContaining('empiezas'), findsWidgets);
      for (final target in [
        key('pattern-step-title'),
        key('pattern-start-date'),
      ]) {
        final paragraphs = find.descendant(
          of: target,
          matching: find.byType(RichText),
        );
        expect(paragraphs, findsWidgets);
        for (final e in paragraphs.evaluate()) {
          final lines = paragraphLines(e.renderObject! as RenderParagraph);
          expect(
            wrapsOnlyBetweenWords(e.renderObject! as RenderParagraph),
            isTrue,
            reason: lines.join(' | '),
          );
        }
      }
      expect(find.textContaining('2026'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }
}
