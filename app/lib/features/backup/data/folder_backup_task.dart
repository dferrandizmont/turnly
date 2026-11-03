import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:workmanager/workmanager.dart';

import '../../../core/background/background_tasks.dart';
import '../../../core/config.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_opener.dart'
    show backupsDirectoryName, databaseFileName;
import '../../../core/diagnostics/debug_log.dart';
import '../../alarms/data/alarm_foreground_relay.dart';
import '../../notes/data/attachment_store.dart';
import '../application/folder_backup_engine.dart';
import '../domain/backup_codec.dart';
import '../domain/backup_task_runner.dart';
import '../domain/folder_backup.dart';
import 'backup_repository.dart';
import 'folder_backup_channel.dart';
import 'folder_backup_state_store.dart';

/// Unique name (and task name) of the daily folder copy in WorkManager. It
/// shares the app's one dispatcher with the alarm renewal
/// ([backgroundTaskDispatcher], docs/copia-de-seguridad.md, section 11).
const String folderBackupTaskName = 'es.cuadrante.app.folderBackup';

/// How often Android runs the folder copy (WorkManager may run it later,
/// never more often). The run itself skips when the folder got a copy in the
/// last 20 h ([FolderBackupPolicy.dailyGap]).
const Duration folderBackupFrequency = Duration(hours: 24);

/// First wait after registering: a folder has just been chosen and copied.
const Duration folderBackupInitialDelay = Duration(hours: 1);

/// Wait before retrying a run that failed for a passing reason, exponential.
const Duration folderBackupBackoff = Duration(hours: 1);

/// How long the background connection waits for the app's write lock.
const Duration folderBackupBusyTimeout = Duration(seconds: 3);

/// Name under which the app listens for "do the folder copy yourself" while
/// it is alive in the same process (then the copy uses the app's own tools
/// and never runs twice at once).
const String folderBackupPortName = 'es.cuadrante.app/backup.folder';

/// Keeps the daily folder copy registered while there is a folder.
abstract interface class FolderBackupScheduling {
  Future<void> setEnabled(bool enabled);
}

/// No background folder copy (iOS, desktop, tests).
class NoFolderBackupScheduling implements FolderBackupScheduling {
  const NoFolderBackupScheduling();

  @override
  Future<void> setEnabled(bool enabled) async {}
}

/// Android: the daily folder copy in WorkManager.
///
/// Registering initializes the plugin with the **shared** dispatcher
/// [backgroundTaskDispatcher] (the alarm renewal does the same): WorkManager
/// keeps a single callback handle per app, so the last `initialize` wins and
/// both must pass the same function. The policy is `update`: an app start
/// keeps the task's timing. The battery-not-low constraint: a backup can wait
/// for the charger. No network requirement: the provider uploads on its own.
class WorkmanagerFolderBackup implements FolderBackupScheduling {
  WorkmanagerFolderBackup({Workmanager? workmanager})
    : _workmanager = workmanager ?? Workmanager();

  final Workmanager _workmanager;
  bool _initialized = false;
  bool? _enabled;

  @override
  Future<void> setEnabled(bool enabled) async {
    if (_enabled == enabled) return;
    if (enabled) {
      if (!_initialized) {
        await _workmanager.initialize(backgroundTaskDispatcher);
        _initialized = true;
      }
      await _workmanager.registerPeriodicTask(
        folderBackupTaskName,
        folderBackupTaskName,
        frequency: folderBackupFrequency,
        initialDelay: folderBackupInitialDelay,
        constraints: Constraints(
          networkType: NetworkType.notRequired,
          requiresBatteryNotLow: true,
        ),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
        backoffPolicy: BackoffPolicy.exponential,
        backoffPolicyDelay: folderBackupBackoff,
      );
    } else {
      await _workmanager.cancelByUniqueName(folderBackupTaskName);
    }
    _enabled = enabled;
  }
}

