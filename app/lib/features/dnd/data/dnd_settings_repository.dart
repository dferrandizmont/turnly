import 'dart:convert';

import '../../../core/database/app_database.dart';
import '../domain/dnd_settings.dart';

/// Key of the silence settings in the `settings` table (JSON value).
///
/// It is a normal setting, not a device one (`isDeviceSetting`): the choices
/// travel in the copy like the alarm settings do, and a restore brings them
/// back (the backup reads and writes every row of `settings`).
const String dndSettingsKey = 'dnd';

/// Reads and writes [DndSettings] as one JSON row of the `settings` table.
///
/// The same pattern as the alarm settings
/// (`features/alarms/data/alarm_settings_repository.dart`).
class DndSettingsRepository {
  DndSettingsRepository(this._db);

  final AppDatabase _db;

  /// What is stored, or everything off when there is nothing (or the stored
  /// value cannot be read: the phone is never silenced because of a value
  /// that cannot be read).
  Future<DndSettings> load() async {
    final row = await (_db.select(
      _db.settings,
    )..where((s) => s.key.equals(dndSettingsKey))).getSingleOrNull();
    if (row == null) return DndSettings.disabled;
    try {
      final json = jsonDecode(row.value);
      if (json is Map) {
        return DndSettings.fromJson(json.cast<String, Object?>());
      }
    } catch (_) {
      // Unreadable in any way: fall through to the defaults.
    }
    return DndSettings.disabled;
  }

  Future<void> save(DndSettings settings) => _db
      .into(_db.settings)
      .insertOnConflictUpdate(
        SettingsCompanion.insert(
          key: dndSettingsKey,
          value: jsonEncode(settings.toJson()),
        ),
      );
}
