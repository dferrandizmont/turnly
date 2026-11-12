import 'package:cuadrante/core/database/app_database.dart';
import 'package:cuadrante/core/database/app_database.steps.dart';
import 'package:cuadrante/core/database/migration_v1_to_v2.dart';
import 'package:cuadrante/core/database/migration_v2_to_v3.dart';
import 'package:cuadrante/core/database/migration_v3_to_v4.dart';
import 'package:cuadrante/core/database/migration_v4_to_v5.dart';
import 'package:cuadrante/core/database/migration_v5_to_v6.dart';
import 'package:cuadrante/core/database/migration_v6_to_v7.dart';
import 'package:cuadrante/features/absences/data/absence_balances_repository.dart';
import 'package:cuadrante/features/absences/domain/absence_balance.dart';
import 'package:cuadrante/features/notes/data/day_tasks_repository.dart';
import 'package:cuadrante/features/notes/data/note_attachments_repository.dart';
import 'package:cuadrante/features/notes/domain/day_task.dart';
import 'package:cuadrante/features/notes/domain/note_attachment.dart';
import 'package:cuadrante/features/schedule/data/schedule_repository.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:cuadrante/features/swaps/data/shift_swaps_repository.dart';
import 'package:cuadrante/features/swaps/domain/shift_swap.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/v2_database.dart';
import '../../support/v3_database.dart';
import '../../support/v5_database.dart';
import '../../support/v6_database.dart';
import 'generated/schema.dart';
import 'generated/schema_v3.dart' as v3;

class _FailingV6 extends AppDatabase {
  _FailingV6(super.e);

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: stepByStep(
      from1To2: migrateFrom1To2,
      from2To3: migrateFrom2To3,
      from3To4: migrateFrom3To4,
      from4To5: migrateFrom4To5,
      from5To6: (m, schema) => migrateFrom5To6(
        m,
        schema,
        afterChanges: () async => throw StateError('boom after the changes'),
      ),
      from6To7: migrateFrom6To7,
    ),
  );
}

const _v6Tables = ['note_attachments', 'day_tasks', 'shift_swaps'];

List<String> _tableNames(InitializedSchema schema) => [
  for (final row in schema.rawDatabase.select(
    "SELECT name FROM sqlite_master WHERE type = 'table'",
  ))
    row['name'] as String,
];

