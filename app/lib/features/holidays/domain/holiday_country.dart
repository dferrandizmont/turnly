import '../../../core/format/text_fold.dart';

/// Spain: the only country with official holidays in the bundle today, and
/// what a place stored before countries existed means (docs/festivos.md).
const String spainCountryCode = 'ES';

/// «Otro país: sin festivos oficiales». `ZZ` is the ISO 3166-1 user-assigned
/// code CLDR uses for an unknown region: it never matches a bundled row, so
/// only the person's own holidays show.
const String otherCountryCode = 'ZZ';

/// A country of the picker: its ISO 3166-1 alpha-2 code and its name in each
/// language of the app.
///
/// Neither `intl` nor Flutter ship territory names, so the names live here,
/// like the region names of `spanish_regions.dart`: reference data, not UI
/// copy. A new language of the app adds its column (the fallback is Spanish).
class HolidayCountry {
  const HolidayCountry(this.code, this.names);

  /// `MX`.
  final String code;

  /// Language code (`es`, `ca`, `gl`, `eu`, `en`) -> name.
  final Map<String, String> names;

  String nameIn(String languageCode) =>
      names[languageCode] ?? names['es'] ?? code;
}

HolidayCountry _c(
  String code,
  String es,
  String ca,
  String gl,
  String eu,
  String en,
) => HolidayCountry(code, {'es': es, 'ca': ca, 'gl': gl, 'eu': eu, 'en': en});

/// The countries the picker offers: the markets of the roadmap (Latin
/// America, Portugal and Brazil, Europe) and the usual destinations of
/// Spanish workers. Any other country is «Otro país» until it has data.
final List<HolidayCountry> holidayCountries = [
  _c('ES', 'España', 'Espanya', 'España', 'Espainia', 'Spain'),
  _c('AD', 'Andorra', 'Andorra', 'Andorra', 'Andorra', 'Andorra'),
  _c('AR', 'Argentina', 'Argentina', 'Arxentina', 'Argentina', 'Argentina'),
  _c('AT', 'Austria', 'Àustria', 'Austria', 'Austria', 'Austria'),
  _c('AU', 'Australia', 'Austràlia', 'Australia', 'Australia', 'Australia'),
  _c('BE', 'Bélgica', 'Bèlgica', 'Bélxica', 'Belgika', 'Belgium'),
  _c('BO', 'Bolivia', 'Bolívia', 'Bolivia', 'Bolivia', 'Bolivia'),
  _c('BR', 'Brasil', 'Brasil', 'Brasil', 'Brasil', 'Brazil'),
  _c('CA', 'Canadá', 'Canadà', 'Canadá', 'Kanada', 'Canada'),
  _c('CH', 'Suiza', 'Suïssa', 'Suíza', 'Suitza', 'Switzerland'),
  _c('CL', 'Chile', 'Xile', 'Chile', 'Txile', 'Chile'),
  _c('CO', 'Colombia', 'Colòmbia', 'Colombia', 'Kolonbia', 'Colombia'),
  _c(
    'CR',
    'Costa Rica',
    'Costa Rica',
    'Costa Rica',
    'Costa Rica',
    'Costa Rica',
  ),
  _c('CU', 'Cuba', 'Cuba', 'Cuba', 'Kuba', 'Cuba'),
  _c('DE', 'Alemania', 'Alemanya', 'Alemaña', 'Alemania', 'Germany'),
  _c('DK', 'Dinamarca', 'Dinamarca', 'Dinamarca', 'Danimarka', 'Denmark'),
  _c(
    'DO',
    'República Dominicana',
    'República Dominicana',
    'República Dominicana',
    'Dominikar Errepublika',
    'Dominican Republic',
  ),
  _c('EC', 'Ecuador', 'Equador', 'Ecuador', 'Ekuador', 'Ecuador'),
  _c('FI', 'Finlandia', 'Finlàndia', 'Finlandia', 'Finlandia', 'Finland'),
  _c('FR', 'Francia', 'França', 'Francia', 'Frantzia', 'France'),
  _c(
    'GB',
    'Reino Unido',
    'Regne Unit',
    'Reino Unido',
    'Erresuma Batua',
    'United Kingdom',
  ),
  _c(
    'GQ',
    'Guinea Ecuatorial',
    'Guinea Equatorial',
    'Guinea Ecuatorial',
    'Ekuatore Ginea',
    'Equatorial Guinea',
  ),
  _c('GR', 'Grecia', 'Grècia', 'Grecia', 'Grezia', 'Greece'),
  _c('GT', 'Guatemala', 'Guatemala', 'Guatemala', 'Guatemala', 'Guatemala'),
  _c('HN', 'Honduras', 'Hondures', 'Honduras', 'Honduras', 'Honduras'),
  _c('IE', 'Irlanda', 'Irlanda', 'Irlanda', 'Irlanda', 'Ireland'),
  _c('IT', 'Italia', 'Itàlia', 'Italia', 'Italia', 'Italy'),
  _c('LU', 'Luxemburgo', 'Luxemburg', 'Luxemburgo', 'Luxenburgo', 'Luxembourg'),
  _c('MA', 'Marruecos', 'Marroc', 'Marrocos', 'Maroko', 'Morocco'),
  _c('MX', 'México', 'Mèxic', 'México', 'Mexiko', 'Mexico'),
  _c('NI', 'Nicaragua', 'Nicaragua', 'Nicaragua', 'Nikaragua', 'Nicaragua'),
  _c(
    'NL',
    'Países Bajos',
    'Països Baixos',
    'Países Baixos',
    'Herbehereak',
    'Netherlands',
  ),
  _c('NO', 'Noruega', 'Noruega', 'Noruega', 'Norvegia', 'Norway'),
  _c(
    'NZ',
    'Nueva Zelanda',
    'Nova Zelanda',
    'Nova Zelandia',
    'Zeelanda Berria',
    'New Zealand',
  ),
  _c('PA', 'Panamá', 'Panamà', 'Panamá', 'Panama', 'Panama'),
  _c('PE', 'Perú', 'Perú', 'Perú', 'Peru', 'Peru'),
  _c('PH', 'Filipinas', 'Filipines', 'Filipinas', 'Filipinak', 'Philippines'),
  _c('PL', 'Polonia', 'Polònia', 'Polonia', 'Polonia', 'Poland'),
  _c(
    'PR',
    'Puerto Rico',
    'Puerto Rico',
    'Porto Rico',
    'Puerto Rico',
    'Puerto Rico',
  ),
  _c('PT', 'Portugal', 'Portugal', 'Portugal', 'Portugal', 'Portugal'),
  _c('PY', 'Paraguay', 'Paraguai', 'Paraguai', 'Paraguai', 'Paraguay'),
  _c('RO', 'Rumanía', 'Romania', 'Romanía', 'Errumania', 'Romania'),
  _c('SE', 'Suecia', 'Suècia', 'Suecia', 'Suedia', 'Sweden'),
  _c(
    'SV',
    'El Salvador',
    'El Salvador',
    'O Salvador',
    'El Salvador',
    'El Salvador',
  ),
  _c(
    'US',
    'Estados Unidos',
    'Estats Units',
    'Estados Unidos',
    'Ameriketako Estatu Batuak',
    'United States',
  ),
  _c('UY', 'Uruguay', 'Uruguai', 'Uruguai', 'Uruguai', 'Uruguay'),
  _c('VE', 'Venezuela', 'Veneçuela', 'Venezuela', 'Venezuela', 'Venezuela'),
];

