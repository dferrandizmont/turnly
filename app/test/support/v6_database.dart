import 'package:cuadrante/core/database/app_database.dart';
import 'package:cuadrante/core/database/app_database.steps.dart';
import 'package:cuadrante/core/database/migration_v1_to_v2.dart';
import 'package:cuadrante/core/database/migration_v2_to_v3.dart';
import 'package:cuadrante/core/database/migration_v3_to_v4.dart';
import 'package:cuadrante/core/database/migration_v4_to_v5.dart';
import 'package:cuadrante/core/database/migration_v5_to_v6.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:cuadrante/features/summary/domain/month_summary.dart';
import 'package:drift/drift.dart';

/// The app's database stopped at schema v6: the real published chain up to
/// v6 and nothing after it, to build a v6 file the v6 -> v7 step can be
/// tested on.
class AppDatabaseAtV6 extends AppDatabase {
  AppDatabaseAtV6(super.e);

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: stepByStep(
      from1To2: migrateFrom1To2,
      from2To3: migrateFrom2To3,
      from3To4: migrateFrom3To4,
      from4To5: migrateFrom4To5,
      from5To6: migrateFrom5To6,
      from6To7: (m, schema) async => throw StateError('not this far'),
      from7To8: (m, schema) async => throw StateError('not this far'),
    ),
  );
}

/// The v6 tables whose rows the step to v7 must keep, with their order.
const Map<String, String> v6TableOrder = {
  'calendars': 'id',
  'shift_types': 'id',
  'shift_type_versions': 'shift_type_id, until_date',
  'patterns': 'rowid',
  'pattern_runs': 'id',
  'day_entries': 'calendar_id, date',
  'note_attachments': 'id',
  'day_tasks': 'id',
  'shift_swaps': 'id',
  'holidays': 'id',
  'absence_balances': 'year, type',
  'settings': 'key',
};

/// What a v6 install adds on top of the v5 seed for the extra hours: old
/// overtime minutes on a day emptied by hand (no shift: the block starts at
/// 08:00), on a day of a night shift (it is the next morning), after a
/// split shift and one over a whole day (the CHECK only stopped negatives;
/// the app always read it as 1440). Pluses per hour on two shift types (v6
/// columns) so the conversion can be checked on the money of the night and
/// the holidays. Plus an extra amount, a v6 column that must stay.
Future<void> seedV6Extras(GeneratedDatabase db) async {
  // The v3 day with overtime also had an early leave: that is the one case
  // that does not count exactly the same (the early leave cuts the shift now,
  // not the extra; docs/datos.md, «Cómo cuentan»), checked in
  // overtime_blocks_test.dart. Here it goes, so the months can be compared
  // whole.
  await db.customStatement(
    'UPDATE day_entries SET early_leave_minutes = NULL '
    "WHERE calendar_id = 'main' AND date = '2026-10-19'",
  );
  await db.customStatement(
    'UPDATE shift_types SET night_plus_cents_per_hour = 175, '
    "holiday_plus_cents_per_hour = 250 WHERE id IN ('night', 'morning')",
  );
  await db.customStatement(
    'INSERT INTO day_entries (calendar_id, date, shift_type_ids, note, '
    'updated_at, overtime_minutes, extra_amount_cents) VALUES '
    "('main', '2027-02-03', '[]', NULL, 1767254400000, 45, NULL), "
    "('main', '2027-02-04', '[\"night\"]', 'Doblé', 1767254400000, 60, 1200), "
    "('pareja', '2027-02-05', '[\"morning\"]', NULL, 1767254400000, 2000, "
    'NULL), '
    "('viejo', '2027-02-06', NULL, NULL, 1767254400000, 0, NULL)",
  );
}

/// Holidays for the equivalence checks: the day of the old v3 overtime (with
/// an early leave), the morning after the night shift of 2027-02-04 and the
/// day of the 24 h block and the next one. Not the day without a shift: its
/// old minutes had no clock, the block has one (from 08:00), so on a
/// holiday it adds holiday hours (docs/datos.md, «Esquema v7»).
final v6Holidays = {
  CivilDate(2026, 10, 19),
  CivilDate(2027, 2, 5),
  CivilDate(2027, 2, 6),
};

/// The v6 columns of every table of [db] (read from the file itself).
Future<Map<String, String>> v6Columns(GeneratedDatabase db) async => {
  for (final table in v6TableOrder.keys)
    table: [
      for (final row
          in await db.customSelect('PRAGMA table_info($table)').get())
        row.read<String>('name'),
    ].join(', '),
};

