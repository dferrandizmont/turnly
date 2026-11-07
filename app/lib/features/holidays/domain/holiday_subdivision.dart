import '../../../core/format/text_fold.dart';
import 'country_holiday_data.dart';
import 'holiday_country.dart';

/// What a country calls the first level of its subdivisions: it picks the
/// word the pickers use («Estado», «Provincia», «Cantón»...).
enum HolidaySubdivisionKind {
  state,
  federalState,
  province,
  region,
  nation,
  canton,
  city,
  cityOrRegion,
  department,
}

/// A subdivision of a country with its own holidays: an ISO 3166-2 code
/// (`DE-BY`) and its name.
class HolidaySubdivision {
  const HolidaySubdivision(this.code, this.name);

  /// `DE-BY`.
  final String code;
  final String name;
}

/// Whether the bundle has official holidays for [countryCode]: Spain and the
/// countries of `country_holiday_data.dart` (generated with the files, see
/// docs/festivos.md «Otros países»).
bool countryHasHolidayData(String? countryCode) {
  final code = normalizeCountryCode(countryCode);
  return code != null &&
      (code == spainCountryCode || bundledCountryCodes.contains(code));
}

/// The country a subdivision code belongs to: the part before the dash.
String? countryOfSubdivision(String? code) {
  if (code == null) return null;
  final dash = code.indexOf('-');
  return dash < 2 ? null : code.substring(0, dash).toUpperCase();
}

/// The kind of subdivision [countryCode] offers, or null when it has none
/// (Spain's communities have their own picker).
HolidaySubdivisionKind? subdivisionKindOf(String? countryCode) {
  final kind = bundledSubdivisionKinds[normalizeCountryCode(countryCode)];
  if (kind == null) return null;
  for (final k in HolidaySubdivisionKind.values) {
    if (k.name == kind) return k;
  }
  return null;
}

/// Whether the person can choose a subdivision in [countryCode].
bool countryHasSubdivisions(String? countryCode) =>
    subdivisionKindOf(countryCode) != null;

final Map<String, List<HolidaySubdivision>> _sorted = {};

/// The subdivisions of [countryCode] in alphabetical order of their names
/// (accents ignored); empty when it has none.
List<HolidaySubdivision> subdivisionsOf(String? countryCode) {
  final country = normalizeCountryCode(countryCode);
  final names = bundledSubdivisionNames[country];
  if (country == null || names == null) return const [];
  return _sorted.putIfAbsent(
    country,
    () => List.unmodifiable(
      [for (final e in names.entries) HolidaySubdivision(e.key, e.value)]
        ..sort((a, b) => compareSpanish(a.name, b.name)),
    ),
  );
}

/// [code] upper-cased when it is a subdivision of [countryCode] the bundle
/// knows (`de-by` -> `DE-BY`), else null.
String? normalizeSubdivisionCode(String? countryCode, String? code) {
  final country = normalizeCountryCode(countryCode);
  if (country == null || code == null) return null;
  final upper = code.toUpperCase();
  return bundledSubdivisionNames[country]?.containsKey(upper) == true
      ? upper
      : null;
}

/// The name of a subdivision (`DE-BY` -> «Bayern»), or null.
String? subdivisionName(String? code) {
  final country = countryOfSubdivision(code);
  return country == null
      ? null
      : bundledSubdivisionNames[country]?[code!.toUpperCase()];
}
