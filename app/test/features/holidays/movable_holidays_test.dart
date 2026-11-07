import 'package:cuadrante/core/database/app_database.dart';
import 'package:cuadrante/features/holidays/data/holiday_bundle_loader.dart';
import 'package:cuadrante/features/holidays/data/holiday_repository.dart';
import 'package:cuadrante/features/holidays/domain/holiday.dart';
import 'package:cuadrante/features/holidays/domain/holiday_calendar.dart';
import 'package:cuadrante/features/holidays/domain/holiday_entry.dart';
import 'package:cuadrante/features/schedule/domain/civil_date.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_storage.dart' show openMemoryDatabase;
import 'bundle_support.dart';

/// Easter Sunday of the Gregorian calendar (Meeus/Jones/Butcher). Written
/// here, apart from the python-holidays library that generated the files, so
/// the test checks the data against a second calculation.
CivilDate westernEaster(int year) {
  final a = year % 19;
  final b = year ~/ 100;
  final c = year % 100;
  final d = b ~/ 4;
  final e = b % 4;
  final f = (b + 8) ~/ 25;
  final g = (b - f + 1) ~/ 3;
  final h = (19 * a + b - d - g + 15) % 30;
  final i = c ~/ 4;
  final k = c % 4;
  final l = (32 + 2 * e + 2 * i - h - k) % 7;
  final m = (a + 11 * h + 22 * l) ~/ 451;
  final month = (h + l - 7 * m + 114) ~/ 31;
  final day = (h + l - 7 * m + 114) % 31 + 1;
  return CivilDate(year, month, day);
}

/// Orthodox Easter Sunday on the Gregorian calendar (Julian computus plus the
/// 13 days between the calendars, valid from 1900 to 2099).
CivilDate orthodoxEaster(int year) {
  final a = year % 4;
  final b = year % 7;
  final c = year % 19;
  final d = (19 * c + 15) % 30;
  final e = (2 * a + 4 * b - d + 34) % 7;
  final month = (d + e + 114) ~/ 31;
  final day = (d + e + 114) % 31 + 1;
  return CivilDate(year, month, day).addDays(13);
}

/// Days from Easter Sunday of the holidays that move with it, per country
/// (negative: before). Fixed days are not here: `country_holidays_test.dart`
/// has them. The offsets are the ones of the national calendar of each
/// country, see `docs/festivos.md`.
const _westernOffsets = <String, Map<String, int>>{
  // The countries of D4.
  'PT': {'Sexta-feira Santa': -2, 'Páscoa': 0, 'Corpo de Deus': 60},
  'FR': {'Lundi de Pâques': 1, 'Ascension': 39, 'Lundi de Pentecôte': 50},
  'IT': {'Pasqua': 0, "Lunedì dell'Angelo": 1},
  'DE': {
    'Karfreitag': -2,
    'Ostermontag': 1,
    'Christi Himmelfahrt': 39,
    'Pfingstmontag': 50,
  },
  'GB': {'Good Friday': -2}, // Easter Monday is not Scotland's
  'CO': {'Jueves Santo': -3, 'Viernes Santo': -2},
  // Proposal 8.
  'GT': {'Jueves Santo': -3, 'Viernes Santo': -2, 'Sábado Santo': -1},
  'BO': {'Carnaval': -47, 'Viernes Santo': -2, 'Corpus Christi': 60},
  'PY': {'Jueves Santo': -3, 'Viernes Santo': -2, 'Domingo de Resurrección': 0},
  'PA': {'Martes de Carnaval': -47, 'Viernes Santo': -2},
  'CR': {'Jueves Santo': -3, 'Viernes Santo': -2},
  'DO': {'Viernes Santo': -2, 'Corpus Christi': 60},
  'HN': {'Jueves Santo': -3, 'Viernes Santo': -2, 'Sábado de Gloria': -1},
  'SV': {'Jueves Santo': -3, 'Viernes Santo': -2, 'Sábado Santo': -1},
  'NI': {'Jueves Santo': -3, 'Viernes Santo': -2},
  'CU': {'Viernes Santo': -2},
  'PL': {
    'Niedziela Wielkanocna': 0,
    'Poniedziałek Wielkanocny': 1,
    'Zielone Świątki': 49,
    'Dzień Bożego Ciała': 60,
  },
  'SE': {
    'Långfredagen': -2,
    'Påskdagen': 0,
    'Annandag påsk': 1,
    'Kristi himmelsfärdsdag': 39,
    'Pingstdagen': 49,
  },
  'NO': {
    'Skjærtorsdag': -3,
    'Langfredag': -2,
    'Første påskedag': 0,
    'Andre påskedag': 1,
    'Kristi himmelfartsdag': 39,
    'Første pinsedag': 49,
  },
  'DK': {
    'Skærtorsdag': -3,
    'Langfredag': -2,
    'Påskedag': 0,
    'Anden påskedag': 1,
    'Kristi himmelfartsdag': 39,
    'Pinsedag': 49,
    'Anden pinsedag': 50,
  },
  'FI': {
    'Pitkäperjantai': -2,
    'Pääsiäispäivä': 0,
    'Toinen pääsiäispäivä': 1,
    'Helatorstai': 39,
    'Helluntaipäivä': 49,
  },
  'LU': {'Easter Monday': 1, 'Ascension Day': 39, 'Pentecost Monday': 50},
  'AD': {
    'Carnaval': -48,
    'Divendres Sant': -2,
    'Dilluns de Pasqua': 1,
    'Dilluns de Pentecosta': 50,
  },
};

