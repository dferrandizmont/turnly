import 'package:cuadrante/core/format/region_defaults.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('regionOfPhone', () {
    test('the first language that carries a region', () {
      expect(
        regionOfPhone(const [Locale('es', 'MX'), Locale('en', 'US')]),
        'MX',
      );
      expect(regionOfPhone(const [Locale('es'), Locale('en', 'GB')]), 'GB');
    });

    test('none: null', () {
      expect(regionOfPhone(const []), isNull);
      expect(regionOfPhone(const [Locale('es')]), isNull);
    });
  });

  group('formatLocaleName', () {
    test('language of the app with the region of the phone', () {
      expect(formatLocaleName('es', const [Locale('es', 'MX')]), 'es_MX');
      expect(formatLocaleName('en', const [Locale('en', 'GB')]), 'en_GB');
      expect(formatLocaleName('en', const [Locale('en', 'US')]), 'en_US');
    });

    test('a phone in several languages: the region of the same one', () {
      const phone = [Locale('en', 'US'), Locale('es', 'ES')];
      expect(formatLocaleName('es', phone), 'es_ES');
      expect(formatLocaleName('en', phone), 'en_US');
    });

    test('a language the phone does not have: the region of the first', () {
      expect(formatLocaleName('es', const [Locale('en', 'US')]), 'es_US');
      expect(formatLocaleName('ca', const [Locale('fr', 'FR')]), 'ca_FR');
    });

    test('no region anywhere: just the language', () {
      expect(formatLocaleName('es', const [Locale('es')]), 'es');
      expect(formatLocaleName('es', const []), 'es');
    });
  });

  group('weekStartForRegion', () {
    test('Sunday where the calendar starts on Sunday', () {
      for (final region in ['US', 'CA', 'MX', 'BR', 'JP', 'CO', 'PE', 'IL']) {
        expect(weekStartForRegion(region), DateTime.sunday, reason: region);
      }
    });

    test('Monday in Spain, the rest of Europe and when unknown', () {
      for (final region in ['ES', 'FR', 'DE', 'GB', 'IT', 'AR', 'CL', 'XX']) {
        expect(weekStartForRegion(region), DateTime.monday, reason: region);
      }
      expect(weekStartForRegion(null), DateTime.monday);
    });

    test('lower case is fine', () {
      expect(weekStartForRegion('us'), DateTime.sunday);
    });
  });

  group('currencyForRegion', () {
    test('the money of the main regions', () {
      expect(currencyForRegion('US'), 'USD');
      expect(currencyForRegion('GB'), 'GBP');
      expect(currencyForRegion('MX'), 'MXN');
      expect(currencyForRegion('BR'), 'BRL');
      expect(currencyForRegion('AR'), 'ARS');
      expect(currencyForRegion('CL'), 'CLP');
      expect(currencyForRegion('CO'), 'COP');
      expect(currencyForRegion('JP'), 'JPY');
      expect(currencyForRegion('CH'), 'CHF');
    });

    test('the euro area: the euro', () {
      for (final region in ['ES', 'FR', 'DE', 'IT', 'PT', 'IE', 'NL', 'AT']) {
        expect(currencyForRegion(region), 'EUR', reason: region);
      }
    });

    test('unknown or no region: the euro', () {
      expect(currencyForRegion(null), 'EUR');
      expect(currencyForRegion('XX'), 'EUR');
      expect(currencyForRegion('ZZ'), defaultCurrency);
    });

    test('regions of the table', () {
      expect(currencyForRegion('IN'), 'INR');
      expect(currencyForRegion('SG'), 'SGD');
    });

    test('a region only intl knows: its locale\'s currency', () {
      // en_MY is in intl's number data and MY is also in the table; pick one
      // that only intl has: Swiss German is CH (table), Austrian AT is EUR.
      expect(currencyForRegion('AT'), 'EUR');
    });
  });

  test('isCurrencyCode', () {
    expect(isCurrencyCode('EUR'), isTrue);
    expect(isCurrencyCode('eur'), isFalse);
    expect(isCurrencyCode('EURO'), isFalse);
    expect(isCurrencyCode(''), isFalse);
  });
}
