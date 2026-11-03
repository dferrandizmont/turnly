import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'app_formats.dart';
import 'region_defaults.dart' show defaultCurrency, isCurrencyCode;

// Money of the app (docs/formatos.md, "Moneda").
//
// **How amounts are stored.** Every amount is a whole number of the *minor
// unit* of the currency (the "cents" of the field names, `hourlyRateCents`,
// `fixedPlusCents`, `earningsCents`...): the smallest unit the currency
// has, so the number of decimals of the currency decides what 1250 means.
//
// - 2 decimals (euro, dollar, pound...): 1250 is 12.50.
// - 0 decimals (yen, won, Chilean peso...): 1250 is 1250, the whole unit.
// - 3 decimals (Bahraini and Kuwaiti dinar, Omani rial...): 1250 is 1.250.
//
// The currency is a preference, not a property of the amount, and changing
// it **does not convert anything**: the stored numbers are only read with
// the decimals of the new currency (12.50 € kept as 1250 reads 12.50 $ in
// dollars and ¥1250 in yen). Sums stay in integers, the range of the
// editors (999999 minor units) is 9,999.99 in a 2-decimal currency and
// 999,999 in a 0-decimal one, and an old backup in euros reads exactly as
// before. The editors take as many decimals as the currency has
// (`parseMoneyCents`).

/// "12,00 €" in the formats of the app (language and region of the phone,
/// currency of Ajustes). [amount] is in main units (12.5, not 1250); use
/// [formatMoneyCents] for a stored amount.
String formatMoney(BuildContext context, double amount) =>
    _format(_localeName(context), currencyOf(context), amount);

/// An amount kept in the minor unit of the currency (no floating point in
/// the sums), as "1.234,56 €" in the formats of the app.
String formatMoneyCents(BuildContext context, int cents) =>
    formatMoneyCentsFor(_localeName(context), currencyOf(context), cents);

/// [formatMoneyCents] without a [BuildContext]. [locale] is a language code
/// or a language with a region ("es", "en_US"); [currency] an ISO 4217 code
/// (anything else is shown as euros).
String formatMoneyCentsFor(String locale, String currency, int cents) {
  final digits = currencyDecimals(currency);
  return _format(locale, currency, cents / math.pow(10, digits));
}

/// The symbol of [currency] in [locale] ("€", "$", "£", "R$"; the code when
/// there is no short symbol): what the rate fields show as a suffix.
String currencySymbol(String locale, String currency) {
  final code = isCurrencyCode(currency) ? currency : defaultCurrency;
  return NumberFormat.simpleCurrency(locale: locale, name: code).currencySymbol;
}

/// How many decimals [currency] has: the exponent of its minor unit (2 for
/// the euro, 0 for the yen, 3 for the dinar). The same in every locale.
int currencyDecimals(String currency) {
  final code = isCurrencyCode(currency) ? currency : defaultCurrency;
  return NumberFormat.simpleCurrency(name: code).decimalDigits ?? 2;
}

/// The decimals of the currency in force in [context].
int currencyDecimalsOf(BuildContext context) =>
    currencyDecimals(currencyOf(context));

String _format(String locale, String currency, double amount) {
  final code = isCurrencyCode(currency) ? currency : defaultCurrency;
  return NumberFormat.simpleCurrency(locale: locale, name: code).format(amount);
}

String _localeName(BuildContext context) =>
    AppFormats.maybeOf(context)?.localeName ??
    Localizations.localeOf(context).toString();

/// The symbol of the currency in force in [context] ("€").
String currencySymbolOf(BuildContext context) =>
    currencySymbol(_localeName(context), currencyOf(context));
