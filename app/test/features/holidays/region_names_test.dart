import 'package:flutter_test/flutter_test.dart';
import 'package:cuadrante/features/holidays/domain/spanish_regions.dart';
import 'package:cuadrante/features/holidays/presentation/holiday_pickers.dart';

void main() {
  test('every community has a name in each language of the app', () {
    for (final region in spanishRegions) {
      for (final language in ['es', 'ca', 'gl', 'eu', 'en']) {
        expect(region.nameIn(language), isNotEmpty, reason: region.code);
      }
    }
  });

  test('Basque reads Euskadi and its own names (0.12.1 QA, Maite 2.1)', () {
    final basque = regionByCode('ES-PV')!;
    expect(basque.nameIn('es'), 'País Vasco');
    expect(basque.nameIn('eu'), 'Euskadi');
    expect(basque.nameIn('ca'), 'País Basc');
    expect(basque.nameIn('en'), 'Basque Country');
    expect(regionByCode('ES-CT')!.nameIn('eu'), 'Katalunia');
    expect(regionByCode('ES-AN')!.nameIn('eu'), 'Andaluzia');
  });

  test('a language with no column falls back to Spanish', () {
    expect(regionByCode('ES-MD')!.nameIn('fr'), 'Comunidad de Madrid');
  });

  test('the picker order follows the names in the app language', () {
    final eu = regionsInOrder('eu').map((r) => r.nameIn('eu')).toList();
    expect(eu.first, 'Andaluzia');
    expect(eu.indexOf('Euskadi'), lessThan(eu.indexOf('Katalunia')));
    expect(eu.last, 'Valentziako Erkidegoa');
    expect(regionsInOrder('es').map((r) => r.code), [
      for (final r in alphabeticalRegions) r.code,
    ]);
  });
}
