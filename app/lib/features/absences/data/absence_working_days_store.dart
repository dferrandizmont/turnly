import 'dart:convert';

import '../../../core/database/app_database.dart';
import '../domain/absence_balance.dart';

/// Which balances are counted in working days
/// ([AbsenceBalance.workingDaysOnly], «días hábiles»).
///
/// The v6 schema has no column for it, and a flag is not worth a migration:
/// like the expiry dates of the carried days (`AbsenceCarryOverStore`) it is
/// kept in the `settings` table, under `absences.workingDays`, as the sorted
/// list of the keys of those balances ([absenceCarryOverExpiryKey] of the
/// year, the series and the calendar): `["main|2027:vac"]`. That table
/// travels in the backup whole, so the flag comes back with a restore.
class AbsenceWorkingDaysStore {
  AbsenceWorkingDaysStore(this._db);

  final AppDatabase _db;

  static const settingsKey = 'absences.workingDays';

  /// The keys of the balances counted in working days. A missing or
  /// unreadable row is none: every balance counts every day, as before.
  Future<Set<String>> load() async {
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
    if (decoded is! List) return const {};
    return {
      for (final value in decoded)
        if (value is String && value.isNotEmpty) value,
    };
  }

  /// Whether the balance of [year] of the series [type] of [calendarId]
  /// counts only working days.
  Future<void> set(
    int year,
    String type,
    String calendarId, {
    required bool workingDaysOnly,
  }) => _db.transaction(() async {
    final key = absenceCarryOverExpiryKey(year, type, calendarId);
    final current = {...await load()};
    final changed = workingDaysOnly ? current.add(key) : current.remove(key);
    if (!changed) return;
    if (current.isEmpty) {
      await (_db.delete(
        _db.settings,
      )..where((s) => s.key.equals(settingsKey))).go();
      return;
    }
    await _db
        .into(_db.settings)
        .insertOnConflictUpdate(
          SettingsCompanion.insert(
            key: settingsKey,
            value: jsonEncode(current.toList()..sort()),
          ),
        );
  });
}
