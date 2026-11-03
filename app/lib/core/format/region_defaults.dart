import 'dart:ui' show Locale;

import 'package:intl/number_symbols_data.dart' show numberFormatSymbols;

/// What the phone's region says about the formats of a person who installs
/// the app for the first time (docs/formatos.md): the first day of the week,
/// the currency and the full locale used to format dates and numbers.
///
/// None of this touches an existing installation: those keep what they had
/// (Monday, euros, 24 h) until the person changes it in Ajustes.

/// The ISO 3166 region ("ES", "US", "MX") of the first of the phone's
/// preferred [phone] languages that carries one, or `null` when none does.
String? regionOfPhone(Iterable<Locale> phone) {
  for (final locale in phone) {
    final region = locale.countryCode;
    if (region != null && region.length == 2) return region.toUpperCase();
  }
  return null;
}

/// The locale the dates, numbers and money are formatted in: the language of
/// the app plus the region of the phone ("es_MX", "en_US", "en_GB").
///
/// The region is the one of the first phone language that is [language] (a
/// phone in `es_MX` with the app in Spanish gives `es_MX`); failing that,
/// the region of the first phone language that has one (a phone in `en_US`
/// with the app forced to Spanish gives `es_US`: Spanish words, the formats
/// of the country the person lives in). Without any region the result is just
/// [language]. `intl` falls back to the bare language on its own when it has
/// no data for the pair (`ca_US` formats as `ca`).
String formatLocaleName(String language, Iterable<Locale> phone) {
  for (final locale in phone) {
    final region = locale.countryCode;
    if (locale.languageCode == language &&
        region != null &&
        region.isNotEmpty) {
      return '${language}_${region.toUpperCase()}';
    }
  }
  final region = regionOfPhone(phone);
  return region == null ? language : '${language}_$region';
}

/// The first day of the week of [region]: [DateTime.sunday] where the
/// calendar starts on Sunday (United States, Canada, Mexico, Brazil, Japan...)
/// and [DateTime.monday] everywhere else, also when the region is unknown.
/// The app offers only those two; the regions whose week starts on Saturday
/// (Egypt, Saudi Arabia...) get Monday, which they can change.
int weekStartForRegion(String? region) =>
    region != null && _sundayRegions.contains(region.toUpperCase())
    ? DateTime.sunday
    : DateTime.monday;

/// The regions whose first day of the week is Sunday (CLDR `firstDay`).
const Set<String> _sundayRegions = {
  'AG', 'AS', 'BD', 'BR', 'BS', 'BT', 'BW', 'BZ', 'CA', 'CO', 'DM', 'DO', //
  'ET', 'GT', 'GU', 'HK', 'HN', 'ID', 'IL', 'IN', 'JM', 'JP', 'KE', 'KH',
  'KR', 'LA', 'MH', 'MM', 'MO', 'MT', 'MX', 'MZ', 'NI', 'NP', 'PA', 'PE',
  'PH', 'PK', 'PR', 'PT', 'PY', 'SA', 'SG', 'SV', 'TH', 'TT', 'TW', 'UM',
  'US', 'VE', 'VI', 'WS', 'YE', 'ZA', 'ZW',
};

/// The ISO 4217 code of the currency of [region]: the euro for the euro area
/// and for any region the app does not know. The table has the Spanish-,
/// Portuguese- and English-speaking regions and the main trade partners;
/// `intl` is asked for the rest (it knows the regions it has a locale for).
String currencyForRegion(String? region) {
  if (region == null) return defaultCurrency;
  final code = region.toUpperCase();
  return _regionCurrency[code] ?? _intlCurrency(code) ?? defaultCurrency;
}

/// The currency of every installation that existed before the currency was a
/// preference, and of the euro area: the euro.
const String defaultCurrency = 'EUR';

String? _intlCurrency(String region) {
  final suffix = '_$region';
  for (final entry in numberFormatSymbols.entries) {
    if (entry.key.endsWith(suffix)) {
      final code = entry.value.DEF_CURRENCY_CODE;
      if (isCurrencyCode(code)) return code;
    }
  }
  return null;
}

/// Whether [value] looks like an ISO 4217 code (three capital letters).
bool isCurrencyCode(String value) => _currencyCode.hasMatch(value);

final RegExp _currencyCode = RegExp(r'^[A-Z]{3}$');

const Map<String, String> _regionCurrency = {
  // Americas
  'US': 'USD', 'CA': 'CAD', 'MX': 'MXN', 'AR': 'ARS', 'BO': 'BOB', //
  'BR': 'BRL', 'CL': 'CLP', 'CO': 'COP', 'CR': 'CRC', 'CU': 'CUP',
  'DO': 'DOP', 'EC': 'USD', 'GT': 'GTQ', 'HN': 'HNL', 'NI': 'NIO',
  'PA': 'PAB', 'PE': 'PEN', 'PR': 'USD', 'PY': 'PYG', 'SV': 'USD',
  'UY': 'UYU', 'VE': 'VES',
  // Europe outside the euro area
  'GB': 'GBP', 'CH': 'CHF', 'SE': 'SEK', 'NO': 'NOK', 'DK': 'DKK',
  'PL': 'PLN', 'CZ': 'CZK', 'HU': 'HUF', 'RO': 'RON', 'BG': 'BGN',
  'IS': 'ISK', 'TR': 'TRY', 'UA': 'UAH', 'RU': 'RUB', 'AD': 'EUR',
  // Asia and Oceania
  'JP': 'JPY', 'CN': 'CNY', 'KR': 'KRW', 'IN': 'INR', 'ID': 'IDR',
  'PH': 'PHP', 'TH': 'THB', 'VN': 'VND', 'MY': 'MYR', 'SG': 'SGD',
  'HK': 'HKD', 'TW': 'TWD', 'AU': 'AUD', 'NZ': 'NZD', 'IL': 'ILS',
  'AE': 'AED', 'SA': 'SAR',
  // Africa
  'ZA': 'ZAR', 'EG': 'EGP', 'MA': 'MAD', 'NG': 'NGN', 'KE': 'KES',
  'GQ': 'XAF',
};
