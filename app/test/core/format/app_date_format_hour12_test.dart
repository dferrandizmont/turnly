import 'package:cuadrante/core/format/app_date_format.dart';
import 'package:cuadrante/core/format/app_formats.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// 12 h / 24 h clock and the formats by language **and region**
/// (docs/formatos.md).
void main() {
  setUpAll(() => initializeDateFormatting('es'));

  final night = DateTime(2026, 10, 19, 22);
  final morning = DateTime(2026, 10, 19, 6, 30);
  final noon = DateTime(2026, 10, 19, 12);
  final midnight = DateTime(2026, 10, 19, 0, 5);

  // CLDR 42+ writes a narrow no-break space before AM/PM.
  String plain(String text) => text.replaceAll(' ', ' ');

  group('24 h clock', () {
    test('is the default and ignores the region', () {
      for (final locale in ['es_ES', 'en_US', 'en_GB', 'pt_BR', 'es_MX']) {
        final format = AppDateFormat(locale);
        expect(format.hour12, isFalse, reason: locale);
        expect(format.time(night), '22:00', reason: locale);
        expect(format.time(morning), '06:30', reason: locale);
        expect(format.time(midnight), '00:05', reason: locale);
      }
    });

    test('ranges', () {
      const format = AppDateFormat('en_US');
      expect(format.timeRange(night, morning), '22:00–06:30');
      expect(format.timeRange(night, null), '22:00');
    });
  });

  group('12 h clock', () {
    test('en_US: 10:00 PM', () {
      const format = AppDateFormat('en_US', true);
      expect(plain(format.time(night)), '10:00 PM');
      expect(plain(format.time(morning)), '6:30 AM');
      expect(plain(format.time(noon)), '12:00 PM');
      expect(plain(format.time(midnight)), '12:05 AM');
    });

    test('en_GB and pt_BR use the AM/PM marks of their language', () {
      expect(
        const AppDateFormat('en_GB', true).time(night).toLowerCase(),
        contains('pm'),
      );
      expect(
        plain(const AppDateFormat('pt_BR', true).time(night)).toLowerCase(),
        matches(RegExp(r'^10:00 ?pm$')),
      );
    });

    test('Spanish: marks of the language', () {
      final text = const AppDateFormat('es_MX', true).time(night);
      expect(text, startsWith('10:00'));
      expect(text.toLowerCase(), contains('p'));
      final es = const AppDateFormat('es_ES', true).time(morning);
      expect(es, startsWith('6:30'));
      expect(es.toLowerCase(), contains('a'));
    });

    test('ranges', () {
      const format = AppDateFormat('en_US', true);
      expect(plain(format.timeRange(night, morning)), '10:00 PM–6:30 AM');
    });
  });

  group('compactClock (the cell of the month, the widget)', () {
    test('24 h: as before', () {
      expect(AppDateFormat.compactClock(22 * 60), '22');
      expect(AppDateFormat.compactClock(6 * 60), '06');
      expect(AppDateFormat.compactClock(7 * 60 + 30), '07:30');
      expect(AppDateFormat.compactClock(0), '00');
      expect(AppDateFormat.compactClock(1440), '00');
    });

    test('12 h: a letter, minutes only when they are not :00', () {
      String c(int h, [int m = 0]) =>
          AppDateFormat.compactClock(h * 60 + m, hour12: true);
      expect(c(22), '10p');
      expect(c(6), '6a');
      expect(c(7, 30), '7:30a');
      expect(c(15, 5), '3:05p');
      expect(c(12), '12p');
      expect(c(0), '12a');
      expect(c(0, 30), '12:30a');
      expect(c(12, 45), '12:45p');
      expect(AppDateFormat.compactClock(1440, hour12: true), '12a');
    });

    test('compactClockHour drops the minutes', () {
      expect(AppDateFormat.compactClockHour(7 * 60 + 30), '07');
      expect(AppDateFormat.compactClockHour(7 * 60 + 30, hour12: true), '7a');
      expect(AppDateFormat.compactClockHour(22 * 60 + 59, hour12: true), '10p');
    });

    test('is at most one character wider than the 24 h form', () {
      for (var minute = 0; minute < 1440; minute += 15) {
        final h24 = AppDateFormat.compactClock(minute);
        final h12 = AppDateFormat.compactClock(minute, hour12: true);
        expect(
          h12.length,
          lessThanOrEqualTo(h24.length + 1),
          reason: '$minute',
        );
      }
    });
  });

  group('dates follow the region', () {
    test('long date: US and GB order the day differently', () {
      final d = DateTime(2026, 10, 23);
      expect(const AppDateFormat('en_US').longDate(d), 'Friday, October 23');
      expect(const AppDateFormat('en_GB').longDate(d), 'Friday 23 October');
      expect(const AppDateFormat('en').longDate(d), 'Friday, October 23');
    });

    test('Spanish and Portuguese keep their month names', () {
      final d = DateTime(2026, 10, 23);
      expect(
        const AppDateFormat('es_ES').longDate(d),
        'viernes, 23 de octubre',
      );
      expect(const AppDateFormat('es_MX').longDate(d), contains('octubre'));
      expect(const AppDateFormat('pt_BR').monthName(d), 'outubro');
    });

    test('the hand-made short forms only depend on the language', () {
      final d = DateTime(2026, 10, 23);
      expect(const AppDateFormat('es_MX').shortDate(d), 'vie 23 oct');
      expect(const AppDateFormat('en_GB').shortDate(d), 'Fri Oct 23');
      expect(const AppDateFormat('en_US').shortDate(d), 'Fri Oct 23');
      expect(const AppDateFormat('es_US').dayMonthYear(d), '23 oct 2026');
    });

    test('a region intl has no data for falls back to the language', () {
      final d = DateTime(2026, 10, 23);
      expect(const AppDateFormat('ca_US').monthName(d), 'octubre');
      expect(const AppDateFormat('eu_ES').shortDate(d), 'urr 23, or');
    });
  });

  group('localeUses12HourClock', () {
    test('by region', () {
      expect(localeUses12HourClock('en_US'), isTrue);
      expect(localeUses12HourClock('es_MX'), isTrue);
      expect(localeUses12HourClock('es_US'), isTrue);
      expect(localeUses12HourClock('es_ES'), isFalse);
      expect(localeUses12HourClock('en_GB'), isFalse);
      expect(localeUses12HourClock('pt_BR'), isFalse);
      expect(localeUses12HourClock('ca'), isFalse);
    });

    test('unknown locale: 24 h', () {
      expect(localeUses12HourClock('xx_YY'), isFalse);
    });
  });

  group('AppDateFormat.of', () {
    Widget app(Widget child, {Widget Function(Widget)? formats}) =>
        Directionality(
          textDirection: TextDirection.ltr,
          child: Localizations(
            locale: const Locale('en', 'GB'),
            delegates: const [DefaultWidgetsLocalizations.delegate],
            child: formats == null ? child : formats(child),
          ),
        );

    testWidgets('without AppFormats: the locale of the tree, 24 h', (
      tester,
    ) async {
      late AppDateFormat format;
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) {
              format = AppDateFormat.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(format.locale, 'en_GB');
      expect(format.hour12, isFalse);
    });

    testWidgets('with AppFormats: its locale and clock, and it rebuilds', (
      tester,
    ) async {
      final seen = <String>[];
      Widget tree(bool hour12) => app(
        Builder(
          builder: (context) {
            final format = AppDateFormat.of(context);
            seen.add('${format.locale} ${format.hour12}');
            return const SizedBox();
          },
        ),
        formats: (child) => AppFormats(
          localeName: 'es_MX',
          hour12: hour12,
          currency: 'MXN',
          child: child,
        ),
      );
      await tester.pumpWidget(tree(false));
      await tester.pumpWidget(tree(true));
      expect(seen, ['es_MX false', 'es_MX true']);
    });
  });
}
