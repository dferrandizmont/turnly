import 'package:cuadrante/core/format/app_formats.dart';
import 'package:cuadrante/core/format/money.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  // Spanish formatting: "." for thousands (also with four digits), "," for
  // decimals and a no-break space before the euro sign.
  const nbsp = ' ';

  test('whole cents as es_ES euros', () {
    expect(formatMoneyCentsFor('es', 'EUR', 123456), '1.234,56$nbsp€');
    expect(formatMoneyCentsFor('es', 'EUR', 100000), '1.000,00$nbsp€');
    expect(formatMoneyCentsFor('es', 'EUR', 99999), '999,99$nbsp€');
    expect(formatMoneyCentsFor('es', 'EUR', 5), '0,05$nbsp€');
    expect(formatMoneyCentsFor('es', 'EUR', 0), '0,00$nbsp€');
    expect(formatMoneyCentsFor('es', 'EUR', 123456789), '1.234.567,89$nbsp€');
  });

  test('the hourly rates the shift editor stores', () {
    expect(formatMoneyCentsFor('es', 'EUR', 1250), '12,50$nbsp€');
    expect(formatMoneyCentsFor('es', 'EUR', 2210), '22,10$nbsp€');
  });

  group('by locale and currency', () {
    test('en_US dollars', () {
      expect(formatMoneyCentsFor('en_US', 'USD', 123456), r'$1,234.56');
      expect(formatMoneyCentsFor('en_US', 'USD', 5), r'$0.05');
    });

    test('en_GB pounds', () {
      expect(formatMoneyCentsFor('en_GB', 'GBP', 123456), '£1,234.56');
    });

    test('pt_BR reais', () {
      expect(formatMoneyCentsFor('pt_BR', 'BRL', 123456), 'R\$${nbsp}1.234,56');
    });

    test('es_MX pesos', () {
      expect(formatMoneyCentsFor('es_MX', 'MXN', 123456), r'$1,234.56');
    });

    test('the euro is written the way of the region', () {
      expect(formatMoneyCentsFor('es_ES', 'EUR', 1250), '12,50$nbsp€');
      expect(formatMoneyCentsFor('en_US', 'EUR', 1250), '€12.50');
      expect(formatMoneyCentsFor('en_GB', 'EUR', 1250), '€12.50');
    });
  });

  group('decimals of the currency', () {
    test('how many each currency has', () {
      expect(currencyDecimals('EUR'), 2);
      expect(currencyDecimals('USD'), 2);
      expect(currencyDecimals('JPY'), 0);
      expect(currencyDecimals('CLP'), 0);
      expect(currencyDecimals('KRW'), 0);
      expect(currencyDecimals('KWD'), 3);
      expect(currencyDecimals('BHD'), 3);
      // Not a code: the euro.
      expect(currencyDecimals('euro'), 2);
    });

    test('0 decimals: the stored number is the whole unit', () {
      expect(formatMoneyCentsFor('ja_JP', 'JPY', 1250), '¥1,250');
      expect(formatMoneyCentsFor('en_US', 'JPY', 0), '¥0');
      expect(formatMoneyCentsFor('es_CL', 'CLP', 25000), contains('25.000'));
    });

    test('3 decimals: the stored number is thousandths', () {
      expect(formatMoneyCentsFor('en_US', 'KWD', 12500), contains('12.500'));
      expect(formatMoneyCentsFor('en_US', 'BHD', 1), contains('0.001'));
    });

    test('2 decimals are not touched', () {
      expect(formatMoneyCentsFor('en_US', 'USD', 1250), r'$12.50');
    });
  });

  test('a stored value that is not a currency code shows as euros', () {
    expect(formatMoneyCentsFor('es', 'euro', 1250), '12,50$nbsp€');
    expect(formatMoneyCentsFor('es', '', 1250), '12,50$nbsp€');
    expect(currencySymbol('es', 'xx'), '€');
  });

  test('currencySymbol: the short symbol, else the code', () {
    expect(currencySymbol('es', 'EUR'), '€');
    expect(currencySymbol('en_US', 'USD'), r'$');
    expect(currencySymbol('en_US', 'GBP'), '£');
    expect(currencySymbol('en_US', 'JPY'), '¥');
    expect(currencySymbol('en_US', 'BRL'), r'R$');
    expect(currencySymbol('en_US', 'CHF'), 'CHF');
  });

  group('in a widget tree', () {
    Widget host(Widget Function(Widget child) wrap, Widget child) =>
        Directionality(
          textDirection: TextDirection.ltr,
          child: Localizations(
            locale: const Locale('es'),
            delegates: const [DefaultWidgetsLocalizations.delegate],
            child: wrap(child),
          ),
        );

    testWidgets('without AppFormats: the euro in the locale', (tester) async {
      late String text;
      late int decimals;
      await tester.pumpWidget(
        host(
          (child) => child,
          Builder(
            builder: (context) {
              text = formatMoneyCents(context, 1250);
              decimals = currencyDecimalsOf(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(text, '12,50$nbsp€');
      expect(decimals, 2);
    });

    testWidgets('with AppFormats: its currency and locale', (tester) async {
      late String text;
      late String symbol;
      late int decimals;
      await tester.pumpWidget(
        host(
          (child) => AppFormats(
            localeName: 'en_US',
            hour12: true,
            currency: 'JPY',
            child: child,
          ),
          Builder(
            builder: (context) {
              text = formatMoneyCents(context, 1250);
              symbol = currencySymbolOf(context);
              decimals = currencyDecimalsOf(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(text, '¥1,250');
      expect(symbol, '¥');
      expect(decimals, 0);
    });
  });
}
