/// The 19 autonomous territories (17 communities plus Ceuta and Melilla) by
/// ISO 3166-2 code, and the INE provinces (first two digits of a municipality
/// code) each one holds.
///
/// Same data as `backend/src/calendars/regions.ts` in Mochila. Pure Dart: the
/// bundle tool imports it too.
class SpanishRegion {
  const SpanishRegion(this.code, this.name, this.provinces);

  /// `ES-CT`.
  final String code;
  final String name;

  /// INE provinces, two digits.
  final List<String> provinces;

  /// The name in the app's language (`es`, `ca`, `gl`, `eu`, `en`), like the
  /// countries of `holiday_country.dart`; [name] (Spanish, the one the data
  /// files use) for a language with no column.
  String nameIn(String languageCode) =>
      _regionNames[code]?[languageCode] ?? name;
}

Map<String, String> _n(String ca, String gl, String eu, String en) => {
  'ca': ca,
  'gl': gl,
  'eu': eu,
  'en': en,
};

/// Names of the 19 in Catalan, Galician, Basque and English (Spanish is
/// [SpanishRegion.name]). The official names in each language.
final Map<String, Map<String, String>> _regionNames = {
  'ES-AN': _n('Andalusia', 'Andalucía', 'Andaluzia', 'Andalusia'),
  'ES-AR': _n('Aragó', 'Aragón', 'Aragoi', 'Aragon'),
  'ES-AS': _n(
    'Principat d’Astúries',
    'Principado de Asturias',
    'Asturiasko Printzerria',
    'Asturias',
  ),
  'ES-IB': _n(
    'Illes Balears',
    'Illas Baleares',
    'Balear Uharteak',
    'Balearic Islands',
  ),
  'ES-CN': _n('Canàries', 'Canarias', 'Kanariak', 'Canary Islands'),
  'ES-CB': _n('Cantàbria', 'Cantabria', 'Kantabria', 'Cantabria'),
  'ES-CL': _n(
    'Castella i Lleó',
    'Castela e León',
    'Gaztela eta Leon',
    'Castile and León',
  ),
  'ES-CM': _n(
    'Castella-la Manxa',
    'Castela-A Mancha',
    'Gaztela-Mantxa',
    'Castilla-La Mancha',
  ),
  'ES-CT': _n('Catalunya', 'Cataluña', 'Katalunia', 'Catalonia'),
  'ES-EX': _n('Extremadura', 'Estremadura', 'Extremadura', 'Extremadura'),
  'ES-GA': _n('Galícia', 'Galicia', 'Galizia', 'Galicia'),
  'ES-RI': _n('La Rioja', 'A Rioxa', 'Errioxa', 'La Rioja'),
  'ES-MD': _n(
    'Comunitat de Madrid',
    'Comunidade de Madrid',
    'Madrilgo Erkidegoa',
    'Community of Madrid',
  ),
  'ES-MC': _n(
    'Regió de Múrcia',
    'Rexión de Murcia',
    'Murtziako Eskualdea',
    'Region of Murcia',
  ),
  'ES-NC': _n(
    'Comunitat Foral de Navarra',
    'Comunidade Foral de Navarra',
    'Nafarroako Foru Komunitatea',
    'Navarre',
  ),
  'ES-PV': _n('País Basc', 'País Vasco', 'Euskadi', 'Basque Country'),
  'ES-VC': _n(
    'Comunitat Valenciana',
    'Comunidade Valenciana',
    'Valentziako Erkidegoa',
    'Valencian Community',
  ),
  'ES-CE': _n('Ceuta', 'Ceuta', 'Ceuta', 'Ceuta'),
  'ES-ML': _n('Melilla', 'Melilla', 'Melilla', 'Melilla'),
};

const List<SpanishRegion> spanishRegions = [
  SpanishRegion('ES-AN', 'Andalucía', [
    '04',
    '11',
    '14',
    '18',
    '21',
    '23',
    '29',
    '41',
  ]),
  SpanishRegion('ES-AR', 'Aragón', ['22', '44', '50']),
  SpanishRegion('ES-AS', 'Principado de Asturias', ['33']),
  SpanishRegion('ES-IB', 'Illes Balears', ['07']),
  SpanishRegion('ES-CN', 'Canarias', ['35', '38']),
  SpanishRegion('ES-CB', 'Cantabria', ['39']),
  SpanishRegion('ES-CL', 'Castilla y León', [
    '05',
    '09',
    '24',
    '34',
    '37',
    '40',
    '42',
    '47',
    '49',
  ]),
  SpanishRegion('ES-CM', 'Castilla-La Mancha', ['02', '13', '16', '19', '45']),
  SpanishRegion('ES-CT', 'Catalunya', ['08', '17', '25', '43']),
  SpanishRegion('ES-EX', 'Extremadura', ['06', '10']),
  SpanishRegion('ES-GA', 'Galicia', ['15', '27', '32', '36']),
  SpanishRegion('ES-RI', 'La Rioja', ['26']),
  SpanishRegion('ES-MD', 'Comunidad de Madrid', ['28']),
  SpanishRegion('ES-MC', 'Región de Murcia', ['30']),
  SpanishRegion('ES-NC', 'Comunidad Foral de Navarra', ['31']),
  SpanishRegion('ES-PV', 'País Vasco', ['01', '20', '48']),
  SpanishRegion('ES-VC', 'Comunitat Valenciana', ['03', '12', '46']),
  SpanishRegion('ES-CE', 'Ceuta', ['51']),
  SpanishRegion('ES-ML', 'Melilla', ['52']),
];

final Map<String, SpanishRegion> _byCode = {
  for (final r in spanishRegions) r.code: r,
};

final Map<String, SpanishRegion> _byProvince = {
  for (final r in spanishRegions)
    for (final p in r.provinces) p: r,
};

/// Upper-cases and validates; null when [code] is not one of the 19.
String? normalizeRegionCode(String? code) {
  if (code == null) return null;
  final upper = code.toUpperCase();
  return _byCode.containsKey(upper) ? upper : null;
}

SpanishRegion? regionByCode(String? code) {
  final normalized = normalizeRegionCode(code);
  return normalized == null ? null : _byCode[normalized];
}

final RegExp _ineCode = RegExp(r'^\d{5}$');

/// Whether [code] looks like an INE municipality code (five digits).
bool isMunicipalityCode(String? code) =>
    code != null && _ineCode.hasMatch(code);

/// The region an INE municipality code (five digits) belongs to.
SpanishRegion? regionOfMunicipality(String? municipalityCode) {
  if (!isMunicipalityCode(municipalityCode)) return null;
  return _byProvince[municipalityCode!.substring(0, 2)];
}
