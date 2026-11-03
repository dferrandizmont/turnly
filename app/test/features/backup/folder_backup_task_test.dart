import 'dart:io';

import 'package:cuadrante/core/background/background_tasks.dart';
import 'package:cuadrante/core/background/isolate_mutex.dart';
import 'package:cuadrante/core/database/app_database.dart';
import 'package:cuadrante/core/database/database_opener.dart';
import 'package:cuadrante/features/alarms/data/alarm_renewal_task.dart';
import 'package:cuadrante/features/backup/application/folder_backup_engine.dart';
import 'package:cuadrante/features/backup/data/folder_backup_state_store.dart';
import 'package:cuadrante/features/backup/data/folder_backup_task.dart';
import 'package:cuadrante/features/backup/domain/backup_codec.dart';
import 'package:cuadrante/features/backup/domain/folder_backup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:workmanager/workmanager.dart';

import '../../support/test_storage.dart';
import 'folder_backup_support.dart';

// P10: the daily folder copy in the background, its WorkManager registration
// and the dispatcher it shares with the alarm renewal.

const _lockName = 'test/folder-task-lock';

void main() {
  group('the shared dispatcher', () {
    test('both tasks are routed by their own name', () {
      final tasks = appBackgroundTasks();
      expect(
        tasks.keys,
        containsAll([alarmRenewalTaskName, folderBackupTaskName]),
      );
      expect(alarmRenewalTaskName, isNot(folderBackupTaskName));
      expect(tasks[alarmRenewalTaskName], same(runAlarmRenewalTask));
      expect(tasks[folderBackupTaskName], same(runFolderBackupTask));
    });

    test('each name runs only its task', () async {
      final ran = <String>[];
      final tasks = <String, BackgroundTask>{
        alarmRenewalTaskName: () async {
          ran.add('alarms');
          return true;
        },
        folderBackupTaskName: () async {
          ran.add('folder');
          return false;
        },
      };
      expect(await runBackgroundTask(alarmRenewalTaskName, tasks), isTrue);
      expect(await runBackgroundTask(folderBackupTaskName, tasks), isFalse);
      expect(ran, ['alarms', 'folder']);
    });

    test('an unknown task is done; a task that throws is retried', () async {
      expect(await runBackgroundTask('es.cuadrante.app.old', const {}), isTrue);
      expect(
        await runBackgroundTask('t', {'t': () async => throw StateError('x')}),
        isFalse,
      );
    });

    test(
      'alarms and folder copy initialize with the same dispatcher',
      () async {
        final alarms = _FakeWorkmanager();
        await WorkmanagerAlarmRenewal(workmanager: alarms).setEnabled(true);
        final folder = _FakeWorkmanager();
        await WorkmanagerFolderBackup(workmanager: folder).setEnabled(true);
        expect(alarms.dispatchers.single, same(backgroundTaskDispatcher));
        expect(folder.dispatchers.single, same(backgroundTaskDispatcher));
      },
    );
  });

  group('WorkmanagerFolderBackup', () {
    test('registers the daily task once and cancels it when off', () async {
      final fake = _FakeWorkmanager();
      final scheduler = WorkmanagerFolderBackup(workmanager: fake);
      await scheduler.setEnabled(true);
      await scheduler.setEnabled(true);
      expect(fake.dispatchers, hasLength(1));
      final call = fake.registered.single;
      expect(call.name, folderBackupTaskName);
      expect(call.frequency, const Duration(hours: 24));
      expect(call.constraints?.networkType, NetworkType.notRequired);
      expect(call.constraints?.requiresBatteryNotLow, isTrue);
      expect(call.policy, ExistingPeriodicWorkPolicy.update);

      await scheduler.setEnabled(false);
      expect(fake.cancelled, [folderBackupTaskName]);
      await scheduler.setEnabled(true);
      expect(fake.registered, hasLength(2));
      expect(fake.dispatchers, hasLength(1));
    });

    test('cancelling does not initialize the plugin', () async {
      final fake = _FakeWorkmanager();
      await WorkmanagerFolderBackup(workmanager: fake).setEnabled(false);
      expect(fake.dispatchers, isEmpty);
      expect(fake.cancelled, [folderBackupTaskName]);
    });

    test('a failed registration is tried again', () async {
      final fake = _FakeWorkmanager()..failRegister = true;
      final scheduler = WorkmanagerFolderBackup(workmanager: fake);
      await expectLater(scheduler.setEnabled(true), throwsStateError);
      fake.failRegister = false;
      await scheduler.setEnabled(true);
      expect(fake.registered, hasLength(1));
    });
  });

  group('runFolderBackupTask', () {
    late Directory support;
    late FakeFolderPlatform folder;
    late FolderBackupStateStore states;
    final now = DateTime.utc(2026, 10, 31, 3);

    setUp(() {
      support = makeTempDir('folder-task');
      folder = FakeFolderPlatform();
      states = FolderBackupStateStore(folderBackupStateFile(support));
    });

    Future<void> createDatabase() async {
      final db = await openAppDatabase(directory: support);
      await db.customSelect('SELECT 1').get();
      await db.close();
    }

    Future<bool> run({bool appAnswers = false}) => runFolderBackupTask(
      askApp: () async => appAnswers,
      supportDirectory: () async => support,
      platform: folder,
      now: () => now,
      appVersion: 'test',
      lock: IsolateFolderRunLock(mutex: IsolateMutex(_lockName)),
    );

    test('the app alive in this process does it: nothing here', () async {
      await states.save(const FolderBackupState().withFolder(folder.uri, 'C'));
      expect(await run(appAnswers: true), isTrue);
      expect(folder.checks, 0);
    });

    test('the app copying right now (lock held): skipped, done', () async {
      await createDatabase();
      await states.save(const FolderBackupState().withFolder(folder.uri, 'C'));
      final app = IsolateMutex(_lockName);
      expect(await app.tryAcquire(), isTrue);
      addTearDown(app.release);
      expect(await run(), isTrue);
      expect(folder.checks, 0);
      expect(folder.docs, isEmpty);
    });

    test('the state lives in its own folder, out of the system backup', () {
      expect(
        p.relative(folderBackupStateFile(support).path, from: support.path),
        p.join('folder_backup', 'state.json'),
      );
    });

    test('no folder: done, nothing touched', () async {
      expect(await run(), isTrue);
      expect(folder.checks, 0);
    });

    test('writes a good .turnly of the database, opened read-only', () async {
      await createDatabase();
      final dbFile = File(p.join(support.path, databaseFileName));
      final before = dbFile.readAsBytesSync();
      await states.save(const FolderBackupState().withFolder(folder.uri, 'C'));
      expect(await run(), isTrue);
      final doc = folder.docs.values.single;
      expect(isFolderBackupName(doc.name), isTrue);
      final file = const BackupCodec().decode(doc.bytes);
      expect(file.appVersion, 'test');
      final state = await states.load();
      expect(state.lastChecksum, file.checksum);
      expect(state.lastSuccessAt, now);
      expect(dbFile.readAsBytesSync(), before, reason: 'never written');
    });

    test('a database on another schema version is skipped', () async {
      final file = File(p.join(support.path, databaseFileName));
      final raw = sqlite3.open(file.path);
      raw.execute(
        'PRAGMA user_version = ${AppDatabase.latestSchemaVersion - 1}',
      );
      raw.close();
      await states.save(const FolderBackupState().withFolder(folder.uri, 'C'));
      expect(await run(), isTrue);
      expect(folder.docs, isEmpty);
      expect((await states.load()).lastProblem, isNull);
    });

    test('revoked permission: recorded, not retried soon', () async {
      await createDatabase();
      await states.save(const FolderBackupState().withFolder(folder.uri, 'C'));
      folder.revoked = true;
      expect(await run(), isTrue);
      expect((await states.load()).lastProblem, FolderProblem.revoked);
    });

    test('a passing failure asks WorkManager to retry', () async {
      await createDatabase();
      await states.save(const FolderBackupState().withFolder(folder.uri, 'C'));
      folder.corruptReads = true;
      expect(await run(), isFalse);
      expect((await states.load()).lastProblem, FolderProblem.failed);
    });
  });
}