/// The Orthodox countries (Greece, Romania) count from the Orthodox Easter.
const _orthodoxOffsets = <String, Map<String, int>>{
  'GR': {
    'Καθαρά Δευτέρα': -48,
    'Μεγάλη Παρασκευή': -2,
    'Δευτέρα του Πάσχα': 1,
    'Δευτέρα του Αγίου Πνεύματος': 50,
  },
  'RO': {'Vinerea Mare': -2, 'Paștele': 0, 'Rusaliile': 49},
};

/// The countries added by proposal 8.
const _newCountries = [
  'GT', 'BO', 'PY', 'PA', 'CR', 'DO', 'HN', 'SV', 'NI', 'CU', //
  'PL', 'SE', 'NO', 'DK', 'FI', 'LU', 'GR', 'RO', 'AD',
];

void main() {
  late List<HolidayEntry> all;

  setUpAll(() async {
    all = await shippedEntries();
  });

  group('the two Easters', () {
    // Dates of the Easter Sunday of three different years, from the churches'
    // own calendars: the calculation is checked before it checks the data.
    test('Western: 2026, 2027 and 2028', () {
      expect(westernEaster(2026), CivilDate(2026, 4, 5));
      expect(westernEaster(2027), CivilDate(2027, 3, 28));
      expect(westernEaster(2028), CivilDate(2028, 4, 16));
    });

    test('Orthodox: 2026, 2027 and 2028', () {
      expect(orthodoxEaster(2026), CivilDate(2026, 4, 12));
      expect(orthodoxEaster(2027), CivilDate(2027, 5, 2));
      expect(orthodoxEaster(2028), CivilDate(2028, 4, 16));
    });
  });

  group('moving holidays follow Easter, they are not fixed dates', () {
    void expectAll(
      Map<String, Map<String, int>> table,
      CivilDate Function(int) easter,
    ) {
      for (final MapEntry(key: cc, value: days) in table.entries) {
        for (final year in [2026, 2027]) {
          for (final MapEntry(key: name, value: offset) in days.entries) {
            test('$cc $year · $name (${offset >= 0 ? '+' : ''}$offset)', () {
              final date = easter(year).addDays(offset);
              final holiday = HolidayCalendar(all, countryCode: cc).on(date);
              expect(holiday, isNotNull, reason: '$date');
              expect(holiday!.scope, HolidayScope.national);
              expect(
                holiday.name,
                startsWith(name),
                reason: '$cc ${date.toIso()}',
              );
            });
          }
        }
      }
    }

    expectAll(_westernOffsets, westernEaster);
    expectAll(_orthodoxOffsets, orthodoxEaster);
  });

  group('choosing the country loads its holidays', () {
    late AppDatabase db;
    late HolidayRepository repo;

    setUp(() async {
      db = openMemoryDatabase();
      addTearDown(db.close);
      repo = HolidayRepository(db);
      await repo.refreshBundled(HolidayBundleLoader(bundle: shippedBundle()));
    });

    for (final cc in _newCountries) {
      test(
        '$cc: its own national days, 2026 and 2027, nothing from Spain',
        () async {
          final place = await repo.savePlace(countryCode: cc);
          expect(place.countryCode, cc);
          final snapshot = await repo.loadSnapshot();
          final days = snapshot.byDay.values.toList();
          // Every country has at least 9 national days a year in the data.
          for (final year in [2026, 2027]) {
            expect(
              days.where(
                (h) => h.date.year == year && h.scope == HolidayScope.national,
              ),
              isNotEmpty,
              reason: '$cc $year',
            );
          }
          expect(days.length, greaterThanOrEqualTo(18), reason: cc);
          expect(snapshot.byDay[CivilDate(2026, 1, 1)], isNotNull, reason: cc);
        },
      );
    }

    test(
      'Poland loads Easter Monday of each year, Morocco still nothing',
      () async {
        await repo.savePlace(countryCode: 'PL');
        var snapshot = await repo.loadSnapshot();
        expect(
          snapshot.byDay[CivilDate(2026, 4, 6)]?.name,
          'Poniedziałek Wielkanocny',
        );
        expect(
          snapshot.byDay[CivilDate(2027, 3, 29)]?.name,
          'Poniedziałek Wielkanocny',
        );
        await repo.savePlace(countryCode: 'MA');
        snapshot = await repo.loadSnapshot();
        expect(snapshot.byDay, isEmpty);
      },
    );

    test(
      'Bolivia: the department adds its own day, not the whole country',
      () async {
        await repo.savePlace(countryCode: 'BO', regionCode: 'BO-L');
        var snapshot = await repo.loadSnapshot();
        expect(
          snapshot.byDay[CivilDate(2026, 7, 16)]?.scope,
          HolidayScope.regional,
        );
        await repo.savePlace(countryCode: 'BO', regionCode: 'BO-S');
        snapshot = await repo.loadSnapshot();
        expect(snapshot.byDay[CivilDate(2026, 7, 16)], isNull);
        expect(
          snapshot.byDay[CivilDate(2026, 9, 24)]?.scope,
          HolidayScope.regional,
        );
      },
    );
  });
}