int _userVersion(InitializedSchema schema) =>
    schema.rawDatabase.select('PRAGMA user_version').single.values.single!
        as int;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;
  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  /// A real v5 file: the v3 install of the other tests taken up to v5 by the
  /// published chain, with fixed pluses, past versions and legacy balances.
  Future<
    ({
      InitializedSchema schema,
      Map<String, List<Map<String, Object?>>> before,
      Map<String, List<Map<String, Object?>>> v3Columns,
      Map<String, List<ShiftTypeVersion>> versions,
    })
  >
  seededV5() async {
    final schema = await verifier.schemaAt(3);
    addTearDown(schema.rawDatabase.close);
    final old = v3.DatabaseAtV3(schema.newConnection());
    await seedV3(old);
    final v3Columns = await dumpV3Columns(old);
    await old.close();
    final atV5 = AppDatabaseAtV5(schema.newConnection());
    await seedV5Extras(atV5);
    final before = await dumpV5Columns(atV5);
    await atV5.close();
    expect(_userVersion(schema), 5);
    return (
      schema: schema,
      before: before,
      v3Columns: v3Columns,
      versions: {
        'night': const [
          ShiftTypeVersion(
            until: CivilDate(2026, 3, 31),
            terms: ShiftTerms(
              category: ShiftCategory.work,
              startMinute: 1260,
              endMinute: 300,
              hourlyRateCents: 1000,
            ),
          ),
          ShiftTypeVersion(
            until: CivilDate(2026, 6, 30),
            terms: ShiftTerms(
              category: ShiftCategory.work,
              startMinute: 1320,
              endMinute: 360,
              paidMinutes: 450,
              nightOverride: true,
              hourlyRateCents: 999999,
              fixedPlusCents: 0,
            ),
          ),
        ],
      },
    );
  }

  Future<void> expectUntouched(
    AppDatabase db, {
    required Map<String, List<Map<String, Object?>>> before,
    required Map<String, List<Map<String, Object?>>> v3Columns,
    required Map<String, List<ShiftTypeVersion>> versions,
  }) async {
    expect(await dumpV5Columns(db), afterV7(before));
    final added = await db
        .customSelect(
          'SELECT '
          '(SELECT COUNT(*) FROM shift_types WHERE location IS NOT NULL OR '
          'night_plus_cents_per_hour IS NOT NULL OR '
          'holiday_plus_cents_per_hour IS NOT NULL) AS types, '
          '(SELECT COUNT(*) FROM shift_type_versions WHERE '
          'night_plus_cents_per_hour IS NOT NULL OR '
          'holiday_plus_cents_per_hour IS NOT NULL) AS versions, '
          '(SELECT COUNT(*) FROM day_entries WHERE extra_amount_cents IS NOT '
          'NULL) AS days, '
          "(SELECT COUNT(*) FROM absence_balances WHERE unit = 'day' AND "
          'calendar_id IS NULL AND name IS NULL AND period_start IS NULL AND '
          'shift_type_quarters IS NULL AND carry_over = 0 AND '
          'carry_over_max_days IS NULL AND adjustment_days = 0 AND '
          'sort_order = 0 AND created_at IS NULL AND updated_at IS NULL) '
          'AS legacy',
        )
        .getSingle();
    expect(added.data, {
      'types': 0,
      'versions': 0,
      'days': 0,
      'legacy': before['absence_balances']!.length,
    });
    for (final table in _v6Tables) {
      final n = await db
          .customSelect('SELECT COUNT(*) AS n FROM $table')
          .getSingle();
      expect(n.read<int>('n'), 0, reason: table);
    }
    for (final id in ['main', 'pareja', 'viejo']) {
      final loaded = await ScheduleRepository(db).load(id);
      final prior = legacyAsBlocks(scheduleFromV3Rows(v3Columns, id));
      expect(
        v2ResolvedDays(loaded.schedule),
        v2ResolvedDays(prior),
        reason: id,
      );
      expect(loaded.schedule.shiftTypeVersions, versions, reason: id);
    }
    final balances = await AbsenceBalancesRepository(db).list();
    expect(balances, [
      for (final row in before['absence_balances']!)
        AbsenceBalance(
          year: row['year']! as int,
          type: row['type']! as String,
          allowedDays: row['allowed_days']! as double,
        ),
    ]);
    expect(
      balances.map((b) => b.type),
      containsAll(['vacaciones', 'moscosos']),
    );
    expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
  }

  test(
    'v5 to v6 keeps every row and value, the new columns and tables '
    'start empty and the 730 days of every calendar resolve as before',
    () async {
      final (:schema, :before, :v3Columns, :versions) = await seededV5();
      expect(before['shift_type_versions'], hasLength(2));
      // The v2 seed has two balances; the v5 extras add two more.
      expect(before['absence_balances'], hasLength(4));
      for (final table in _v6Tables) {
        expect(_tableNames(schema), isNot(contains(table)));
      }
      final db = AppDatabase(schema.newConnection());
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, 7);
      await expectUntouched(
        db,
        before: before,
        v3Columns: v3Columns,
        versions: versions,
      );
      expect(_userVersion(schema), 7);
      expect(_tableNames(schema), containsAll(_v6Tables));
    },
  );

  test('with foreign keys on during the upgrade, rebuilding shift_types '
      'does not cascade into its versions', () async {
    final (:schema, :before, :v3Columns, :versions) = await seededV5();
    schema.rawDatabase.execute('PRAGMA foreign_keys = ON');
    expect(
      schema.rawDatabase.select('PRAGMA foreign_keys').single.values.single,
      1,
    );
    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 7);
    await expectUntouched(
      db,
      before: before,
      v3Columns: v3Columns,
      versions: versions,
    );
  });

  test('a failure rolls back to the untouched v5 file; the next start '
      'migrates', () async {
    final (:schema, :before, :v3Columns, :versions) = await seededV5();
    final failing = _FailingV6(schema.newConnection());
    await expectLater(
      failing.customSelect('SELECT 1').get(),
      throwsA(isA<StateError>()),
    );
    await failing.close();
    expect(_userVersion(schema), 5);
    final tables = _tableNames(schema);
    for (final table in _v6Tables) {
      expect(tables, isNot(contains(table)));
    }
    expect(tables.where((t) => t.startsWith('tmp_')), isEmpty);
    final columns = [
      for (final row in schema.rawDatabase.select(
        'PRAGMA table_info(shift_types)',
      ))
        row['name'] as String,
    ];
    expect(columns, isNot(contains('location')));
    final atV5 = AppDatabaseAtV5(schema.newConnection());
    expect(await dumpV5Columns(atV5), before);
    await atV5.close();

    final retried = AppDatabase(schema.newConnection());
    addTearDown(retried.close);
    await verifier.migrateAndValidate(retried, 7);
    await expectUntouched(
      retried,
      before: before,
      v3Columns: v3Columns,
      versions: versions,
    );
  });

  test('after migrating, the new columns and tables are written, read and '
      'checked', () async {
    final (:schema, before: _, v3Columns: _, versions: _) = await seededV5();
    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 7);

    // Shift types: place and pluses, also in the versions; old money cap
    // raised.
    final repo = ScheduleRepository(db);
    final night = (await repo.load('main')).schedule.shiftTypeById('night')!;
    final richer = night.copyWith(
      location: 'UCI planta 3',
      nightPlusCentsPerHour: 250,
      holidayPlusCentsPerHour: 5000000,
      fixedPlusCents: 5000000,
    );
    final history = [
      ShiftTypeVersion(
        until: const CivilDate(2026, 9, 30),
        terms: ShiftTerms.of(night).copyWithPluses(night: 100, holiday: 200),
      ),
    ];
    await repo.saveShiftTypeWithHistory(richer, history);
    final reloaded = (await repo.load('pareja')).schedule;
    expect(reloaded.shiftTypeById('night'), richer);
    expect(reloaded.versionsOf('night'), history);

    // Day extra amount, negative too, in any calendar.
    final day = const CivilDate(2026, 10, 19);
    await repo.apply(
      'main',
      ScheduleChange(
        patch: EntriesPatch({
          day: EntryChange(
            (await repo.load('main')).schedule.entries[day],
            (await repo.load('main')).schedule.entries[day]!
                .copyWith(extraAmountCents: -1550),
          ),
        }),
      ),
    );
    expect(
      (await repo.load('main')).schedule.entries[day]!.extraAmountCents,
      -1550,
    );

    // The new tables through their repositories.
    final attachment = NoteAttachment(
      id: 'att-1',
      calendarId: 'pareja',
      date: day,
      kind: AttachmentKind.photo,
      relativePath: 'aa/${'a' * 64}',
      mimeType: 'image/jpeg',
      sizeBytes: 12345,
      sha256: 'a' * 64,
      createdAt: 1,
    );
    await NoteAttachmentsRepository(db).save(attachment);
    expect(await NoteAttachmentsRepository(db).forDay('pareja', day), [
      attachment,
    ]);
    final task = DayTask(
      id: 'task-1',
      calendarId: 'main',
      date: day,
      title: 'Llevar la bata',
      createdAt: 1,
      updatedAt: 1,
    );
    await DayTasksRepository(db).save(task);
    expect(await DayTasksRepository(db).forDay('main', day), [task]);
    final swap = ShiftSwap(
      id: 'swap-1',
      calendarId: 'main',
      date: day,
      colleague: 'Marta',
      direction: SwapDirection.theyOwe,
      givenShiftTypeIds: const ['night'],
      createdAt: 1,
      updatedAt: 1,
    );
    await ShiftSwapsRepository(db).save(swap);
    expect(await ShiftSwapsRepository(db).list(), [swap]);
    final balance = AbsenceBalance(
      year: 2027,
      type: 'vac-main',
      allowedDays: 22.5,
      calendarId: 'main',
      name: 'Vacaciones',
      periodStart: const CivilDate(2027, 4, 1),
      periodEnd: const CivilDate(2028, 3, 31),
      unit: AbsenceUnit.half,
      shiftTypeQuarters: const {'vacation': 4},
      carryOver: true,
      carryOverMaxDays: 5,
      adjustmentDays: -1.5,
      createdAt: 1,
      updatedAt: 1,
    );
    await AbsenceBalancesRepository(db).save(balance);
    expect(await AbsenceBalancesRepository(db).find(2027, 'vac-main'), balance);

    // The CHECKs of the migrated file.
    for (final sql in [
      "UPDATE shift_types SET fixed_plus_cents = 1000000000 WHERE id = 'night'",
      "UPDATE shift_types SET location = '  ' WHERE id = 'night'",
      "UPDATE shift_types SET night_plus_cents_per_hour = -1 WHERE id = 'night'",
      "UPDATE shift_type_versions SET hourly_rate_cents = -1 WHERE shift_type_id = 'night'",
      'UPDATE day_entries SET extra_amount_cents = 1000000000',
      "UPDATE note_attachments SET relative_path = '../cuadrante.sqlite'",
      "UPDATE note_attachments SET relative_path = '/data/x'",
      "UPDATE note_attachments SET kind = 'video'",
      "UPDATE note_attachments SET sha256 = 'abc'",
      "UPDATE day_tasks SET title = ' '",
      "UPDATE shift_swaps SET status = 'returned'",
      "UPDATE shift_swaps SET direction = 'both'",
      "UPDATE absence_balances SET period_end = '2027-01-01' WHERE type = 'vac-main'",
      "UPDATE absence_balances SET period_start = NULL WHERE type = 'vac-main'",
      "UPDATE absence_balances SET unit = 'hour' WHERE type = 'vac-main'",
      "UPDATE absence_balances SET adjustment_days = 0.3 WHERE type = 'vac-main'",
      "UPDATE day_tasks SET calendar_id = 'ghost'",
    ]) {
      await expectLater(
        db.customStatement(sql),
        throwsA(anything),
        reason: sql,
      );
    }
    // Same day and file path cannot be shared by two attachments.
    await expectLater(
      NoteAttachmentsRepository(db)
          .save(_copyAttachment(attachment, id: 'att-2')),
      throwsA(anything),
    );
  });

  test('the literal limits of the CHECKs are the domain constants', () {
    expect(maxAttachmentPathLength, 512);
    expect(maxAttachmentMimeLength, 255);
    expect(maxAttachmentBytes, 52428800);
    expect(maxAttachmentNameLength, 255);
    expect(maxDayTaskTitleLength, 500);
    expect(maxSwapColleagueLength, 200);
    expect(maxSwapNoteLength, 2000);
    expect(maxAbsenceBalanceNameLength, 100);
  });

  test('deleting a calendar takes its attachments, tasks, swaps and '
      'balances with it', () async {
    final (:schema, before: _, v3Columns: _, versions: _) = await seededV5();
    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 7);
    const day = CivilDate(2026, 10, 19);
    await db.customStatement(
      'INSERT INTO calendars (id, name, color_value, sort_order, archived, '
      "created_at, updated_at) VALUES ('tmp', 'Temporal', 1, 9, 0, 0, 0)",
    );
    await NoteAttachmentsRepository(db).save(
      NoteAttachment(
        id: 'att-tmp',
        calendarId: 'tmp',
        date: day,
        kind: AttachmentKind.sketch,
        relativePath: 'bb/${'b' * 64}',
        mimeType: 'image/png',
        sizeBytes: 1,
        sha256: 'b' * 64,
        createdAt: 1,
      ),
    );
    await DayTasksRepository(db).save(
      DayTask(
        id: 't',
        calendarId: 'tmp',
        date: day,
        title: 'x',
        createdAt: 1,
        updatedAt: 1,
      ),
    );
    await ShiftSwapsRepository(db).save(
      ShiftSwap(
        id: 's',
        calendarId: 'tmp',
        date: day,
        colleague: 'Ana',
        direction: SwapDirection.iOwe,
        createdAt: 1,
        updatedAt: 1,
      ),
    );
    await AbsenceBalancesRepository(db).save(
      const AbsenceBalance(
        year: 2026,
        type: 'tmp-vac',
        allowedDays: 1,
        calendarId: 'tmp',
      ),
    );
    await db.customStatement('PRAGMA foreign_keys = ON');
    await db.customStatement("DELETE FROM calendars WHERE id = 'tmp'");
    for (final table in [..._v6Tables, 'absence_balances']) {
      final n = await db
          .customSelect(
            "SELECT COUNT(*) AS n FROM $table WHERE calendar_id = 'tmp'",
          )
          .getSingle();
      expect(n.read<int>('n'), 0, reason: table);
    }
    // The legacy balances (no calendar) are still there.
    expect(await AbsenceBalancesRepository(db).list(), hasLength(4));
  });
}

NoteAttachment _copyAttachment(NoteAttachment a, {required String id}) =>
    NoteAttachment(
      id: id,
      calendarId: a.calendarId,
      date: a.date,
      kind: a.kind,
      relativePath: a.relativePath,
      mimeType: a.mimeType,
      sizeBytes: a.sizeBytes,
      sha256: a.sha256,
      createdAt: a.createdAt,
    );

extension on ShiftTerms {
  ShiftTerms copyWithPluses({required int night, required int holiday}) =>
      ShiftTerms(
        category: category,
        startMinute: startMinute,
        endMinute: endMinute,
        paidMinutes: paidMinutes,
        nightOverride: nightOverride,
        hourlyRateCents: hourlyRateCents,
        fixedPlusCents: fixedPlusCents,
        segment2StartMinute: segment2StartMinute,
        segment2DurationMinutes: segment2DurationMinutes,
        nightPlusCentsPerHour: night,
        holidayPlusCentsPerHour: holiday,
      );
}
