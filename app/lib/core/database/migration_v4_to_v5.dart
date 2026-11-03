import 'package:collection/collection.dart';
import 'package:drift/drift.dart';

import 'app_database.steps.dart';

/// Adds the empty table of shift type versions (changes made «only from today
/// on»). No existing row is touched: every type keeps its terms for every day,
/// as before. The automatic pre-migration copy is made by openAppDatabase,
/// before opening Drift (docs/datos.md).
Future<void> migrateFrom4To5(
  Migrator m,
  Schema5 schema, {
  Future<void> Function()? afterCreate,
}) async {
  final db = m.database;
  await db.transaction(() async {
    const tables = [
      'calendars',
      'shift_types',
      'patterns',
      'pattern_runs',
      'day_entries',
      'holidays',
      'absence_balances',
      'settings',
    ];
    Future<Map<String, List<Map<String, Object?>>>> dump() async => {
      for (final table in tables)
        table: [
          for (final row
              in await db
                  .customSelect('SELECT * FROM $table ORDER BY rowid')
                  .get())
            row.data,
        ],
    };
    final before = await dump();
    await m.createTable(schema.shiftTypeVersions);
    await afterCreate?.call();
    final after = await dump();
    final versions = await db
        .customSelect('SELECT COUNT(*) AS n FROM shift_type_versions')
        .getSingle();
    if (!const DeepCollectionEquality().equals(before, after) ||
        versions.read<int>('n') != 0) {
      throw StateError('Migration v4 -> v5 changed user data; rolled back');
    }
  });
}
