import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:drift/drift.dart';

import '../../features/schedule/domain/schedule_domain.dart';
import 'app_database.steps.dart';

/// The two built-in overtime types as the step to v7 creates them, frozen:
/// «Horas extra» (`overtime`, paid as the shift x1, counts for the goal) and
/// «Otro trabajo» (`other-work`, not paid, does not count), both without a
/// stored name. Literal on purpose: a published step must never move with
/// `defaultOvertimeTypes` or the table classes (a test checks they are the
/// same today). Used by the step, by a brand new database and by «Empezar de
/// cero».
Future<void> insertDefaultOvertimeTypes(GeneratedDatabase db) =>
    db.customStatement(
      'INSERT INTO overtime_types (id, name, color_value, rate_mode, '
      'multiplier_basis_points, hourly_rate_cents, counts_for_goal, archived, '
      'sort_order) VALUES '
      "('overtime', NULL, 4283125713, 'shift', 10000, NULL, 1, 0, 0), "
      "('other-work', NULL, 4279412116, 'none', 10000, NULL, 0, 0, 1)",
    );

/// The v6 tables the step must leave exactly as they were, with the order
/// that identifies each row. `day_entries` is compared without
/// `overtime_minutes`, the one column the step empties. Literal on purpose:
/// a published migration must not change when the schema does.
const Map<String, String> _v6Tables = {
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

const String _v6ShiftColumns =
    'category, start_minute, end_minute, paid_minutes, '
    'hourly_rate_cents, segment2_start_minute, segment2_duration_minutes';

/// Schema v7 (docs/datos.md, «Esquema v7»): extra hours become blocks with a
/// type, a schedule and a price.
///
/// In one transaction: if anything fails, the file stays at v6 exactly. It
/// creates `overtime_types` (with the two built-in types) and
/// `overtime_blocks`, and turns the `overtime_minutes` of every day into one
/// block of «Horas extra» that starts when the last work shift with a
/// schedule of that day ends (08:00 without one: no night hours it never had) and
/// lasts those minutes; then it empties the column. A value over 1440 (the
/// CHECK only stops negatives) becomes 1440, which is what the app always
/// read it as. It checks that every other column of every row is the same,
/// that there is one block per day that had overtime with exactly its
/// minutes, that the column is empty and that the foreign keys hold;
/// otherwise it throws and rolls back. The automatic pre-migration copy is
/// made by openAppDatabase, before opening Drift.
///
/// [afterConvert] runs inside the transaction once the blocks are written
/// (tests use it to make the step fail).
Future<void> migrateFrom6To7(
  Migrator m,
  Schema7 schema, {
  Future<void> Function()? afterConvert,
}) async {
  final db = m.database;
  await db.transaction(() async {
    final columns = <String, String>{
      for (final table in _v6Tables.keys)
        table: [
          for (final row
              in await db.customSelect('PRAGMA table_info($table)').get())
            if (!(table == 'day_entries' &&
                row.read<String>('name') == 'overtime_minutes'))
              row.read<String>('name'),
        ].join(', '),
    };
    Future<Map<String, List<Map<String, Object?>>>> dump() async => {
      for (final MapEntry(key: table, value: order) in _v6Tables.entries)
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

    await m.createTable(schema.overtimeTypes);
    await m.createTable(schema.overtimeBlocks);
    await insertDefaultOvertimeTypes(db);

    final schedules = await _v6Schedules(db);
    final legacy = await db
        .customSelect(
          'SELECT calendar_id, date, overtime_minutes FROM day_entries '
          'WHERE overtime_minutes > 0 ORDER BY calendar_id, date',
        )
        .get();
    final expected = <String, int>{};
    for (final row in legacy) {
      final calendarId = row.read<String>('calendar_id');
      final date = CivilDate.parse(row.read<String>('date'));
      final minutes = row.read<int>('overtime_minutes').clamp(1, 1440);
      final schedule = schedules[calendarId] ?? Schedule();
      // Frozen here (the same rule as `legacyOvertimeBlock` today): from the
      // end of the day's last work shift with a schedule, or 08:00 without
      // one, for exactly those minutes; type «Horas extra».
      int? lastEnd;
      for (final shift in schedule.resolve(date).shifts) {
        if (shift.category != ShiftCategory.work || !shift.hasTimes) continue;
        final end = shift.startMinute! + shift.spanMinutes;
        if (lastEnd == null || end > lastEnd) lastEnd = end;
      }
      final start = (lastEnd ?? 8 * 60) % 1440;
      await db.customStatement(
        'INSERT INTO overtime_blocks (calendar_id, date, id, type_id, '
        'start_minute, end_minute, break_minutes, note) '
        "VALUES (?, ?, ?, 'overtime', ?, ?, 0, NULL)",
        [
          calendarId,
          date.toIso(),
          'legacy-${date.toIso()}',
          start,
          (start + minutes) % 1440,
        ],
      );
      expected['$calendarId|${date.toIso()}'] = minutes;
    }
    await afterConvert?.call();
    await db.customStatement(
      'UPDATE day_entries SET overtime_minutes = NULL '
      'WHERE overtime_minutes IS NOT NULL',
    );

    // Checks: nothing else moved, every minute is in its block, the old
    // column is empty and every reference holds.
    if (!const DeepCollectionEquality().equals(before, await dump())) {
      throw StateError('Migration v6 -> v7 changed existing data');
    }
    final blocks = await db
        .customSelect(
          'SELECT calendar_id, date, type_id, break_minutes, '
          '(end_minute - start_minute + 1439) % 1440 + 1 AS minutes '
          'FROM overtime_blocks',
        )
        .get();
    final actual = <String, int>{
      for (final b in blocks)
        '${b.read<String>('calendar_id')}|${b.read<String>('date')}': b
            .read<int>('minutes'),
    };
    if (blocks.length != expected.length ||
        blocks.any(
          (b) =>
              b.read<String>('type_id') != 'overtime' ||
              b.read<int>('break_minutes') != 0,
        ) ||
        !const MapEquality<String, int>().equals(actual, expected)) {
      throw StateError('Migration v6 -> v7 changed the overtime minutes');
    }
    final left = await db
        .customSelect(
          'SELECT COUNT(*) AS n FROM day_entries '
          'WHERE overtime_minutes IS NOT NULL',
        )
        .getSingle();
    if (left.read<int>('n') != 0) {
      throw StateError('Migration v6 -> v7 left overtime minutes');
    }
    final types = await db
        .customSelect('SELECT COUNT(*) AS n FROM overtime_types')
        .getSingle();
    if (types.read<int>('n') != 2) {
      throw StateError('Migration v6 -> v7 did not create the types');
    }
    if ((await db.customSelect('PRAGMA foreign_key_check').get()).isNotEmpty) {
      throw StateError('Migration v6 -> v7 broke a foreign key');
    }
  });
}

/// The schedule of each calendar as the v6 app resolved it (shift types with
/// their versions, patterns, runs and day overrides), read with literal SQL
/// over the v6 columns: enough to know when each day's last shift ended and
/// what it paid.
Future<Map<String, Schedule>> _v6Schedules(GeneratedDatabase db) async {
  ShiftTerms terms(QueryRow r) {
    final start = r.readNullable<int>('start_minute');
    final end = r.readNullable<int>('end_minute');
    final s2Start = r.readNullable<int>('segment2_start_minute');
    final s2Length = r.readNullable<int>('segment2_duration_minutes');
    // A second segment the domain refuses reads as none (as the app did).
    final s2Valid =
        s2Start != null &&
        s2Length != null &&
        checkSegment2(
              startMinute: start,
              endMinute: end,
              segment2StartMinute: s2Start,
              segment2DurationMinutes: s2Length,
            ) ==
            null;
    return ShiftTerms(
      category: ShiftCategory.values.byName(r.read<String>('category')),
      startMinute: start,
      endMinute: end,
      paidMinutes: r.readNullable<int>('paid_minutes'),
      hourlyRateCents: r.readNullable<int>('hourly_rate_cents'),
      segment2StartMinute: s2Valid ? s2Start : null,
      segment2DurationMinutes: s2Valid ? s2Length : null,
    );
  }

  final shiftTypes = [
    for (final r
        in await db
            .customSelect(
              'SELECT id, code, name, color_value, $_v6ShiftColumns '
              'FROM shift_types',
            )
            .get())
      terms(r).applyTo(
        ShiftType(
          id: r.read<String>('id'),
          code: r.read<String>('code'),
          name: r.read<String>('name'),
          colorValue: r.read<int>('color_value'),
          category: ShiftCategory.work,
        ),
      ),
  ];
  final versions = <String, List<ShiftTypeVersion>>{};
  for (final r
      in await db
          .customSelect(
            'SELECT shift_type_id, until_date, $_v6ShiftColumns '
            'FROM shift_type_versions',
          )
          .get()) {
    final version = ShiftTypeVersion(
      until: CivilDate.parse(r.read<String>('until_date')),
      terms: terms(r),
    );
    if (version.terms.problem != null) continue;
    (versions[r.read<String>('shift_type_id')] ??= []).add(version);
  }
  final patterns = [
    for (final r
        in await db
            .customSelect('SELECT id, name, steps FROM patterns ORDER BY rowid')
            .get())
      Pattern(
        id: r.read<String>('id'),
        name: r.read<String>('name'),
        steps: [
          for (final step in jsonDecode(r.read<String>('steps')) as List)
            (step as List).cast<String>(),
        ],
      ),
  ];
  final schedules = <String, Schedule>{};
  for (final c in await db.customSelect('SELECT id FROM calendars').get()) {
    final calendarId = c.read<String>('id');
    final runs = [
      for (final r
          in await db
              .customSelect(
                'SELECT id, pattern_id, start_date, end_date, step_offset, '
                'seq FROM pattern_runs WHERE calendar_id = ?',
                variables: [Variable.withString(calendarId)],
              )
              .get())
        PatternRun(
          id: r.read<String>('id'),
          patternId: r.read<String>('pattern_id'),
          startDate: CivilDate.parse(r.read<String>('start_date')),
          endDate: switch (r.readNullable<String>('end_date')) {
            final d? => CivilDate.parse(d),
            null => null,
          },
          stepOffset: r.read<int>('step_offset'),
          seq: r.read<int>('seq'),
        ),
    ];
    final entries = <CivilDate, DayEntry>{
      for (final r
          in await db
              .customSelect(
                'SELECT date, shift_type_ids FROM day_entries '
                'WHERE calendar_id = ?',
                variables: [Variable.withString(calendarId)],
              )
              .get())
        CivilDate.parse(r.read<String>('date')): DayEntry(
          date: CivilDate.parse(r.read<String>('date')),
          shiftTypeIds: switch (r.readNullable<String>('shift_type_ids')) {
            final ids? => (jsonDecode(ids) as List).cast<String>(),
            null => null,
          },
        ),
    };
    schedules[calendarId] = Schedule(
      shiftTypes: shiftTypes,
      patterns: patterns,
      runs: runs,
      entries: entries,
      shiftTypeVersions: {
        for (final MapEntry(:key, :value) in versions.entries)
          key: sortedVersions(value),
      },
    );
  }
  return schedules;
}
