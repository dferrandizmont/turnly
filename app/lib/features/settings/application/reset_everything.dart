import 'dart:async';

import '../../backup/domain/backup_store.dart';

class ResetBackupFailure implements Exception {
  const ResetBackupFailure(this.cause);
  final Object cause;
}

enum ResetCleanupStep {
  calendar,
  alarms,
  dnd,
  widget,
  attachments,
  background,
  exports,
  ics,
  images,
  shareLink,
  folderBackup,
  preferences,
  reload,
  resume,
}

class ResetCleanup {
  const ResetCleanup(this.step, this.run);
  final ResetCleanupStep step;
  final Future<void> Function() run;
}

/// The database transaction is the point of no return. Everything afterwards
/// is independent best effort; failure must never suggest that data survived.
class ResetEverything {
  ResetEverything({
    required this.runExclusive,
    required this.createBackup,
    required this.pause,
    required this.resume,
    required this.clearDatabase,
    required this.cleanup,
    required this.reload,
    this.verifyBackup,
    this.onError,
  });

  final Future<void> Function(Future<void> Function()) runExclusive;
  final Future<BackupEntry> Function() createBackup;
  final Future<void> Function(BackupEntry)? verifyBackup;
  final Future<void> Function() pause;
  final FutureOr<void> Function() resume;
  final Future<void> Function() clearDatabase;
  final List<ResetCleanup> cleanup;
  final Future<void> Function() reload;
  final void Function(Object error, StackTrace stack)? onError;
  final Set<ResetCleanupStep> cleanupFailures = {};
  bool _running = false;

  Future<BackupEntry> prepareBackup() async {
    late BackupEntry copy;
    await runExclusive(() async => copy = await createBackup());
    return copy;
  }

  Future<void> _bestEffort(ResetCleanup action) async {
    try {
      await action.run();
    } catch (error, stack) {
      cleanupFailures.add(action.step);
      try {
        onError?.call(error, stack);
      } catch (_) {
        // Diagnostics must never interrupt the remaining cleanup.
      }
    }
  }

  /// Pause/drain before taking the write queue: planners can themselves be
  /// waiting for that queue. A concurrent call must not pause or resume them.
  Future<bool> resetEverything({
    required Future<bool> Function(BackupEntry copy) confirm,
    BackupEntry? preparedBackup,
    void Function()? onDeleting,
  }) async {
    if (_running) return false;
    _running = true;
    cleanupFailures.clear();
    var deleted = false;
    try {
      await pause();
      await runExclusive(() async {
        late BackupEntry copy;
        try {
          var reusable = false;
          if (preparedBackup != null && verifyBackup != null) {
            try {
              await verifyBackup!(preparedBackup);
              reusable = true;
            } catch (_) {
              // Missing or unreadable: take a fresh verified copy before
              // asking for confirmation. Never delete without one.
            }
          }
          copy = reusable ? preparedBackup! : await createBackup();
        } catch (error) {
          throw ResetBackupFailure(error);
        }
        if (!await confirm(copy)) return;
        onDeleting?.call();
        await clearDatabase();
        deleted = true;
      });
      if (deleted) {
        for (final action in cleanup) {
          await _bestEffort(action);
        }
        await _bestEffort(ResetCleanup(ResetCleanupStep.reload, reload));
      }
      return deleted;
    } finally {
      try {
        if (deleted) {
          await _bestEffort(
            ResetCleanup(ResetCleanupStep.resume, () async => await resume()),
          );
        } else {
          await resume();
        }
      } finally {
        _running = false;
      }
    }
  }
}
