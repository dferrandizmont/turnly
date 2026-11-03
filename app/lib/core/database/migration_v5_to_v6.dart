import 'package:collection/collection.dart';
import 'package:drift/drift.dart';

import 'app_database.steps.dart';

/// The tables of v5 with the columns they had then and the order that
/// identifies each row. Literal on purpose: a published migration must not
/// change when the schema does.
const Map<String, String> _v5Tables = {
  'calendars': 'id',
  'shift_types': 'id',
  'shift_type_versions': 'shift_type_id, until_date',
  // rowid: the insertion order of patterns is data (docs/datos.md).
  'patterns': 'rowid',
  'pattern_runs': 'id',
  'day_entries': 'calendar_id, date',
  'holidays': 'id',
  'absence_balances': 'year, type',
  'settings': 'key',
};

/// The v6 additions to existing tables, and what an untouched row holds in
/// them.
const String _newColumnsUntouched = '''
SELECT
  (SELECT COUNT(*) FROM shift_types WHERE location IS NOT NULL
     OR night_plus_cents_per_hour IS NOT NULL
     OR holiday_plus_cents_per_hour IS NOT NULL)
  + (SELECT COUNT(*) FROM shift_type_versions
     WHERE night_plus_cents_per_hour IS NOT NULL
     OR holiday_plus_cents_per_hour IS NOT NULL)
  + (SELECT COUNT(*) FROM day_entries WHERE extra_amount_cents IS NOT NULL)
  + (SELECT COUNT(*) FROM absence_balances WHERE calendar_id IS NOT NULL
     OR name IS NOT NULL OR period_start IS NOT NULL OR period_end IS NOT NULL
     OR unit <> 'day' OR shift_type_quarters IS NOT NULL OR carry_over <> 0
     OR carry_over_max_days IS NOT NULL OR adjustment_days <> 0
     OR sort_order <> 0 OR created_at IS NOT NULL OR updated_at IS NOT NULL)
  + (SELECT COUNT(*) FROM note_attachments)
  + (SELECT COUNT(*) FROM day_tasks)
  + (SELECT COUNT(*) FROM shift_swaps) AS n
''';

/// Schema v6 (docs/datos.md, «Esquema v6»): what the paid-feature parity
/// packages need (attachments and tasks of a day, the swap ledger, absence
/// balances, place and pluses per hour of a shift type, an extra amount per
/// day) and a higher cap for money columns.
///
/// In one transaction: if anything fails, the file stays at v5 exactly. No
/// existing value changes: every v5 column of every row is compared before
/// and after, the new columns must be empty (or at their default) and the
/// new tables empty, and the foreign keys must hold; otherwise it throws and
/// rolls back. The automatic pre-migration copy is made by openAppDatabase,
/// before opening Drift.
///
/// `shift_types` and `shift_type_versions` are rebuilt (a CHECK can only be
/// changed by rebuilding the table): the versions are kept in memory, their
/// table dropped, `shift_types` rebuilt and the versions table created and
/// filled again. That way dropping `shift_types` can never cascade into its
/// versions, whatever the state of `PRAGMA foreign_keys`. `absence_balances`
/// is rebuilt too (it gets table CHECKs); `day_entries` only gets a column.
Future<void> migrateFrom5To6(
  Migrator m,
  Schema6 schema, {
  Future<void> Function()? afterChanges,
}) async {
  final db = m.database;
  await db.transaction(() async {
    final columns = <String, String>{
      for (final table in _v5Tables.keys)
        table: [
          for (final row
              in await db.customSelect('PRAGMA table_info($table)').get())
            row.read<String>('name'),
        ].join(', '),
    };
    Future<Map<String, List<Map<String, Object?>>>> dump() async => {
      for (final MapEntry(key: table, value: order) in _v5Tables.entries)
        table: [
          for (final row
              in await db
                  .customSelect(
                    'SELECT ${columns[table]} FROM $table ORDER BY $order',
                  )
                  .get())
            row.data,
        ],
    };

    final before = await dump();

    // The versions, in memory, while the table is gone.
    final versionColumns = columns['shift_type_versions']!;
    final versions = before['shift_type_versions']!;
    await db.customStatement('DROP TABLE shift_type_versions');
    await m.alterTable(
      TableMigration(
        schema.shiftTypes,
        newColumns: [
          schema.shiftTypes.location,
          schema.shiftTypes.nightPlusCentsPerHour,
          schema.shiftTypes.holidayPlusCentsPerHour,
        ],
      ),
    );
    await m.createTable(schema.shiftTypeVersions);
    final names = versionColumns.split(', ');
    final placeholders = List.filled(names.length, '?').join(', ');
    for (final row in versions) {
      await db.customStatement(
        'INSERT INTO shift_type_versions ($versionColumns) '
        'VALUES ($placeholders)',
        [for (final name in names) row[name]],
      );
    }

    await m.addColumn(schema.dayEntries, schema.dayEntries.extraAmountCents);
    await m.alterTable(
      TableMigration(
        schema.absenceBalances,
        newColumns: [
          schema.absenceBalances.calendarId,
          schema.absenceBalances.name,
          schema.absenceBalances.periodStart,
          schema.absenceBalances.periodEnd,
          schema.absenceBalances.unit,
          schema.absenceBalances.shiftTypeQuarters,
          schema.absenceBalances.carryOver,
          schema.absenceBalances.carryOverMaxDays,
          schema.absenceBalances.adjustmentDays,
          schema.absenceBalances.sortOrder,
          schema.absenceBalances.createdAt,
          schema.absenceBalances.updatedAt,
        ],
      ),
    );
    await m.createTable(schema.noteAttachments);
    await m.createIndex(schema.idxNoteAttachmentsDay);
    await m.createTable(schema.dayTasks);
    await m.createIndex(schema.idxDayTasksDay);
    await m.createTable(schema.shiftSwaps);
    await m.createIndex(schema.idxShiftSwapsDay);

    await afterChanges?.call();

    final after = await dump();
    final added = await db.customSelect(_newColumnsUntouched).getSingle();
    final broken = await db.customSelect('PRAGMA foreign_key_check').get();
    if (!const DeepCollectionEquality().equals(before, after) ||
        added.read<int>('n') != 0 ||
        broken.isNotEmpty) {
      throw StateError('Migration v5 -> v6 changed user data; rolled back');
    }
  });
}
