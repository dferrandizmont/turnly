import 'dart:convert';

import '../../../core/database/app_database.dart';
import '../../schedule/domain/civil_date.dart';
import '../domain/hours_goal.dart';

/// Keeps the hours goal of the summary (C2) as one JSON row of the `settings`
/// table, `summary.hoursGoal` = `{"period": "year", "hours": 1642}`, and the
/// day it was first set, `summary.hoursGoalSince` = `"2026-01-01"` (the day
/// the hours bag starts, so an old note or a rotation set up years ago does
/// not count as debt). That table already travels in the backup
/// (docs/copia-de-seguridad.md), so the goal and its date come back with a
/// restore. A missing, unreadable or invalid row is "no goal".
class HoursGoalStore {
  HoursGoalStore(this._db);

  static const key = 'summary.hoursGoal';

  /// The day the goal was first set.
  static const sinceKey = 'summary.hoursGoalSince';

  final AppDatabase _db;

  Future<HoursGoal?> load() async {
    final row = await (_db.select(
      _db.settings,
    )..where((s) => s.key.equals(key))).getSingleOrNull();
    if (row == null) return null;
    try {
      return HoursGoal.fromJson(jsonDecode(row.value));
    } on FormatException {
      return null;
    }
  }

  /// The day the goal was first set, or `null` when it is not known (the goal
  /// was set before this date was stored).
  Future<CivilDate?> loadSince() async {
    final row = await (_db.select(
      _db.settings,
    )..where((s) => s.key.equals(sinceKey))).getSingleOrNull();
    if (row == null) return null;
    try {
      final decoded = jsonDecode(row.value);
      return decoded is String ? CivilDate.parse(decoded) : null;
    } on FormatException {
      return null;
    }
  }

  /// Throws [ArgumentError] for a goal outside 1 h to [HoursGoalPeriod.maxHours].
  Future<void> save(HoursGoal goal) async {
    if (!goal.isValid) {
      throw ArgumentError.value(goal, 'goal', 'out of range');
    }
    await _db
        .into(_db.settings)
        .insertOnConflictUpdate(
          SettingsCompanion.insert(key: key, value: jsonEncode(goal.toJson())),
        );
  }

  /// Remembers the day the goal was first set (the hours bag starts there).
  Future<void> saveSince(CivilDate date) async {
    await _db
        .into(_db.settings)
        .insertOnConflictUpdate(
          SettingsCompanion.insert(
            key: sinceKey,
            value: jsonEncode(date.toIso()),
          ),
        );
  }

  Future<void> clear() => (_db.delete(
    _db.settings,
  )..where((s) => s.key.isIn([key, sinceKey]))).go();
}
