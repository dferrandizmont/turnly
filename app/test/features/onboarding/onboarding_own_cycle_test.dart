import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:cuadrante/core/widgets/choice_pill.dart';
import 'package:cuadrante/features/calendars/domain/calendar.dart';
import 'package:cuadrante/features/calendar/application/schedule_controller.dart';
import 'package:cuadrante/features/onboarding/application/onboarding_controller.dart';
import 'package:cuadrante/features/onboarding/data/onboarding_repository.dart';
import 'package:cuadrante/features/patterns/application/pattern_wizard.dart';
import 'package:cuadrante/features/schedule/data/schedule_repository.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:cuadrante/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/real_font.dart';
import 'onboarding_support.dart';

/// First use, «Crear mi ciclo» (QA of the 0.12.1, personas 4 and 7): the
/// pattern builder on «Tu ciclo», over «¿Cómo es tu rotación?», with the cycle
/// kept in memory until the end; and, with big text, «Siguiente» and
/// «Continuar» of the two long steps fixed instead of 8 swipes away (M2).
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeLocale();
    expect(await loadRoboto(), isTrue, reason: 'Roboto from the Flutter SDK');
  });

  /// M M T T N N S L L: the nurse of QA (two mornings, two afternoons, two
  /// nights, the saliente and two days off).
  const nine = [
    ['morning'],
    ['morning'],
    ['afternoon'],
    ['afternoon'],
    ['night'],
    ['night'],
    ['postNight'],
    ['rest'],
    ['rest'],
  ];

  /// Opens «Tu ciclo» from the catalogue and taps the days of [ids].
  Future<void> build(FirstLaunch app, List<String> ids) async {
    await app.tap(key('onboarding-own-cycle-new'));
    for (final id in ids) {
      await app.tap(key('builder-add-$id'));
    }
  }

  const sequence = [
    'morning',
    'morning',
    'afternoon',
    'afternoon',
    'night',
    'night',
    'postNight',
    'rest',
    'rest',
  ];

  Future<bool> savedNothing(FirstLaunch app) async {
    final repository = OnboardingRepository(app.database);
    return !await app.real(repository.hasUserData) &&
        !await app.real(repository.isDone);
  }

  /// A count straight from the database (not through the app's schedule).
  Future<int> count(FirstLaunch app, String sql) => app.real(
    () async =>
        (await app.database.customSelect(sql).getSingle()).read<int>('n'),
  );
  Future<int> patternRows(FirstLaunch app) =>
      count(app, 'SELECT COUNT(*) AS n FROM patterns');
  Future<int> customRows(FirstLaunch app) =>
      count(app, "SELECT COUNT(*) AS n FROM patterns WHERE id LIKE 'custom-%'");
  Future<int> runRows(FirstLaunch app) =>
      count(app, 'SELECT COUNT(*) AS n FROM pattern_runs');

  /// The schedule as the database has it now (what a restart would read).
  Future<Schedule> reloaded(FirstLaunch app) async => (await app.real(
    () => ScheduleRepository(
      app.database,
      now: () => onboardingNow,
    ).load(mainCalendarId),
  )).schedule;

  /// Waits (in real time) until the flow reaches «Listo».
  Future<void> untilReady(FirstLaunch app, WidgetTester tester) async {
    for (var i = 0; i < 50; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      if (find.text('Listo').evaluate().isNotEmpty) break;
    }
    await app.flushWrites();
  }

  group('the controller', () {
    testWidgets('request() builds the own cycle from the start day', (
      tester,
    ) async {
      final app = await FirstLaunch.open(tester);
      await app.chooseRotation();
      final controller = app.container.read(
        onboardingControllerProvider.notifier,
      );
      controller.useOwnCycle(nine, 'Mi ciclo');
      var state = app.container.read(onboardingControllerProvider);
      expect(state.stage, OnboardingStage.start, reason: 'straight to step 3');
      expect(state.hasOwnCycle, isTrue);
      expect(state.hasRotation, isTrue);
      expect(state.presetId, isNull);
      expect(controller.canAdvance, isTrue);

      controller.setStepOffset(11);
      final request = controller.request(app.schedule)!;
      expect(request.pattern.id, startsWith('custom-'));
      expect(request.pattern.name, 'Mi ciclo');
      expect(request.pattern.steps, nine);
      expect(request.from, onboardingToday);
      expect(request.stepOffset, 2, reason: '11 % 9');
      expect(request.until, isNull);

      // Without a cycle, a preset is still a preset.
      controller.selectPreset('12h');
      state = app.container.read(onboardingControllerProvider);
      expect(state.hasOwnCycle, isFalse);
      expect(state.customSteps, nine, reason: 'kept on its card');
      expect(controller.request(app.schedule)!.pattern.id, '12h');
      controller.selectOwnCycle();
      expect(
        controller.request(app.schedule)!.pattern.steps,
        nine,
        reason: 'chosen again from its card',
      );
      controller.removeOwnCycle();
      state = app.container.read(onboardingControllerProvider);
      expect(state.customSteps, isNull);
      expect(state.hasRotation, isFalse);

      // An empty cycle is no cycle.
      controller.useOwnCycle(const [], 'Nada');
      expect(
        app.container.read(onboardingControllerProvider).hasOwnCycle,
        isFalse,
      );
    });

    testWidgets('nothing is written until the end: not on the way, not '
        'leaving half way (patterns and runs counted in the database)', (
      tester,
    ) async {
      final app = await FirstLaunch.open(tester);
      await app.chooseRotation();
      final patterns = await patternRows(app);
      expect(await runRows(app), 0);
      expect(await customRows(app), 0);

      // The cycle built and used, on the way to the start day.
      await build(app, sequence);
      expect(await patternRows(app), patterns, reason: 'while building');
      await app.tap(key('own-cycle-use'));
      expect(app.title, '¿Cuándo empiezas?');
      expect(await savedNothing(app), isTrue);
      expect(await patternRows(app), patterns, reason: 'after «Usar»');
      expect(await runRows(app), 0);
      expect(app.schedule.runs, isEmpty);

      // And back to the catalogue, then out of the flow's rotation: skipping
      // writes the choices (the place) but never the cycle.
      await app.tap(key('onboarding-back'));
      expect(app.title, '¿Cómo es tu rotación?');
      expect(await savedNothing(app), isTrue);
      await tester.tap(key('onboarding-skip'));
      await untilReady(app, tester);
      expect(await patternRows(app), patterns, reason: 'after leaving');
      expect(await customRows(app), 0);
      expect(await runRows(app), 0);
      expect(app.schedule.runs, isEmpty);
    });

    testWidgets('«Saltar» while the writing runs: nothing can be chosen again '
        'and the cycle is never written', (tester) async {
      final app = await FirstLaunch.open(tester);
      await app.chooseRotation();
      await build(app, sequence);
      await app.tap(key('own-cycle-use'));
      await app.tap(key('onboarding-back'));
      final controller = app.container.read(
        onboardingControllerProvider.notifier,
      );
      expect(
        app.container.read(onboardingControllerProvider).hasOwnCycle,
        isTrue,
      );

      // «Saltar» starts the writing; the card is tapped (and the rotation
      // changed) before it has read what was chosen.
      await tester.tap(key('onboarding-skip'));
      expect(
        app.container.read(onboardingControllerProvider).finishing,
        isTrue,
      );
      controller.selectOwnCycle();
      controller.selectPreset('12h');
      controller.setStart(const CivilDate(2026, 11, 1));
      expect(
        app.container.read(onboardingControllerProvider).hasRotation,
        isFalse,
        reason: 'nothing can be chosen while it writes',
      );
      await untilReady(app, tester);
      expect(await customRows(app), 0);
      expect(await runRows(app), 0);
      expect(app.schedule.runs, isEmpty);
    });

    testWidgets('edit and finish twice with fast taps: one custom pattern '
        'and one run after reloading', (tester) async {
      final app = await FirstLaunch.open(tester);
      await app.chooseRotation();
      await build(app, sequence);
      await app.tap(key('own-cycle-use'));
      await app.tap(key('onboarding-back'));
      await app.tap(
        find.descendant(
          of: key('onboarding-own-cycle'),
          matching: find.text('Editar'),
        ),
      );
      await app.tap(key('builder-add-rest'));
      await app.tap(key('own-cycle-use'));
      expect(app.title, '¿Cuándo empiezas?');
      expect(await customRows(app), 0);

      // Two quick taps on «Continuar» before anything is redrawn.
      await tester.tap(key('onboarding-next'));
      await tester.tap(key('onboarding-next'));
      await untilReady(app, tester);

      expect(await customRows(app), 1);
      expect(await runRows(app), 1);
      final loaded = await reloaded(app);
      expect(
        loaded.patterns.where((p) => p.id.startsWith('custom-')),
        hasLength(1),
      );
      expect(loaded.runs, hasLength(1));
      expect(
        loaded.patternById(loaded.runs.single.patternId)!.steps.length,
        10,
      );
    });
  });

  group('«Crear mi ciclo» is on the first screen (390 x 844, text 1.0)', () {
    for (final language in ['es', 'eu']) {
      testWidgets('$language: the card is in view with «Siguiente» pinned', (
        tester,
      ) async {
        final app = await FirstLaunch.open(tester);
        if (language == 'eu') {
          await app.tap(key('onboarding-language'));
          await app.tap(
            find.descendant(
              of: find.byType(BottomSheet),
              matching: find.text('Euskara'),
            ),
          );
        }
        await app.chooseRotation();
        final scroll = find.byType(SingleChildScrollView).first;
        final view = tester.getRect(scroll);
        final card = tester.getRect(key('onboarding-own-cycle-new'));
        // The card is whole inside the first view, over the pinned button.
        expect(card.top, greaterThanOrEqualTo(view.top));
        expect(card.bottom, lessThanOrEqualTo(view.bottom));
        expect(
          tester.getRect(key('onboarding-next')).top,
          greaterThanOrEqualTo(view.bottom),
          reason: '«Siguiente» pinned under the list',
        );
        expect(
          find.descendant(of: scroll, matching: key('onboarding-next')),
          findsNothing,
        );
        // The jobs are one row of chips, scrolled sideways.
        expect(
          tester.getRect(key('onboarding-profession-chips')).height,
          lessThan(80),
        );
        // A job far in the row can still be chosen.
        await app.tap(key('onboarding-profession-hospitality'));
        expect(
          app.container.read(onboardingControllerProvider).profession,
          isNotNull,
        );
      });
    }
  });

  group('«Crear mi ciclo»', () {
    testWidgets('the entry is under the job, over the lists, and again at '
        'the end', (tester) async {
      final app = await FirstLaunch.open(tester);
      await app.chooseRotation();
      expect(
        find.text(
          lookupAppLocalizations(const Locale('es')).onboardingRotationHelp,
        ),
        findsOneWidget,
      );
      // Under the job (the section above it) and over the lists.
      final entry = tester.getRect(key('onboarding-own-cycle-new'));
      expect(
        entry.top,
        greaterThan(tester.getRect(key('onboarding-title')).bottom),
      );
      final byHand = tester.getRect(key('onboarding-by-hand'));
      expect(entry.bottom, lessThanOrEqualTo(byHand.top));
      expect(find.text('Crear mi ciclo'), findsOneWidget);
      expect(find.text('Monta tu ciclo día a día'), findsOneWidget);
      // The sample strip: nine chips.
      expect(
        find.descendant(
          of: key('onboarding-own-cycle-new'),
          matching: find.text('S'),
        ),
        findsOneWidget,
      );
      await tester.ensureVisible(key('onboarding-own-cycle-end'));
      expect(find.text('¿No está la tuya? Crear mi ciclo'), findsOneWidget);
      // The one at the end opens the same screen.
      await app.tap(key('onboarding-own-cycle-end'));
      expect(key('own-cycle-close'), findsOneWidget);
    });

    testWidgets('«Usar este ciclo» is disabled until there is a day', (
      tester,
    ) async {
      final app = await FirstLaunch.open(tester);
      await app.chooseRotation();
      await app.tap(key('onboarding-own-cycle-new'));
      expect(key('own-cycle-close'), findsOneWidget);
      final use = find.widgetWithText(FilledButton, 'Usar este ciclo');
      expect(tester.widget<FilledButton>(use).onPressed, isNull);
      await app.tap(key('builder-add-morning'));
      expect(tester.widget<FilledButton>(use).onPressed, isNotNull);
    });

    testWidgets('the palette is the first-use one: the app\'s language, the '
        'job\'s hours, no absences, no way back to the list', (tester) async {
      final app = await FirstLaunch.open(tester);
      await app.chooseRotation();
      await app.tap(key('onboarding-profession-nursing'));
      await app.tap(key('onboarding-own-cycle-new'));
      for (final id in ['morning', 'afternoon', 'night', 'postNight', 'rest']) {
        expect(key('builder-add-$id'), findsOneWidget, reason: id);
      }
      expect(key('builder-add-vacation'), findsNothing);
      expect(key('builder-add-personalDay'), findsNothing);
      expect(key('builder-back'), findsNothing);
      expect(
        find.text('Las horas las cambias luego en Ajustes › Mis turnos.'),
        findsOneWidget,
      );
      // The nurse's hours (08-15), not the factory ones (06-14), before
      // anything is saved.
      expect(
        find.descendant(
          of: key('builder-add-morning'),
          matching: find.textContaining('15'),
        ),
        findsWidgets,
      );
      expect(
        find.descendant(
          of: key('builder-add-morning'),
          matching: find.textContaining('14'),
        ),
        findsNothing,
      );
    });

    testWidgets('M M T T N N S L L from 11 October gives the October of the '
        'nurse, and the summary says it', (tester) async {
      final app = await FirstLaunch.open(tester);
      await app.chooseRotation();
      await build(app, sequence);
      expect(find.text('9 días'), findsWidgets);
      await app.tap(key('own-cycle-use'));
      expect(app.title, '¿Cuándo empiezas?');

      // 11 October 2026 (a Sunday), day 1 of the cycle.
      const start = CivilDate(2026, 10, 11);
      final controller = app.container.read(
        onboardingControllerProvider.notifier,
      );
      controller.setStart(start);
      await tester.pumpAndSettle();
      await app.selectCycleDay(0);
      // «Así quedará» is drawn from the own cycle.
      expect(find.text('Así quedará'), findsOneWidget);

      await app.tap(key('onboarding-next')); // writes
      await app.flushWrites();
      expect(app.title, 'Listo');
      expect(
        find.text(
          'Rotación: Mi ciclo (9 días), desde el domingo 11 de octubre',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Empiezas en el día 1 del ciclo'), findsOne);

      final run = app.schedule.runs.single;
      expect(run.patternId, startsWith('custom-'));
      expect(run.startDate, start);
      expect(run.stepOffset, 0);
      final pattern = app.schedule.patternById(run.patternId)!;
      expect(pattern.name, 'Mi ciclo');
      expect(pattern.steps, nine);

      // M 11-12, T 13-14, N 15-16, S 17, L 18-19, M 20-21, T 22-23...
      String on(int day) => idsOn(app.schedule, CivilDate(2026, 10, day));
      expect([for (var d = 11; d <= 12; d++) on(d)], ['morning', 'morning']);
      expect(
        [for (var d = 13; d <= 14; d++) on(d)],
        ['afternoon', 'afternoon'],
      );
      expect([for (var d = 15; d <= 16; d++) on(d)], ['night', 'night']);
      expect(on(17), 'postNight');
      expect([for (var d = 18; d <= 19; d++) on(d)], ['rest', 'rest']);
      expect([for (var d = 20; d <= 21; d++) on(d)], ['morning', 'morning']);
      expect(
        [for (var d = 22; d <= 23; d++) on(d)],
        ['afternoon', 'afternoon'],
      );
      expect(on(10), '', reason: 'nothing before the start');

      // Every cell up to the 31st, in the app and as reloaded from the
      // database.
      final loaded = await reloaded(app);
      for (var day = 11; day <= 31; day++) {
        final expected = nine[(day - 11) % 9].single;
        expect(on(day), expected, reason: 'app, 2026-10-$day');
        expect(
          idsOn(loaded, CivilDate(2026, 10, day)),
          expected,
          reason: 'reloaded, 2026-10-$day',
        );
      }
    });

    testWidgets('a start on day 4 of the cycle shows in the preview, the '
        'summary and the reloaded app', (tester) async {
      final app = await FirstLaunch.open(tester);
      await app.chooseRotation();
      await build(app, sequence);
      await app.tap(key('own-cycle-use'));
      const start = CivilDate(2026, 10, 11);
      app.container.read(onboardingControllerProvider.notifier).setStart(start);
      await tester.pumpAndSettle();
      await app.selectCycleDay(3); // day 4: the second afternoon

      // The preview (the same planner as the writing).
      final plan = app.container.read(onboardingPreviewProvider)!;
      String preview(int day) =>
          plan.schedule.resolve(CivilDate(2026, 10, day)).shiftIds.join('+');
      for (var day = 11; day <= 31; day++) {
        expect(preview(day), nine[(day - 11 + 3) % 9].single, reason: '$day');
      }

      await app.tap(key('onboarding-next'));
      await untilReady(app, tester);
      expect(find.textContaining('Empiezas en el día 4 del ciclo'), findsOne);
      expect(find.textContaining('(Tarde)'), findsOne);
      expect(app.schedule.runs.single.stepOffset, 3);
      final loaded = await reloaded(app);
      expect(loaded.runs.single.stepOffset, 3);
      for (var day = 11; day <= 31; day++) {
        expect(
          idsOn(loaded, CivilDate(2026, 10, day)),
          nine[(day - 11 + 3) % 9].single,
          reason: 'reloaded, $day',
        );
      }
    });
  });

  group('back', () {
    testWidgets('the system back closes «Tu ciclo», not the step', (
      tester,
    ) async {
      final app = await FirstLaunch.open(tester);
      await app.chooseRotation();

      // Nothing built: it just closes.
      await app.tap(key('onboarding-own-cycle-new'));
      expect(key('own-cycle-close'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(key('own-cycle-close'), findsNothing);
      expect(app.title, '¿Cómo es tu rotación?');

      // With a change not used: the question of the wizard first.
      await build(app, ['morning', 'morning']);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('¿Descartar la secuencia?'), findsOneWidget);
      await tester.tap(find.text('Seguir editando'));
      await tester.pumpAndSettle();
      expect(key('own-cycle-close'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Descartar'));
      await tester.pumpAndSettle();
      expect(key('own-cycle-close'), findsNothing);
      expect(app.title, '¿Cómo es tu rotación?');
      expect(
        app.container.read(onboardingControllerProvider).customSteps,
        isNull,
      );
      expect(await savedNothing(app), isTrue);
    });

    testWidgets('the close button asks the same, and the draft of an earlier '
        'opening is not kept', (tester) async {
      final app = await FirstLaunch.open(tester);
      await app.chooseRotation();
      await build(app, ['night']);
      await app.tap(key('own-cycle-close'));
      expect(find.text('¿Descartar la secuencia?'), findsOneWidget);
      await tester.tap(find.text('Descartar'));
      await tester.pumpAndSettle();
      expect(app.title, '¿Cómo es tu rotación?');

      // Opened again, it starts empty (the family is autoDispose).
      await app.tap(key('onboarding-own-cycle-new'));
      expect(find.text('1 día'), findsNothing);
      final use = find.widgetWithText(FilledButton, 'Usar este ciclo');
      expect(tester.widget<FilledButton>(use).onPressed, isNull);
    });

    testWidgets('from the start day, back shows the cycle chosen on its card '
        'with «Editar», «Quitar» and «Crear otro ciclo»', (tester) async {
      final app = await FirstLaunch.open(tester);
      await app.chooseRotation();
      await build(app, sequence);
      await app.tap(key('own-cycle-use'));
      expect(app.title, '¿Cuándo empiezas?');
      await app.tap(key('onboarding-back'));
      expect(app.title, '¿Cómo es tu rotación?');

      final card = key('onboarding-own-cycle');
      expect(card, findsOneWidget);
      expect(
        find.descendant(of: card, matching: find.text('Mi ciclo')),
        findsOne,
      );
      expect(
        find.descendant(of: card, matching: find.text('9 días')),
        findsOne,
      );
      expect(
        app.container.read(onboardingControllerProvider).hasOwnCycle,
        isTrue,
      );
      expect(key('onboarding-own-cycle-new'), findsNothing);
      expect(find.text('Crear otro ciclo'), findsOneWidget);
      expect(find.text('Quitar'), findsOneWidget);

      // Picking a rotation of the list leaves the card there, not chosen.
      await app.tap(key('onboarding-pattern-12h'));
      var state = app.container.read(onboardingControllerProvider);
      expect(state.hasOwnCycle, isFalse);
      expect(state.customSteps, isNotNull);
      expect(card, findsOneWidget);
      await app.tap(card);
      state = app.container.read(onboardingControllerProvider);
      expect(state.hasOwnCycle, isTrue);
      expect(state.presetId, isNull);

      // «Editar» opens «Tu ciclo» with the days it had, unchanged: closing it
      // asks nothing.
      await app.tap(find.descendant(of: card, matching: find.text('Editar')));
      expect(key('own-cycle-close'), findsOneWidget);
      expect(find.text('9 días'), findsWidgets);
      await app.tap(key('own-cycle-close'));
      expect(find.text('¿Descartar la secuencia?'), findsNothing);
      expect(key('own-cycle-close'), findsNothing);

      // «Quitar» takes it out.
      await app.tap(find.text('Quitar'));
      expect(card, findsNothing);
      expect(key('onboarding-own-cycle-new'), findsOneWidget);
      expect(
        app.container.read(onboardingControllerProvider).hasRotation,
        isFalse,
      );
    });
  });

  group('«Ajustar»', () {
    testWidgets('opens the builder with the rotation loaded; the result is '
        'an own cycle and the original stays', (tester) async {
      final app = await FirstLaunch.open(tester);
      await app.chooseRotation();
      final preset = patternPresetById('12h');
      await app.tap(
        find.descendant(
          of: key('onboarding-pattern-12h'),
          matching: find.text('Ajustar'),
        ),
      );
      expect(key('own-cycle-close'), findsOneWidget);
      expect(
        find.text(
          preset.steps.length == 1 ? '1 día' : '${preset.steps.length} días',
        ),
        findsWidgets,
      );
      // Unchanged: closing asks nothing; changed: «Usar este ciclo» takes it.
      await app.tap(key('builder-add-rest'));
      await app.tap(key('own-cycle-use'));
      expect(app.title, '¿Cuándo empiezas?');
      final state = app.container.read(onboardingControllerProvider);
      expect(state.hasOwnCycle, isTrue);
      expect(state.customSteps!.length, preset.steps.length + 1);
      expect(state.presetId, isNull);
      expect(state.customName, 'Mi ciclo');
      expect(patternPresetById('12h').steps.length, preset.steps.length);
    });
  });

  group('review fixes', () {
    testWidgets('the sheets of a block offer the first-use shifts: Enfermería, '
        'the app in Basque over a Spanish base, no absences', (tester) async {
      final app = await FirstLaunch.open(tester);
      await app.tap(key('onboarding-language'));
      await app.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('Euskara'),
        ),
      );
      await app.chooseRotation();
      await app.tap(key('onboarding-profession-nursing'));
      await app.tap(key('onboarding-own-cycle-new'));
      await app.tap(key('builder-add-morning'));
      await app.tap(key('block-options'));

      // «Cambiar el turno».
      await app.tap(key('block-change-shift'));
      expect(key('block-replace-night'), findsOneWidget);
      expect(key('block-replace-vacation'), findsNothing);
      expect(key('block-replace-personalDay'), findsNothing);
      expect(find.textContaining('Mañana'), findsNothing, reason: 'Spanish');
      expect(
        find.descendant(
          of: key('block-replace-morning'),
          matching: find.textContaining('15'),
        ),
        findsWidgets,
        reason: 'the nurse: 08-15',
      );
      expect(
        find.descendant(
          of: key('block-replace-morning'),
          matching: find.textContaining('14'),
        ),
        findsNothing,
        reason: 'not the factory 06-14',
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      // «Varios turnos en un día».
      await app.tap(key('block-same-day'));
      expect(key('block-add-night'), findsOneWidget);
      expect(key('block-add-vacation'), findsNothing);
      expect(key('block-add-personalDay'), findsNothing);
      expect(find.textContaining('Mañana'), findsNothing, reason: 'Spanish');
      expect(find.textContaining('Tarde'), findsNothing, reason: 'Spanish');
    });

    testWidgets('«Ajustar» keeps the work shift chosen for the rotation', (
      tester,
    ) async {
      final app = await FirstLaunch.open(tester);
      await app.chooseRotation();
      await app.tap(key('onboarding-pattern-2x2'));
      app.container
          .read(onboardingControllerProvider.notifier)
          .setWorkShift('night');
      await tester.pumpAndSettle();
      await app.tap(
        find.descendant(
          of: key('onboarding-pattern-2x2'),
          matching: find.text('Ajustar'),
        ),
      );
      final draft = app.container
          .read(patternWizardProvider(firstUseWizardArgs))
          .draft;
      expect(draft, [
        ['night'],
        ['night'],
        ['rest'],
        ['rest'],
      ]);
    });

    testWidgets('the palette is the factory one, whatever the base holds: an '
        'imported type is not offered', (tester) async {
      final app = await FirstLaunch.open(tester);
      app.container
          .read(scheduleControllerProvider.notifier)
          .saveShiftType(
            const ShiftType(
              id: 'imported-z',
              code: 'Z',
              name: 'Importado',
              colorValue: 0xFF123456,
              category: ShiftCategory.work,
              startMinute: 480,
              endMinute: 900,
            ),
          );
      await app.flushWrites();
      await app.chooseRotation();
      await app.tap(key('onboarding-own-cycle-new'));
      expect(key('builder-add-imported-z'), findsNothing);
      final offered = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('builder-add-'),
      );
      expect(offered, findsNWidgets(8));
      for (final id in [
        'morning',
        'afternoon',
        'night',
        'rest',
        'guard24',
        'postNight',
        'day12',
        'night12',
      ]) {
        expect(key('builder-add-$id'), findsOneWidget, reason: id);
      }
    });

    testWidgets('the first-use wizard never shares a draft with a wizard of '
        'the route /patron?turno=first-use', (tester) async {
      final app = await FirstLaunch.open(tester);
      const route = PatternWizardArgs(shiftId: 'first-use');
      expect(route, isNot(firstUseWizardArgs));
      // Two live consumers at once.
      final keepRoute = app.container.listen(
        patternWizardProvider(route),
        (_, _) {},
      );
      final keepFirstUse = app.container.listen(
        patternWizardProvider(firstUseWizardArgs),
        (_, _) {},
      );
      addTearDown(keepRoute.close);
      addTearDown(keepFirstUse.close);
      app.container
          .read(patternWizardProvider(route).notifier)
          .appendShift('night');
      final own = app.container.read(
        patternWizardProvider(firstUseWizardArgs).notifier,
      );
      own.appendShift('morning');
      own.appendShift('morning');
      expect(app.container.read(patternWizardProvider(route)).draft, [
        ['night'],
      ]);
      expect(
        app.container.read(patternWizardProvider(firstUseWizardArgs)).draft,
        [
          ['morning'],
          ['morning'],
        ],
      );
    });

    testWidgets('the row of jobs shows that there are more, and a swipe '
        'reaches the hidden one', (tester) async {
      final app = await FirstLaunch.open(tester);
      await app.chooseRotation();
      final view = tester.getRect(key('onboarding-profession-chips'));
      final last = key('onboarding-profession-hospitality');
      expect(tester.getRect(last).left, greaterThan(view.right));

      double opacity(String side) => tester
          .widget<AnimatedOpacity>(
            find.ancestor(
              of: key('onboarding-profession-fade-$side'),
              matching: find.byType(AnimatedOpacity),
            ),
          )
          .opacity;
      expect(opacity('end'), 1, reason: 'more jobs on the right');
      expect(opacity('start'), 0);

      await tester.drag(
        key('onboarding-profession-chips'),
        const Offset(-3000, 0),
      );
      await tester.pumpAndSettle();
      final rect = tester.getRect(last);
      expect(rect.left, greaterThanOrEqualTo(view.left));
      expect(rect.right, lessThanOrEqualTo(view.right + 0.5));
      expect(opacity('end'), 0);
      expect(opacity('start'), 1, reason: 'jobs on the left now');
    });

    testWidgets('the keyboard reaches a job that was hidden', (tester) async {
      final app = await FirstLaunch.open(tester);
      await app.chooseRotation();
      final view = tester.getRect(key('onboarding-profession-chips'));
      expect(
        tester.getRect(key('onboarding-profession-hospitality')).left,
        greaterThan(view.right),
      );
      bool onHospitality() {
        final focus = FocusManager.instance.primaryFocus?.context;
        final pill = focus?.findAncestorWidgetOfExactType<ChoicePill>();
        return pill?.key == const ValueKey('onboarding-profession-hospitality');
      }

      var presses = 0;
      while (!onHospitality() && presses < 80) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        presses++;
      }
      expect(onHospitality(), isTrue, reason: 'Tab reaches it');
      final rect = tester.getRect(key('onboarding-profession-hospitality'));
      expect(rect.left, greaterThanOrEqualTo(view.left));
      expect(rect.right, lessThanOrEqualTo(view.right + 0.5));
      // And Enter chooses it.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(
        app.container.read(onboardingControllerProvider).profession?.name,
        'hospitality',
      );
    });

    testWidgets('closing with only the name edited asks, and «Seguir '
        'editando» keeps the text and the focus', (tester) async {
      final app = await FirstLaunch.open(tester);
      await app.chooseRotation();
      await app.tap(key('onboarding-own-cycle-new'));
      await app.tap(key('builder-name'));
      await tester.enterText(key('builder-name'), 'Mi enfermería');
      await tester.pumpAndSettle();
      EditableText field() => tester.widget<EditableText>(
        find.descendant(
          of: key('builder-name'),
          matching: find.byType(EditableText),
        ),
      );
      expect(field().focusNode.hasFocus, isTrue);

      await tester.tap(key('own-cycle-close'));
      await tester.pumpAndSettle();
      expect(find.text('¿Descartar la secuencia?'), findsOneWidget);
      await tester.tap(find.text('Seguir editando'));
      await tester.pumpAndSettle();
      expect(key('own-cycle-close'), findsOneWidget);
      expect(field().controller.text, 'Mi enfermería');
      expect(field().focusNode.hasFocus, isTrue, reason: 'focus kept');

      // And «Descartar» does close it.
      await tester.tap(key('own-cycle-close'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Descartar'));
      await tester.pumpAndSettle();
      expect(key('own-cycle-close'), findsNothing);
    });
  });

  group('M2: «Siguiente» and «Continuar» with text at 2.0', () {
    final scroll = find.byType(SingleChildScrollView).first;

    for (final (name, size) in [
      ('portrait 320 dp', const Size(320, 640)),
      ('portrait 412 dp', const Size(412, 892)),
      ('landscape', const Size(640, 320)),
    ]) {
      testWidgets('$name: both buttons are on screen without scrolling', (
        tester,
      ) async {
        final app = await FirstLaunch.open(tester, size: size, textScale: 2);
        await app.chooseRotation();
        void expectPinned(String step) {
          final next = tester.getRect(key('onboarding-next'));
          expect(
            find.descendant(of: scroll, matching: key('onboarding-next')),
            findsNothing,
            reason: '$step: outside the scroll',
          );
          expect(next.top, greaterThanOrEqualTo(tester.getRect(scroll).bottom));
          expect(next.top, greaterThanOrEqualTo(0), reason: step);
          expect(next.bottom, lessThanOrEqualTo(size.height + 0.5));
        }

        expect(app.title, '¿Cómo es tu rotación?');
        expectPinned('step 2');
        await app.tap(key('onboarding-pattern-12h'));
        expectPinned('step 2, chosen');
        await app.tap(key('onboarding-next'));
        expect(app.title, '¿Cuándo empiezas?');
        expectPinned('step 3');
        expect(tester.takeException(), isNull);
      });
    }

    for (final (name, size) in [
      ('portrait 320 dp', const Size(320, 640)),
      ('landscape', const Size(640, 320)),
    ]) {
      testWidgets('$name: the button of the place step is pinned too', (
        tester,
      ) async {
        final app = await FirstLaunch.open(tester, size: size, textScale: 2);
        await app.choosePath('rotation');
        expect(app.title, '¿Dónde trabajas?');
        final next = tester.getRect(key('onboarding-next'));
        expect(
          find.descendant(of: scroll, matching: key('onboarding-next')),
          findsNothing,
        );
        expect(next.top, greaterThanOrEqualTo(tester.getRect(scroll).bottom));
        expect(next.bottom, lessThanOrEqualTo(size.height + 0.5));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('«Tu ciclo» at 2.0: «Usar este ciclo» is reachable and the '
        'sequence can be built', (tester) async {
      final app = await FirstLaunch.open(
        tester,
        size: const Size(320, 640),
        textScale: 2,
      );
      await app.chooseRotation();
      await app.tap(key('onboarding-own-cycle-new'));
      await app.tap(key('builder-add-night'));
      final use = tester.getRect(key('own-cycle-use'));
      expect(use.bottom, lessThanOrEqualTo(640.5));
      expect(use.top, greaterThan(0));
      expect(tester.takeException(), isNull);
    });
  });
}
