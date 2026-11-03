import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:cuadrante/core/format/text_fold.dart';
import 'package:cuadrante/features/holidays/data/holiday_bundle_format.dart';
import 'package:cuadrante/features/holidays/data/holiday_bundle_loader.dart';
import 'package:cuadrante/features/holidays/domain/holiday.dart';
import 'package:cuadrante/features/holidays/domain/holiday_calendar.dart';
import 'package:cuadrante/features/holidays/domain/holiday_country.dart';
import 'package:cuadrante/features/holidays/domain/holiday_entry.dart';
import 'package:cuadrante/features/schedule/domain/civil_date.dart';
import 'package:flutter_test/flutter_test.dart';

import 'bundle_support.dart';

const _year2026 = (CivilDate(2026, 1, 1), CivilDate(2026, 12, 31));

/// What a future Mexican package would bring (D4): a national row stored
/// with the country code as region, and a subdivision row.
final List<HolidayEntry> _mexico = [
  const HolidayEntry(
    date: CivilDate(2026, 9, 16),
    scope: HolidayScope.national,
    name: 'Día de la Independencia',
    regionCode: 'MX',
  ),
  const HolidayEntry(
    date: CivilDate(2026, 3, 21),
    scope: HolidayScope.regional,
    name: 'Natalicio',
    regionCode: 'MX-CMX',
  ),
];

const _own = HolidayEntry(
  date: CivilDate(2026, 6, 3),
  scope: HolidayScope.local,
  name: 'Mi fiesta',
  source: HolidaySource.user,
);

