import 'dart:io';

import 'package:cuadrante/core/database/app_database.dart';
import 'package:cuadrante/features/backup/domain/backup_codec.dart';
import 'package:cuadrante/features/holidays/data/holiday_bundle_loader.dart';
import 'package:cuadrante/features/holidays/data/holiday_repository.dart';
import 'package:cuadrante/features/holidays/data/holiday_snapshot.dart';
import 'package:cuadrante/features/holidays/domain/holiday.dart';
import 'package:cuadrante/features/holidays/domain/holiday_country.dart';
import 'package:cuadrante/features/holidays/domain/holiday_place.dart';
import 'package:cuadrante/features/schedule/domain/civil_date.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_storage.dart' show openMemoryDatabase, makeTempDir;
import '../backup/backup_test_support.dart' show makeRepository;
import 'bundle_support.dart';

/// The place of a person who used the app before countries existed: only
/// `holidays.region` / `holidays.municipality`, no `holidays.country`.
Future<void> _legacyPlace(
  AppDatabase db, {
  String? region,
  String? municipality,
}) async {
  for (final (key, value) in [
    ('holidays.region', region),
    ('holidays.municipality', municipality),
  ]) {
    if (value == null) continue;
    await db
        .into(db.settings)
        .insert(SettingsCompanion.insert(key: key, value: '"$value"'));
  }
}

