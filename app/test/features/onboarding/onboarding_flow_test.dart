import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:cuadrante/core/format/text_wrap.dart';
import 'package:cuadrante/core/icons/app_icons.dart';
import 'package:cuadrante/core/widgets/choice_pill.dart';
import 'package:cuadrante/features/backup/presentation/backup_screen.dart';
import 'package:cuadrante/features/calendar/application/paint_controller.dart';
import 'package:cuadrante/features/calendar/presentation/month_screen.dart';
import 'package:cuadrante/core/database/database_provider.dart';
import 'package:cuadrante/features/calendars/domain/calendar.dart';
import 'package:cuadrante/features/holidays/application/holidays_provider.dart';
import 'package:cuadrante/features/onboarding/application/onboarding_controller.dart';
import 'package:cuadrante/features/schedule/application/schedule_providers.dart';
import 'package:cuadrante/features/schedule/data/schedule_repository.dart';
import 'package:cuadrante/features/holidays/domain/holiday.dart';
import 'package:cuadrante/features/import/application/import_providers.dart';
import 'package:cuadrante/features/import/data/import_file_picker.dart';
import 'package:cuadrante/features/holidays/domain/holiday_place.dart';
import 'package:cuadrante/features/onboarding/data/onboarding_repository.dart';
import 'package:cuadrante/features/onboarding/domain/profession.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../backup/backup_ui_support.dart' show BackupUiHarness, pumpIo;
import '../import/import_ui_support.dart' show FakePicker;
import 'onboarding_support.dart';

Future<void> _next(FirstLaunch app) => app.tap(key('onboarding-next'));

FilledButton _nextButton(WidgetTester tester) => tester.widget<FilledButton>(
  find.descendant(
    of: key('onboarding-next'),
    matching: find.byType(FilledButton),
  ),
);

/// «Usar una rotación», the 12 h one chosen, on its start day.
Future<void> _toStart(FirstLaunch app, {String preset = '12h'}) async {
  await app.choosePath('rotation');
  await app.tap(key('onboarding-pattern-$preset'));
  await _next(app);
}

/// Nursing and Comunidad de Madrid, on the last step.
Future<void> _nurseInMadrid(FirstLaunch app) async {
  await app.tap(key('onboarding-profession-nursing'));
  await app.tap(key('onboarding-region'));
  await app.tap(find.text('Comunidad de Madrid'));
}

/// Shift-type writes that take their time (and can fail), to see whether the
/// flow waits for them.
class _SlowTypes extends ScheduleRepository {
  _SlowTypes(super.db, {super.now, this.fail = false});

  final bool fail;
  final saved = <String>[];

  @override
  Future<void> saveShiftType(ShiftType type, {int? sortOrder}) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (fail) throw StateError('disk full');
    await super.saveShiftType(type, sortOrder: sortOrder);
    saved.add(type.id);
  }
}