class _Registration {
  _Registration(this.name, this.frequency, this.constraints, this.policy);
  final String name;
  final Duration? frequency;
  final Constraints? constraints;
  final ExistingPeriodicWorkPolicy? policy;
}

class _FakeWorkmanager implements Workmanager {
  bool failRegister = false;
  final List<Function> dispatchers = [];
  final List<_Registration> registered = [];
  final List<String> cancelled = [];

  @override
  Future<void> initialize(
    Function callbackDispatcher, {
    bool isInDebugMode = false,
  }) async => dispatchers.add(callbackDispatcher);

  @override
  Future<void> registerPeriodicTask(
    String uniqueName,
    String taskName, {
    Duration? frequency,
    Duration? flexInterval,
    Map<String, dynamic>? inputData,
    Duration? initialDelay,
    Constraints? constraints,
    ExistingPeriodicWorkPolicy? existingWorkPolicy,
    BackoffPolicy? backoffPolicy,
    Duration? backoffPolicyDelay,
    String? tag,
    ForegroundServiceConfig? foregroundServiceConfig,
  }) async {
    if (failRegister) throw StateError('WorkManager');
    registered.add(
      _Registration(uniqueName, frequency, constraints, existingWorkPolicy),
    );
  }

  @override
  Future<void> cancelByUniqueName(String uniqueName) async =>
      cancelled.add(uniqueName);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