List<String> _dates(HolidayCalendar c) => [
  for (final h in c.list(_year2026.$1, _year2026.$2)) h.date.toIso(),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('codes', () {
    test('normalizes alpha-2 codes, rejects anything else', () {
      expect(normalizeCountryCode('mx'), 'MX');
      expect(normalizeCountryCode('ES'), 'ES');
      expect(normalizeCountryCode('ZZ'), otherCountryCode);
      expect(normalizeCountryCode(null), isNull);
      expect(normalizeCountryCode(''), isNull);
      expect(normalizeCountryCode('ESP'), isNull);
      expect(normalizeCountryCode('E1'), isNull);
      expect(normalizeCountryCode('ES-CT'), isNull);
    });

    test('a row tells its country by its region code', () {
      HolidayEntry row(String? region) => HolidayEntry(
        date: const CivilDate(2026, 1, 1),
        scope: HolidayScope.national,
        name: 'x',
        regionCode: region,
      );
      expect(row(null).countryCode, 'ES');
      expect(row(null).isCountryWide, isTrue);
      expect(row('ES-CT').countryCode, 'ES');
      expect(row('ES-CT').isCountryWide, isFalse);
      expect(row('MX').countryCode, 'MX');
      expect(row('MX').isCountryWide, isTrue);
      expect(row('MX-CMX').countryCode, 'MX');
      expect(row('MX-CMX').isCountryWide, isFalse);
    });
  });

  group('proposal from the phone region', () {
    test('Spain proposes Spain', () {
      expect(proposeHolidayCountry('ES'), spainCountryCode);
      expect(proposeHolidayCountry('es'), spainCountryCode);
    });

    test('a listed country proposes itself', () {
      expect(proposeHolidayCountry('MX'), 'MX');
      expect(proposeHolidayCountry('br'), 'BR');
    });

    test('a country the picker does not list is «Otro país»', () {
      expect(proposeHolidayCountry('JP'), otherCountryCode);
      expect(proposeHolidayCountry('ZZ'), otherCountryCode);
    });

    test('a phone that says nothing keeps Spain (what the app did)', () {
      expect(proposeHolidayCountry(null), spainCountryCode);
      expect(proposeHolidayCountry(''), spainCountryCode);
      expect(proposeHolidayCountry('419'), spainCountryCode);
    });
  });

  group('picker list', () {
    test('every country has a name in the five languages', () {
      for (final c in holidayCountries) {
        expect(normalizeCountryCode(c.code), c.code, reason: c.code);
        for (final language in ['es', 'ca', 'gl', 'eu', 'en']) {
          expect(c.names[language], isNotEmpty, reason: '${c.code} $language');
        }
      }
      expect(
        holidayCountries.map((c) => c.code).toSet(),
        hasLength(holidayCountries.length),
        reason: 'no repeated code',
      );
      expect(countryByCode(otherCountryCode), isNull);
    });

    for (final language in ['es', 'ca', 'gl', 'eu', 'en']) {
      test('$language: Spain first, the rest by name, accents ignored', () {
        final list = countriesForPicker(language);
        expect(list.first.code, spainCountryCode);
        expect(list, hasLength(holidayCountries.length));
        final rest = [for (final c in list.skip(1)) c.nameIn(language)];
        final sorted = [...rest]..sort(compareSpanish);
        expect(rest, sorted);
      });
    }

    test('names follow the language', () {
      expect(countryName('MX', 'es'), 'México');
      expect(countryName('MX', 'ca'), 'Mèxic');
      expect(countryName('MX', 'eu'), 'Mexiko');
      expect(countryName('DE', 'gl'), 'Alemaña');
      expect(countryName('US', 'en'), 'United States');
      // Unknown language: Spanish. Unknown country: its code.
      expect(countryName('FR', 'pt'), 'Francia');
      expect(countryName('jp', 'es'), 'JP');
    });

    test('in Spanish «Bélgica» goes between «Austria» and «Bolivia»', () {
      final names = [for (final c in countriesForPicker('es')) c.code];
      expect(names.indexOf('BE'), greaterThan(names.indexOf('AU')));
      expect(names.indexOf('BE'), lessThan(names.indexOf('BO')));
    });
  });

  group('HolidayCalendar by country', () {
    late List<HolidayEntry> spain;
    late List<HolidayEntry> all;

    setUpAll(() async {
      // Spain's rows only: this group builds its own Mexico.
      spain = [
        for (final e in await shippedEntries())
          if (e.countryCode == spainCountryCode) e,
      ];
      all = [...spain, ..._mexico, _own];
    });

    test('the default is Spain: exactly what it showed before', () {
      expect(
        HolidayCalendar(spain).list(_year2026.$1, _year2026.$2),
        HolidayCalendar(
          spain,
          countryCode: 'ES',
        ).list(_year2026.$1, _year2026.$2),
      );
      expect(_dates(HolidayCalendar(spain)), hasLength(7));
      expect(
        _dates(HolidayCalendar(spain, regionCode: 'ES-CT')),
        contains('2026-12-26'),
      );
    });

    test('Spain never sees another country\'s rows', () {
      final dates = _dates(HolidayCalendar(all));
      expect(dates, isNot(contains('2026-09-16')));
      expect(dates, contains('2026-10-12'));
      expect(dates, contains('2026-06-03'), reason: 'own holiday');
    });

    test('Mexico: no 12 October, its own national day', () {
      final dates = _dates(HolidayCalendar(all, countryCode: 'MX'));
      expect(dates, ['2026-06-03', '2026-09-16']);
    });

    test('a country without data: only the person\'s own holidays', () {
      expect(_dates(HolidayCalendar(all, countryCode: 'AR')), ['2026-06-03']);
    });

    test('«Otro país» (ZZ): only the person\'s own holidays', () {
      final calendar = HolidayCalendar(all, countryCode: otherCountryCode);
      expect(_dates(calendar), ['2026-06-03']);
      expect(calendar.on(const CivilDate(2026, 6, 3))!.isUserAdded, isTrue);
      expect(calendar.on(const CivilDate(2026, 12, 25)), isNull);
    });

    test('a bad country code counts as «Otro país»', () {
      expect(
        HolidayCalendar(all, countryCode: 'ESP').countryCode,
        otherCountryCode,
      );
      expect(_dates(HolidayCalendar(all, countryCode: '')), ['2026-06-03']);
    });

    test('a Spanish region or municipality is ignored outside Spain', () {
      final calendar = HolidayCalendar(
        all,
        countryCode: 'MX',
        regionCode: 'ES-CT',
        municipalityCode: '08019',
      );
      expect(calendar.regionCode, isNull);
      expect(calendar.municipalityCode, isNull);
      expect(_dates(calendar), ['2026-06-03', '2026-09-16']);
    });

    test('the own holiday wins on a day with an official one', () {
      final ownOnNational = HolidayEntry(
        date: const CivilDate(2026, 9, 16),
        scope: HolidayScope.local,
        name: 'Turno doble',
        source: HolidaySource.user,
      );
      final calendar = HolidayCalendar([
        ..._mexico,
        ownOnNational,
      ], countryCode: 'MX');
      expect(calendar.on(const CivilDate(2026, 9, 16))!.name, 'Turno doble');
    });
  });

  group('country packages', () {
    Map<String, Object?> mexicoFile() => {
      'schema': 1,
      'year': 2027,
      'country': 'MX',
      'national': [
        {'date': '2027-09-16', 'name': 'Día de la Independencia'},
      ],
      'regional': {
        'MX-CMX': [
          {'date': '2027-03-15', 'name': 'Natalicio', 'origin': 'regional'},
        ],
      },
    };

    test('a country file: national rows carry the country code', () {
      final rows = parseCountryFile(mexicoFile());
      expect(rows, hasLength(2));
      expect(rows.first.regionCode, 'MX');
      expect(rows.first.scope, HolidayScope.national);
      expect(rows.first.countryCode, 'MX');
      expect(rows.last.regionCode, 'MX-CMX');
      expect(rows.last.scope, HolidayScope.regional);
    });

    test('regional is optional', () {
      final rows = parseCountryFile(mexicoFile()..remove('regional'));
      expect(rows.map((e) => e.regionCode), ['MX']);
    });

    test('a file of Spain reads exactly like es.json', () {
      final es = {
        'schema': 1,
        'year': 2026,
        'national': [
          {'date': '2026-01-01', 'name': 'Año Nuevo'},
        ],
        'regional': {
          'ES-CT': [
            {'date': '2026-12-26', 'name': 'San Esteban', 'origin': 'regional'},
          ],
        },
      };
      expect(parseCountryFile({...es, 'country': 'es'}), parseEsFile(es));
    });

    test('rejects a bad country, schema or subdivision', () {
      expect(
        () => parseCountryFile(mexicoFile()..['country'] = 'MEX'),
        throwsA(isA<HolidayBundleException>()),
      );
      expect(
        () => parseCountryFile(mexicoFile()..['country'] = otherCountryCode),
        throwsA(isA<HolidayBundleException>()),
      );
      expect(
        () => parseCountryFile(mexicoFile()..['schema'] = 2),
        throwsA(isA<HolidayBundleException>()),
      );
      expect(
        () => parseCountryFile(
          mexicoFile()
            ..['regional'] = {
              'ES-CT': [
                {'date': '2027-01-06', 'name': 'x', 'origin': 'regional'},
              ],
            },
        ),
        throwsA(isA<HolidayBundleException>()),
        reason: 'a region of another country',
      );
      expect(
        () => parseCountryFile(mexicoFile()..['year'] = 2026),
        throwsA(isA<HolidayBundleException>()),
        reason: 'dates outside the year',
      );
    });

    group('in a bundle', () {
      MemoryAssetBundle bundleWithMexico({String manifestCountry = 'MX'}) {
        final files = shippedBundleFiles();
        final bytes = utf8.encode(jsonEncode(mexicoFile()));
        const path = '2027/mx.json';
        files['assets/holidays/$path'] = bytes;
        final manifest = jsonDecode(
          utf8.decode(files['assets/holidays/manifest.json']!),
        ) as Map<String, Object?>;
        // The shipped bundle has its own Mexico: this fixture replaces 2027.
        (manifest['files']! as List).removeWhere(
          (f) => (f as Map)['path'] == path,
        );
        (manifest['files']! as List).add({
          'path': path,
          'year': 2027,
          'scope': 'country',
          'country': manifestCountry,
          'sha256': sha256.convert(bytes).toString(),
          'bytes': bytes.length,
        });
        files['assets/holidays/manifest.json'] = utf8.encode(
          jsonEncode(manifest),
        );
        return MemoryAssetBundle(files);
      }

      test('the loader reads a country package next to Spain\'s', () async {
        final loaded = await HolidayBundleLoader(bundle: bundleWithMexico())
            .load();
        final shipped = await shippedEntries();
        expect(loaded.manifest.countries, containsAll(['ES', 'MX']));
        expect(loaded.manifest.years, [2026, 2027], reason: 'es.json years');
        bool mexico2027(HolidayEntry e) =>
            e.countryCode == 'MX' && e.date.year == 2027;
        expect(loaded.entries.where(mexico2027), hasLength(2));
        // Everything else is what ships.
        expect(
          loaded.entries.length,
          shipped.length - shipped.where(mexico2027).length + 2,
        );
      });

      test('a manifest whose country does not match is rejected', () async {
        await expectLater(
          HolidayBundleLoader(bundle: bundleWithMexico(manifestCountry: 'AR'))
              .load(),
          throwsA(isA<HolidayBundleException>()),
        );
      });

      test('a country line without a country is rejected', () {
        expect(
          () => HolidayManifestFile.fromJson({
            'path': '2027/mx.json',
            'year': 2027,
            'scope': 'country',
            'sha256': 'x',
            'bytes': 1,
          }),
          throwsA(isA<HolidayBundleException>()),
        );
      });

      test('the manifest line keeps its country', () {
        final line = HolidayManifestFile.fromJson({
          'path': '2027/mx.json',
          'year': 2027,
          'scope': 'country',
          'country': 'mx',
          'sha256': 'x',
          'bytes': 1,
        });
        expect(line.country, 'MX');
        expect(line.toJson()['country'], 'MX');
      });

      test('the shipped bundle: Spain plus the 21 countries of D4', () async {
        final manifest = await HolidayBundleLoader(bundle: shippedBundle())
            .readManifest();
        expect(manifest.countries, hasLength(22));
        expect(manifest.countries, containsAll(['ES', 'MX', 'DE', 'US']));
        expect(manifest.countries, isNot(contains('PL')));
      });
    });
  });
}
