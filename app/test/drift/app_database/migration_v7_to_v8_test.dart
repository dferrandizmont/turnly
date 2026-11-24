import 'dart:convert';
import 'dart:io';

import 'package:cuadrante/core/database/database_opener.dart';
import 'package:cuadrante/core/database/migration_backup.dart';
import 'package:cuadrante/features/swaps/domain/swap_application.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../../support/test_storage.dart';
import 'generated/schema_v7.dart';

void main() {
  test(
    'v7 applications migrate after a complete on-disk safety copy',
    () async {
      final dir = makeTempDir('swap-migration');
      final file = File(p.join(dir.path, databaseFileName));
      final old = DatabaseAtV7(NativeDatabase(file));
      await old.customStatement("""
      INSERT INTO calendars (id, name, color_value, sort_order, created_at, updated_at)
      VALUES ('main', 'My schedule', 0, 0, 1, 1)
    """);
      for (final id in ['applied', 'malformed']) {
        await old.customStatement(
          """
        INSERT INTO shift_swaps (id, calendar_id, date, colleague, direction, created_at, updated_at)
        VALUES (?, 'main', '2026-11-02', 'Marta', 'theyOwe', 2, 3)
      """,
          [id],
        );
      }
      await old.customStatement("""
      INSERT INTO day_entries (calendar_id, date, shift_type_ids, note, updated_at)
      VALUES ('main', '2026-11-02', '[]', 'Keep this note', 4)
    """);
      final legacy = jsonEncode({
        'applied': {
          '2026-11-02': null,
          '2026-11-03': [],
          '2026-11-04': ['morning', 'night'],
        },
        'malformed': {
          '2026-11-02': ['morning'],
          '2026-11-03': ['night', 1],
        },
        'orphan': {'2026-11-02': null},
      });
      await old.customStatement(
        "INSERT INTO settings (key, value) VALUES ('swaps.applied', ?), ('other', 'true')",
        [legacy],
      );
      await old.customStatement("""
        CREATE TRIGGER fail_move BEFORE DELETE ON settings
        WHEN OLD.key = 'swaps.applied'
        BEGIN SELECT RAISE(ABORT, 'test failure'); END
      """);
      await old.close();
      expect(readUserVersion(file), 7);

      final failing = await openAppDatabase(
        directory: dir,
        now: () => DateTime.utc(2026, 11, 23),
      );
      try {
        await expectLater(
          failing.customSelect('SELECT 1').get(),
          throwsA(
            isA<Exception>().having(
              (error) => error.toString(),
              'message',
              contains('test failure'),
            ),
          ),
        );
      } finally {
        await failing.close();
      }
      expect(readUserVersion(file), 7);
      final v7 = sqlite3.open(file.path);
      try {
        expect(
          v7
              .select("SELECT value FROM settings WHERE key = 'swaps.applied'")
              .single['value'],
          legacy,
        );
        expect(
          v7.select(
            "SELECT name FROM sqlite_master WHERE name = 'swap_applications'",
          ),
          isEmpty,
        );
        expect(
          v7.select(
            "SELECT key FROM settings WHERE key LIKE 'swaps.applied.%'",
          ),
          isEmpty,
        );
        v7.execute('DROP TRIGGER fail_move');
      } finally {
        v7.close();
      }

      final db = await openAppDatabase(
        directory: dir,
        now: () => DateTime.utc(2026, 11, 24),
      );
      final rows = await db.select(db.swapApplications).get();
      expect(rows, hasLength(3));
      expect(rows.map((row) => row.swapId), everyElement('applied'));
      expect(rows.map((row) => row.createdAt), everyElement(3));
      expect(rows.map((row) => row.appliedOverride), everyElement(isNull));
      expect(
        {for (final row in rows) row.date.toIso(): row.previousShiftTypeIds},
        {
          '2026-11-02': null,
          '2026-11-03': [],
          '2026-11-04': ['morning', 'night'],
        },
      );
      final settings = {
        for (final row in await db.select(db.settings).get())
          row.key: row.value,
      };
      expect(
        settings.keys,
        unorderedEquals(['other', swapApplicationRecoveryKey]),
      );
      expect(jsonDecode(settings[swapApplicationRecoveryKey]!), {
        'malformed': {
          '2026-11-02': ['morning'],
          '2026-11-03': ['night', 1],
        },
        'orphan': {'2026-11-02': null},
      });
      expect(
        (await db.select(db.dayEntries).get()).single.note,
        'Keep this note',
      );
      expect(await db.select(db.shiftSwaps).get(), hasLength(2));
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
      await db.close();
      expect(readUserVersion(file), 8);

      final reopened = await openAppDatabase(
        directory: dir,
        now: () => DateTime.utc(2026, 11, 25),
      );
      addTearDown(reopened.close);
      expect(
        (await reopened.select(reopened.swapApplications).get()).map(
          (row) => row.toJson(),
        ),
        unorderedEquals(rows.map((row) => row.toJson())),
      );
      expect({
        for (final row in await reopened.select(reopened.settings).get())
          row.key: row.value,
      }, settings);

      final backup = File(
        p.join(
          dir.path,
          backupsDirectoryName,
          'pre-v7-a-v8-20261123-000000.sqlite',
        ),
      );
      expect(readUserVersion(backup), 7);
      expect(await backup.parent.list().map((file) => file.path).toList(), [
        backup.path,
      ]);
      final raw = sqlite3.open(backup.path, mode: OpenMode.readOnly);
      addTearDown(raw.close);
      expect(
        raw
            .select("SELECT value FROM settings WHERE key = 'swaps.applied'")
            .single['value'],
        legacy,
      );
      expect(
        raw.select(
          "SELECT name FROM sqlite_master WHERE name = 'swap_applications'",
        ),
        isEmpty,
      );
    },
  );

  test('v7 swaps that share a day: the first stays, the rest goes to '
      'recovery whole', () async {
    final dir = makeTempDir('swap-migration-overlap');
    final file = File(p.join(dir.path, databaseFileName));
    final old = DatabaseAtV7(NativeDatabase(file));
    await old.customStatement("""
      INSERT INTO calendars (id, name, color_value, sort_order, created_at, updated_at)
      VALUES ('main', 'My schedule', 0, 0, 1, 1), ('work', 'Work', 0, 1, 1, 1)
    """);
    for (final (id, calendar, updatedAt) in [
      ('first', 'main', 3),
      ('second', 'main', 5),
      ('elsewhere', 'work', 4),
    ]) {
      await old.customStatement(
        """
        INSERT INTO shift_swaps (id, calendar_id, date, colleague, direction, created_at, updated_at)
        VALUES (?, ?, '2026-11-02', 'Marta', 'theyOwe', 2, ?)
      """,
        [id, calendar, updatedAt],
      );
    }
    final legacy = jsonEncode({
      'second': {
        '2026-11-02': ['night'],
        '2026-11-05': null,
      },
      'first': {
        '2026-11-02': ['morning'],
      },
      // Another calendar may use the same day.
      'elsewhere': {'2026-11-02': null},
    });
    await old.customStatement(
      "INSERT INTO settings (key, value) VALUES ('swaps.applied', ?)",
      [legacy],
    );
    await old.close();

    final db = await openAppDatabase(directory: dir);
    addTearDown(db.close);
    final rows = await db.select(db.swapApplications).get();
    expect(
      {for (final row in rows) (row.swapId, row.calendarId, row.date.toIso())},
      {('first', 'main', '2026-11-02'), ('elsewhere', 'work', '2026-11-02')},
    );
    final settings = {
      for (final row in await db.select(db.settings).get()) row.key: row.value,
    };
    expect(settings.keys, [swapApplicationRecoveryKey]);
    final dropped =
        (jsonDecode(settings[swapApplicationRecoveryKey]!)
                as Map)['overlapping']
            as List;
    expect(
      [for (final row in dropped) ((row as Map)['swapId'], row['date'])],
      [('second', '2026-11-02'), ('second', '2026-11-05')],
    );
    await expectLater(
      db.customStatement(
        'INSERT INTO swap_applications (swap_id, calendar_id, date, created_at) '
        "VALUES ('second', 'main', '2026-11-02', 9)",
      ),
      throwsA(isA<Exception>()),
    );
  });

  for (final raw in [null, '{"unreadable":']) {
    test(
      'v7 distinguishes an absent setting from unreadable JSON ($raw)',
      () async {
        final dir = makeTempDir('swap-migration-setting');
        final file = File(p.join(dir.path, databaseFileName));
        final old = DatabaseAtV7(NativeDatabase(file));
        await old.customSelect('SELECT 1').get();
        if (raw != null) {
          await old.customStatement(
            'INSERT INTO settings (key, value) VALUES (?, ?)',
            [legacySwapApplicationsKey, raw],
          );
        }
        await old.close();

        final db = await openAppDatabase(directory: dir);
        addTearDown(db.close);
        expect(await db.select(db.swapApplications).get(), isEmpty);
        expect(
          {
            for (final row in await db.select(db.settings).get())
              row.key: row.value,
          },
          {swapApplicationRecoveryKey: ?raw},
        );
      },
    );
  }
}
