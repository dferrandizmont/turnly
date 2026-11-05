import 'dart:io';

import 'package:cuadrante/core/database/database_opener.dart';
import 'package:cuadrante/features/alarms/data/alarm_settings_repository.dart';
import 'package:cuadrante/features/alarms/domain/alarm_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

// The app's connection waits for a lock held by another connection (the
// background renewal of the alarms, docs/alarmas.md) instead of failing.

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('busy_timeout_');
    addTearDown(() => dir.deleteSync(recursive: true));
  });

  test('the app connection has a busy timeout of 3 s', () async {
    final db = await openAppDatabase(directory: dir);
    addTearDown(db.close);
    final row = await db.customSelect('PRAGMA busy_timeout').getSingle();
    expect(row.data.values.single, databaseBusyTimeout.inMilliseconds);
    expect(databaseBusyTimeout, const Duration(seconds: 3));
  });

  test(
    'a write that meets a reader holding the file waits for it and '
    'succeeds',
    () async {
      final db = await openAppDatabase(directory: dir);
      addTearDown(db.close);
      await db.customSelect('SELECT 1').get();

      // Another connection (like the background renewal) holds a read lock.
      final reader = sqlite3.open(
        p.join(dir.path, databaseFileName),
        mode: OpenMode.readOnly,
      );
      reader.execute('BEGIN');
      reader.select('SELECT COUNT(*) FROM settings');
      final released = Future<void>.delayed(
        const Duration(milliseconds: 300),
        () {
          reader.execute('COMMIT');
          reader.close();
        },
      );

      // Rollback journal: the write needs an exclusive lock, so it can only
      // commit after the reader lets go; with the timeout it waits.
      await AlarmSettingsRepository(db)
          .save(const AlarmSettings(enabled: true));
      await released;
      expect((await AlarmSettingsRepository(db).load()).enabled, isTrue);
    },
    // On Linux, flutter_tester's sampling profiler (SIGPROF, about every
    // millisecond) cuts SQLite's nanosleep short (EINTR), so the busy
    // handler runs out its retries in ~30 ms instead of waiting 3 s. That
    // is the test runner, not the phone (a release build has no profiler):
    // the wait is checked on Windows and macOS, the timeout itself above.
    skip: Platform.isLinux
        ? 'flutter_tester on Linux interrupts SQLite busy waits'
        : false,
  );
}
