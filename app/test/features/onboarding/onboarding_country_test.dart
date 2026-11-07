import 'dart:ui' show Locale;

import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:cuadrante/core/database/database_provider.dart';
import 'package:cuadrante/core/format/text_wrap.dart';
import 'package:cuadrante/core/providers.dart';
import 'package:cuadrante/features/holidays/application/holidays_provider.dart';
import 'package:cuadrante/features/holidays/data/holiday_bundle_loader.dart';
import 'package:cuadrante/features/holidays/data/holiday_repository.dart';
import 'package:cuadrante/features/holidays/domain/holiday_country.dart';
import 'package:cuadrante/features/holidays/domain/holiday_place.dart';
import 'package:cuadrante/features/onboarding/application/onboarding_controller.dart';
import 'package:cuadrante/features/onboarding/application/onboarding_providers.dart';
import 'package:cuadrante/features/onboarding/data/onboarding_repository.dart';
import 'package:cuadrante/features/onboarding/domain/profession.dart';
import 'package:cuadrante/features/schedule/domain/civil_date.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_storage.dart' show openMemoryDatabase;
import '../holidays/bundle_support.dart';
import 'onboarding_support.dart';

Future<void> _next(FirstLaunch app) => app.tap(key('onboarding-next'));

/// The first launch on a phone whose region is [country].
Future<FirstLaunch> _openIn(WidgetTester tester, String? country) =>
    FirstLaunch.open(
      tester,
      overrides: [systemCountryCodeProvider.overrideWithValue(country)],
    );

OnboardingState _state(FirstLaunch app) =>
    app.container.read(onboardingControllerProvider);

