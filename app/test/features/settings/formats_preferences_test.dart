import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:cuadrante/core/config.dart';
import 'package:cuadrante/core/database/app_database.dart';
import 'package:cuadrante/features/backup/data/backup_repository.dart'
    show isDeviceSetting;
import 'package:cuadrante/features/settings/application/preferences_controller.dart';
import 'package:cuadrante/features/settings/data/preferences_repository.dart';
import 'package:cuadrante/features/settings/domain/preferences.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_storage.dart';

/// Formato de hora, moneda y los valores por defecto de una instalación nueva
/// frente a una existente (docs/formatos.md).
void main() {
  late AppDatabase db;
  late PreferencesRepository repository;

  setUp(() {
    db = openMemoryDatabase();
    repository = PreferencesRepository(db);
  });
  tearDown(() => db.close());

  Future<void> store(String key, String json) => db
      .into(db.settings)
      .insertOnConflictUpdate(
        SettingsCompanion(key: Value(key), value: Value(json)),
      );

  Future<String?> stored(String key) async {
    final row = await (db.select(
      db.settings,
    )..where((s) => s.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  group('an existing installation (no rows)', () {
    test('keeps today\'s behaviour: 24 h, euros, Monday', () async {
      final loaded = await repository.load();
      expect(loaded.timeFormat, TimeFormatPreference.h24);
      expect(loaded.currency, 'EUR');
      expect(loaded.weekStart, WeekStart.monday);
      expect(loaded, Preferences.defaults);
    });

    test('rows that hold something else fall back to the defaults', () async {
      await store(PreferenceKeys.timeFormat, '"26"');
      await store(PreferenceKeys.currency, '"euro"');
      final loaded = await repository.load();
      expect(loaded.timeFormat, TimeFormatPreference.h24);
      expect(loaded.currency, 'EUR');
      await store(PreferenceKeys.timeFormat, '12');
      await store(PreferenceKeys.currency, '7');
      expect((await repository.load()).timeFormat, TimeFormatPreference.h24);
      expect((await repository.load()).currency, 'EUR');
    });
  });

  group('round trip', () {
    test('time format and currency', () async {
      await repository.setTimeFormat(TimeFormatPreference.h12);
      await repository.setCurrency('JPY');
      final loaded = await repository.load();
      expect(loaded.timeFormat, TimeFormatPreference.h12);
      expect(loaded.currency, 'JPY');
      expect(await stored(PreferenceKeys.timeFormat), '"12"');
      expect(await stored(PreferenceKeys.currency), '"JPY"');

      await repository.setTimeFormat(TimeFormatPreference.auto);
      expect(await stored(PreferenceKeys.timeFormat), '"auto"');
      expect((await repository.load()).timeFormat, TimeFormatPreference.auto);
    });

    test('a currency that is not an ISO code is refused', () async {
      for (final bad in ['', 'eur', 'EURO', 'E1R', '€']) {
        expect(() => repository.setCurrency(bad), throwsArgumentError);
      }
      expect(await stored(PreferenceKeys.currency), isNull);
    });
  });

  group('seedRegionDefaults (a new installation)', () {
    Future<Preferences> seeded(List<Locale> phone) async {
      await repository.seedRegionDefaults(phone);
      return repository.load();
    }

    test('Spain: Monday, euros, the clock of the phone', () async {
      final p = await seeded(const [Locale('es', 'ES')]);
      expect(p.weekStart, WeekStart.monday);
      expect(p.currency, 'EUR');
      expect(p.timeFormat, TimeFormatPreference.auto);
    });

    test('United States: Sunday, dollars', () async {
      final p = await seeded(const [Locale('en', 'US')]);
      expect(p.weekStart, WeekStart.sunday);
      expect(p.currency, 'USD');
      expect(p.timeFormat, TimeFormatPreference.auto);
    });

    test('Mexico, Brazil, United Kingdom, Japan', () async {
      expect(
        (await seeded(const [Locale('es', 'MX')])).weekStart,
        WeekStart.sunday,
      );
      await db.delete(db.settings).go();
      final br = await seeded(const [Locale('pt', 'BR')]);
      expect(br.weekStart, WeekStart.sunday);
      expect(br.currency, 'BRL');
      await db.delete(db.settings).go();
      final gb = await seeded(const [Locale('en', 'GB')]);
      expect(gb.weekStart, WeekStart.monday);
      expect(gb.currency, 'GBP');
      await db.delete(db.settings).go();
      final jp = await seeded(const [Locale('ja', 'JP')]);
      expect(jp.weekStart, WeekStart.sunday);
      expect(jp.currency, 'JPY');
    });

    test('no region or an unknown one: Monday and euros', () async {
      final p = await seeded(const [Locale('es')]);
      expect(p.weekStart, WeekStart.monday);
      expect(p.currency, 'EUR');
      await db.delete(db.settings).go();
      expect((await seeded(const [Locale('xx', 'ZZ')])).currency, 'EUR');
      await db.delete(db.settings).go();
      expect((await seeded(const [])).currency, 'EUR');
    });

    test('never overwrites what is already stored', () async {
      await repository.setWeekStart(WeekStart.monday);
      await repository.setCurrency('GBP');
      await repository.setTimeFormat(TimeFormatPreference.h24);
      final p = await seeded(const [Locale('en', 'US')]);
      expect(p.weekStart, WeekStart.monday);
      expect(p.currency, 'GBP');
      expect(p.timeFormat, TimeFormatPreference.h24);
    });

    test('seeding twice changes nothing', () async {
      await seeded(const [Locale('en', 'US')]);
      await repository.setCurrency('CAD');
      final again = await seeded(const [Locale('es', 'ES')]);
      expect(again.currency, 'CAD');
      expect(again.weekStart, WeekStart.sunday);
    });
  });

  group('bootstrap', () {
    // A new database is seeded; the phone's languages are fixed by
    // `debugPhoneLocales` (the test config puts Spanish Spain).
    tearDown(() => debugPhoneLocales = const [Locale('es', 'ES')]);

    Future<Preferences> start(List<Locale> phone, {bool demo = false}) async {
      debugPhoneLocales = phone;
      final database = openMemoryDatabase();
      addTearDown(database.close);
      final result = await bootstrapApp(
        database: database,
        now: () => DateTime(2026, 10, 19, 12),
        config: AppConfig(useDemoData: demo),
      );
      return result.preferences;
    }

    test('a new installation in the United States', () async {
      final p = await start(const [Locale('en', 'US')]);
      expect(p.weekStart, WeekStart.sunday);
      expect(p.currency, 'USD');
      expect(p.timeFormat, TimeFormatPreference.auto);
    });

    test('a new installation in Spain', () async {
      final p = await start(const [Locale('es', 'ES')]);
      expect(p.weekStart, WeekStart.monday);
      expect(p.currency, 'EUR');
      expect(p.timeFormat, TimeFormatPreference.auto);
    });

    test('the demo database keeps the defaults of the QA scripts', () async {
      final p = await start(const [Locale('en', 'US')], demo: true);
      expect(p, Preferences.defaults);
    });
  });

  group('TimeFormatPreference', () {
    test('stored values', () {
      expect(TimeFormatPreference.auto.stored, 'auto');
      expect(TimeFormatPreference.h24.stored, '24');
      expect(TimeFormatPreference.h12.stored, '12');
      for (final option in TimeFormatPreference.values) {
        expect(TimeFormatPreference.fromStored(option.stored), option);
      }
      expect(TimeFormatPreference.fromStored(null), TimeFormatPreference.h24);
      expect(TimeFormatPreference.fromStored('x'), TimeFormatPreference.h24);
    });

    test('resolve: 24 h and 12 h are what they say', () {
      for (final phone24 in [true, false]) {
        for (final locale12 in [true, false]) {
          expect(
            TimeFormatPreference.h24.resolve(
              phoneUses24Hour: phone24,
              localeUses12Hour: locale12,
            ),
            isFalse,
          );
          expect(
            TimeFormatPreference.h12.resolve(
              phoneUses24Hour: phone24,
              localeUses12Hour: locale12,
            ),
            isTrue,
          );
        }
      }
    });

    test('resolve: automatic follows the phone, then the region', () {
      bool auto({required bool phone24, required bool locale12}) =>
          TimeFormatPreference.auto.resolve(
            phoneUses24Hour: phone24,
            localeUses12Hour: locale12,
          );
      expect(auto(phone24: true, locale12: true), isFalse);
      expect(auto(phone24: true, locale12: false), isFalse);
      expect(auto(phone24: false, locale12: true), isTrue);
      expect(auto(phone24: false, locale12: false), isFalse);
    });
  });

  group('backup', () {
    test('the clock is a setting of this phone, the currency travels', () {
      expect(isDeviceSetting(PreferenceKeys.timeFormat), isTrue);
      expect(isDeviceSetting(PreferenceKeys.language), isTrue);
      expect(isDeviceSetting(PreferenceKeys.currency), isFalse);
      expect(isDeviceSetting(PreferenceKeys.weekStart), isFalse);
    });
  });

  group('controller', () {
    test('applies at once, writes, and undoes a failed write', () async {
      final container = ProviderContainer(
        overrides: [
          preferencesRepositoryProvider.overrideWithValue(repository),
          initialPreferencesProvider.overrideWithValue(Preferences.defaults),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(preferencesProvider.notifier);

      await controller.setTimeFormat(TimeFormatPreference.h12);
      await controller.setCurrency('USD');
      expect(
        container.read(preferencesProvider).timeFormat,
        TimeFormatPreference.h12,
      );
      expect(container.read(preferencesProvider).currency, 'USD');
      expect((await repository.load()).currency, 'USD');

      // A code that is not valid is refused by the repository: the previous
      // value comes back.
      await expectLater(controller.setCurrency('dollar'), throwsArgumentError);
      expect(container.read(preferencesProvider).currency, 'USD');
    });
  });
}
