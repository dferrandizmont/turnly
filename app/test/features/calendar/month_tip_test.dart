import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:cuadrante/features/calendar/presentation/paint_bar.dart';
import 'package:cuadrante/features/onboarding/application/onboarding_providers.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/real_font.dart';
import '../../support/text_lines.dart';
import 'harness.dart';

/// H-T18-6 (design item 3) and decision 28: the tip «Elige un turno y arrastra»
/// is an instruction for painting, so it left the month screen (which keeps
/// nothing but the month) and shows inside the paint sheet the first time the
/// person enters paint mode. It is one line (it wraps with large text, it is
/// never cut), the cross closes it for good and it goes away by itself when
/// the first stroke ends.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeLocale();
    expect(await loadRoboto(), isTrue, reason: 'Roboto from the Flutter SDK');
  });

  Finder tip() => find.byKey(const ValueKey('onboarding-tip'));
  Finder tipText() => find.descendant(
    of: tip(),
    matching: find.text('Elige un turno y arrastra.'),
  );

  Future<void> pump(
    WidgetTester tester, {
    required Size size,
    required double scale,
  }) async {
    await pumpCalendar(tester, size: size, textScale: scale);
    containerOf(tester).read(onboardingTipProvider.notifier).show();
    await tester.pumpAndSettle();
  }

  testWidgets('the month screen has no tip: it waits for paint mode', (
    tester,
  ) async {
    await pump(tester, size: const Size(412, 900), scale: 1.0);
    expect(tip(), findsNothing);

    await enterPaintMode(tester);
    expect(tip(), findsOneWidget);
    // It is a line of the sheet, above the modes.
    expect(
      find.descendant(of: find.byType(PaintBar), matching: tip()),
      findsOneWidget,
    );
    expect(
      tester.getRect(tip()).bottom,
      lessThanOrEqualTo(
        tester.getRect(find.byKey(const ValueKey('paint-mode-replace'))).top,
      ),
    );
  });

  testWidgets('320 dp, text 1.0: the tip is one line', (tester) async {
    await pump(tester, size: const Size(320, 640), scale: 1.0);
    await enterPaintMode(tester);

    expect(tip(), findsOneWidget);
    final paragraph = tester.renderObject<RenderParagraph>(tipText());
    expect(
      paragraphLines(paragraph).length,
      1,
      reason: 'the tip is one line with the normal text',
    );
    // One line of text and the cross: barely taller than the touch target.
    expect(tester.getRect(tip()).height, lessThanOrEqualTo(64));
    expect(tester.takeException(), isNull);
  });

  testWidgets('320 dp, text 2.0: the tip wraps but it is never cut', (
    tester,
  ) async {
    await pump(tester, size: const Size(320, 640), scale: 2.0);
    await enterPaintMode(tester);

    expect(tip(), findsOneWidget);
    final paragraph = tester.renderObject<RenderParagraph>(tipText());
    final lines = paragraphLines(paragraph);
    expect(lines, isNotEmpty);
    expect(
      lines.join(' ').replaceAll(' ', ''),
      'Eligeunturnoyarrastra.',
      reason: 'the whole text is there, line by line',
    );
    expect(
      paragraph.didExceedMaxLines,
      isFalse,
      reason: 'the tip is never cut',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the cross closes the tip for good', (tester) async {
    await pump(tester, size: const Size(412, 900), scale: 1.0);
    await enterPaintMode(tester);
    expect(tip(), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('onboarding-tip-close')));
    await tester.pumpAndSettle();
    expect(tip(), findsNothing);
    expect(containerOf(tester).read(onboardingTipProvider), isFalse);
    // Leaving paint mode and coming back does not bring it again.
    paintOf(tester).exit();
    await tester.pumpAndSettle();
    await enterPaintMode(tester);
    expect(tip(), findsNothing);
  });

  testWidgets('the tip goes away by itself when the first stroke ends', (
    tester,
  ) async {
    await pump(tester, size: const Size(412, 900), scale: 1.0);
    await enterPaintMode(tester);
    expect(tip(), findsOneWidget);

    await tester.tap(cell(const CivilDate(2026, 10, 22)));
    await tester.pumpAndSettle();
    expect(tip(), findsNothing);
    expect(containerOf(tester).read(onboardingTipProvider), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the tip of the wide screen keeps the whole advice', (
    tester,
  ) async {
    await pumpCalendar(tester, size: const Size(1280, 800));
    containerOf(tester).read(onboardingTipProvider.notifier).show();
    await tester.pumpAndSettle();

    // The day pane of the wide screen keeps the whole tip (the title, what it
    // explains and the button to close it).
    expect(find.text('Pinta tu mes en un momento'), findsOneWidget);
    expect(find.textContaining('botón Patrón'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('onboarding-tip-dismiss')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