void main() {
  setUpAll(initializeLocale);

  group('proposed country (phone region)', () {
    testWidgets('a Spanish phone: Spain, the Spanish list and the community', (
      tester,
    ) async {
      final app = await FirstLaunch.open(tester);
      expect(_state(app).countryCode, spainCountryCode);
      await app.toLastStep();
      expect(app.title, '¿Dónde trabajas?');
      expect(key('onboarding-profession-medicine'), findsOneWidget);
      expect(key('onboarding-profession-commerce'), findsNothing);
      expect(
        find.descendant(
          of: key('onboarding-country'),
          matching: find.text('España'),
        ),
        findsOneWidget,
      );
      expect(key('onboarding-region'), findsOneWidget);
      expect(key('onboarding-municipality'), findsOneWidget);
      expect(key('onboarding-country-note'), findsNothing);
    });

    testWidgets('a Mexican phone: neutral jobs, Mexico, no community', (
      tester,
    ) async {
      final app = await _openIn(tester, 'MX');
      expect(_state(app).countryCode, 'MX');
      // The first question says nothing of the country.
      expect(key('onboarding-country'), findsNothing);
      await app.toLastStep();
      for (final p in neutralProfessions) {
        expect(key('onboarding-profession-${p.name}'), findsOneWidget);
      }
      expect(key('onboarding-profession-medicine'), findsNothing);
      expect(find.text('Enfermería y sanidad'), findsOneWidget);
      expect(find.text('Policía'), findsOneWidget);
      expect(find.text('Seguridad'), findsOneWidget);
      expect(find.text('Hostelería'), findsOneWidget);
      expect(find.text('Comercio'), findsOneWidget);
      expect(find.text('Transporte'), findsOneWidget);
      expect(find.textContaining('Guardia Civil'), findsNothing);
      expect(find.textContaining('TCAE'), findsNothing);
      expect(find.textContaining('saliente'), findsNothing);
      expect(find.textContaining('Correturnos'), findsNothing);

      await app.tap(key('onboarding-profession-transport'));
      expect(
        find.text(keepTimeRangesTogether('M 06–14, T 14–22 y N 22–06')),
        findsOneWidget,
      );
      expect(key('onboarding-region'), findsNothing);
      expect(key('onboarding-municipality'), findsNothing);
      expect(
        find.descendant(
          of: key('onboarding-country'),
          matching: find.text('México'),
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Marcaremos en tu calendario los festivos oficiales de México. '
          'Puedes añadir los tuyos en Ajustes › Festivos.',
        ),
        findsOneWidget,
      );
      expect(key('onboarding-subdivision'), findsNothing);

      await _next(app); // last step: finishes
      expect(app.title, 'Listo');
      expect(find.text('Trabajo: Transporte'), findsOneWidget);
      expect(find.text('Festivos: México'), findsOneWidget);

      expect(
        app.container.read(holidayPlaceProvider),
        const HolidayPlace(countryCode: 'MX'),
      );
      // Mexico's own days, never Spain's 12 October.
      final holidays = app.container.read(holidaysProvider);
      expect(holidays[const CivilDate(2026, 10, 12)], isNull);
      expect(
        holidays[const CivilDate(2026, 9, 16)]?.name,
        'Día de la Independencia',
      );
      expect(
        await app.real(OnboardingRepository(app.database).loadProfile),
        Profession.transport,
      );
    });

    testWidgets('a country in the list without data yet says so', (
      tester,
    ) async {
      final app = await _openIn(tester, 'MA');
      expect(_state(app).countryCode, 'MA');
      await app.toLastStep();
      expect(
        find.text(
          'Aún no tenemos los festivos oficiales de Marruecos. Puedes añadir '
          'los tuyos en Ajustes › Festivos.',
        ),
        findsOneWidget,
      );
      expect(key('onboarding-subdivision'), findsNothing);
    });

    testWidgets('a German phone: official holidays and a Land to choose', (
      tester,
    ) async {
      final app = await _openIn(tester, 'DE');
      expect(_state(app).countryCode, 'DE');
      await app.toLastStep();
      expect(
        find.text(
          'Marcaremos en tu calendario los festivos oficiales de Alemania. '
          'Puedes añadir los tuyos en Ajustes › Festivos.',
        ),
        findsOneWidget,
      );
      expect(key('onboarding-region'), findsNothing);
      expect(
        find.descendant(
          of: key('onboarding-subdivision'),
          matching: find.text('Estado federado'),
        ),
        findsOneWidget,
      );
      await app.tap(key('onboarding-subdivision'));
      await app.tap(key('subdivision-option-DE-BY'));
      expect(_state(app).regionCode, 'DE-BY');
      expect(
        find.descendant(
          of: key('onboarding-subdivision'),
          matching: find.text('Bayern'),
        ),
        findsOneWidget,
      );

      await _next(app); // last step: finishes
      expect(app.title, 'Listo');
      expect(find.text('Festivos: Bayern, Alemania'), findsOneWidget);
      expect(
        app.container.read(holidayPlaceProvider),
        const HolidayPlace(countryCode: 'DE', regionCode: 'DE-BY'),
      );
      final holidays = app.container.read(holidaysProvider);
      expect(holidays[const CivilDate(2026, 6, 4)]?.name, 'Fronleichnam');
      expect(
        holidays[const CivilDate(2026, 10, 3)]?.name,
        'Tag der Deutschen Einheit',
      );
    });

    testWidgets('changing country drops the Land', (tester) async {
      final app = await _openIn(tester, 'DE');
      await app.toLastStep();
      await app.tap(key('onboarding-subdivision'));
      await app.tap(key('subdivision-option-DE-BY'));
      expect(_state(app).regionCode, 'DE-BY');
      await app.tap(key('onboarding-country'));
      await app.tap(key('country-option-FR'));
      expect(_state(app).regionCode, isNull);
      expect(_state(app).countryCode, 'FR');
    });

    testWidgets('a country the list does not have: «Otro país»', (
      tester,
    ) async {
      final app = await _openIn(tester, 'JP');
      expect(_state(app).countryCode, otherCountryCode);
      await app.choosePath('import');
      await _next(app); // nothing imported
      expect(
        find.text(
          'Sin festivos oficiales. Puedes añadir los tuyos en Ajustes › '
          'Festivos.',
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: key('onboarding-country'),
          matching: find.text('Sin festivos oficiales'),
        ),
        findsOneWidget,
      );
      // Skipping the last step keeps the country: no Spanish holidays.
      await app.tap(key('onboarding-skip'));
      expect(app.title, 'Listo');
      expect(find.text('Festivos: solo los que añadas tú'), findsOneWidget);
      expect(
        app.container.read(holidayPlaceProvider),
        HolidayPlace.otherCountry,
      );
      expect(app.container.read(holidaysProvider), isEmpty);
    });

    testWidgets('a Mexican phone that skips the last step keeps Mexico', (
      tester,
    ) async {
      final app = await _openIn(tester, 'MX');
      await app.choosePath('rotation');
      await app.tap(key('onboarding-skip')); // rotation
      await app.tap(key('onboarding-skip')); // last step: finishes
      expect(app.title, 'Listo');
      expect(find.text('Festivos: México'), findsOneWidget);
      expect(
        app.container.read(holidayPlaceProvider),
        const HolidayPlace(countryCode: 'MX'),
      );
      expect(
        app.container.read(holidaysProvider)[const CivilDate(2026, 10, 12)],
        isNull,
      );
    });

    testWidgets('a phone with no region keeps Spain', (tester) async {
      final app = await _openIn(tester, null);
      expect(_state(app).countryCode, spainCountryCode);
    });

    testWidgets('the region is read from the phone\'s preferred locales', (
      tester,
    ) async {
      String? read() => ProviderContainer().read(systemCountryCodeProvider);
      addTearDown(tester.platformDispatcher.clearAllTestValues);

      tester.platformDispatcher.localesTestValue = const [Locale('es', 'MX')];
      expect(read(), 'MX');
      // The first locale with a region wins.
      tester.platformDispatcher.localesTestValue = const [
        Locale('eu'),
        Locale('es', 'AR'),
      ];
      expect(read(), 'AR');
      tester.platformDispatcher.localesTestValue = const [Locale('en')];
      tester.platformDispatcher.localeTestValue = const Locale('en');
      expect(read(), isNull);
    });
  });

  group('changing the country in the last step', () {
    testWidgets('to Mexico: the community goes, medicine becomes health care', (
      tester,
    ) async {
      final app = await FirstLaunch.open(tester);
      await app.toLastStep();
      await app.tap(key('onboarding-profession-medicine'));
      await app.tap(key('onboarding-region'));
      await app.tap(find.text('Catalunya'));
      expect(_state(app).regionCode, 'ES-CT');

      await app.tap(key('onboarding-country'));
      expect(find.text('Tu país'), findsOneWidget);
      // Spain first, «Otro país» last.
      final spainY = tester.getTopLeft(key('country-option-ES')).dy;
      expect(
        tester.getTopLeft(key('country-option-AD')).dy,
        greaterThan(spainY),
      );
      await app.tap(key('country-option-MX'));

      final state = _state(app);
      expect(state.countryCode, 'MX');
      expect(state.regionCode, isNull);
      expect(state.profession, Profession.nursing);
      expect(key('onboarding-region'), findsNothing);
      expect(key('onboarding-country-note'), findsOneWidget);

      // The jobs below become the neutral list, with the mapped choice.
      expect(key('onboarding-profession-medicine'), findsNothing);
      expect(key('onboarding-profession-commerce'), findsOneWidget);
      expect(find.text('Enfermería y sanidad'), findsOneWidget);
    });

    testWidgets('«Otro país» then Spain again: the community comes back', (
      tester,
    ) async {
      final app = await FirstLaunch.open(tester);
      await app.toLastStep();
      await app.tap(key('onboarding-country'));
      await app.tap(key('country-option-ZZ'));
      expect(_state(app).countryCode, otherCountryCode);
      expect(key('onboarding-region'), findsNothing);

      await app.tap(key('onboarding-country'));
      await app.tap(key('country-option-ES'));
      expect(_state(app).countryCode, spainCountryCode);
      expect(key('onboarding-region'), findsOneWidget);

      await app.tap(key('onboarding-region'));
      await app.tap(find.text('Comunidad de Madrid'));
      await _next(app); // last step: finishes
      expect(
        app.container.read(holidayPlaceProvider),
        const HolidayPlace(regionCode: 'ES-MD'),
      );
    });
  });

  group('controller', () {
    test('professionForCountry keeps what the list has, maps the rest', () {
      expect(professionForCountry(Profession.police, 'MX'), Profession.police);
      expect(
        professionForCountry(Profession.medicine, 'MX'),
        Profession.nursing,
      );
      expect(
        professionForCountry(Profession.commerce, 'ES'),
        Profession.hospitality,
      );
      expect(
        professionForCountry(Profession.transport, 'ES'),
        Profession.other,
      );
      expect(
        professionForCountry(Profession.medicine, 'ES'),
        Profession.medicine,
      );
      for (final p in Profession.values) {
        for (final country in ['ES', 'MX', otherCountryCode]) {
          expect(
            professionsFor(country),
            contains(professionForCountry(p, country)),
          );
        }
      }
    });

    test('the two lists: Spain as before, neutral elsewhere', () {
      expect(professionsFor('ES'), spainProfessions);
      expect(spainProfessions, [
        Profession.nursing,
        Profession.medicine,
        Profession.police,
        Profession.firefighters,
        Profession.industry,
        Profession.security,
        Profession.hospitality,
        Profession.other,
      ]);
      expect(professionsFor('MX'), neutralProfessions);
      expect(professionsFor(otherCountryCode), neutralProfessions);
      expect(neutralProfessions, isNot(contains(Profession.medicine)));
      expect(neutralProfessions.last, Profession.other);
    });
  });

  group('local holidays of the year (first use)', () {
    test('this year, and the next one in November and December', () {
      expect(localHolidayYears(const CivilDate(2026, 10, 31)), [2026]);
      expect(localHolidayYears(const CivilDate(2026, 11, 1)), [2026, 2027]);
      expect(localHolidayYears(const CivilDate(2026, 12, 31)), [2026, 2027]);
      expect(localHolidayYears(const CivilDate(2027, 1, 1)), [2027]);
    });

    Future<List<int>> missing(String municipality, DateTime now) async {
      final db = openMemoryDatabase();
      addTearDown(db.close);
      await HolidayRepository(db)
          .refreshBundled(HolidayBundleLoader(bundle: shippedBundle()));
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(container.dispose);
      return container.read(
        localHolidaysMissingYearsProvider(municipality).future,
      );
    }

    test('Barcelona in October 2026: covered', () async {
      expect(await missing('08019', DateTime(2026, 10, 19)), isEmpty);
    });

    test('Barcelona in November 2026: 2027 is not out yet', () async {
      expect(await missing('08019', DateTime(2026, 11, 20)), [2027]);
    });

    test(
      'Barcelona in 2027: missing (some other year is not enough)',
      () async {
        expect(await missing('08019', DateTime(2027, 3, 1)), [2027]);
      },
    );

    test('Murcia city has both years', () async {
      // Region de Murcia ships 2026 and 2027 locals for its capital.
      expect(await missing('30030', DateTime(2026, 12, 1)), isEmpty);
    });

    test('Dos Hermanas: none at all', () async {
      expect(await missing('41038', DateTime(2026, 12, 1)), [2026, 2027]);
    });

    test('Arona: the island holiday is not its locals', () async {
      // Tenerife's Candelaria day is in the bundle, Arona's own two are not.
      expect(await missing('38006', DateTime(2026, 12, 1)), [2026, 2027]);
    });

    test('Sevilla: both years', () async {
      expect(await missing('41091', DateTime(2026, 12, 1)), isEmpty);
    });
  });
}