Future<Map<String, String>> _holidaySettings(AppDatabase db) async {
  final rows = await db
      .customSelect(
        "SELECT key, value FROM settings WHERE key LIKE 'holidays.%' "
        "AND key <> 'holidays.bundleVersion' ORDER BY key",
      )
      .get();
  return {for (final r in rows) r.read<String>('key'): r.read<String>('value')};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late HolidayRepository repo;
  late HolidayBundleLoader loader;

  setUp(() {
    db = openMemoryDatabase();
    repo = HolidayRepository(db);
    loader = HolidayBundleLoader(bundle: shippedBundle());
  });

  tearDown(() => db.close());

  Future<List<String>> datesFor(HolidayPlace place) async {
    final calendar = HolidaySnapshot(
      place: place,
      entries: await repo.entriesFor(place),
    ).calendar;
    return [
      for (final h in calendar.list(
        const CivilDate(2026, 1, 1),
        const CivilDate(2026, 12, 31),
      ))
        h.date.toIso(),
    ];
  }

  group('what is already stored keeps what it showed', () {
    test('nothing stored: Spain, national only', () async {
      await repo.refreshBundled(loader);
      final place = await repo.loadPlace();
      expect(place, HolidayPlace.spain);
      expect(place.isSpain, isTrue);
      expect(await datesFor(place), hasLength(7));
      expect(await datesFor(place), contains('2026-10-12'));
    });

    test(
      'region and municipality without a country: Spain, both kept',
      () async {
        await _legacyPlace(db, region: 'ES-CT', municipality: '08019');
        expect(
          await repo.loadPlace(),
          const HolidayPlace(
            countryCode: 'ES',
            regionCode: 'ES-CT',
            municipalityCode: '08019',
          ),
        );
      },
    );

    test('a region alone without a country: Spain with it', () async {
      await _legacyPlace(db, region: 'ES-MD');
      expect(await repo.loadPlace(), const HolidayPlace(regionCode: 'ES-MD'));
    });

    test(
      'loading never writes: the stored settings stay as they were',
      () async {
        await _legacyPlace(db, region: 'ES-VC', municipality: '46250');
        await repo.loadPlace();
        await repo.loadSnapshot();
        expect(await _holidaySettings(db), {
          'holidays.municipality': '"46250"',
          'holidays.region': '"ES-VC"',
        });
      },
    );

    test('an unreadable country is Spain (never loses the holidays)', () async {
      await _legacyPlace(db, region: 'ES-CT');
      for (final raw in ['"ESP"', '42', 'not json', '""', 'null']) {
        await db
            .into(db.settings)
            .insertOnConflictUpdate(
              SettingsCompanion(
                key: const Value('holidays.country'),
                value: Value(raw),
              ),
            );
        expect(
          await repo.loadPlace(),
          const HolidayPlace(regionCode: 'ES-CT'),
          reason: raw,
        );
      }
    });
  });

  group('choosing a country', () {
    test(
      'another country is stored and clears region and municipality',
      () async {
        await repo.savePlace(regionCode: 'ES-CT', municipalityCode: '08019');
        final place = await repo.savePlace(countryCode: 'mx');
        expect(place, const HolidayPlace(countryCode: 'MX'));
        expect(await repo.loadPlace(), const HolidayPlace(countryCode: 'MX'));
        expect(await _holidaySettings(db), {'holidays.country': '"MX"'});
      },
    );

    test('«Otro país» is stored as ZZ', () async {
      await repo.savePlace(countryCode: otherCountryCode);
      final place = await repo.loadPlace();
      expect(place, HolidayPlace.otherCountry);
      expect(place.isOtherCountry, isTrue);
      expect(await _holidaySettings(db), {'holidays.country': '"ZZ"'});
    });

    test('back to Spain writes ES and the region again', () async {
      await repo.savePlace(countryCode: 'MX');
      await repo.savePlace(regionCode: 'ES-MD');
      expect(await repo.loadPlace(), const HolidayPlace(regionCode: 'ES-MD'));
      expect(await _holidaySettings(db), {
        'holidays.country': '"ES"',
        'holidays.region': '"ES-MD"',
      });
    });

    test('a region or a municipality outside Spain is rejected', () async {
      expect(
        () => repo.savePlace(countryCode: 'MX', regionCode: 'ES-CT'),
        throwsArgumentError,
      );
      expect(
        () => repo.savePlace(countryCode: 'MX', municipalityCode: '08019'),
        throwsArgumentError,
      );
      expect(() => repo.savePlace(countryCode: 'MEX'), throwsArgumentError);
      expect(() => repo.savePlace(countryCode: ''), throwsArgumentError);
      expect(await repo.loadPlace(), HolidayPlace.spain);
    });

    test('a region stored by hand under another country is ignored', () async {
      await repo.savePlace(countryCode: 'MX');
      await _legacyPlace(db, region: 'ES-CT');
      expect(await repo.loadPlace(), const HolidayPlace(countryCode: 'MX'));
    });
  });

  group('rows for another country', () {
    const own = CivilDate(2026, 6, 3);

    setUp(() async {
      await repo.refreshBundled(loader);
      await repo.addUserHoliday(date: own, name: 'Mi fiesta');
    });

    test('Poland without data: only the own holidays, no 12 October', () async {
      final place = await repo.savePlace(countryCode: 'PL');
      final entries = await repo.entriesFor(place);
      expect(entries.every((e) => e.source == HolidaySource.user), isTrue);
      expect(await datesFor(place), ['2026-06-03']);
    });

    test('«Otro país»: only the own holidays', () async {
      final place = await repo.savePlace(countryCode: otherCountryCode);
      expect(await datesFor(place), ['2026-06-03']);
      final snapshot = await repo.loadSnapshot();
      expect(snapshot.byDay.keys, [own]);
    });

    test('Poland with rows: its national ones, never Spain\'s', () async {
      await db.batch((b) {
        b.insertAll(db.holidays, [
          HolidaysCompanion.insert(
            date: '2026-09-16',
            scope: HolidayScope.national.name,
            name: 'Día de la Independencia',
            regionCode: const Value('PL'),
            source: HolidaySource.bundled.name,
          ),
          HolidaysCompanion.insert(
            date: '2026-01-06',
            scope: HolidayScope.national.name,
            name: 'Reyes',
            regionCode: const Value('PL-MZ'),
            source: HolidaySource.bundled.name,
          ),
        ]);
      });
      final poland = await repo.savePlace(countryCode: 'PL');
      expect(await datesFor(poland), ['2026-06-03', '2026-09-16']);
      // Spain does not see them, and the «No son festivo en…» note only
      // reads Spanish regions.
      expect(await datesFor(HolidayPlace.spain), isNot(contains('2026-09-16')));
      expect(
        (await repo.regionalNationalEntries()).where(
          (e) => e.countryCode != 'ES',
        ),
        isEmpty,
      );
    });

    test('the own holidays survive a change of country', () async {
      await repo.savePlace(countryCode: 'MX');
      await repo.savePlace(countryCode: otherCountryCode);
      await repo.savePlace();
      expect((await repo.userHolidays()).map((e) => e.date), [own]);
    });
  });

  group('backups', () {
    test(
      'a version 1 backup (no country) restores as Spain with its place',
      () async {
        final bytes = File('test/fixtures/golden_backup/golden_v1.cuadrante')
            .readAsBytesSync();
        final data = const BackupCodec().decode(bytes).data;
        expect(data.settings.containsKey('holidays.country'), isFalse);

        await makeRepository(db, makeTempDir('festivos-v1')).restore(data);

        expect(
          await repo.loadPlace(),
          const HolidayPlace(regionCode: 'ES-VC', municipalityCode: '46250'),
        );
      },
    );

    test('the country travels in a new backup and comes back', () async {
      await repo.savePlace(countryCode: 'MX');
      final source = makeRepository(db, makeTempDir('festivos-out'));
      final data = await source.readAll();
      expect(data.settings['holidays.country'], '"MX"');

      final other = openMemoryDatabase();
      addTearDown(other.close);
      await makeRepository(other, makeTempDir('festivos-in')).restore(data);
      expect(
        await HolidayRepository(other).loadPlace(),
        const HolidayPlace(countryCode: 'MX'),
      );
    });

    test(
      'restoring an old backup over another country goes back to Spain',
      () async {
        await repo.savePlace(countryCode: otherCountryCode);
        final bytes = File('test/fixtures/golden_backup/golden_v1.cuadrante')
            .readAsBytesSync();
        await makeRepository(
          db,
          makeTempDir('festivos-over'),
        ).restore(const BackupCodec().decode(bytes).data);
        expect((await repo.loadPlace()).isSpain, isTrue);
      },
    );
  });
}
