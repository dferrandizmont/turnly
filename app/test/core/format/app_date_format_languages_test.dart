import 'package:cuadrante/core/format/app_date_format.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    for (final l in ['es', 'ca', 'gl', 'eu', 'en']) {
      await initializeDateFormatting(l);
    }
  });

  // Monday 20 October 2025.
  final monday = DateTime(2025, 10, 20);

  test('«lunes, 20 de octubre» in each language', () {
    expect(const AppDateFormat('es').longDate(monday), 'lunes, 20 de octubre');
    expect(const AppDateFormat('ca').longDate(monday), 'dilluns, 20 d’octubre');
    expect(const AppDateFormat('gl').longDate(monday), 'luns, 20 de outubro');
    expect(
      const AppDateFormat('eu').longDate(monday),
      'astelehena, urriaren 20a',
    );
    expect(const AppDateFormat('en').longDate(monday), 'Monday, October 20');
  });

  test('Catalan writes «de» before a consonant', () {
    expect(
      const AppDateFormat('ca').longDate(DateTime(2025, 12, 1)),
      'dilluns, 1 de desembre',
    );
  });

  test('Basque: the day takes -a except 11 and 31 (already ending in -a)', () {
    const eu = AppDateFormat('eu');
    expect(eu.longDate(DateTime(2026, 1, 1)), 'osteguna, urtarrilaren 1a');
    expect(eu.longDate(DateTime(2026, 3, 11)), 'asteazkena, martxoaren 11');
    expect(eu.longDate(DateTime(2026, 8, 31)), 'astelehena, abuztuaren 31');
    expect(eu.longDate(DateTime(2026, 6, 21)), 'igandea, ekainaren 21a');
  });

  test('the Spanish spoken form keeps its «de» and no comma', () {
    expect(
      const AppDateFormat('es').weekdayDayMonth(monday),
      'lunes 20 de octubre',
    );
    expect(
      const AppDateFormat('gl').weekdayDayMonth(monday),
      'luns, 20 de outubro',
    );
  });

  test('short dates: three-letter month, no dot', () {
    expect(const AppDateFormat('es').shortDate(monday), 'lun 20 oct');
    expect(const AppDateFormat('ca').shortDate(monday), 'dl 20 oct');
    expect(const AppDateFormat('gl').shortDate(monday), 'luns 20 out');
    expect(const AppDateFormat('eu').shortDate(monday), 'urr 20, al');
    expect(const AppDateFormat('en').shortDate(monday), 'Mon Oct 20');
    final september = DateTime(2025, 9, 3);
    expect(const AppDateFormat('es').monthShort(september), 'sep');
    expect(const AppDateFormat('ca').monthShort(september), 'set');
    expect(const AppDateFormat('gl').monthShort(DateTime(2025, 6)), 'xuñ');
    expect(const AppDateFormat('eu').monthShort(DateTime(2025, 1)), 'urt');
    expect(const AppDateFormat('en').dayMonthYear(monday), 'Oct 20, 2025');
  });

  test('month and year headers come from the language data', () {
    expect(const AppDateFormat('eu').monthYear(monday), 'urria 2025');
    expect(const AppDateFormat('ca').monthYear(monday), 'octubre 2025');
    expect(const AppDateFormat('gl').monthYear(monday), 'outubro 2025');
    expect(const AppDateFormat('en').monthYear(monday), 'October 2025');
  });

  group('spokenDate: the whole date with its year', () {
    // Sunday 11 October 2026.
    final sunday = DateTime.utc(2026, 10, 11);

    test('in each language', () {
      expect(
        const AppDateFormat('es').spokenDate(sunday),
        'domingo, 11 de octubre de 2026',
      );
      expect(
        const AppDateFormat('ca').spokenDate(sunday),
        'diumenge, 11 d’octubre del 2026',
      );
      expect(
        const AppDateFormat('gl').spokenDate(sunday),
        'domingo, 11 de outubro de 2026',
      );
      expect(
        const AppDateFormat('en').spokenDate(sunday),
        'Sunday, October 11, 2026',
      );
      expect(
        const AppDateFormat('eu').spokenDate(sunday),
        '2026ko urriaren 11, igandea',
      );
    });

    test('Basque: the day keeps its ending rule', () {
      const eu = AppDateFormat('eu');
      expect(
        eu.spokenDate(DateTime.utc(2026, 6, 21)),
        '2026ko ekainaren 21a, igandea',
      );
      expect(
        eu.spokenDate(DateTime.utc(2026, 8, 31)),
        '2026ko abuztuaren 31, astelehena',
      );
    });

    test('Basque: the year takes -ko after a vowel, -eko after a consonant', () {
      String year(int y) => AppDateFormat.basqueYearOf(y);
      // 1 (bat), 5 (bost), 10 (hamar), 15 (hamabost), 30 (hogeita hamar), 100.
      for (final y in [2001, 2010, 2015, 2021, 2025, 2030, 2050, 2090, 2100]) {
        expect(year(y), '${y}eko', reason: '$y');
      }
      // 2, 3, 4, 6, 7, 8, 9, 11 (hamaika), 12, 20 (hogei), 40, 2000 (mila).
      for (final y in [
        2000,
        2011,
        2012,
        2020,
        2022,
        2023,
        2024,
        2026,
        2027,
        2028,
        2029,
        2040,
      ]) {
        expect(year(y), '${y}ko', reason: '$y');
      }
      expect(
        const AppDateFormat('eu').spokenDate(DateTime.utc(2025, 3, 2)),
        '2025eko martxoaren 2a, igandea',
      );
    });

    test('a day a time zone skipped is still the day it says', () {
      // Samoa jumped from 29 to 31 December 2011: a date built from UTC fields
      // names the same day wherever the phone is.
      expect(
        const AppDateFormat('es').spokenDate(DateTime.utc(2011, 12, 30)),
        'viernes, 30 de diciembre de 2011',
      );
    });
  });
}
