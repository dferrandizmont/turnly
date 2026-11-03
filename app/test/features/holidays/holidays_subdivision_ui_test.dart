import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:cuadrante/features/holidays/application/holidays_provider.dart';
import 'package:cuadrante/features/holidays/domain/holiday_place.dart';
import 'package:cuadrante/features/holidays/presentation/holiday_pickers.dart';
import 'package:cuadrante/features/schedule/domain/civil_date.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';

void main() {
  setUpAll(initializeLocale);

  const tall = Size(390, 2900);

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

  testWidgets('Germany: official holidays and a Land row, Spain\'s untouched', (
    tester,
  ) async {
    final app = await AppUnderTest.pump(tester, size: tall);
    await openHolidays(tester, app);
    // Spain: community and municipality, no subdivision row.
    expect(key('holidays-region'), findsOneWidget);
    expect(key('holidays-subdivision'), findsNothing);

    await chooseCountry(tester, 'DE');

    expect(
      app.container.read(holidayPlaceProvider),
      const HolidayPlace(countryCode: 'DE'),
    );
    expect(key('holidays-region'), findsNothing);
    expect(key('holidays-municipality'), findsNothing);
    expect(
      inRow('holidays-subdivision', find.text('Estado federado')),
      findsOneWidget,
    );
    expect(
      inRow('holidays-subdivision', find.text('Sin elegir')),
      findsOneWidget,
    );
    // National days are there; the country-without-data note is not.
    expect(find.textContaining('Todavía no tenemos'), findsNothing);
    expect(find.text('Tag der Deutschen Einheit'), findsOneWidget);
    expect(
      find.text(
        'Sin elegir solo salen los festivos de todo el país. Elige el tuyo '
        'para ver también los de tu zona.',
      ),
      findsOneWidget,
    );
    expect(find.text('Fronleichnam'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('choosing Bayern adds its days; «Sin elegir» takes them off', (
    tester,
  ) async {
    final app = await AppUnderTest.pump(tester, size: tall);
    await openHolidays(tester, app);
    await chooseCountry(tester, 'DE');

    await tester.tap(key('holidays-subdivision'));
    await tester.pumpAndSettle();
    // 16 Länder: the search shows, the list is alphabetical.
    expect(key('subdivision-search'), findsOneWidget);
    expect(key('subdivision-option-none'), findsOneWidget);
    final bayern = tester.getTopLeft(key('subdivision-option-DE-BY')).dy;
    final berlin = tester.getTopLeft(key('subdivision-option-DE-BE')).dy;
    expect(bayern, lessThan(berlin)); // Ba-y before Be-r
    await tester.tap(key('subdivision-option-DE-BY'));
    await tester.pumpAndSettle();

    expect(
      app.container.read(holidayPlaceProvider),
      const HolidayPlace(countryCode: 'DE', regionCode: 'DE-BY'),
    );
    expect(inRow('holidays-subdivision', find.text('Bayern')), findsOneWidget);
    expect(find.textContaining('Elige el tuyo'), findsNothing);
    expect(
      app.container.read(holidaysProvider)[const CivilDate(2027, 5, 27)]?.name,
      'Fronleichnam',
    );

    await tester.tap(key('holidays-subdivision'));
    await tester.pumpAndSettle();
    final current = tester.widget<PickerOptionRow>(
      key('subdivision-option-DE-BY'),
    );
    expect(current.selected, isTrue);
    await tester.tap(key('subdivision-option-none'));
    await tester.pumpAndSettle();
    expect(
      app.container.read(holidayPlaceProvider),
      const HolidayPlace(countryCode: 'DE'),
    );
    expect(
      app.container.read(holidaysProvider)[const CivilDate(2027, 5, 27)],
      isNull,
    );
  });

  testWidgets('the search finds a Land without caring for accents', (
    tester,
  ) async {
    final app = await AppUnderTest.pump(tester, size: tall);
    await openHolidays(tester, app);
    await chooseCountry(tester, 'DE');
    await tester.tap(key('holidays-subdivision'));
    await tester.pumpAndSettle();

    await tester.enterText(key('subdivision-search'), 'thuring');
    await tester.pumpAndSettle();
    expect(key('subdivision-option-DE-TH'), findsOneWidget);
    expect(key('subdivision-option-DE-BY'), findsNothing);
    expect(key('subdivision-option-none'), findsNothing);
  });

  testWidgets('Mexico: official holidays, no subdivision row', (tester) async {
    final app = await AppUnderTest.pump(tester, size: tall);
    await openHolidays(tester, app);
    await chooseCountry(tester, 'MX');

    expect(key('holidays-subdivision'), findsNothing);
    expect(find.textContaining('Todavía no tenemos'), findsNothing);
    expect(
      app.container.read(holidaysProvider)[const CivilDate(2026, 9, 16)]?.name,
      'Día de la Independencia',
    );
    // Not Spain's.
    expect(
      app.container.read(holidaysProvider)[const CivilDate(2026, 10, 12)],
      isNull,
    );
  });

  testWidgets('a subdivision title per country: Suiza says Cantón', (
    tester,
  ) async {
    final app = await AppUnderTest.pump(tester, size: tall);
    await openHolidays(tester, app);
    await chooseCountry(tester, 'CH');
    expect(inRow('holidays-subdivision', find.text('Cantón')), findsOneWidget);
    await chooseCountry(tester, 'US');
    expect(inRow('holidays-subdivision', find.text('Estado')), findsOneWidget);
    await chooseCountry(tester, 'GB');
    expect(inRow('holidays-subdivision', find.text('Nación')), findsOneWidget);
  });

  testWidgets('back to Spain: its rows again, no subdivision', (tester) async {
    final app = await AppUnderTest.pump(tester, size: tall);
    await openHolidays(tester, app);
    await chooseCountry(tester, 'DE');
    await chooseCountry(tester, 'ES');
    expect(key('holidays-subdivision'), findsNothing);
    expect(key('holidays-region'), findsOneWidget);
    expect(app.container.read(holidayPlaceProvider), HolidayPlace.spain);
  });
}
