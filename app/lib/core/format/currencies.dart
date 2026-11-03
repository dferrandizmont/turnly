/// The currencies Ajustes › Apariencia › Moneda offers (ISO 4217 codes).
/// [commonCurrencies] come first in the picker: the euro, the dollar and the
/// money of the places where the app is most likely to be used; the rest
/// follow in alphabetical order. Any other code a backup or an older build
/// stored still formats (with its code as the symbol).
const List<String> commonCurrencies = [
  'EUR', 'USD', 'GBP', 'MXN', 'ARS', 'CLP', 'COP', 'PEN', 'UYU', 'BRL', //
  'CAD', 'CHF',
];

/// The other currencies of the picker, alphabetical.
const List<String> otherCurrencies = [
  'AED', 'AUD', 'BGN', 'BHD', 'BOB', 'CNY', 'CRC', 'CZK', 'DKK', 'DOP', //
  'EGP', 'GTQ', 'HKD', 'HNL', 'HUF', 'IDR', 'ILS', 'INR', 'ISK', 'JOD',
  'JPY', 'KRW', 'KWD', 'MAD', 'MYR', 'NGN', 'NIO', 'NOK', 'NZD', 'OMR',
  'PAB', 'PHP', 'PLN', 'PYG', 'RON', 'RUB', 'SAR', 'SEK', 'SGD', 'THB',
  'TND', 'TRY', 'TWD', 'UAH', 'VES', 'VND', 'ZAR',
];

/// Every currency of the picker, common ones first.
List<String> get allCurrencies => [...commonCurrencies, ...otherCurrencies];
