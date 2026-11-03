import 'dart:convert';

import '../../../core/database/app_database.dart';
import '../domain/device_events_settings.dart';

/// Key of the person's choice of phone calendars in the `settings` table
/// (JSON). A **device** setting (`isDeviceSetting`): the ids are the numbers
/// this phone's calendar app gave out and mean nothing on another one.
const String deviceEventsKey = 'deviceEvents';

/// Reads and writes [DeviceEventsSettings] as one JSON row of the `settings`
/// table (no schema change).
class DeviceEventsRepository {
  DeviceEventsRepository(this._db);

  final AppDatabase _db;

  /// What is stored, or nothing chosen when there is nothing (or the stored
  /// value cannot be read).
  Future<DeviceEventsSettings> load() async {
    final row = await (_db.select(
      _db.settings,
    )..where((s) => s.key.equals(deviceEventsKey))).getSingleOrNull();
    if (row == null) return DeviceEventsSettings.none;
    try {
      final json = jsonDecode(row.value);
      if (json is Map) {
        return DeviceEventsSettings.fromJson(json.cast<String, Object?>());
      }
    } catch (_) {
      // Unreadable in any way: nothing chosen.
    }
    return DeviceEventsSettings.none;
  }

  Future<void> save(DeviceEventsSettings settings) => _db
      .into(_db.settings)
      .insertOnConflictUpdate(
        SettingsCompanion.insert(
          key: deviceEventsKey,
          value: jsonEncode(settings.toJson()),
        ),
      );
}
