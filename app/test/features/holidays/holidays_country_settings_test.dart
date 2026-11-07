import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:cuadrante/features/holidays/application/holidays_provider.dart';
import 'package:cuadrante/features/holidays/domain/holiday_country.dart';
import 'package:cuadrante/features/holidays/domain/holiday_place.dart';
import 'package:cuadrante/features/holidays/presentation/holiday_pickers.dart';
import 'package:cuadrante/features/schedule/domain/civil_date.dart';
import 'package:cuadrante/core/theme/app_theme.dart';
import 'package:cuadrante/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';

void main() {
  setUpAll(initializeLocale);

  const tall = Size(390, 3400);

  Finder key(String value) => find.byKey(ValueKey(value));

  Finder inRow(String rowKey, Finder matching) =>
      find.descendant(of: key(rowKey), matching: matching);

  Future<void> openHolidays(WidgetTester tester, AppUnderTest app) async {
    await app.openSettings();
    await tester.ensureVisible(key('settings-holidays'));
    await tester.pumpAndSettle();
    await tester.tap(key('settings-holidays'));
    await tester.pumpAndSettle();
  }

  Future<void> chooseCountry(WidgetTester tester, String code) async {
    await tester.tap(key('holidays-country'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(key('country-option-$code'));
    await tester.pumpAndSettle();
    await tester.tap(key('country-option-$code'));
    await tester.pumpAndSettle();
  }

  testWidgets('Spain: the country row first, then community and municipality', (
    tester,
  ) async {
    final app = await AppUnderTest.pump(tester, size: tall);
    await openHolidays(tester, app);
    expect(inRow('holidays-country', find.text('País')), findsOneWidget);
    expect(inRow('holidays-country', find.text('España')), findsOneWidget);
    expect(key('holidays-region'), findsOneWidget);
    expect(key('holidays-municipality'), findsOneWidget);
    expect(
      tester.getTopLeft(key('holidays-country')).dy,
      lessThan(tester.getTopLeft(key('holidays-region')).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the picker: Spain first, sorted, «Otro país» last, marked', (
    tester,
  ) async {
    final app = await AppUnderTest.pump(tester, size: tall);
    await openHolidays(tester, app);
    await tester.tap(key('holidays-country'));
    await tester.pumpAndSettle();

    final ys = [
      for (final c in countriesForPicker('es'))
        tester.getTopLeft(key('country-option-${c.code}')).dy,
      tester.getTopLeft(key('country-option-$otherCountryCode')).dy,
    ];
    expect(ys, [...ys]..sort(), reason: 'shown in the picker order');
    expect(find.text('Otro país: sin festivos oficiales'), findsOneWidget);
    final spain = tester.widget<PickerOptionRow>(key('country-option-ES'));
    expect(spain.selected, isTrue);
    final mexico = tester.widget<PickerOptionRow>(key('country-option-MX'));
    expect(mexico.selected, isFalse);
  });

  testWidgets(
    'a country without data yet: no community, no 12 October, a clear note',
    (tester) async {
      final app = await AppUnderTest.pump(tester, size: tall);
      await openHolidays(tester, app);
      await tester.tap(key('holidays-region'));
      await tester.pumpAndSettle();
      await tester.tap(key('region-option-ES-CT'));
      await tester.pumpAndSettle();

      await chooseCountry(tester, 'MA');

      expect(
        app.container.read(holidayPlaceProvider),
        const HolidayPlace(countryCode: 'MA'),
      );
      expect(inRow('holidays-country', find.text('Marruecos')), findsOneWidget);
      expect(key('holidays-region'), findsNothing);
      expect(key('holidays-municipality'), findsNothing);
      expect(
        find.text(
          'Todavía no tenemos los festivos oficiales de Marruecos: añade los '
          'tuyos abajo',
        ),
        findsOneWidget,
      );
      expect(find.text('Fiesta Nacional de España'), findsNothing);
      expect(find.text('Año Nuevo'), findsNothing);
      expect(key('holidays-empty'), findsOneWidget);
      expect(key('holidays-add'), findsOneWidget);
      expect(key('holidays-substituted'), findsNothing);
      expect(
        app.container.read(holidaysProvider)[const CivilDate(2026, 10, 12)],
        isNull,
      );

      // Settings shows the country instead of «Sin elegir».
      await app.back();
      expect(
        inRow('settings-holidays', find.text('Marruecos')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('«Otro país»: no official holidays, own ones still work', (
    tester,
  ) async {
    final app = await AppUnderTest.pump(tester, size: tall);
    await openHolidays(tester, app);
    await chooseCountry(tester, otherCountryCode);

    expect(app.container.read(holidayPlaceProvider), HolidayPlace.otherCountry);
    expect(
      inRow('holidays-country', find.text('Sin festivos oficiales')),
      findsOneWidget,
    );
    expect(
      find.text('Sin festivos oficiales: solo salen los que añades tú abajo'),
      findsOneWidget,
    );

    await tester.runAsync(
      () => app.container
          .read(holidayControllerProvider.notifier)
          .addUserHoliday(date: const CivilDate(2026, 6, 3), name: 'Mi fiesta'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Mi fiesta'), findsOneWidget);
    expect(app.container.read(holidaysProvider).keys, [
      const CivilDate(2026, 6, 3),
    ]);

    await app.back();
    expect(
      inRow('settings-holidays', find.text('Sin festivos oficiales')),
      findsOneWidget,
    );
  });

  testWidgets('back to Spain: the national days and the community return', (
    tester,
  ) async {
    final app = await AppUnderTest.pump(tester, size: tall);
    await openHolidays(tester, app);
    await chooseCountry(tester, 'MA');
    expect(find.text('Año Nuevo'), findsNothing);
    await chooseCountry(tester, 'ES');
    expect(app.container.read(holidayPlaceProvider), HolidayPlace.spain);
    expect(key('holidays-region'), findsOneWidget);
    expect(find.text('Año Nuevo'), findsOneWidget);
  });

  for (final language in ['es', 'ca', 'gl', 'eu', 'en']) {
    for (final dark in [false, true]) {
      testWidgets(
        '$language ${dark ? 'dark' : 'light'}, 320 dp, text x2: the picker '
        'follows the app language and fits',
        (tester) async {
          tester.view.physicalSize = const Size(320, 640) * 3;
          tester.view.devicePixelRatio = 3;
          addTearDown(tester.view.reset);
          String? picked;
          await tester.pumpWidget(
            MaterialApp(
              theme: dark ? AppTheme.dark() : AppTheme.light(),
              locale: Locale(language),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: CountryPicker(
                    selected: 'MX',
                    onSelected: (code) => picked = code,
                  ),
                ),
              ),
            ),
          );
          final l10n = lookupAppLocalizations(Locale(language));
          expect(
            find.descendant(
              of: key('country-option-MX'),
              matching: find.text(countryName('MX', language)),
            ),
            findsOneWidget,
          );
          expect(
            tester.widget<PickerOptionRow>(key('country-option-MX')).selected,
            isTrue,
          );
          final other = key('country-option-$otherCountryCode');
          await tester.ensureVisible(other);
          await tester.pumpAndSettle();
          expect(
            find.descendant(
              of: other,
              matching: find.text(l10n.holidaysSettingsCountryOther),
            ),
            findsOneWidget,
          );
          await tester.tap(other);
          expect(picked, otherCountryCode);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
