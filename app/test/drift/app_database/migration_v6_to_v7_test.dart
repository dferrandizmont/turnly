import 'package:cuadrante/core/database/app_database.dart';
import 'package:cuadrante/core/database/app_database.steps.dart';
import 'package:cuadrante/core/database/migration_v1_to_v2.dart';
import 'package:cuadrante/core/database/migration_v2_to_v3.dart';
import 'package:cuadrante/core/database/migration_v3_to_v4.dart';
import 'package:cuadrante/core/database/migration_v4_to_v5.dart';
import 'package:cuadrante/core/database/migration_v5_to_v6.dart';
import 'package:cuadrante/core/database/migration_v6_to_v7.dart';
import 'package:cuadrante/features/schedule/data/overtime_store.dart';
import 'package:cuadrante/features/schedule/data/schedule_repository.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:cuadrante/features/summary/domain/month_summary.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/v3_database.dart';
import '../../support/v5_database.dart';
import '../../support/v6_database.dart';
import 'generated/schema.dart';
import 'generated/schema_v3.dart' as v3;

class _FailingV7 extends AppDatabase {
  _FailingV7(super.e);

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: stepByStep(
      from1To2: migrateFrom1To2,
      from2To3: migrateFrom2To3,
      from3To4: migrateFrom3To4,
      from4To5: migrateFrom4To5,
      from5To6: migrateFrom5To6,
      from6To7: (m, schema) => migrateFrom6To7(
        m,
        schema,
        afterConvert: () async => throw StateError('boom after the blocks'),
      ),
    ),
  );
}

const _calendars = ['main', 'pareja', 'viejo'];
final _from = CivilDate(2026, 1, 1);
final _to = CivilDate(2027, 12, 31);

List<String> _tableNames(InitializedSchema schema) => [
  for (final row in schema.rawDatabase.select(
    "SELECT name FROM sqlite_master WHERE type = 'table'",
  ))
    row['name'] as String,
];

int _userVersion(InitializedSchema schema) =>
    schema.rawDatabase.select('PRAGMA user_version').single.values.single!
        as int;

/// The worked minutes of each day of [schedule] in the window.
List<int> _workedByDay(Schedule schedule) => [
  for (final day in schedule.resolveRange(_from, _to))
    summarizeRange(schedule, day.date, day.date).workedMinutes,
];

