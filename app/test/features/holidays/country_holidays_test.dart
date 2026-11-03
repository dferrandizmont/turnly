import 'dart:convert';

import 'package:cuadrante/core/database/app_database.dart';
import 'package:cuadrante/features/holidays/data/holiday_bundle_format.dart';
import 'package:cuadrante/features/holidays/data/holiday_bundle_loader.dart';
import 'package:cuadrante/features/holidays/data/holiday_repository.dart';
import 'package:cuadrante/features/holidays/domain/country_holiday_data.dart';
import 'package:cuadrante/features/holidays/domain/holiday.dart';
import 'package:cuadrante/features/holidays/domain/holiday_calendar.dart';
import 'package:cuadrante/features/holidays/domain/holiday_country.dart';
import 'package:cuadrante/features/holidays/domain/holiday_entry.dart';
import 'package:cuadrante/features/holidays/domain/holiday_place.dart';
import 'package:cuadrante/features/holidays/domain/holiday_subdivision.dart';
import 'package:cuadrante/features/schedule/domain/civil_date.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_storage.dart' show openMemoryDatabase;
import 'bundle_support.dart';

/// The 21 countries of D4, in the order of the roadmap.
const _countries = [
  'MX', 'AR', 'CO', 'CL', 'PE', 'EC', 'UY', 'VE', 'PT', 'BR', //
  'FR', 'IT', 'DE', 'GB', 'IE', 'US', 'CA', 'NL', 'BE', 'CH', 'AT',
];

/// A national day each country must have, as (country, date). Fixed days and
/// at least one moving one (Easter, a Monday rule, a moved or observed day),
/// checked against an official or reliable source (docs/festivos.md,
/// «Contraste con fuentes»).
const _nationalDays = <(String, String)>[
  ('MX', '2026-09-16'), // Independencia
  ('MX', '2027-02-01'), // Constitución: first Monday of February
  ('MX', '2027-03-15'), // Benito Juárez: third Monday of March
  ('MX', '2027-11-15'), // Revolución: third Monday of November
  ('AR', '2026-05-25'),
  ('AR', '2026-11-09'), // visit of the Pope (DNU 1103/2026)
  ('AR', '2027-03-26'), // Viernes Santo
  ('CO', '2026-07-20'),
  ('CO', '2026-07-13'), // Chiquinquirá moved to Monday (Ley 2578 de 2026)
  ('CO', '2027-05-10'), // Ascensión moved to Monday
  ('CL', '2026-09-18'),
  ('CL', '2027-06-28'), // San Pedro y San Pablo moved to the nearest Monday
  ('CL', '2027-03-27'), // Sábado Santo
  ('PE', '2026-07-28'),
  ('PE', '2027-03-26'),
  ('EC', '2026-08-10'),
  ('EC', '2027-03-26'),
  ('UY', '2026-08-25'),
  ('UY', '2027-12-25'),
  ('VE', '2026-06-24'),
  ('VE', '2027-03-26'),
  ('PT', '2026-04-25'),
  ('PT', '2027-05-27'), // Corpo de Deus
  ('BR', '2026-09-07'),
  ('BR', '2027-03-26'),
  ('FR', '2026-07-14'),
  ('FR', '2027-03-29'), // Lundi de Pâques
  ('FR', '2027-05-06'), // Ascension
  ('IT', '2026-06-02'),
  ('IT', '2027-10-04'), // San Francesco, festivo from 2026 (L. 151/2025)
  ('IT', '2027-03-29'), // Lunedì dell'Angelo
  ('DE', '2026-10-03'),
  ('DE', '2027-03-26'), // Karfreitag
  ('DE', '2027-05-17'), // Pfingstmontag
  ('GB', '2026-12-28'), // Boxing Day, substitute day
  ('GB', '2027-12-27'), // Christmas Day, substitute day
  ('GB', '2027-05-31'), // Spring bank holiday
  ('IE', '2026-03-17'),
  ('IE', '2027-06-07'), // June bank holiday
  ('US', '2026-07-03'), // Independence Day observed
  ('US', '2027-06-18'), // Juneteenth observed
  ('US', '2027-12-24'), // Christmas observed
  ('US', '2027-11-25'), // Thanksgiving
  ('CA', '2026-07-01'),
  ('CA', '2027-03-26'),
  ('NL', '2027-04-27'), // Koningsdag
  ('NL', '2027-05-06'), // Hemelvaartsdag
  ('BE', '2027-07-21'),
  ('BE', '2027-05-17'), // Pinkstermaandag
  ('CH', '2027-08-01'),
  ('CH', '2027-05-06'), // Auffahrt
  ('AT', '2027-10-26'),
  ('AT', '2027-05-27'), // Fronleichnam
];

