import 'package:cuadrante/core/database/app_database.dart';
import 'package:cuadrante/core/database/app_database.steps.dart';
import 'package:cuadrante/core/database/migration_v1_to_v2.dart';
import 'package:cuadrante/core/database/migration_v2_to_v3.dart';
import 'package:cuadrante/core/database/migration_v3_to_v4.dart';
import 'package:cuadrante/core/database/migration_v4_to_v5.dart';
import 'package:drift/drift.dart';

/// The app's database stopped at schema v5: the real published chain up to
/// v5 and nothing after it, to build a v5 file the v5 -> v6 step can be
/// tested on.
class AppDatabaseAtV5 extends AppDatabase {
  AppDatabaseAtV5(super.e);

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: stepByStep(
      from1To2: migrateFrom1To2,
      from2To3: migrateFrom2To3,
      from3To4: migrateFrom3To4,
      from4To5: migrateFrom4To5,
      from5To6: (m, schema) async => throw StateError('not this far'),
      from6To7: (m, schema) async => throw StateError('not this far'),
    ),
  );
}

/// What a v5 install adds on top of the v3 seed (`seedV3`): fixed pluses
/// (v4, one at the old cap), two past versions of the night (v5) and two
/// legacy absence balances (schema v1, never used by the interface).
Future<void> seedV5Extras(GeneratedDatabase db) async {
  await db.customStatement(
    "UPDATE shift_types SET fixed_plus_cents = 999999 WHERE id = 'night'",
  );
  await db.customStatement(
    "UPDATE shift_types SET fixed_plus_cents = 0 WHERE id = 'morning'",
  );
  await db.customStatement(
    'INSERT INTO shift_type_versions (shift_type_id, until_date, category, '
    'start_minute, end_minute, paid_minutes, night_override, '
    'hourly_rate_cents, fixed_plus_cents, segment2_start_minute, '
    'segment2_duration_minutes, created_at) VALUES '
    "('night', '2026-03-31', 'work', 1260, 300, NULL, NULL, 1000, NULL, "
    'NULL, NULL, 1767254400000), '
    "('night', '2026-06-30', 'work', 1320, 360, 450, 1, 999999, 0, "
    'NULL, NULL, 1767254400001)',
  );
  await db.customStatement(
    'INSERT INTO absence_balances (year, type, allowed_days) VALUES '
    "(2026, 'vacaciones', 22.0), (2027, 'moscosos', 2.5)",
  );
}

/// Every v5 column of every table, in a stable order (the v6 additions left
/// out on purpose), to compare a file before and after the upgrade.
Future<Map<String, List<Map<String, Object?>>>> dumpV5Columns(
  GeneratedDatabase db,
) async {
  Future<List<Map<String, Object?>>> rows(String sql) async => [
    for (final row in await db.customSelect(sql).get()) row.data,
  ];
  return {
    'calendars': await rows(
      'SELECT id, name, color_value, sort_order, archived, created_at, '
      'updated_at FROM calendars ORDER BY id',
    ),
    'shift_types': await rows(
      'SELECT id, code, name, color_value, category, start_minute, '
      'end_minute, paid_minutes, night_override, hourly_rate_cents, '
      'fixed_plus_cents, icon, alarm_sound, segment2_start_minute, '
      'segment2_duration_minutes, sort_order, archived, created_at, '
      'updated_at FROM shift_types ORDER BY id',
    ),
    'shift_type_versions': await rows(
      'SELECT shift_type_id, until_date, category, start_minute, end_minute, '
      'paid_minutes, night_override, hourly_rate_cents, fixed_plus_cents, '
      'segment2_start_minute, segment2_duration_minutes, created_at '
      'FROM shift_type_versions ORDER BY shift_type_id, until_date',
    ),
    'patterns': await rows(
      'SELECT id, name, steps, created_at, updated_at FROM patterns '
      'ORDER BY rowid',
    ),
    'pattern_runs': await rows(
      'SELECT id, calendar_id, pattern_id, start_date, end_date, step_offset, '
      'seq, created_at FROM pattern_runs ORDER BY seq',
    ),
    'day_entries': await rows(
      'SELECT calendar_id, date, shift_type_ids, note, updated_at, '
      'note_reminder_minute, overtime_minutes, early_leave_minutes '
      'FROM day_entries ORDER BY calendar_id, date',
    ),
    'holidays': await rows(
      'SELECT id, date, scope, name, region_code, municipality_code, source '
      'FROM holidays ORDER BY id',
    ),
    'absence_balances': await rows(
      'SELECT year, type, allowed_days FROM absence_balances '
      'ORDER BY year, type',
    ),
    'settings': await rows('SELECT key, value FROM settings ORDER BY key'),
  };
}