/// The background folder copy (Android, WorkManager), with every dependency
/// injectable for the tests. Returns what WorkManager is told: `false` only
/// for a passing failure worth a retry soon; a revoked permission or a folder
/// that is gone waits for the next day (the screen tells the user).
///
/// 1. If the app is alive in this process, it does the copy ([askApp]): it
///    answers at once and copies under the run lock.
/// 2. Otherwise, with no folder chosen, nothing.
/// 3. Otherwise a [FolderBackupEngine] over the platform channel (the plugin
///    is registered in this engine too) and a payload read from the database
///    opened **read-only**, only once the copy is due, and closed right after.
Future<bool> runFolderBackupTask({
  Future<bool> Function()? askApp,
  Future<Directory> Function()? supportDirectory,
  Future<AppDatabase?> Function(Directory support)? openDatabase,
  FolderBackupPlatform platform = const MethodChannelFolderBackupPlatform(),
  FolderRunLock? lock,
  DateTime Function() now = DateTime.now,
  String? appVersion,
}) async {
  try {
    final ask =
        askApp ?? () => askForegroundToResync(portName: folderBackupPortName);
    if (await ask()) {
      debugLog('Copia en carpeta: la hace la app');
      return true;
    }
    final support =
        await (supportDirectory ?? getApplicationSupportDirectory)();
    final states = FolderBackupStateStore(folderBackupStateFile(support));
    final open = openDatabase ?? openFolderBackupDatabase;
    final version = appVersion ?? _version(AppConfig.current.appVersion);
    final engine = FolderBackupEngine(
      platform: platform,
      states: states,
      now: now,
      // The same lock as the app's runs: if the app is copying (it did not
      // answer the relay, or is starting), this run is skipped.
      lock: lock ?? IsolateFolderRunLock(),
      onError: (error, _) => debugLogFailure('Copia en carpeta', error),
      payload: () async {
        final db = await open(support);
        if (db == null) return null;
        try {
          return await folderPayloadFrom(
            db,
            support: support,
            appVersion: version,
            at: now(),
          );
        } finally {
          await db.close();
        }
      },
    );
    final outcome = await engine.run(FolderBackupTrigger.daily);
    debugLog('Copia en carpeta en segundo plano: $outcome');
    return outcome.kind != FolderBackupOutcomeKind.failed ||
        outcome.problem != FolderProblem.failed;
  } catch (error) {
    debugLogFailure('Copia en carpeta', error);
    return false;
  }
}

String _version(String configured) => configured.isEmpty ? 'dev' : configured;

/// The current data of [db] as a folder payload: the same `.turnly` as a
/// manual export (everything, absences of health included: question 13 of
/// docs/preguntas.md, answered "leave it as it is"), decoded back once.
Future<FolderPayload> folderPayloadFrom(
  AppDatabase db, {
  required Directory support,
  required String appVersion,
  required DateTime at,
  BackupCodec codec = const BackupCodec(),
}) async {
  final repository = BackupRepository(
    db,
    safetyDirectory: Directory(p.join(support.path, backupsDirectoryName)),
    appVersion: appVersion,
    // The attachments of the notes travel with the data (the copy is a
    // container): a copy without the files of its rows is a broken one.
    attachmentStore: AttachmentStore(
      Directory(p.join(support.path, attachmentsDirectoryName)),
    ),
    runner: runOnThisIsolate,
    codec: codec,
  );
  final data = await repository.readAll();
  // Lenient: an attachment whose file is already lost is left out of the copy
  // (and reported) so the daily copy does not fail for it for ever.
  final encoding = await repository.encodeCurrent(data, at: at);
  final file = codec.decode(encoding.bytes);
  return FolderPayload(
    encoding.bytes,
    file.checksum,
    warnings: encoding.warnings,
  );
}

/// `<support>/folder_backup/state.json`.
File folderBackupStateFile(Directory support) =>
    File(p.join(support.path, folderBackupDirName, folderBackupStateFileName));

/// Opens the app's database for the background copy, **read-only** and
/// without Drift migrations, or returns null when it must not be read: no
/// file yet, or another schema version than this code's (an update the user
/// has not opened: its migration is only ever run by the app). Throws when
/// SQLite cannot open it (busy): the run fails and WorkManager retries.
Future<AppDatabase?> openFolderBackupDatabase(Directory support) async {
  final file = File(p.join(support.path, databaseFileName));
  if (!file.existsSync() || file.lengthSync() == 0) return null;
  final raw = sqlite3.open(file.path, mode: OpenMode.readOnly);
  try {
    raw.execute(
      'PRAGMA busy_timeout = ${folderBackupBusyTimeout.inMilliseconds}',
    );
    final version = raw.select('PRAGMA user_version').first.values.first;
    if (version != AppDatabase.latestSchemaVersion) {
      raw.close();
      return null;
    }
  } catch (_) {
    raw.close();
    rethrow;
  }
  return AppDatabase(NativeDatabase.opened(raw, enableMigrations: false));
}
