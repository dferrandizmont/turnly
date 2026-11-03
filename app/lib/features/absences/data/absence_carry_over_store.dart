import 'dart:convert';

import '../../../core/database/app_database.dart';
import '../../schedule/domain/civil_date.dart';
import '../domain/absence_balance.dart';

/// The day the days carried over expire.
///
/// The v6 schema has no column for it: `absence_balances` has the cap of the
/// carry-over (`carry_over_max_days`) but not the date the carried days are
/// lost, and this wave does not migrate. So the dates are kept in the
/// `settings` table as JSON, under the key `absences.carryOverExpiry`:
/// `{"<year>:<type>": "YYYY-MM-DD"}` ([absenceCarryOverExpiryKey]).
///
/// They travel in the backup of safety with the rest of the settings (the
/// table is exported and restored whole).
class AbsenceCarryOverStore {
  AbsenceCarryOverStore(this._db);

  final AppDatabase _db;

  /// The key of the `settings` row.
  static const settingsKey = 'absences.carryOverExpiry';

  /// The expiry date of every series and year, by key
  /// ([absenceCarryOverExpiryKey]). A missing, unreadable or invalid value is
  /// ignored: a bad date never blocks the app.
  Future<Map<String, CivilDate>> load() async {
    final row = await (_db.select(
      _db.settings,
    )..where((s) => s.key.equals(settingsKey))).getSingleOrNull();
    if (row == null) return const {};
    Object? decoded;
    try {
      decoded = jsonDecode(row.value);
    } on FormatException {
      return const {};
    }
    if (decoded is! Map<String, dynamic>) return const {};
    final result = <String, CivilDate>{};
    for (final entry in decoded.entries) {
      final value = entry.value;
      if (value is! String) continue;
      try {
        result[entry.key] = CivilDate.parse(value);
      } on FormatException {
        // Not a date: ignored.
      }
    }
    return result;
  }

  /// Sets the day the days carried into [year] of the series [type] of
  /// [calendarId] expire (`null` clears it). Without [calendarId] it is the
  /// key rows written before v6 used, still read as a fallback.
  Future<void> setExpiry(
    int year,
    String type,
    CivilDate? date, {
    String? calendarId,
  }) => _db.transaction(() async {
    final key = absenceCarryOverExpiryKey(year, type, calendarId);
    final current = Map<String, CivilDate>.from(await load());
    if (date == null) {
      current.remove(key);
      // A row written before the calendar was part of the key.
      current.remove(absenceCarryOverExpiryKey(year, type));
    } else {
      current[key] = date;
    }
    if (current.isEmpty) {
      await (_db.delete(
        _db.settings,
      )..where((s) => s.key.equals(settingsKey))).go();
      return;
    }
    final keys = current.keys.toList()..sort();
    await _db
        .into(_db.settings)
        .insertOnConflictUpdate(
          SettingsCompanion.insert(
            key: settingsKey,
            value: jsonEncode({
              for (final key in keys) key: current[key]!.toIso(),
            }),
          ),
        );
  });
}
