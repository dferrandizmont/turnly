import '../../schedule/domain/civil_date.dart';
import 'holiday.dart';

/// One stored holiday row: a date that applies to everybody, to one region or
/// to one municipality. `HolidayCalendar` decides which of them a person
/// sees.
///
/// - National, `regionCode == null`: applies everywhere.
/// - National with a `regionCode`: a national holiday that region keeps
///   (`origin: national-optional` in the Mochila files: Epiphany, Holy
///   Thursday, All Saints moved to Monday...).
/// - Regional: only in that region.
/// - Local: only in that municipality (INE code).
/// - User: added by hand, applies whatever the chosen place is.
///
/// The country of a row is in [regionCode] too, so the table needs no new
/// column: `null` or `ES-..` is Spain (every row stored before countries
/// existed), `MX` alone is a national row of Mexico, `MX-CMX` a row of one of
/// its subdivisions (docs/festivos.md, «Paquetes por país»).
class HolidayEntry {
  const HolidayEntry({
    required this.date,
    required this.scope,
    required this.name,
    this.regionCode,
    this.municipalityCode,
    this.source = HolidaySource.bundled,
  });

  final CivilDate date;
  final HolidayScope scope;
  final String name;

  /// `ES-CT`, a country code alone (`MX`, a national row of that country)
  /// or null (a national row of Spain).
  final String? regionCode;

  /// INE code, five digits, or null.
  final String? municipalityCode;
  final HolidaySource source;

  /// ISO 3166-1 alpha-2 country of an official row: the part of
  /// [regionCode] before the dash, Spain when there is none.
  String get countryCode {
    final region = regionCode;
    if (region == null) return 'ES';
    final dash = region.indexOf('-');
    return dash < 0 ? region : region.substring(0, dash);
  }

  /// A national row that applies in the whole country (not one a region
  /// keeps): no [regionCode], or the country code alone.
  bool get isCountryWide {
    final region = regionCode;
    return region == null || !region.contains('-');
  }

  Holiday toHoliday() =>
      Holiday(
        date: date,
        name: name,
        scope: scope,
        source: source,
        countryCode: countryCode,
      );

  @override
  bool operator ==(Object other) =>
      other is HolidayEntry &&
      other.date == date &&
      other.scope == scope &&
      other.name == name &&
      other.regionCode == regionCode &&
      other.municipalityCode == municipalityCode &&
      other.source == source;

  @override
  int get hashCode =>
      Object.hash(date, scope, name, regionCode, municipalityCode, source);

  @override
  String toString() =>
      'HolidayEntry($date, ${scope.name}, $name, $regionCode, '
      '$municipalityCode, ${source.name})';
}