/// [schedule] as the v6 app saw it: no blocks, and the old minutes of each
/// day back (an independent view of what the summary counted before).
Schedule _asBefore(Schedule schedule, String id, Map<String, int> overtime) {
  final entries = <CivilDate, DayEntry>{
    for (final MapEntry(key: date, value: entry) in schedule.entries.entries)
      date: entry.copyWith(overtimeBlocks: const []),
  };
  for (final MapEntry(key: key, value: minutes) in overtime.entries) {
    final [calendar, iso] = key.split('|');
    if (calendar != id) continue;
    final date = CivilDate.parse(iso);
    entries[date] = (entries[date] ?? DayEntry(date: date)).copyWith(
      overtimeMinutes: minutes.clamp(0, maxDayExtraMinutes),
    );
  }
  return schedule.copyWith(entries: entries);
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;
  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  /// A real v6 file: the v3 install of the other tests taken up to v6 by the
  /// published chain, with the v5 extras and days with old overtime minutes
  /// (with a shift, a night shift, no shift and over a whole day).
  Future<
    ({
      InitializedSchema schema,
      Map<String, String> columns,
      Map<String, List<Map<String, Object?>>> before,
      Map<String, int> overtime,
    })
  >
  seededV6() async {
    final schema = await verifier.schemaAt(3);
    addTearDown(schema.rawDatabase.close);
    final old = v3.DatabaseAtV3(schema.newConnection());
    await seedV3(old);
    await old.close();
    final atV5 = AppDatabaseAtV5(schema.newConnection());
    await seedV5Extras(atV5);
    await atV5.close();
    final atV6 = AppDatabaseAtV6(schema.newConnection());
    await seedV6Extras(atV6);
    final columns = await v6Columns(atV6);
    final before = await dumpV6Rows(atV6, columns);
    final overtime = await legacyOvertime(atV6);
    await atV6.close();
    expect(_userVersion(schema), 6);
    return (
      schema: schema,
      columns: columns,
      before: before,
      overtime: overtime,
    );
  }

  Future<void> expectConverted(
    AppDatabase db, {
    required Map<String, String> columns,
    required Map<String, List<Map<String, Object?>>> before,
    required Map<String, int> overtime,
  }) async {
    // Nothing else moved.
    expect(await dumpV6Rows(db, columns), before);
    final left = await db
        .customSelect(
          'SELECT COUNT(*) AS n FROM day_entries '
          'WHERE overtime_minutes IS NOT NULL',
        )
        .getSingle();
    expect(left.read<int>('n'), 0);
    // The two built-in types.
    expect(await OvertimeStore(db).types(), defaultOvertimeTypes);
    // One block of «Horas extra» per day that had minutes, with them (1440
    // at most), from the end of the day's last shift or 00:00.
    var blocks = 0;
    for (final id in _calendars) {
      final schedule = (await ScheduleRepository(db).load(id)).schedule;
      for (final block in await OvertimeStore(db).blocks(id)) {
        blocks++;
        final minutes = overtime['$id|${block.date.toIso()}'];
        expect(minutes, isNotNull, reason: '$id ${block.date}');
        expect(block.paidMinutes, minutes!.clamp(1, 1440));
        expect(block.typeId, overtimeTypeId);
        expect(block.breakMinutes, 0);
        expect(block.note, isNull);
        expect(block.id, legacyOvertimeBlockId(block.date));
        final day = schedule.resolve(block.date);
        expect(
          block.startMinute,
          (lastWorkEndMinute(day) ?? legacyFreeDayOvertimeStart) % 1440,
          reason: '$id ${block.date}',
        );
        expect(day.overtimeBlocks, [block]);
      }
    }
    expect(blocks, overtime.length);
    // Every day keeps the minutes it counted with the old overtime, and
    // every month the same summary: money, overtime, night and holiday
    // hours, pluses (the built-in type is paid as the shift, x1).
    for (final id in _calendars) {
      final schedule = (await ScheduleRepository(db).load(id)).schedule;
      final before = _asBefore(schedule, id, overtime);
      expect(_workedByDay(schedule), _workedByDay(before), reason: id);
      expect(
        monthsFacts(schedule, holidays: v6Holidays),
        monthsFacts(before, holidays: v6Holidays),
        reason: id,
      );
    }
    expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
  }

  test('v6 to v7 turns every overtime into a block and keeps the rest '
      'exactly', () async {
    final (:schema, :columns, :before, :overtime) = await seededV6();
    // The v3 day (90 min after a shift) and the four v6 extras (the 0 is
    // nothing).
    expect(overtime, {
      'main|2026-10-19': 90,
      'main|2027-02-03': 45,
      'main|2027-02-04': 60,
      'pareja|2027-02-05': 2000,
    });
    expect(_tableNames(schema), isNot(contains('overtime_blocks')));
    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 7);
    await expectConverted(
      db,
      columns: columns,
      before: before,
      overtime: overtime,
    );
    expect(_userVersion(schema), 7);
    final blocks = {
      for (final b in await OvertimeStore(db).blocks('main'))
        b.date.toIso(): (b.startMinute, b.endMinute),
    };
    // No shift: from 08:00. A night shift (22:00-06:00): from 06:00, the
    // morning after.
    expect(blocks['2027-02-03'], (480, 525));
    expect(blocks['2027-02-04'], (360, 420));
    final mainSchedule = (await ScheduleRepository(db).load('main')).schedule;
    final night = mainSchedule.resolve(CivilDate(2027, 2, 4));
    expect(overtimeOnNextDay(night.overtimeBlocks.single, night), isTrue);
    // The money of the night is there: the pluses of the night shift.
    expect(
      summarizeMonth(mainSchedule, CivilDate(2027, 2, 1)).nightPlusCents,
      greaterThan(0),
    );
    final pareja = await OvertimeStore(db).blocks('pareja');
    expect(pareja.single.durationMinutes, 1440);
  });

  test('with foreign keys on during the upgrade', () async {
    final (:schema, :columns, :before, :overtime) = await seededV6();
    schema.rawDatabase.execute('PRAGMA foreign_keys = ON');
    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 7);
    await expectConverted(
      db,
      columns: columns,
      before: before,
      overtime: overtime,
    );
  });

  test('a failure rolls back to the untouched v6 file; the next start '
      'migrates', () async {
    final (:schema, :columns, :before, :overtime) = await seededV6();
    final failing = _FailingV7(schema.newConnection());
    await expectLater(
      failing.customSelect('SELECT 1').get(),
      throwsA(isA<StateError>()),
    );
    await failing.close();
    expect(_userVersion(schema), 6);
    expect(_tableNames(schema), isNot(contains('overtime_types')));
    expect(_tableNames(schema), isNot(contains('overtime_blocks')));
    final atV6 = AppDatabaseAtV6(schema.newConnection());
    expect(await dumpV6Rows(atV6, columns), before);
    expect(await legacyOvertime(atV6), overtime);
    await atV6.close();

    final retried = AppDatabase(schema.newConnection());
    addTearDown(retried.close);
    await verifier.migrateAndValidate(retried, 7);
    await expectConverted(
      retried,
      columns: columns,
      before: before,
      overtime: overtime,
    );
  });

  test('after migrating, types and blocks are written and read, the CHECKs '
      'hold and a calendar takes its blocks with it', () async {
    final (:schema, columns: _, before: _, overtime: _) = await seededV6();
    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 7);
    await db.customStatement('PRAGMA foreign_keys = ON');
    final store = OvertimeStore(db);
    const second = OvertimeType(
      id: 'ot-guard',
      name: 'Guardia localizada',
      colorValue: 0xFFE5484D,
      rateMode: OvertimeRateMode.fixed,
      hourlyRateCents: 1200,
      countsForGoal: false,
      sortOrder: 2,
    );
    await store.saveType(second);
    await store.saveType(defaultOvertimeTypes.first.copyWith(name: 'Extras'));
    final types = await store.types();
    expect(types.map((t) => t.id), [
      overtimeTypeId,
      otherWorkTypeId,
      'ot-guard',
    ]);
    expect(types.first.name, 'Extras');
    expect(types.last, second);

    final day = CivilDate(2027, 3, 1);
    final blocks = [
      OvertimeBlock(
        id: 'a',
        date: day,
        typeId: 'ot-guard',
        startMinute: 1320,
        endMinute: 120,
        breakMinutes: 30,
        note: 'Aviso',
      ),
    ];
    await store.replaceDay('viejo', day, blocks);
    expect([
      for (final b in await store.blocks('viejo'))
        if (b.date == day) b,
    ], blocks);

    Future<void> raw(String sql) => db.customStatement(sql);
    // CHECKs: a break as long as the block, a fixed rate without rate, a
    // blank name, a note over 200.
    await expectLater(
      raw(
        'INSERT INTO overtime_blocks (calendar_id, date, id, type_id, '
        "start_minute, end_minute, break_minutes) VALUES ('main', "
        "'2027-03-02', 'x', 'overtime', 600, 660, 60)",
      ),
      throwsA(anything),
    );
    await expectLater(
      raw(
        'INSERT INTO overtime_types (id, color_value, rate_mode, '
        "counts_for_goal) VALUES ('x', 1, 'fixed', 1)",
      ),
      throwsA(anything),
    );
    await expectLater(
      raw(
        'INSERT INTO overtime_types (id, name, color_value, rate_mode, '
        "counts_for_goal) VALUES ('y', '  ', 1, 'none', 1)",
      ),
      throwsA(anything),
    );
    await expectLater(
      raw(
        'INSERT INTO overtime_blocks (calendar_id, date, id, type_id, '
        "start_minute, end_minute, note) VALUES ('main', '2027-03-02', 'z', "
        "'overtime', 600, 660, '${'n' * 201}')",
      ),
      throwsA(anything),
    );
    // A type in use cannot go (it is archived instead); a calendar takes
    // its blocks with it.
    await expectLater(
      raw("DELETE FROM overtime_types WHERE id = 'ot-guard'"),
      throwsA(anything),
    );
    await raw("DELETE FROM pattern_runs WHERE calendar_id = 'viejo'");
    await raw("DELETE FROM day_entries WHERE calendar_id = 'viejo'");
    await raw("DELETE FROM calendars WHERE id = 'viejo'");
    expect(await store.blocks('viejo'), isEmpty);

    await store.setBaseRate(1550);
    expect(await store.baseRate(), 1550);
    await store.setBaseRate(null);
    expect(await store.baseRate(), isNull);
  });

  test('a brand new database has the two built-in types', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    expect(await OvertimeStore(db).types(), defaultOvertimeTypes);
  });
}
