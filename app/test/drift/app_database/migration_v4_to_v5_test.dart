import 'package:cuadrante/core/database/app_database.dart';
import 'package:cuadrante/core/database/app_database.steps.dart';
import 'package:cuadrante/core/database/migration_v1_to_v2.dart';
import 'package:cuadrante/core/database/migration_v2_to_v3.dart';
import 'package:cuadrante/core/database/migration_v3_to_v4.dart';
import 'package:cuadrante/core/database/migration_v4_to_v5.dart';
import 'package:cuadrante/core/database/migration_v5_to_v6.dart';
import 'package:cuadrante/features/schedule/data/schedule_repository.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/v2_database.dart';
import '../../support/v3_database.dart';
import 'generated/schema.dart';
import 'generated/schema_v3.dart' as v3;

/// Opens a file at v4 exactly (the real chain up to v4), so the v4 -> v5
/// step can be tested on its own with real data.
class _AtV4 extends AppDatabase {
  _AtV4(super.e);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: stepByStep(
      from1To2: migrateFrom1To2,
      from2To3: migrateFrom2To3,
      from3To4: migrateFrom3To4,
      from4To5: (m, schema) async => throw StateError('not this far'),
      from5To6: (m, schema) async => throw StateError('not this far'),
    ),
  );
}

class _FailingV5 extends AppDatabase {
  _FailingV5(super.e);

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: stepByStep(
      from1To2: migrateFrom1To2,
      from2To3: migrateFrom2To3,
      from3To4: migrateFrom3To4,
      from4To5: (m, schema) => migrateFrom4To5(
        m,
        schema,
        afterCreate: () async => throw StateError('boom after the table'),
      ),
      from5To6: migrateFrom5To6,
    ),
  );
}

const _tables = [
  'calendars',
  'shift_types',
  'patterns',
  'pattern_runs',
  'day_entries',
  'holidays',
  'absence_balances',
  'settings',
];

/// Columns added after v5 (schema v6), left out so the v4/v5 rows compare
/// the same whatever the file has been migrated to.
const _laterColumns = {
  'shift_types': {
    'location',
    'night_plus_cents_per_hour',
    'holiday_plus_cents_per_hour',
  },
  'day_entries': {'extra_amount_cents'},
  'absence_balances': {
    'calendar_id',
    'name',
    'period_start',
    'period_end',
    'unit',
    'shift_type_quarters',
    'carry_over',
    'carry_over_max_days',
    'adjustment_days',
    'sort_order',
    'created_at',
    'updated_at',
  },
};

Future<Map<String, List<Map<String, Object?>>>> _dumpAll(
  GeneratedDatabase db,
) async => {
  for (final table in _tables)
    table: [
      for (final row
          in await db.customSelect('SELECT * FROM $table ORDER BY rowid').get())
        {
          for (final e in row.data.entries)
            if (!(_laterColumns[table]?.contains(e.key) ?? false))
              e.key: e.value,
        },
    ],
};

List<String> _tableNames(InitializedSchema schema) => [
  for (final row in schema.rawDatabase.select(
    "SELECT name FROM sqlite_master WHERE type = 'table'",
  ))
    row['name'] as String,
];

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;
  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  /// A real v4 file: the v3 install of the other tests, migrated to v4 and
  /// with a fixed plus (the v4 field) on two types.
  Future<
    ({
      InitializedSchema schema,
      Map<String, List<Map<String, Object?>>> before,
      Map<String, List<Map<String, Object?>>> v3Columns,
    })
  >
  seededV4() async {
    final schema = await verifier.schemaAt(3);
    addTearDown(schema.rawDatabase.close);
    final old = v3.DatabaseAtV3(schema.newConnection());
    await seedV3(old);
    final v3Columns = await dumpV3Columns(old);
    await old.close();
    final atV4 = _AtV4(schema.newConnection());
    await atV4.customStatement(
      "UPDATE shift_types SET fixed_plus_cents = 2500 WHERE id = 'night'",
    );
    await atV4.customStatement(
      "UPDATE shift_types SET fixed_plus_cents = 0 WHERE id = 'morning'",
    );
    final before = await _dumpAll(atV4);
    await atV4.close();
    expect(
      schema.rawDatabase.select('PRAGMA user_version').single.values.single,
      4,
    );
    return (schema: schema, before: before, v3Columns: v3Columns);
  }

  test('v4 to v5 keeps every row and value, adds an empty table and the '
      '730 days of every calendar resolve as before', () async {
    final (:schema, :before, :v3Columns) = await seededV4();
    expect(_tableNames(schema), isNot(contains('shift_type_versions')));
    expect(before['calendars'], hasLength(3));
    expect(
      before['shift_types']!.where((r) => r['fixed_plus_cents'] != null),
      hasLength(2),
    );
    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 6);
    expect(await _dumpAll(db), before);
    expect(await db.select(db.shiftTypeVersions).get(), isEmpty);
    for (final id in ['main', 'pareja', 'viejo']) {
      final loaded = await ScheduleRepository(db).load(id);
      final prior = scheduleFromV3Rows(v3Columns, id);
      expect(
        v2ResolvedDays(loaded.schedule),
        v2ResolvedDays(prior),
        reason: id,
      );
      expect(loaded.schedule.shiftTypeVersions, isEmpty);
    }
    expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    expect(
      schema.rawDatabase.select('PRAGMA user_version').single.values.single,
      6,
    );
  });

  test('a failure rolls back to the untouched v4 file; the next start '
      'migrates', () async {
    final (:schema, :before, v3Columns: _) = await seededV4();
    final failing = _FailingV5(schema.newConnection());
    await expectLater(
      failing.customSelect('SELECT 1').get(),
      throwsA(isA<StateError>()),
    );
    await failing.close();
    expect(
      schema.rawDatabase.select('PRAGMA user_version').single.values.single,
      4,
    );
    expect(_tableNames(schema), isNot(contains('shift_type_versions')));
    final retried = AppDatabase(schema.newConnection());
    addTearDown(retried.close);
    await verifier.migrateAndValidate(retried, 6);
    expect(await _dumpAll(retried), before);
  });

  test('after migrating, versions are written, read, checked and go with '
      'their type', () async {
    final (:schema, before: _, v3Columns: _) = await seededV4();
    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 6);
    final repo = ScheduleRepository(db);
    final night = (await repo.load('main')).schedule.shiftTypeById('night')!;
    final history = [
      ShiftTypeVersion(
        until: const CivilDate(2026, 10, 31),
        terms: ShiftTerms.of(night),
      ),
    ];
    final longer = night.copyWith(endMinute: 8 * 60, hourlyRateCents: 1500);
    await repo.saveShiftTypeWithHistory(longer, history);
    for (final id in ['main', 'pareja']) {
      final loaded = (await repo.load(id)).schedule;
      expect(loaded.versionsOf('night'), history, reason: id);
      expect(loaded.shiftTypeById('night'), longer, reason: id);
    }
    // The CHECKs are those of shift_types.
    for (final sql in [
      "UPDATE shift_type_versions SET start_minute = NULL WHERE shift_type_id = 'night'",
      "UPDATE shift_type_versions SET hourly_rate_cents = -1 WHERE shift_type_id = 'night'",
      "UPDATE shift_type_versions SET shift_type_id = 'ghost' WHERE shift_type_id = 'night'",
    ]) {
      await expectLater(
        db.customStatement(sql),
        throwsA(anything),
        reason: sql,
      );
    }
  });
}
