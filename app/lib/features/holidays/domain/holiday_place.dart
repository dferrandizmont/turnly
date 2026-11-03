import 'holiday_country.dart';

/// Where the person works: the country (ISO 3166-1 alpha-2) and, in Spain,
/// the region (`ES-CT`) and the municipality (INE code) whose holidays they
/// get.
///
/// - Spain without a region: only the national holidays (what the app showed
///   before countries existed, and what a place stored back then still means).
/// - Another country: its official holidays when the bundle has them, none
///   until then. [otherCountryCode] (`ZZ`): never any official holiday.
///
/// The person's own holidays show whatever the place is.
class HolidayPlace {
  const HolidayPlace({
    this.countryCode = spainCountryCode,
    this.regionCode,
    this.municipalityCode,
  });

  /// Spain, no region: the national holidays only (the default).
  static const HolidayPlace spain = HolidayPlace();

  /// «Otro país: sin festivos oficiales».
  static const HolidayPlace otherCountry = HolidayPlace(
    countryCode: otherCountryCode,
  );

  /// Upper-case alpha-2 code, or [otherCountryCode].
  final String countryCode;
  final String? regionCode;
  final String? municipalityCode;

  bool get isSpain => countryCode == spainCountryCode;

  /// «Otro país: sin festivos oficiales».
  bool get isOtherCountry => countryCode == otherCountryCode;

  @override
  bool operator ==(Object other) =>
      other is HolidayPlace &&
      other.countryCode == countryCode &&
      other.regionCode == regionCode &&
      other.municipalityCode == municipalityCode;

  @override
  int get hashCode => Object.hash(countryCode, regionCode, municipalityCode);

  @override
  String toString() =>
      'HolidayPlace($countryCode, $regionCode, $municipalityCode)';
}