/// Every row of the v6 tables with [columns] (from [v6Columns]) and, for
/// `day_entries`, without `overtime_minutes`: what the step must not touch.
Future<Map<String, List<Map<String, Object?>>>> dumpV6Rows(
  GeneratedDatabase db,
  Map<String, String> columns,
) async => {
  for (final MapEntry(key: table, value: order) in v6TableOrder.entries)
    table: [
      for (final row
          in await db
              .customSelect(
                'SELECT ${columns[table]!.split(', ').where((c) => c != 'overtime_minutes').join(', ')} '
                'FROM $table ORDER BY $order',
              )
              .get())
        row.data,
    ],
};

/// `calendar|date` -> the old overtime minutes of every day that has some.
Future<Map<String, int>> legacyOvertime(GeneratedDatabase db) async => {
  for (final row
      in await db
          .customSelect(
            'SELECT calendar_id, date, overtime_minutes FROM day_entries '
            'WHERE overtime_minutes > 0',
          )
          .get())
    '${row.read<String>('calendar_id')}|${row.read<String>('date')}': row
        .read<int>('overtime_minutes'),
};

/// [dump] (rows by table) as the step to v7 leaves it: the same rows, with
/// the old `day_entries.overtime_minutes` emptied (they are blocks now). For
/// the tests of the older steps, which run the whole chain to the newest
/// schema.
Map<String, List<Map<String, Object?>>> afterV7(
  Map<String, List<Map<String, Object?>>> dump,
) => {
  for (final MapEntry(key: table, value: rows) in dump.entries)
    table: table != 'day_entries'
        ? rows
        : [
            for (final row in rows)
              if (row.containsKey('overtime_minutes'))
                {...row, 'overtime_minutes': null}
              else
                row,
          ],
};

/// [schedule] (rebuilt from the rows of an older version) as the step to v7
/// leaves it: the old overtime minutes of each day are a block of «Horas
/// extra» from the end of the day's last shift (`legacyOvertimeBlock`).
Schedule legacyAsBlocks(Schedule schedule) => schedule.copyWith(
  entries: {
    for (final MapEntry(key: date, value: entry) in schedule.entries.entries)
      date: switch (entry.overtimeMinutes) {
        final minutes? when minutes > 0 => entry.copyWith(
          clearOvertime: true,
          overtimeBlocks: [
            legacyOvertimeBlock(
              schedule.resolve(date),
              minutes.clamp(1, maxDayExtraMinutes),
            ),
          ],
        ),
        null => entry,
        _ => entry.copyWith(clearOvertime: true),
      },
  },
);

/// Everything a month summary says, to compare two of them field by field.
Map<String, Object?> summaryFacts(MonthSummary s) => {
  'shiftsWorked': s.shiftsWorked,
  'workedDays': s.workedDays,
  'workedMinutes': s.workedMinutes,
  'nightMinutes': s.nightMinutes,
  'holidayShifts': s.holidayShifts,
  'holidayMinutes': s.holidayMinutes,
  'earningsCents': s.earningsCents,
  'overtimeMinutes': s.overtimeMinutes,
  'overtimeCents': s.overtimeCents,
  'earlyLeaveMinutes': s.earlyLeaveMinutes,
  'earlyLeaveCents': s.earlyLeaveCents,
  'extrasWithoutRateMinutes': s.extrasWithoutRateMinutes,
  'fixedPlusCents': s.fixedPlusCents,
  'nightPlusCents': s.nightPlusCents,
  'holidayPlusCents': s.holidayPlusCents,
  'extraAmountCents': s.extraAmountCents,
  'cappedOvertimeMinutes': s.cappedOvertimeMinutes,
  'goalCountedMinutes': s.goalCountedMinutes,
  'types': [
    for (final t in s.types)
      [
        t.type.id,
        t.count,
        t.paidMinutes,
        t.nightMinutes,
        t.earningsCents,
        t.nightPlusCents,
        t.holidayPlusCents,
      ],
  ],
};

/// [summaryFacts] of every month of 2026 and 2027 of [schedule].
List<Map<String, Object?>> monthsFacts(
  Schedule schedule, {
  Set<CivilDate> holidays = const {},
}) => [
  for (var m = 0; m < 24; m++)
    summaryFacts(
      summarizeMonth(
        schedule,
        CivilDate(2026 + m ~/ 12, m % 12 + 1, 1),
        holidays: holidays,
      ),
    ),
];
