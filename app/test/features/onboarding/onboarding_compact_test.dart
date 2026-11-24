import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/real_font.dart';
import 'onboarding_support.dart';

/// H-T01-6: with text at 2.0 or in landscape the top bar (back, dots,
/// «Saltar») and the title left a card and a half of the list. There the bar
/// scrolls away with the step, so the list gets the screen. «Siguiente» stays
/// fixed under the list on the two long steps of the rotation (M2, 0.12.1: at
/// the end of the content it was 8 and 3-4 long swipes away at 2.0).
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeLocale();
    expect(await loadRoboto(), isTrue, reason: 'Roboto from the Flutter SDK');
  });

  final scroll = find.byType(SingleChildScrollView).first;

  bool barScrolls() => find
      .descendant(of: scroll, matching: key('onboarding-dots'))
      .evaluate()
      .isNotEmpty;

  bool nextScrolls() => find
      .descendant(of: scroll, matching: key('onboarding-next'))
      .evaluate()
      .isNotEmpty;

  testWidgets('a normal phone keeps the bar and «Siguiente» fixed', (
    tester,
  ) async {
    final app = await FirstLaunch.open(tester, size: const Size(390, 844));
    await app.chooseRotation();
    expect(barScrolls(), isFalse);
    expect(nextScrolls(), isFalse);
    expect(
      tester.getRect(key('onboarding-next')).top,
      greaterThanOrEqualTo(tester.getRect(scroll).bottom),
    );
  });

  for (final (name, size, scale) in [
    ('text 2.0 at 320 dp', const Size(320, 640), 2.0),
    ('text 2.0 at 412 dp', const Size(412, 892), 2.0),
    ('landscape', const Size(800, 360), 1.0),
  ]) {
    testWidgets('$name: the bar scrolls away and the list gets the room', (
      tester,
    ) async {
      final app = await FirstLaunch.open(tester, size: size, textScale: scale);
      await app.chooseRotation();
      expect(barScrolls(), isTrue);

      // The scroll view starts at the top of the screen (the bar is inside
      // it). «Siguiente» stays fixed under the list at any text size, also at
      // 2.0 (QA 0.12.1, M2: inside, it was 8 long swipes away on this step),
      // and it is on the screen without scrolling.
      final viewport = tester.getRect(scroll);
      expect(viewport.top, lessThan(8));
      expect(nextScrolls(), isFalse);
      final nextRect = tester.getRect(key('onboarding-next'));
      expect(nextRect.top, greaterThanOrEqualTo(viewport.bottom));
      expect(nextRect.bottom, lessThanOrEqualTo(size.height + 0.5));
      expect(tester.takeException(), isNull);

      // The bar is reachable at the top, and gone after scrolling the list.
      expect(tester.getRect(key('onboarding-skip')).top, greaterThan(0));
      await tester.drag(scroll, Offset(0, -size.height));
      await tester.pumpAndSettle();
      expect(tester.getRect(key('onboarding-skip')).bottom, lessThan(0));

      // And it still works: pick a rotation and go on from where the list
      // is.
      await app.tap(key('onboarding-pattern-12h'));
      await app.tap(key('onboarding-next'));
      expect(app.title, '¿Cuándo empiezas?');
      expect(barScrolls(), isTrue);
    });
  }

  for (final (name, size, scale) in [
    ('text 2.0 at 320 dp', const Size(320, 640), 2.0),
    ('landscape', const Size(800, 360), 1.0),
  ]) {
    testWidgets('$name: the first question scrolls whole, the backup at the '
        'end', (tester) async {
      await FirstLaunch.open(tester, size: size, textScale: scale);
      expect(key('onboarding-next'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.drag(scroll, Offset(0, -size.height * 4));
      await tester.pumpAndSettle();
      final restore = tester.getRect(key('onboarding-restore'));
      expect(restore.bottom, lessThanOrEqualTo(size.height + 0.5));
      expect(restore.top, greaterThan(0));
    });
  }

  group('H-T01-6 on every width and text size', () {
    for (final width in [320.0, 360.0, 412.0]) {
      for (final scale in [1.0, 1.3, 2.0]) {
        testWidgets('$width dp, text $scale: «Siguiente» and «Continuar» are '
            'fixed and on screen without scrolling', (
          tester,
        ) async {
          final app = await FirstLaunch.open(
            tester,
            size: Size(width, 760),
            textScale: scale,
          );
          await app.chooseRotation();
          for (var step = 0; step < 2; step++) {
            expect(nextScrolls(), isFalse, reason: 'step $step');
            final next = key('onboarding-next');
            // Fixed: always on screen, under the list, at any text size.
            expect(tester.getRect(next).bottom, lessThanOrEqualTo(760));
            expect(
              tester.getRect(next).top,
              greaterThanOrEqualTo(tester.getRect(scroll).bottom),
            );
            if (step == 0) {
              await app.tap(key('onboarding-pattern-12h'));
            }
            await app.tap(key('onboarding-next'));
          }
          expect(app.title, isNotEmpty);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
