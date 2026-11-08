import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:cuadrante/features/calendar/presentation/month_screen.dart';
import 'package:cuadrante/features/holidays/application/holidays_provider.dart';
import 'package:cuadrante/features/onboarding/application/onboarding_controller.dart';
import 'package:cuadrante/features/onboarding/application/onboarding_providers.dart';
import 'package:cuadrante/features/onboarding/domain/profession.dart';
import 'package:cuadrante/features/settings/application/preferences_controller.dart';
import 'package:cuadrante/features/settings/domain/preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'onboarding_support.dart';

/// With a rotation the place (country, community, municipality) is asked
/// first: the country sets the first day of the week, and the preview of the
/// rotation («Así quedará», on the start step) is drawn with it. Before, the
/// place came last and a Spanish user on a phone set to a region that starts
/// the week on Sunday (en-US) saw Sunday-first weeks in the preview.
void main() {
  setUpAll(initializeLocale);

  OnboardingState state(FirstLaunch app) =>
      app.container.read(onboardingControllerProvider);

  String nextLabel(WidgetTester tester) {
    final text = find.descendant(
      of: key('onboarding-next'),
      matching: find.byType(Text),
    );
    return (tester.widget(text.first) as Text).data!;
  }

  String progress(WidgetTester tester) =>
      tester.getSemantics(key('onboarding-dots')).label;

  group('the order of the rotation path', () {
    testWidgets('place, rotation, start, then «Listo»: «Paso N de 3» and the '
        'button of each', (tester) async {
      final app = await FirstLaunch.open(tester);

      await app.choosePath('rotation');
      expect(state(app).stage, OnboardingStage.place);
      expect(app.title, '¿Dónde trabajas?');
      expect(progress(tester), 'Paso 1 de 3');
      expect(find.text('Paso 1 de 3 · Opcional'), findsOneWidget);
      expect(nextLabel(tester), 'Siguiente', reason: 'not the last step');

      await app.tap(key('onboarding-next'));
      expect(state(app).stage, OnboardingStage.rotation);
      expect(app.title, '¿Cómo es tu rotación?');
      expect(progress(tester), 'Paso 2 de 3');
      expect(nextLabel(tester), 'Siguiente');

      await app.tap(key('onboarding-pattern-12h'));
      await app.tap(key('onboarding-next'));
      expect(state(app).stage, OnboardingStage.start);
      expect(app.title, '¿Cuándo empiezas?');
      expect(progress(tester), 'Paso 3 de 3');
      expect(nextLabel(tester), 'Continuar', reason: 'the last step');

      await app.tap(key('onboarding-next'));
      expect(state(app).stage, OnboardingStage.ready);
      expect(app.title, 'Listo');
      await app.flushWrites();
      expect(idsOn(app.schedule, onboardingToday), 'day12');
      await app.tap(key('onboarding-next'));
      expect(find.byType(MonthScreen), findsOneWidget);
    });

    testWidgets('the place chosen first is written with the rotation', (
      tester,
    ) async {
      final app = await FirstLaunch.open(tester);
      await app.choosePath('rotation');
      await app.tap(key('onboarding-region'));
      await app.tap(find.text('Comunidad de Madrid'));
      await app.tap(key('onboarding-next'));
      await app.tap(key('onboarding-pattern-12h'));
      await app.tap(key('onboarding-next'));
      await app.tap(key('onboarding-next'));
      await app.flushWrites();

      expect(app.title, 'Listo');
      expect(find.text('Festivos: Comunidad de Madrid'), findsOneWidget);
      expect(app.container.read(holidayPlaceProvider).regionCode, 'ES-MD');
      expect(idsOn(app.schedule, onboardingToday), 'day12');
    });
  });

  group('the preview uses the week start of the country chosen first', () {
    // The phone is set to a region that starts the week on Sunday (the
    // database is seeded from it), but the person is in Spain.
    Future<FirstLaunch> openOnAnAmericanPhone(WidgetTester tester) async {
      debugPhoneLocales = const [Locale('en', 'US')];
      addTearDown(() => debugPhoneLocales = const [Locale('es', 'ES')]);
      return FirstLaunch.open(
        tester,
        overrides: [systemCountryCodeProvider.overrideWithValue('US')],
      );
    }

    // October 2026 starts on a Thursday. With Monday-first weeks the 5th
    // (Monday) opens a row and the 4th (Sunday) closes the one above, so the
    // 5th is drawn to the left of the 4th; with Sunday-first weeks it is the
    // other way round.
    bool mondayFirst(WidgetTester tester) {
      final sunday = tester.getTopLeft(key('preview-2026-10-04')).dx;
      final monday = tester.getTopLeft(key('preview-2026-10-05')).dx;
      return monday < sunday;
    }

    Future<void> toStart(FirstLaunch app, WidgetTester tester) async {
      await app.tap(key('onboarding-next')); // place -> rotation
      await app.tap(key('onboarding-pattern-12h'));
      await app.tap(key('onboarding-next'));
      expect(app.title, '¿Cuándo empiezas?');
      final preview = key('onboarding-pattern-preview');
      await tester.ensureVisible(preview);
      await tester.pumpAndSettle();
    }

    testWidgets('Spain chosen on a US phone: weeks start on Monday', (
      tester,
    ) async {
      final app = await openOnAnAmericanPhone(tester);
      expect(
        app.container.read(preferencesProvider).weekStart,
        WeekStart.sunday,
        reason: 'the phone region seeded Sunday',
      );
      await app.choosePath('rotation');
      expect(state(app).countryCode, 'US');
      await app.tap(key('onboarding-country'));
      await app.tap(key('country-option-ES'));
      expect(state(app).countryCode, 'ES');
      await app.flushWrites();
      expect(
        app.container.read(preferencesProvider).weekStart,
        WeekStart.monday,
      );

      await toStart(app, tester);
      expect(mondayFirst(tester), isTrue);
    });

    testWidgets('keeping the American country keeps Sunday', (tester) async {
      final app = await openOnAnAmericanPhone(tester);
      await app.choosePath('rotation');
      await toStart(app, tester);
      expect(mondayFirst(tester), isFalse);
    });
  });

  group('skip and back on the rotation path', () {
    testWidgets('back: start to rotation to place to the first question', (
      tester,
    ) async {
      final app = await FirstLaunch.open(tester);
      await app.choosePath('rotation');
      await app.tap(key('onboarding-region'));
      await app.tap(find.text('Comunidad de Madrid'));
      await app.tap(key('onboarding-next'));
      await app.tap(key('onboarding-pattern-12h'));
      await app.tap(key('onboarding-next'));
      expect(state(app).stage, OnboardingStage.start);

      await app.tap(key('onboarding-back'));
      expect(state(app).stage, OnboardingStage.rotation);
      expect(state(app).presetId, '12h', reason: 'the rotation is kept');
      await app.tap(key('onboarding-back'));
      expect(state(app).stage, OnboardingStage.place);
      expect(state(app).regionCode, 'ES-MD', reason: 'the place is kept');
      await app.tap(key('onboarding-back'));
      expect(state(app).stage, OnboardingStage.choose);
      expect(key('onboarding-back'), findsNothing);
    });

    testWidgets('«Saltar» on the place keeps the country, drops the community '
        'and goes on to the rotation', (tester) async {
      final app = await FirstLaunch.open(tester);
      await app.choosePath('rotation');
      // The job is asked on the rotation screen: skipping the place does
      // not take it away.
      app.container
          .read(onboardingControllerProvider.notifier)
          .selectProfession(Profession.nursing);
      await app.tap(key('onboarding-region'));
      await app.tap(find.text('Comunidad de Madrid'));
      await app.tap(key('onboarding-skip'));

      expect(state(app).stage, OnboardingStage.rotation);
      expect(state(app).regionCode, isNull);
      expect(state(app).countryCode, 'ES');
      expect(state(app).profession, Profession.nursing);
    });

    testWidgets('«Saltar» on the rotation writes without it', (tester) async {
      final app = await FirstLaunch.open(tester);
      await app.chooseRotation();
      await app.tap(key('onboarding-pattern-12h'));
      await app.tap(key('onboarding-skip'));
      expect(app.title, 'Listo');
      await app.flushWrites();
      expect(app.schedule.runs, isEmpty);
      expect(state(app).hasRotation, isFalse);
    });

    testWidgets('«Saltar» on the start step writes without the rotation', (
      tester,
    ) async {
      final app = await FirstLaunch.open(tester);
      await app.chooseRotation();
      await app.tap(key('onboarding-pattern-12h'));
      await app.tap(key('onboarding-next'));
      await app.tap(key('onboarding-skip'));
      expect(app.title, 'Listo');
      await app.flushWrites();
      expect(app.schedule.runs, isEmpty);
    });

    testWidgets('«Lo pinto a mano» finishes in paint mode', (tester) async {
      final app = await FirstLaunch.open(tester);
      await app.chooseRotation();
      await app.tap(key('onboarding-by-hand'));
      expect(app.title, 'Listo');
      expect(state(app).byHand, isTrue);
      await app.flushWrites();
      expect(app.schedule.runs, isEmpty);
    });
  });
}