void main() {
  setUpAll(initializeLocale);

  group('the first question: ¿Cómo empiezas tu cuadrante?', () {
    testWidgets('opens first: three ways, the backup, no bar, no button', (
      tester,
    ) async {
      final app = await FirstLaunch.open(tester);
      expect(find.byType(MonthScreen), findsNothing);
      expect(app.title, '¿Cómo empiezas tu cuadrante?');
      final cards = [
        for (final path in ['import', 'rotation', 'paint'])
          key('onboarding-path-$path'),
      ];
      for (final card in cards) {
        expect(card, findsOneWidget);
      }
      // In the order of the design: import, rotation, by hand.
      final ys = [for (final c in cards) tester.getTopLeft(c).dy];
      expect(ys, orderedEquals([...ys]..sort()));
      expect(find.text('Importar mis turnos'), findsOneWidget);
      expect(find.text('Usar una rotación'), findsOneWidget);
      expect(find.text('Si tu turno se repite'), findsOneWidget);
      expect(find.text('Pintar a mano'), findsOneWidget);
      expect(find.text('Recuperar una copia de seguridad'), findsOneWidget);
      expect(
        tester.getTopLeft(key('onboarding-restore')).dy,
        greaterThan(ys.last),
        reason: 'the backup is under the three ways',
      );
      expect(key('onboarding-language'), findsOneWidget);
      // One question, nothing else: no back, no «Saltar», no dots, no
      // «Siguiente» (the cards go on by themselves).
      expect(key('onboarding-back'), findsNothing);
      expect(key('onboarding-skip'), findsNothing);
      expect(key('onboarding-dots'), findsNothing);
      expect(key('onboarding-next'), findsNothing);
    });

    testWidgets('the system back button leaves the flow from here', (
      tester,
    ) async {
      final app = await FirstLaunch.open(tester);
      await app.choosePath('rotation');
      expect(app.title, '¿Cómo es tu rotación?');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(app.title, '¿Cómo empiezas tu cuadrante?');
    });
  });

  group('Usar una rotación', () {
    testWidgets('the whole catalogue (no job yet) and «Lo pinto a mano»', (
      tester,
    ) async {
      final app = await FirstLaunch.open(tester);
      await app.choosePath('rotation');
      expect(app.title, '¿Cómo es tu rotación?');
      expect(find.text('LO HABITUAL EN TU TRABAJO'), findsNothing);
      expect(find.text('ROTACIONES'), findsOneWidget);
      expect(key('onboarding-by-hand'), findsOneWidget);
      expect(key('onboarding-pattern-12h'), findsOneWidget);
      expect(key('onboarding-pattern-24x72'), findsOneWidget);
    });

    testWidgets(
      'Siguiente needs a rotation; then the start day and cycle day',
      (tester) async {
        final app = await FirstLaunch.open(tester);
        await app.choosePath('rotation');
        expect(_nextButton(tester).onPressed, isNull);
        await app.tap(key('onboarding-pattern-12h'));
        expect(_nextButton(tester).onPressed, isNotNull);
        await _next(app);

        expect(app.title, '¿Cuándo empiezas?');
        expect(find.text('Lunes 19 de octubre 2026'), findsOneWidget);
        expect(
          find.text(
            keepTimeRangesTogether('Ese día te toca: Día 12 h 08:00–20:00'),
          ),
          findsOneWidget,
        );
        await app.tap(key('onboarding-shift-night12'));
        expect(
          find.text(
            keepTimeRangesTogether('Ese día te toca: Noche 12 h 20:00–08:00'),
          ),
          findsOneWidget,
        );
        await _next(app);
        expect(app.title, '¿Dónde trabajas?');
      },
    );

    testWidgets('a shift that repeats asks which of its days', (tester) async {
      final app = await FirstLaunch.open(tester);
      await app.choosePath('rotation');
      await app.tap(key('onboarding-pattern-continental'));
      await _next(app);
      expect(app.title, '¿Cuándo empiezas?');

      // «Mañana» appears several times in the 28-day cycle: after picking it
      // the picker asks which of its days, one option per day of the run,
      // labelled by its run (no counting). Its three runs are all after
      // Libre, so the run number is what tells them apart.
      await app.tap(key('onboarding-shift-morning'));
      expect(key('onboarding-occurrence-0'), findsOneWidget);
      expect(key('onboarding-offset-0'), findsNothing, reason: 'grid hidden');
      expect(
        find.text('Tanda 1 · Día 1 de 2, después de Libre'),
        findsOneWidget,
      );
      expect(
        find.text('Tanda 2 · Día 1 de 2, después de Libre'),
        findsOneWidget,
      );
      expect(
        find.text('Tanda 3 · Día 1 de 3, después de Libre'),
        findsOneWidget,
      );
      // Every option of the shift has a label of its own: no two pills read
      // the same.
      final labels = [
        for (final pill in tester.widgetList<ChoicePill>(find.byType(ChoicePill)))
          if (pill.key is ValueKey<String> &&
              (pill.key! as ValueKey<String>).value.startsWith(
                'onboarding-occurrence-',
              ))
            pill.label,
      ];
      expect(labels.toSet(), hasLength(labels.length));
      await app.tap(key('onboarding-occurrence-9'));
      await _next(app);
      await app.tap(key('onboarding-profession-nursing'));
      await _next(app);

      expect(app.title, 'Listo');
      // The 10th day of the cycle is a morning (M2 T2 N3 L2 M2...).
      expect(
        find.textContaining('Empiezas en el día 10 del ciclo (Mañana)'),
        findsOneWidget,
      );
    });

    testWidgets('tapping the shift already chosen keeps the cycle day', (
      tester,
    ) async {
      final app = await FirstLaunch.open(tester);
      await app.choosePath('rotation');
      await app.tap(key('onboarding-pattern-continental'));
      await _next(app);

      // Choose the first day of the second morning run (day 10 of the cycle,
      // offset 9)…
      await app.tap(key('onboarding-shift-morning'));
      await app.tap(key('onboarding-occurrence-9'));
      expect(app.container.read(onboardingControllerProvider).stepOffset, 9);
      // …and tapping the same shift again must not jump back to its first
      // day (offset 0).
      await app.tap(key('onboarding-shift-morning'));
      expect(app.container.read(onboardingControllerProvider).stepOffset, 9);
    });

    testWidgets('the catalogue cards talk the app language, not the phone\'s', (
      tester,
    ) async {
      // The database is seeded in the phone's language (English); the app
      // follows the phone but the person may have another one. Here the
      // phone is English and the app shows Spanish.
      debugPhoneLocales = const [Locale('en', 'US')];
      addTearDown(() => debugPhoneLocales = const [Locale('es', 'ES')]);
      final app = await FirstLaunch.open(tester);
      await app.choosePath('rotation');

      // The chips of a card with afternoon and off: Spanish T/L, not the
      // stored English A/O.
      final card = key('onboarding-pattern-correturnos');
      expect(
        find.descendant(of: card, matching: find.text('T')),
        findsWidgets,
        reason: 'Tarde, in the app language',
      );
      expect(find.descendant(of: card, matching: find.text('L')), findsWidgets);
      expect(
        find.descendant(of: card, matching: find.text('A')),
        findsNothing,
        reason: 'the phone\'s English code must not show',
      );
      expect(find.descendant(of: card, matching: find.text('O')), findsNothing);
    });

    testWidgets('the «Así quedará» preview talks the app language too', (
      tester,
    ) async {
      // Found on a real phone (0.8.4): the chips said «Tarde» but the month
      // preview drew the stored English «A» (Afternoon).
      debugPhoneLocales = const [Locale('en', 'US')];
      addTearDown(() => debugPhoneLocales = const [Locale('es', 'ES')]);
      final app = await FirstLaunch.open(tester);
      await app.choosePath('rotation');
      await app.tap(key('onboarding-pattern-correturnos'));
      await _next(app);
      await app.tap(key('onboarding-shift-afternoon'));

      final preview = key('onboarding-pattern-preview');
      await tester.ensureVisible(preview);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: preview, matching: find.text('T')),
        findsWidgets,
        reason: 'Tarde, in the app language',
      );
      expect(
        find.descendant(of: preview, matching: find.text('A')),
        findsNothing,
        reason: 'the phone\'s English code must not show',
      );
    });

    testWidgets('the job chosen at the end orders the catalogue on the way '
        'back, and keeps the rotation', (tester) async {
      final app = await FirstLaunch.open(tester);
      await _toStart(app);
      await _next(app);
      await app.tap(key('onboarding-profession-nursing'));
      await app.tap(key('onboarding-back')); // start
      await app.tap(key('onboarding-back')); // rotation
      expect(find.text('LO HABITUAL EN TU TRABAJO'), findsOneWidget);
      expect(find.text('OTRAS ROTACIONES'), findsOneWidget);
      // Nursing: 12 h, correturnos, continental, 5x2 ... then the others.
      final order = [
        for (final id in ['12h', 'correturnos', 'continental', '5x2', '24x72'])
          tester.getTopLeft(key('onboarding-pattern-$id')).dy,
      ];
      expect(order, orderedEquals([...order]..sort()));
      expect(
        tester.getTopLeft(key('onboarding-by-hand')).dy,
        lessThan(tester.getTopLeft(key('onboarding-pattern-24x72')).dy),
      );
      // Choosing the job did not throw the rotation away.
      expect(_nextButton(tester).onPressed, isNotNull);
      expect(app.container.read(onboardingControllerProvider).presetId, '12h');
    });

    testWidgets('"Lo pinto a mano" goes to the last step without rotation, '
        'and the month opens ready to paint', (tester) async {
      final app = await FirstLaunch.open(tester);
      await app.choosePath('rotation');
      await app.tap(key('onboarding-by-hand'));
      expect(app.title, '¿Dónde trabajas?');
      await _next(app);
      expect(app.title, 'Listo');
      expect(find.text('Rotación: la pintas tú a mano'), findsOneWidget);
      await app.flushWrites();
      expect(app.schedule.runs, isEmpty);
      await app.tap(key('onboarding-next'));
      expect(find.byType(MonthScreen), findsOneWidget);
      expect(app.container.read(paintControllerProvider).active, isTrue);
      expect(idsOn(app.schedule, onboardingToday), '');
    });
  });

  group('Importar mis turnos', () {
    Future<void> toImport(FirstLaunch app) => app.choosePath('import');

    testWidgets('offers the import, LRHSoft and Continuar; no rotation', (
      tester,
    ) async {
      final app = await FirstLaunch.open(tester);
      await toImport(app);
      expect(app.title, '¿Vienes de otra app?');
      expect(find.textContaining('0.5.0'), findsNothing);
      expect(key('onboarding-import'), findsOneWidget);
      expect(find.text('Importar ahora'), findsOneWidget);
      expect(find.text('Continuar'), findsOneWidget);
      await _next(app);
      expect(app.title, '¿Dónde trabajas?');
      await _next(app);
      expect(app.title, 'Listo');
      await app.flushWrites();
      expect(app.schedule.runs, isEmpty);
      await app.tap(key('onboarding-next'));
      expect(find.byType(MonthScreen), findsOneWidget);
      expect(app.container.read(paintControllerProvider).active, isFalse);
    });

    testWidgets('LRHSoft users get their own button: the .Shifter backup', (
      tester,
    ) async {
      final picker = FakePicker();
      final app = await FirstLaunch.open(
        tester,
        overrides: [importFilePickerProvider.overrideWithValue(picker.call)],
      );
      await toImport(app);
      expect(find.text('Importar copia de LRHSoft'), findsOneWidget);
      // It opens the import and asks for the backup file right away.
      await app.tap(key('onboarding-import-lrhsoft'));
      expect(picker.asked, [ImportFileKind.lrhsoft]);
      expect(find.text('¿De dónde vienen tus turnos?'), findsOneWidget);
      expect(key('import-source-lrhsoft'), findsOneWidget);
    });

    testWidgets('the button opens the import and Atrás returns to the step', (
      tester,
    ) async {
      final app = await FirstLaunch.open(tester);
      await toImport(app);
      await app.tap(key('onboarding-import'));
      expect(find.text('¿De dónde vienen tus turnos?'), findsOneWidget);
      expect(key('import-source-device'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(app.title, '¿Vienes de otra app?');
      // Nothing was written by opening the import.
      await app.flushWrites();
      expect(app.schedule.runs, isEmpty);
    });

    testWidgets('what was imported stays, and the last step is still saved '
        'over it', (tester) async {
      final app = await FirstLaunch.open(tester);
      await toImport(app);
      await app.tap(key('onboarding-import'));
      // The import brings a shift (written as the import screen would).
      await app.real(
        () => ScheduleRepository(app.database, now: () => onboardingNow).apply(
          mainCalendarId,
          ScheduleChange(
            patch: EntriesPatch({
              onboardingToday: EntryChange(
                null,
                DayEntry(date: onboardingToday, shiftTypeIds: const ['night']),
              ),
            }),
          ),
        ),
      );
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await _next(app);
      await _nurseInMadrid(app);
      await _next(app);
      expect(app.title, 'Listo');
      expect(
        find.text('Trabajo: Enfermería, TCAE y celadores'),
        findsOneWidget,
      );
      await app.flushWrites();
      expect(
        await app.real(OnboardingRepository(app.database).loadProfile),
        Profession.nursing,
      );
      expect(app.container.read(holidayPlaceProvider).regionCode, 'ES-MD');
      final days = await app.real(
        () => app.database.select(app.database.dayEntries).get(),
      );
      expect(days, hasLength(1), reason: 'the imported day is kept');
    });
  });

  group('Pintar a mano', () {
    testWidgets('straight to the last step, «Paso 1 de 1 · Opcional», then '
        'the month in paint mode', (tester) async {
      final app = await FirstLaunch.open(tester);
      await app.choosePath('paint');
      expect(app.title, '¿Dónde trabajas?');
      expect(find.text('Paso 1 de 1 · Opcional'), findsOneWidget);
      await _next(app);
      expect(app.title, 'Listo');
      expect(find.text('Rotación: la pintas tú a mano'), findsOneWidget);
      await app.tap(key('onboarding-next'));
      expect(find.byType(MonthScreen), findsOneWidget);
      expect(app.container.read(paintControllerProvider).active, isTrue);
      await app.flushWrites();
      expect(app.schedule.runs, isEmpty);
      expect(await app.real(OnboardingRepository(app.database).isDone), isTrue);
    });

    testWidgets('back from the last step returns to the question; another '
        'way forgets «a mano»', (tester) async {
      final app = await FirstLaunch.open(tester);
      await app.choosePath('paint');
      await app.tap(key('onboarding-back'));
      expect(app.title, '¿Cómo empiezas tu cuadrante?');
      await app.choosePath('import');
      expect(app.container.read(onboardingControllerProvider).byHand, isFalse);
    });
  });

  group('Recuperar una copia de seguridad', () {
    /// The first question, and the backups opened from it (with the real
    /// I/O the screen does, as in the backup tests).
    Future<FirstLaunch> openBackups(WidgetTester tester) async {
      final backups = BackupUiHarness(tester);
      final app = await FirstLaunch.open(tester, overrides: backups.overrides);
      await tester.ensureVisible(key('onboarding-restore'));
      await tester.pumpAndSettle();
      await tester.tap(key('onboarding-restore'));
      await pumpIo(tester, until: find.byType(BackupScreen));
      await pumpIo(tester);
      return app;
    }

    testWidgets('opens the backups; back returns to the question', (
      tester,
    ) async {
      final app = await openBackups(tester);
      expect(find.byType(BackupScreen), findsOneWidget);
      await tester.binding.handlePopRoute();
      await pumpIo(tester, until: key('onboarding-title'));
      expect(app.title, '¿Cómo empiezas tu cuadrante?');
      expect(
        await app.real(OnboardingRepository(app.database).isDone),
        isFalse,
      );
    });

    testWidgets('after a restore the flow ends on the month', (tester) async {
      final app = await openBackups(tester);
      // What a finished restore leaves (`RestoreCoordinator`): the data and
      // the first use marked as done.
      await app.real(() => OnboardingRepository(app.database).markDone());
      await tester.binding.handlePopRoute();
      await pumpIo(tester, until: find.byType(MonthScreen));
      expect(find.byType(MonthScreen), findsOneWidget);
      expect(key('onboarding-title'), findsNothing);
    });
  });

  group('last step: ¿Dónde trabajas?', () {
    testWidgets('the 19 communities in a list; the municipality needs one', (
      tester,
    ) async {
      final app = await FirstLaunch.open(tester);
      await app.toLastStep();
      expect(app.title, '¿Dónde trabajas?');
      expect(find.text('Elige antes la comunidad'), findsOneWidget);

      await app.tap(key('onboarding-region'));
      // 19 rows: 17 communities, Ceuta and Melilla.
      for (final name in [
        'Andalucía',
        'Catalunya',
        'Comunidad de Madrid',
        'Ceuta',
        'Melilla',
        'País Vasco',
      ]) {
        await tester.ensureVisible(find.text(name));
        expect(find.text(name), findsOneWidget, reason: name);
      }
      await tester.tap(find.text('Catalunya'));
      await tester.pumpAndSettle();
      expect(find.text('Catalunya'), findsOneWidget);
      expect(find.text('Buscar municipio'), findsOneWidget);
    });

    testWidgets('the municipality is searched, filtered by region', (
      tester,
    ) async {
      final app = await FirstLaunch.open(tester);
      await app.toLastStep();
      await app.tap(key('onboarding-region'));
      await app.tap(find.text('Comunidad de Madrid'));
      await app.tap(key('onboarding-municipality'));

      // Accents and capitals do not matter; only Madrid's own are offered.
      await tester.enterText(
        key('onboarding-municipality-search'),
        'alcala de h',
      );
      await tester.pumpAndSettle();
      expect(find.text('Alcalá de Henares'), findsOneWidget);
      expect(find.text('Barcelona'), findsNothing);

      await tester.enterText(key('onboarding-municipality-search'), 'zzzz');
      await tester.pumpAndSettle();
      expect(find.text('Ningún municipio se llama así'), findsOneWidget);

      await tester.enterText(key('onboarding-municipality-search'), 'madrid');
      await tester.pumpAndSettle();
      await tester.tap(key('municipality-28079'));
      await tester.pumpAndSettle();
      expect(find.text('Madrid'), findsOneWidget);
      // Madrid's locals are in the bundle: no note.
      expect(key('onboarding-local-missing'), findsNothing);
    });

    testWidgets('a municipality without local holidays says so', (
      tester,
    ) async {
      final app = await FirstLaunch.open(tester);
      await app.toLastStep();
      await app.tap(key('onboarding-region'));
      await app.tap(find.text('Andalucía'));
      await app.tap(key('onboarding-municipality'));
      await tester.enterText(
        key('onboarding-municipality-search'),
        'dos hermanas',
      );
      await tester.pumpAndSettle();
      await tester.tap(key('municipality-41038'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Los festivos locales de tu municipio los puedes añadir tú en dos '
          'toques.',
        ),
        findsOneWidget,
      );
      // Taking the municipality off removes the note; changing the community
      // drops the municipality.
      await app.tap(key('onboarding-municipality-clear'));
      expect(key('onboarding-local-missing'), findsNothing);
      expect(find.text('Buscar municipio'), findsOneWidget);
    });

    testWidgets('changing the community forgets the municipality', (
      tester,
    ) async {
      final app = await FirstLaunch.open(tester);
      await app.toLastStep();
      await app.tap(key('onboarding-region'));
      await app.tap(find.text('Comunidad de Madrid'));
      await app.tap(key('onboarding-municipality'));
      await tester.enterText(key('onboarding-municipality-search'), 'getafe');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Getafe'));
      await tester.pumpAndSettle();
      expect(find.text('Getafe'), findsOneWidget);

      await app.tap(key('onboarding-region'));
      await app.tap(find.text('Catalunya'));
      expect(find.text('Getafe'), findsNothing);
      expect(find.text('Buscar municipio'), findsOneWidget);
    });
  });

  group('last step: ¿A qué te dedicas? (optional)', () {
    testWidgets('one pill per job; the chosen one has a check and its hours', (
      tester,
    ) async {
      final app = await FirstLaunch.open(tester);
      await app.toLastStep();
      for (final p in spainProfessions) {
        expect(
          key('onboarding-profession-${p.name}'),
          findsOneWidget,
          reason: p.name,
        );
      }
      // The neutral jobs are for other countries (D5).
      expect(key('onboarding-profession-commerce'), findsNothing);
      expect(key('onboarding-profession-transport'), findsNothing);
      expect(find.text('Enfermería, TCAE y celadores'), findsOneWidget);
      expect(find.text('Policía y Guardia Civil'), findsOneWidget);
      expect(key('onboarding-profession-hint'), findsNothing);

      await app.tap(key('onboarding-profession-police'));
      expect(
        find.descendant(
          of: key('onboarding-profession-police'),
          matching: find.byIcon(AppIcons.check),
        ),
        findsOneWidget,
        reason: 'la elegida lleva marca, no solo color',
      );
      final hint = tester.widget<Text>(key('onboarding-profession-hint'));
      expect(hint.data, keepTimeRangesTogether('M 07–15, T 15–23 y N 23–07'));

      // Optional: the chosen one, tapped again, leaves none.
      await app.tap(key('onboarding-profession-police'));
      expect(app.container.read(onboardingControllerProvider).profession, null);
      expect(key('onboarding-profession-hint'), findsNothing);
      // «Continuar» never waits for a job.
      expect(_nextButton(tester).onPressed, isNotNull);
    });
  });

  group('navigation', () {
    testWidgets('back keeps what was chosen, screen by screen', (tester) async {
      final app = await FirstLaunch.open(tester);
      await _toStart(app, preset: 'continental');
      await app.selectCycleDay(3);
      await _next(app);
      await _nurseInMadrid(app);
      expect(app.title, '¿Dónde trabajas?');

      await app.tap(key('onboarding-back'));
      expect(app.title, '¿Cuándo empiezas?');
      await app.tap(key('onboarding-back'));
      expect(app.title, '¿Cómo es tu rotación?');
      await app.tap(key('onboarding-back'));
      expect(app.title, '¿Cómo empiezas tu cuadrante?');
      expect(key('onboarding-back'), findsNothing);

      // Forward again: the choices are still there.
      await app.choosePath('rotation');
      await _next(app);
      expect(app.title, '¿Cuándo empiezas?');
      // Continental, day 4 of the cycle (M M T T N N N ...): a Tarde, with
      // the nurse's hours (the job chosen at the end is already shown).
      expect(
        find.text(keepTimeRangesTogether('Ese día te toca: Tarde 15:00–22:00')),
        findsOneWidget,
      );
      await _next(app);
      expect(find.text('Comunidad de Madrid'), findsOneWidget);
    });

    testWidgets('the system back button goes back, not out of the app', (
      tester,
    ) async {
      final app = await FirstLaunch.open(tester);
      await _toStart(app);
      expect(app.title, '¿Cuándo empiezas?');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(app.title, '¿Cómo es tu rotación?');
    });
  });

  group('skipping', () {
    testWidgets('"Saltar" on every screen: nothing is written but "done" '
        'and the country', (tester) async {
      final app = await FirstLaunch.open(tester);
      await app.choosePath('rotation');
      await app.tap(key('onboarding-skip')); // rotation
      expect(app.title, '¿Dónde trabajas?');
      await app.tap(key('onboarding-skip')); // last step: finishes
      expect(app.title, 'Listo');
      expect(key('onboarding-skip'), findsNothing);
      expect(key('onboarding-back'), findsNothing);
      expect(find.textContaining('calendario en blanco'), findsOneWidget);

      await app.flushWrites();
      expect(app.schedule.runs, isEmpty);
      expect(app.schedule.entries, isEmpty);
      expect(app.container.read(holidayPlaceProvider), HolidayPlace.spain);
      final repository = OnboardingRepository(app.database);
      expect(await app.real(repository.isDone), isTrue);
      expect(await app.real(repository.loadProfile), isNull);

      await app.tap(key('onboarding-next'));
      expect(find.byType(MonthScreen), findsOneWidget);
      expect(app.container.read(paintControllerProvider).active, isFalse);
    });

    testWidgets('skipping a screen drops what was chosen in it', (
      tester,
    ) async {
      final app = await FirstLaunch.open(tester);
      await _toStart(app);
      await app.tap(key('onboarding-skip')); // the start day: no rotation
      expect(app.title, '¿Dónde trabajas?');
      await _nurseInMadrid(app);
      await app.tap(key('onboarding-skip')); // the job and community go
      expect(app.title, 'Listo');
      await app.flushWrites();
      expect(app.schedule.runs, isEmpty);
      expect(
        await app.real(OnboardingRepository(app.database).loadProfile),
        isNull,
      );
      // The country stays: Spain, without a community.
      expect(app.container.read(holidayPlaceProvider), HolidayPlace.spain);
    });
  });

  group('the result', () {
    testWidgets('a nurse in Madrid: types, place, rotation and month', (
      tester,
    ) async {
      final app = await FirstLaunch.open(tester);
      await _toStart(app);
      await app.tap(key('onboarding-shift-night12'));
      await _next(app);
      await app.tap(key('onboarding-profession-nursing'));
      await app.tap(key('onboarding-region'));
      await app.tap(find.text('Comunidad de Madrid'));
      await app.tap(key('onboarding-municipality'));
      await tester.enterText(key('onboarding-municipality-search'), 'madrid');
      await tester.pumpAndSettle();
      await tester.tap(key('municipality-28079'));
      await tester.pumpAndSettle();
      await _next(app);

      expect(app.title, 'Listo');
      expect(
        find.text('Trabajo: Enfermería, TCAE y celadores'),
        findsOneWidget,
      );
      expect(
        find.text('Festivos: Madrid, Comunidad de Madrid'),
        findsOneWidget,
      );
      expect(
        find.text('Rotación: 12 horas, desde el lunes 19 de octubre'),
        findsOneWidget,
      );
      await app.tap(key('onboarding-next'));
      expect(find.byType(MonthScreen), findsOneWidget);
      expect(app.container.read(paintControllerProvider).active, isFalse);
      await app.flushWrites();

      // Day 2 of D E S L is the Noche 12 h.
      expect(idsOn(app.schedule, onboardingToday), 'night12');
      expect(idsOn(app.schedule, onboardingToday.addDays(1)), 'postNight');
      expect(idsOn(app.schedule, onboardingToday.addDays(2)), 'rest');
      expect(idsOn(app.schedule, onboardingToday.addDays(3)), 'day12');

      final place = app.container.read(holidayPlaceProvider);
      expect(place.regionCode, 'ES-MD');
      expect(place.municipalityCode, '28079');
      // Madrid's own days (Almudena, 9 November) and the community's.
      final holidays = app.container.read(holidaysProvider);
      expect(holidays[const CivilDate(2026, 11, 9)]?.scope, HolidayScope.local);
      expect(
        holidays[const CivilDate(2026, 12, 8)]?.scope,
        HolidayScope.national,
      );
      expect(holidays[const CivilDate(2026, 10, 12)], isNotNull);

      final repository = OnboardingRepository(app.database);
      expect(await app.real(repository.loadProfile), Profession.nursing);
      expect(await app.real(repository.isDone), isTrue);
    });

    testWidgets('the holidays of the place show in the month', (tester) async {
      final app = await FirstLaunch.open(tester);
      await app.choosePath('import');
      await _next(app); // nothing imported
      await app.tap(key('onboarding-region'));
      await app.tap(find.text('Comunidad de Madrid'));
      await app.tap(key('onboarding-municipality'));
      await tester.enterText(key('onboarding-municipality-search'), 'madrid');
      await tester.pumpAndSettle();
      await tester.tap(key('municipality-28079'));
      await tester.pumpAndSettle();
      await _next(app); // last step
      await app.tap(key('onboarding-next'));

      expect(find.byType(MonthScreen), findsOneWidget);
      // October: the national holiday. The local one is next month.
      expect(key('holiday-dot-2026-10-12'), findsOneWidget);
      await tester.tap(find.byTooltip('Mes siguiente'));
      await tester.pumpAndSettle();
      expect(key('holiday-dot-2026-11-09'), findsOneWidget);
    });
  });

  group('finishing', () {
    // Nurse, no place, no rotation: only the shift types are written.
    Future<void> toLastStep(FirstLaunch app) async {
      await app.choosePath('rotation');
      await app.tap(key('onboarding-skip'));
      await app.tap(key('onboarding-profession-nursing'));
      expect(app.title, '¿Dónde trabajas?');
    }

    testWidgets('«Listo» comes only after the shift types are in the '
        'database', (tester) async {
      late _SlowTypes repository;
      final app = await FirstLaunch.open(
        tester,
        overrides: [
          scheduleRepositoryProvider.overrideWith((ref) {
            repository = _SlowTypes(
              ref.watch(appDatabaseProvider),
              now: () => onboardingNow,
            );
            return repository;
          }),
        ],
      );
      await toLastStep(app);

      var savedWhenReady = -1;
      app.container.listen(onboardingControllerProvider, (previous, next) {
        if (next.stage == OnboardingStage.ready && savedWhenReady < 0) {
          savedWhenReady = repository.saved.length;
        }
      });
      await app.tap(key('onboarding-next'));
      // The writes take 50 ms each: let fake time pass until it ends.
      for (var i = 0; i < 40 && savedWhenReady < 0; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();

      expect(repository.saved, isNotEmpty);
      expect(
        savedWhenReady,
        repository.saved.length,
        reason: 'every queued write had landed when the flow said «Listo»',
      );
      expect(
        app.container.read(onboardingControllerProvider).saveFailed,
        isFalse,
      );
      expect(await app.real(OnboardingRepository(app.database).isDone), isTrue);
    });

    testWidgets('a shift type that cannot be saved is reported', (
      tester,
    ) async {
      final app = await FirstLaunch.open(
        tester,
        overrides: [
          scheduleRepositoryProvider.overrideWith(
            (ref) => _SlowTypes(
              ref.watch(appDatabaseProvider),
              now: () => onboardingNow,
              fail: true,
            ),
          ),
        ],
      );
      await toLastStep(app);
      await app.tap(key('onboarding-next'));
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();

      expect(app.title, 'Listo');
      expect(
        app.container.read(onboardingControllerProvider).saveFailed,
        isTrue,
      );
    });

    testWidgets('data that appeared meanwhile (a restore) is not '
        'overwritten', (tester) async {
      final app = await FirstLaunch.open(tester);
      await _toStart(app);
      await _next(app);
      await _nurseInMadrid(app);
      expect(app.title, '¿Dónde trabajas?');

      // A backup is restored under the flow: a rotation of its own.
      await app.real(
        () => ScheduleRepository(app.database, now: () => onboardingNow).apply(
          mainCalendarId,
          ScheduleChange(
            runsAfter: [
              PatternRun(
                id: 'restored',
                patternId: '12h',
                startDate: onboardingToday.addDays(-30),
                seq: 7,
              ),
            ],
          ),
        ),
      );
      await _next(app);
      await app.flushWrites();

      expect(app.title, 'Listo');
      expect(key('onboarding-summary-empty'), findsOneWidget);
      final runs = await app.real(
        () => app.database.select(app.database.patternRuns).get(),
      );
      expect(runs.map((r) => r.id), ['restored'], reason: 'no run added');
      expect(
        app.container.read(holidayPlaceProvider),
        HolidayPlace.spain,
        reason: 'the place of the flow was not written',
      );
      expect(
        await app.real(OnboardingRepository(app.database).loadProfile),
        isNull,
      );
    });
  });

  group('the tip of the paint sheet', () {
    Future<void> skipAll(FirstLaunch app) async {
      await app.choosePath('import');
      await app.tap(key('onboarding-skip'));
      await app.tap(key('onboarding-skip'));
      await app.tap(key('onboarding-next'));
    }

    testWidgets('appears once after the flow and stays closed', (tester) async {
      final app = await FirstLaunch.open(tester);
      await skipAll(app);
      // Decision 28: the month keeps nothing but the month; the tip is a line
      // of the paint sheet, the first time paint mode opens.
      expect(key('onboarding-tip'), findsNothing);
      await app.tap(find.text('Pintar'));
      expect(key('onboarding-tip'), findsOneWidget);
      // One line that says how to paint (the whole advice is in its label,
      // for a screen reader).
      expect(find.text('Elige un turno y arrastra.'), findsOneWidget);

      await tester.tap(key('onboarding-tip-close'));
      await tester.pumpAndSettle();
      expect(key('onboarding-tip'), findsNothing);

      // Remembered: the next start does not bring it back.
      final repository = OnboardingRepository(app.database);
      expect(await app.real(repository.isTipPending), isFalse);
      final status = await app.real(
        () => repository.resolve(demo: false, force: false),
      );
      expect(status.tipPending, isFalse);
      expect(status.needed, isFalse);
    });

    testWidgets('the cross closes it as well', (tester) async {
      final app = await FirstLaunch.open(tester);
      await skipAll(app);
      await app.tap(find.text('Pintar'));
      await tester.tap(key('onboarding-tip-close'));
      await tester.pumpAndSettle();
      expect(key('onboarding-tip'), findsNothing);
    });
  });
}
