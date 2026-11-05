import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:cuadrante/core/theme/theme_context.dart';
import 'package:cuadrante/features/calendar/presentation/month_screen.dart';
import 'package:cuadrante/features/calendar/presentation/shift_badge.dart';
import 'package:cuadrante/features/onboarding/application/onboarding_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/real_font.dart';
import 'onboarding_support.dart';

/// 2A, «¿Cómo empiezas tu cuadrante?» (docs/diseno.md): the three ways in
/// light and dark, on a small phone with big text, and what a screen reader
/// hears.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeLocale();
    expect(await loadRoboto(), isTrue, reason: 'Roboto from the Flutter SDK');
  });

  OnboardingState state(FirstLaunch app) =>
      app.container.read(onboardingControllerProvider);

  for (final brightness in Brightness.values) {
    testWidgets('${brightness.name}: the cards draw the shifts in colour and '
        'code, on the theme of the app', (tester) async {
      final app = await FirstLaunch.open(tester, brightness: brightness);
      final context = tester.element(key('onboarding-path-rotation'));
      expect(context.colors.brightness, brightness);
      expect(
        Theme.of(context).scaffoldBackgroundColor,
        context.colors.background,
      );
      // The rotation drawing: badges with the codes (never colour alone).
      final badges = find.descendant(
        of: key('onboarding-path-rotation'),
        matching: find.byType(ShiftBadge),
      );
      expect(badges, findsNWidgets(6));
      expect(
        find.descendant(of: badges.first, matching: find.text('M')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      // Every way still works in this theme.
      await app.choosePath('rotation');
      expect(app.title, '¿Cómo es tu rotación?');
    });
  }

  group('320 dp with text x2: every way to the month, nothing overflows', () {
    Future<FirstLaunch> open(WidgetTester tester) =>
        FirstLaunch.open(tester, size: const Size(320, 640), textScale: 2.0);

    testWidgets('rotation', (tester) async {
      final app = await open(tester);
      await app.choosePath('rotation');
      await app.tap(key('onboarding-pattern-12h'));
      await app.tap(key('onboarding-next'));
      await app.selectCycleDay(1);
      await app.tap(key('onboarding-next'));
      await app.tap(key('onboarding-profession-nursing'));
      await app.tap(key('onboarding-region'));
      await app.tap(find.text('Comunidad de Madrid'));
      await app.tap(key('onboarding-next'));
      expect(app.title, 'Listo');
      await app.tap(key('onboarding-next'));
      expect(find.byType(MonthScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('import', (tester) async {
      final app = await open(tester);
      await app.choosePath('import');
      expect(key('onboarding-import-lrhsoft'), findsOneWidget);
      await app.tap(key('onboarding-next'));
      await app.tap(key('onboarding-skip'));
      expect(app.title, 'Listo');
      expect(tester.takeException(), isNull);
    });

    testWidgets('by hand', (tester) async {
      final app = await open(tester);
      await app.choosePath('paint');
      await app.tap(key('onboarding-profession-hospitality'));
      await app.tap(key('onboarding-next'));
      await app.tap(key('onboarding-next'));
      expect(find.byType(MonthScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the cards keep their text whole: no line is cut', (
      tester,
    ) async {
      await open(tester);
      for (final path in ['import', 'rotation', 'paint']) {
        final card = key('onboarding-path-$path');
        await tester.ensureVisible(card);
        await tester.pumpAndSettle();
        for (final paragraph in tester.renderObjectList<RenderParagraph>(
          find.descendant(of: card, matching: find.byType(RichText)),
        )) {
          expect(paragraph.didExceedMaxLines, isFalse, reason: path);
        }
        // The card stays inside the screen.
        final rect = tester.getRect(card);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(320));
      }
      expect(tester.takeException(), isNull);
    });
  });

  group('what a screen reader hears', () {
    testWidgets('each way is one button that says what it does', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final app = await FirstLaunch.open(tester);
      final rotation = tester.getSemantics(key('onboarding-path-rotation'));
      expect(
        rotation.label,
        'Si tu turno se repite. Usar una rotación. Elige tu ciclo '
        '(mañanas, tardes, noches, saliente…) y se rellena solo, mes tras '
        'mes.',
      );
      expect(rotation.getSemanticsData().flagsCollection.isButton, isTrue);
      expect(
        tester
            .getSemantics(key('onboarding-path-import'))
            .label
            .startsWith('Importar mis turnos. Desde el calendario del móvil'),
        isTrue,
      );
      expect(
        tester
            .getSemantics(key('onboarding-path-paint'))
            .label
            .startsWith('Pintar a mano. '),
        isTrue,
      );
      // The title is a heading; the language says which one is in use.
      expect(
        find.bySemanticsLabel('¿Cómo empiezas tu cuadrante?'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(RegExp(r'^Idioma: ')), findsOneWidget);
      expect(
        find.bySemanticsLabel('Recuperar una copia de seguridad'),
        findsOneWidget,
      );

      // The last step says it is optional, and the job heading too.
      await app.choosePath('paint');
      expect(find.bySemanticsLabel('Paso 1 de 1'), findsOneWidget);
      expect(find.bySemanticsLabel('Paso 1 de 1 · Opcional'), findsOneWidget);
      expect(
        find.bySemanticsLabel('¿A qué te dedicas? Opcional'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('the controller', () {
    testWidgets('choosing a way sets only what that way needs', (tester) async {
      final app = await FirstLaunch.open(tester);
      final controller = app.container.read(
        onboardingControllerProvider.notifier,
      );
      expect(state(app).stage, OnboardingStage.choose);
      expect(state(app).stepNumber, isNull);
      expect(controller.canAdvance, isFalse);
      expect(controller.back(), isFalse, reason: 'nowhere to go back to');

      controller.chooseRotation();
      controller.selectPreset('12h');
      expect(state(app).path, OnboardingPath.rotation);
      expect(state(app).hasRotation, isTrue);
      expect(controller.back(), isTrue);
      expect(state(app).stage, OnboardingStage.choose);

      // Importing drops the rotation chosen before; by hand too.
      controller.chooseImport();
      expect(state(app).presetId, isNull);
      expect(state(app).stage, OnboardingStage.importCalendar);
      controller.back();
      controller.choosePaint();
      expect(state(app).byHand, isTrue);
      expect(state(app).stage, OnboardingStage.place);
      expect(state(app).steps, [OnboardingStage.place]);
      // Back to the question, and a rotation again: not by hand any more.
      controller.back();
      controller.chooseRotation();
      expect(state(app).byHand, isFalse);
      await tester.pumpAndSettle();
    });

    test('the screens of each way', () {
      expect(OnboardingStage.stepsOf(OnboardingPath.rotation), [
        OnboardingStage.rotation,
        OnboardingStage.start,
        OnboardingStage.place,
      ]);
      expect(OnboardingStage.stepsOf(OnboardingPath.import), [
        OnboardingStage.importCalendar,
        OnboardingStage.place,
      ]);
      expect(OnboardingStage.stepsOf(OnboardingPath.paint), [
        OnboardingStage.place,
      ]);
      expect(OnboardingStage.stepsOf(null), [OnboardingStage.place]);
    });
  });
}
