import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cuadrante/core/database/migration_backup.dart';
import 'package:cuadrante/features/backup/domain/backup_codec.dart';
import 'package:cuadrante/features/backup/domain/backup_data.dart';
import 'package:cuadrante/features/backup/domain/backup_warnings.dart';
import 'package:cuadrante/features/backup/domain/restore_summary.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:cuadrante/features/swaps/domain/shift_swap.dart';
import 'package:cuadrante/features/swaps/domain/swap_application.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../backup/backup_test_support.dart';

// QA M4: at most one applied swap per calendar and day, also for data the
// app did not write itself (a backup file), and the safety copies of a
// migration or a restore are never lost to pruning.

const _third = CivilDate(2026, 11, 3);
const _tenth = CivilDate(2026, 11, 10);
const _codec = BackupCodec();

BackupShiftSwap _swap(String id, int updatedAt) => BackupShiftSwap(
  id: id,
  calendarId: 'main',
  colleague: id,
  date: _third,
  direction: SwapDirection.theyOwe,
  createdAt: 1,
  updatedAt: updatedAt,
);

SwapApplicationRecord _record(String swapId, CivilDate date, int createdAt) =>
    SwapApplicationRecord(
      swapId: swapId,
      date: date,
      previousShiftTypeIds: const ['morning'],
      createdAt: createdAt,
      appliedOverride: (shiftTypeIds: const ['night']),
    );

Uint8List _envelope(int version, Map<String, Object?> data) => gzipEnvelope({
  'format': BackupCodec.formatName,
  'schemaVersion': version,
  'appVersion': testAppVersion,
  'exportedAt': '2026-11-10T00:00:00.000Z',
  'data': data,
  'checksum': BackupCodec.checksumOfJson(data),
});

/// A SQLite file at [path] with `user_version = [version]`.
void _sqlite(String path, int version, {String marker = 'x'}) {
  final db = sqlite3.open(path);
  db.execute('CREATE TABLE t (v TEXT)');
  db.execute('INSERT INTO t VALUES (?)', [marker]);
  db.execute('PRAGMA user_version = $version');
  db.close();
}

String _marker(File file) {
  final db = sqlite3.open(file.path, mode: OpenMode.readOnly);
  try {
    return db.select('SELECT v FROM t').single['v'] as String;
  } finally {
    db.close();
  }
}

void main() {
  test('restoring two swaps applied on one day keeps the first and recovers '
      'the other whole', () async {
    final dir = makeTempDir('swaps-overlap');
    final target = openMemoryDatabase();
    addTearDown(target.close);
    final repository = makeRepository(target, dir);
    final json = BackupData(
      shiftSwaps: [_swap('first', 2), _swap('second', 3)],
      swapApplications: [
        _record('first', _third, 2),
        _record('second', _third, 3),
        _record('second', _tenth, 3),
      ].map(BackupSwapApplication.new),
    ).toJson();
    final bytes = _envelope(5, json);

    expect(
      await repository.verifyRestore(bytes, today: _tenth),
      isA<VerificationIncomplete>(),
    );
    expect(await repository.restore(_codec.decode(bytes).data), [
      isA<SwapApplicationsSkipped>(),
    ]);

    final restored = await repository.readAll();
    expect(restored.swapApplications.map((entry) => entry.record.swapId), [
      'first',
    ]);
    final recovery = [
      for (final MapEntry(:key, :value) in restored.settings.entries)
        if (isSwapApplicationRecoveryKey(key)) jsonDecode(value),
    ];
    expect(recovery, hasLength(1));
    final dropped = (recovery.single as Map)['overlapping'] as List;
    expect(
      [for (final row in dropped) ((row as Map)['swapId'], row['date'])],
      [('second', '2026-11-03'), ('second', '2026-11-10')],
    );
  });

  test(
    'a migration copy goes above the highest suffix and is never pruned',
    () async {
      final dir = makeTempDir('migration-suffix');
      final backups = Directory(p.join(dir.path, 'backups'))..createSync();
      const stamp = '20261102-083015';
      // The original and three copies of the same second that cannot be
      // checked (another version than their name says): all are kept.
      for (final suffix in ['', '-3', '-4', '-5']) {
        _sqlite(p.join(backups.path, 'pre-v1-a-v3-$stamp$suffix.sqlite'), 9);
      }
      final database = File(p.join(dir.path, 'cuadrante.sqlite'));
      _sqlite(database.path, 1, marker: 'live v1');

      final copy = (await backupBeforeMigration(
        databaseFile: database,
        targetVersion: 3,
        backupsDirectory: backups,
        now: () => DateTime.utc(2026, 11, 2, 8, 30, 15),
      ))!;

      expect(p.basename(copy.path), 'pre-v1-a-v3-$stamp-6.sqlite');
      expect(copy.existsSync(), isTrue);
      expect(_marker(copy), 'live v1');
      expect(
        File(p.join(backups.path, 'pre-v1-a-v3-$stamp.sqlite')).existsSync(),
        isTrue,
      );
    },
  );

  test('the pre-restore copy survives copies dated later', () async {
    final dir = makeTempDir('restore-safety');
    final target = openMemoryDatabase();
    addTearDown(target.close);
    // The clock was set back: three copies are dated after "now".
    for (final suffix in ['', '-2', '-3']) {
      File(p.join(dir.path, 'pre-restore-20270101-000000$suffix.turnly'))
          .writeAsStringSync('later');
    }
    final repository = makeRepository(target, dir);
    await repository.restore(BackupData());

    expect(
      File(p.join(dir.path, 'pre-restore-20261110-090000.turnly')).existsSync(),
      isTrue,
    );
  });
}