/// (subdivision, date, name fragment): a day that only that subdivision has.
const _subdivisionDays = <(String, String, String)>[
  ('DE-BY', '2027-05-27', 'Fronleichnam'),
  ('DE-BE', '2026-03-08', 'Frauentag'),
  ('FR-57', '2026-12-26', 'Saint-Étienne'),
  ('GB-SCT', '2026-11-30', "Saint Andrew's"),
  ('GB-SCT', '2026-06-15', 'World Cup'),
  ('GB-NIR', '2026-03-17', "Saint Patrick's"),
  ('US-TX', '2026-03-02', 'Texas Independence'),
  ('US-CA', '2026-03-31', 'Cesar Chavez'),
  ('BR-SP', '2026-07-09', 'Revolução'),
  ('IT-MI', '2026-12-07', "Sant'Ambrogio"),
  ('IT-RM', '2026-06-29', 'Pietro e Paolo'),
  ('CA-QC', '2026-06-24', 'Jean Baptiste'),
  ('PT-20', '2026-05-25', 'Açores'),
  ('CL-AP', '2026-06-07', 'Morro de Arica'),
  ('CH-ZH', '2027-03-26', 'Good Friday'),
];

Future<List<HolidayEntry>> _entries() => shippedEntries();

List<HolidayEntry> _of(List<HolidayEntry> all, String country) => [
  for (final e in all)
    if (e.countryCode == country) e,
];

