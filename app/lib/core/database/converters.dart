import 'dart:convert';

import 'package:drift/drift.dart';

import '../../features/schedule/domain/civil_date.dart';

/// `CivilDate` <-> ISO text `YYYY-MM-DD`. Sorts correctly as text and does not
/// depend on the time zone.
class CivilDateConverter extends TypeConverter<CivilDate, String> {
  const CivilDateConverter();

  @override
  CivilDate fromSql(String fromDb) => CivilDate.parse(fromDb);

  @override
  String toSql(CivilDate value) => value.toIso();
}

/// `List<String>` <-> JSON text (`["a","b"]`).
class StringListConverter extends TypeConverter<List<String>, String> {
  const StringListConverter();

  @override
  List<String> fromSql(String fromDb) =>
      List<String>.unmodifiable((jsonDecode(fromDb) as List).cast<String>());

  @override
  String toSql(List<String> value) => jsonEncode(value);
}

/// `List<List<String>>` <-> JSON text (`[["a"],["b","c"],[]]`), the steps of a
/// pattern.
class StepsConverter extends TypeConverter<List<List<String>>, String> {
  const StepsConverter();

  @override
  List<List<String>> fromSql(String fromDb) => List.unmodifiable([
    for (final step in jsonDecode(fromDb) as List)
      List<String>.unmodifiable((step as List).cast<String>()),
  ]);

  @override
  String toSql(List<List<String>> value) => jsonEncode(value);
}

/// `Map<String, int>` <-> JSON object text with sorted keys (`{"a":2,"b":4}`),
/// the shift types an absence balance counts (schema v6). Sorted so the same
/// map is always the same text.
class StringIntMapConverter extends TypeConverter<Map<String, int>, String> {
  const StringIntMapConverter();

  @override
  Map<String, int> fromSql(String fromDb) => Map<String, int>.unmodifiable(
    (jsonDecode(fromDb) as Map).map(
      (key, value) => MapEntry(key as String, value as int),
    ),
  );

  @override
  String toSql(Map<String, int> value) =>
      jsonEncode({for (final key in value.keys.toList()..sort()) key: value[key]});
}
