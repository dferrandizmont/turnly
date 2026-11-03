import 'dart:convert';

import '../../../core/database/app_database.dart';
import '../domain/calendar_sync_settings.dart';

/// Key of the continuous export in the `settings` table (JSON value).
const String calendarSyncKey = 'calendarSync';

/// Reads and writes [CalendarSyncSettings] as one JSON row of the `settings`
/// table (no schema change).
class CalendarSyncRepository {
  CalendarSyncRepository(this._db);

  final AppDatabase _db;

  /// What is stored, or everything off when there is nothing (or the stored
  /// value cannot be read).
  Future<CalendarSyncSettings> load() async {
    final row = await (_db.select(
      _db.settings,
    )..where((s) => s.key.equals(calendarSyncKey))).getSingleOrNull();
    if (row == null) return CalendarSyncSettings.off;
    try {
      final json = jsonDecode(row.value);
      if (json is Map) {
        return CalendarSyncSettings.fromJson(json.cast<String, Object?>());
      }
    } catch (_) {
      // Unreadable in any way: off.
    }
    return CalendarSyncSettings.off;
  }

  Future<void> save(CalendarSyncSettings settings) => _db
      .into(_db.settings)
      .insertOnConflictUpdate(
        SettingsCompanion.insert(
          key: calendarSyncKey,
          value: jsonEncode(settings.toJson()),
        ),
      );
}