void main() {
  late List<HolidayEntry> all;
  late HolidayManifest manifest;

  setUpAll(() async {
    final loader = HolidayBundleLoader(bundle: shippedBundle());
    manifest = await loader.readManifest();
    all = (await loader.load(manifest: manifest)).entries;
  });

  group('the bundle', () {
    test(
      'lists the 21 countries plus Spain, every file checked by the loader',
      () {
        expect(
          manifest.countries,
          [...List.of(_countries)..sort(), 'ES']..sort(),
        );
        // Loading verified size and SHA-256 of every file already (setUpAll).
        expect(all, isNotEmpty);
      },
    );

    test('every country has 2026 and 2027 with its provenance', () {
      for (final cc in _countries) {
        for (final year in [2026, 2027]) {
          final files = manifest.files.where(
            (f) =>
                f.kind == HolidayFileKind.country &&
                f.country == cc &&
                f.year == year,
          );
          expect(files, hasLength(1), reason: '$cc $year');
          final file = files.single;
          expect(file.path, '$year/${cc.toLowerCase()}.json');
          final source = file.source!;
          expect(source['url'], startsWith('https://'));
          expect(source['ref'], contains('python-holidays 0.107'));
          expect(source['published'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
        }
      }
    });

    test(
      'every country has national days in both years, all in their year',
      () {
        for (final cc in _countries) {
          final rows = _of(all, cc);
          for (final year in [2026, 2027]) {
            final national = rows.where(
              (e) => e.isCountryWide && e.date.year == year,
            );
            expect(
              national.length,
              greaterThanOrEqualTo(4),
              reason: '$cc $year',
            );
          }
          expect(
            rows.every((e) => e.date.year == 2026 || e.date.year == 2027),
            isTrue,
          );
          expect(
            rows.every((e) => e.regionCode!.startsWith(cc)),
            isTrue,
            reason: cc,
          );
          // Names are real text, with no placeholder left.
          expect(rows.every((e) => e.name.trim().isNotEmpty), isTrue);
        }
      },
    );

    test('Spain still has exactly its own rows', () {
      final spain = _of(all, spainCountryCode);
      expect(
        spain.every((e) => !e.regionCode.toString().startsWith('MX')),
        isTrue,
      );
      final national2026 = spain.where(
        (e) => e.isCountryWide && e.date.year == 2026,
      );
      expect(national2026, hasLength(7));
      final calendar = HolidayCalendar(all);
      expect(
        calendar
            .list(CivilDate(2026, 1, 1), CivilDate(2026, 12, 31))
            .map((h) => h.date.toIso()),
        [
          '2026-01-01',
          '2026-04-03',
          '2026-05-01',
          '2026-08-15',
          '2026-10-12',
          '2026-12-08',
          '2026-12-25',
        ],
      );
      final catalonia = HolidayCalendar(all, regionCode: 'ES-CT');
      expect(catalonia.on(CivilDate(2026, 12, 26))?.name, 'San Esteban');
    });

    test('a country never sees another one\'s days', () {
      final mexico = HolidayCalendar(all, countryCode: 'MX');
      expect(mexico.on(CivilDate(2026, 10, 12)), isNull); // Spain's
      expect(mexico.on(CivilDate(2026, 12, 25))?.name, 'Navidad');
      final germany = HolidayCalendar(all, countryCode: 'DE');
      expect(germany.on(CivilDate(2026, 9, 16)), isNull); // Mexico's
      final other = HolidayCalendar(all, countryCode: otherCountryCode);
      expect(
        other.list(CivilDate(2026, 1, 1), CivilDate(2027, 12, 31)),
        isEmpty,
      );
    });
  });

  group('known national days', () {
    for (final (cc, iso) in _nationalDays) {
      test('$cc $iso', () {
        final calendar = HolidayCalendar(all, countryCode: cc);
        final holiday = calendar.on(CivilDate.parse(iso));
        expect(holiday, isNotNull);
        expect(holiday!.scope, HolidayScope.national);
      });
    }

    test('Mexico: the Mondays of the labour law, not the 12th of October', () {
      final mexico = HolidayCalendar(all, countryCode: 'MX');
      // 2026: Feb 2, Mar 16, Nov 16 (first/third Mondays).
      for (final iso in ['2026-02-02', '2026-03-16', '2026-11-16']) {
        expect(mexico.on(CivilDate.parse(iso)), isNotNull, reason: iso);
      }
      expect(mexico.on(CivilDate(2026, 2, 5)), isNull);
    });

    test('Venezuela: 15 May (a 2024 decree) is not included', () {
      final venezuela = HolidayCalendar(all, countryCode: 'VE');
      expect(venezuela.on(CivilDate(2026, 5, 15)), isNull);
      expect(venezuela.on(CivilDate(2026, 12, 31)), isNotNull);
    });
  });

  group('subdivisions', () {
    for (final (code, iso, fragment) in _subdivisionDays) {
      test('$code $iso', () {
        final country = countryOfSubdivision(code)!;
        final date = CivilDate.parse(iso);
        final inside = HolidayCalendar(
          all,
          countryCode: country,
          regionCode: code,
        ).on(date);
        expect(inside, isNotNull);
        expect(inside!.name, contains(fragment));
        final outside = HolidayCalendar(all, countryCode: country).on(date);
        expect(outside?.name, isNot(contains(fragment)));
      });
    }

    test('a subdivision of another country is ignored', () {
      final calendar = HolidayCalendar(
        all,
        countryCode: 'MX',
        regionCode: 'DE-BY',
      );
      expect(calendar.regionCode, isNull);
      expect(
        HolidayCalendar(all, countryCode: 'DE', regionCode: 'de-by').regionCode,
        'DE-BY',
      );
      expect(
        HolidayCalendar(all, countryCode: 'DE', regionCode: 'DE-XX').regionCode,
        isNull,
      );
    });

    test('Spain keeps its regions and municipalities only', () {
      final calendar = HolidayCalendar(
        all,
        regionCode: 'ES-CT',
        municipalityCode: '08019',
      );
      expect(calendar.regionCode, 'ES-CT');
      expect(calendar.municipalityCode, '08019');
      expect(calendar.on(CivilDate(2026, 5, 25))?.scope, HolidayScope.local);
    });

    test('every key of `regional` has a name, and the data says the kind', () {
      // The keys of `regional` in the files, empty lists included.
      final bundle = shippedBundle();
      final keysByCountry = <String, Set<String>>{};
      for (final cc in _countries) {
        for (final year in [2026, 2027]) {
          final json = jsonDecode(
            utf8.decode(
              bundle.files['assets/holidays/$year/${cc.toLowerCase()}.json']!,
            ),
          ) as Map<String, Object?>;
          final regional = json['regional'] as Map<String, Object?>?;
          if (regional == null) continue;
          keysByCountry.putIfAbsent(cc, () => {}).addAll(regional.keys);
        }
      }
      expect(keysByCountry.keys.toSet(), bundledSubdivisionNames.keys.toSet());
      expect(bundledSubdivisionKinds.keys.toSet(), keysByCountry.keys.toSet());
      for (final MapEntry(key: cc, value: keys) in keysByCountry.entries) {
        final names = bundledSubdivisionNames[cc]!;
        expect(names.keys.toSet(), keys, reason: cc);
        expect(names.keys.every((k) => k.startsWith('$cc-')), isTrue);
        expect(names.values.every((n) => n.trim().isNotEmpty), isTrue);
        expect(subdivisionKindOf(cc), isNotNull, reason: cc);
        expect(subdivisionsOf(cc), hasLength(names.length));
      }
    });

    test('the covered subdivisions (counts of the 2026 export)', () {
      final counts = {
        for (final cc in bundledSubdivisionNames.keys)
          cc: bundledSubdivisionNames[cc]!.length,
      };
      expect(counts['DE'], 16);
      expect(counts['FR'], 14);
      expect(counts['PT'], 20);
      expect(counts['US'], 51); // 50 states and DC
      expect(counts['CH'], 26);
      expect(counts['CA'], 13);
      expect(counts['GB'], 4);
      expect(counts['BR'], 27);
      expect(counts['AR'], 24);
      expect(counts['CL'], 16);
      expect(counts['IT'], 107);
      expect(counts.containsKey('MX'), isFalse);
      expect(counts.containsKey('AT'), isFalse); // no day of their own
    });

    test('the list is alphabetical without caring about accents', () {
      final names = [for (final s in subdivisionsOf('AR')) s.name];
      expect(names.first, 'Buenos Aires');
      expect(names.indexOf('Córdoba'), lessThan(names.indexOf('Corrientes')));
      expect(names.indexOf('Entre Ríos'), lessThan(names.indexOf('Formosa')));
      expect(subdivisionName('de-by'), 'Bayern');
      expect(subdivisionName('XX-1'), isNull);
      expect(subdivisionName(null), isNull);
    });

    test('normalizing', () {
      expect(normalizeSubdivisionCode('DE', 'de-by'), 'DE-BY');
      expect(normalizeSubdivisionCode('de', 'DE-BY'), 'DE-BY');
      expect(normalizeSubdivisionCode('MX', 'DE-BY'), isNull);
      expect(normalizeSubdivisionCode('DE', null), isNull);
      expect(normalizeSubdivisionCode('ES', 'ES-CT'), isNull);
      expect(countryHasHolidayData('mx'), isTrue);
      expect(countryHasHolidayData('ES'), isTrue);
      expect(countryHasHolidayData('JP'), isFalse);
      expect(countryHasHolidayData(otherCountryCode), isFalse);
      expect(countryHasHolidayData(null), isFalse);
      expect(countryHasSubdivisions('US'), isTrue);
      expect(countryHasSubdivisions('MX'), isFalse);
      expect(countryHasSubdivisions('ES'), isFalse);
    });

    test('every bundled country is in the picker list', () {
      for (final cc in bundledCountryCodes) {
        expect(countryByCode(cc), isNotNull, reason: cc);
      }
      expect(bundledCountryCodes, _countries);
    });
  });

  group('the repository', () {
    late AppDatabase db;
    late HolidayRepository repo;

    setUp(() async {
      db = openMemoryDatabase();
      addTearDown(db.close);
      repo = HolidayRepository(db);
      await repo.refreshBundled(HolidayBundleLoader(bundle: shippedBundle()));
    });

    test('stores and reads a subdivision', () async {
      final saved = await repo.savePlace(
        countryCode: 'de',
        regionCode: 'de-by',
      );
      expect(saved, const HolidayPlace(countryCode: 'DE', regionCode: 'DE-BY'));
      expect(await repo.loadPlace(), saved);
      final snapshot = await repo.loadSnapshot();
      expect(snapshot.byDay[CivilDate(2027, 5, 27)]?.name, 'Fronleichnam');
      expect(snapshot.byDay[CivilDate(2027, 3, 26)]?.name, 'Karfreitag');
      // Berlin's Women's Day is not Bavaria's.
      expect(snapshot.byDay[CivilDate(2026, 3, 8)], isNull);
    });

    test('without a subdivision only the national days load', () async {
      final place = await repo.savePlace(countryCode: 'DE');
      final entries = await repo.entriesFor(place);
      expect(entries.every((e) => e.isCountryWide), isTrue);
      expect(entries.length, 18); // 9 days in each of 2026 and 2027
    });

    test('changing country drops the subdivision', () async {
      await repo.savePlace(countryCode: 'DE', regionCode: 'DE-BY');
      final place = await repo.savePlace(countryCode: 'FR');
      expect(place, const HolidayPlace(countryCode: 'FR'));
      expect(await repo.loadPlace(), place);
    });

    test(
      'a subdivision of another country, or a municipality, is refused',
      () async {
        await expectLater(
          repo.savePlace(countryCode: 'DE', regionCode: 'FR-57'),
          throwsArgumentError,
        );
        await expectLater(
          repo.savePlace(countryCode: 'DE', regionCode: 'ES-CT'),
          throwsArgumentError,
        );
        await expectLater(
          repo.savePlace(countryCode: 'MX', regionCode: 'MX-CMX'),
          throwsArgumentError,
        );
        await expectLater(
          repo.savePlace(countryCode: 'DE', municipalityCode: '08019'),
          throwsArgumentError,
        );
      },
    );

    test(
      'a stored subdivision of another country is ignored when read',
      () async {
        await repo.savePlace(countryCode: 'DE', regionCode: 'DE-BY');
        await repo.savePlace(countryCode: 'MX');
        // Same row a hand-edited backup could carry.
        await db
            .into(db.settings)
            .insertOnConflictUpdate(
              SettingsCompanion.insert(
                key: 'holidays.region',
                value: '"DE-BY"',
              ),
            );
        expect(await repo.loadPlace(), const HolidayPlace(countryCode: 'MX'));
      },
    );

    test(
      'Spain is unchanged: region, municipality and the 7 national days',
      () async {
        final spain = await repo.savePlace();
        expect(await repo.entriesFor(spain), isNotEmpty);
        expect(
          (await repo.entriesFor(spain)).every((e) => e.countryCode == 'ES'),
          isTrue,
        );
        final place = await repo.savePlace(
          regionCode: 'ES-CT',
          municipalityCode: '08019',
        );
        expect(place.municipalityCode, '08019');
        final snapshot = await repo.loadSnapshot();
        expect(snapshot.byDay[CivilDate(2026, 12, 26)]?.name, 'San Esteban');
        expect(
          snapshot.byDay[CivilDate(2026, 5, 25)]?.scope,
          HolidayScope.local,
        );
      },
    );
  });

  group('the files', () {
    test('parse and keep the shape of docs/festivos.md', () async {
      final bundle = shippedBundle();
      for (final cc in _countries) {
        for (final year in [2026, 2027]) {
          final path = 'assets/holidays/$year/${cc.toLowerCase()}.json';
          final json = jsonDecode(
            utf8.decode(bundle.files[path]!),
          ) as Map<String, Object?>;
          expect(json['schema'], 1);
          expect(json['year'], year);
          expect(json['country'], cc);
          final rows = parseCountryFile(json);
          expect(rows, isNotEmpty);
          // A day is in `national` once at most.
          final dates = [
            for (final r in rows)
              if (r.isCountryWide) r.date.toIso(),
          ];
          expect(dates.toSet().length, dates.length, reason: path);
        }
      }
    });

    test('a NOTICE with the licence ships next to them', () {
      final notice = utf8.decode(
        shippedBundle().files['assets/holidays/NOTICE']!,
      );
      expect(notice, contains('MIT License'));
      expect(notice, contains('python-holidays 0.107'));
    });

    test('everything loads in one pass', () async {
      expect(await _entries(), hasLength(all.length));
    });
  });
}