final Map<String, HolidayCountry> _byCode = {
  for (final c in holidayCountries) c.code: c,
};

/// The picker's country of [code] (any case), or null.
HolidayCountry? countryByCode(String? code) =>
    code == null ? null : _byCode[code.toUpperCase()];

final RegExp _alpha2 = RegExp(r'^[A-Za-z]{2}$');

/// [code] as an upper-case ISO 3166-1 alpha-2 code (`mx` -> `MX`), or null
/// when it is not two letters. Accepts countries the picker does not list
/// (a future bundle may bring them) and [otherCountryCode].
String? normalizeCountryCode(String? code) {
  if (code == null || !_alpha2.hasMatch(code)) return null;
  return code.toUpperCase();
}

/// The country a fresh install proposes from the phone's region
/// (`PlatformDispatcher.locale.countryCode`): that country when the picker
/// lists it, [otherCountryCode] when it does not, Spain when the phone says
/// nothing (the market the app was made for, and what it showed before).
String proposeHolidayCountry(String? systemCountryCode) {
  final code = normalizeCountryCode(systemCountryCode);
  if (code == null) return spainCountryCode;
  return _byCode.containsKey(code) ? code : otherCountryCode;
}

/// Name of [code] in [languageCode]; the code itself for a country the
/// picker does not list.
String countryName(String code, String languageCode) =>
    countryByCode(code)?.nameIn(languageCode) ?? code.toUpperCase();

/// The picker's order: Spain first, then the rest by their name in
/// [languageCode] (accents and case ignored).
List<HolidayCountry> countriesForPicker(String languageCode) {
  final rest =
      [
        for (final c in holidayCountries)
          if (c.code != spainCountryCode) c,
      ]..sort(
        (a, b) =>
            compareSpanish(a.nameIn(languageCode), b.nameIn(languageCode)),
      );
  return [_byCode[spainCountryCode]!, ...rest];
}
