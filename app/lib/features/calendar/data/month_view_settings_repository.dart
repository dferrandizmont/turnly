import 'dart:convert';

import '../../../core/database/app_database.dart';

/// Keys of the month screen in the `settings` table (one JSON value each).
class MonthViewSettingKeys {
  const MonthViewSettingKeys._();

  /// `"grid"` or `"list"`: the presentation the person last chose (B7).
  static const presentation = 'calendar.monthPresentation';

  /// `true` when the «Hoy» card is folded to one line (B1).
  static const todayCardCollapsed = 'calendar.todayCardCollapsed';
}

/// Reads and writes the two remembered choices of the month screen: Grid or
/// List and the folded «Hoy» card. They are view preferences, not data: a
/// missing or unreadable row falls back to the default (grid, open card) and
/// never blocks the screen. No schema change: rows of the existing key-value
/// `settings` table.
class MonthViewSettingsRepository {
  MonthViewSettingsRepository(this._db);

  final AppDatabase _db;

  /// The stored presentation name (`"grid"` / `"list"`), or null.
  Future<String?> readPresentation() async {
    final value = await _read(MonthViewSettingKeys.presentation);
    return value is String ? value : null;
  }

  Future<void> writePresentation(String name) =>
      _write(MonthViewSettingKeys.presentation, name);

  /// Whether the card was left folded; null when never chosen.
  Future<bool?> readTodayCardCollapsed() async {
    final value = await _read(MonthViewSettingKeys.todayCardCollapsed);
    return value is bool ? value : null;
  }

  Future<void> writeTodayCardCollapsed(bool collapsed) =>
      _write(MonthViewSettingKeys.todayCardCollapsed, collapsed);

  Future<Object?> _read(String key) async {
    final row = await (_db.select(
      _db.settings,
    )..where((s) => s.key.equals(key))).getSingleOrNull();
    if (row == null) return null;
    try {
      return jsonDecode(row.value);
    } on FormatException {
      return null;
    }
  }

  Future<void> _write(String key, Object value) => _db
      .into(_db.settings)
      .insertOnConflictUpdate(
        SettingsCompanion.insert(key: key, value: jsonEncode(value)),
      );
}
