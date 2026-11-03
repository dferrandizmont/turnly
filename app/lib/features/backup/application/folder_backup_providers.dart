import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/diagnostics/crash_reporting.dart' show redactError;
import '../../../core/providers.dart';
import '../../alarms/data/alarm_foreground_relay.dart';
import '../../schedule/domain/civil_date.dart';
import '../data/folder_backup_channel.dart';
import '../data/folder_backup_state_store.dart';
import '../data/folder_backup_task.dart';
import '../domain/backup_errors.dart';
import '../domain/folder_backup.dart';
import '../domain/restore_summary.dart';
import 'auto_backup_runner.dart';
import 'backup_providers.dart';
import 'folder_backup_engine.dart';

// The automatic copy to a folder (P10, docs/copia-de-seguridad.md, section
// 11). Android only for now; on iOS everything here is inert and the block is
// not shown (iCloud Drive is done on the Mac).

/// Whether this phone can copy to a folder (Android). Tests override it.
final folderBackupSupportedProvider = Provider<bool>(
  (ref) => Platform.isAndroid,
);

/// The folder on the platform. Tests override it with a fake.
final folderBackupPlatformProvider = Provider<FolderBackupPlatform>(
  (ref) => const MethodChannelFolderBackupPlatform(),
);

/// `<Application Support>/folder_backup/state.json`. Tests override it.
final folderBackupStateFileProvider = FutureProvider<File>((ref) async {
  final support = await getApplicationSupportDirectory();
  return folderBackupStateFile(support);
});

/// The run lock shared with the background task (an `IsolateMutex`). Widget
/// tests override it with [NoFolderRunLock].
final folderBackupRunLockProvider = Provider<FolderRunLock>(
  (ref) => IsolateFolderRunLock(),
);

/// The timing and the rotation. Tests override it.
final folderBackupPolicyProvider = Provider<FolderBackupPolicy>(
  (ref) => const FolderBackupPolicy(),
);

/// The daily background copy (WorkManager on Android). Tests override it.
final folderBackupSchedulerProvider = Provider<FolderBackupScheduling>(
  (ref) => ref.watch(folderBackupSupportedProvider)
      ? WorkmanagerFolderBackup()
      : const NoFolderBackupScheduling(),
);

/// The relay through which the background task hands the copy to the app
/// when the app is alive in the same process. Tests override it.
final folderBackupRelayProvider = Provider<AlarmForegroundRelay>(
  // Answers at once: the background side never waits for (nor times out on)
  // the app's copy, which runs under the run lock afterwards.
  (ref) =>
      AlarmForegroundRelay(portName: folderBackupPortName, answerFirst: true),
);

/// The one engine of the app: every foreground run goes through it, so runs
/// never overlap ("Copiar ahora" during a copy after changes waits for it).
final folderBackupEngineProvider = FutureProvider<FolderBackupEngine>((
  ref,
) async {
  final file = await ref.watch(folderBackupStateFileProvider.future);
  final reporter = ref.watch(crashReporterProvider);
  return FolderBackupEngine(
    platform: ref.watch(folderBackupPlatformProvider),
    states: FolderBackupStateStore(file),
    now: ref.watch(clockProvider),
    policy: ref.watch(folderBackupPolicyProvider),
    lock: ref.watch(folderBackupRunLockProvider),
    onError: (error, stack) => unawaited(
      reporter
          .record(redactError(error), stack, fatal: false)
          .catchError((_) {}),
    ),
    payload: () async {
      // The same file as "Exportar archivo": encoded in an isolate and read
      // back before it goes anywhere.
      final tools = await ref.read(backupToolsProvider.future);
      // Lenient: an attachment whose file is already lost is left out (and
      // reported) so the copy to the folder does not stop for it.
      final encoding = await tools.service.exportDetailed();
      final decoded = await tools.service.decodeFile(
        encoding.bytes,
        codec: tools.codec,
      );
      return FolderPayload(
        encoding.bytes,
        decoded.checksum,
        warnings: encoding.warnings,
      );
    },
  );
});

/// What the block on the backup screen shows.
class FolderBackupView {
  const FolderBackupView({
    this.supported = false,
    this.state = const FolderBackupState(),
    this.access,
  });

  /// Whether this phone has the folder copy at all.
  final bool supported;
  final FolderBackupState state;

  /// How the folder is right now, asked when the block opens; `null` with no
  /// folder or when it could not be asked.
  final FolderAccess? access;

  /// What to warn about: the folder's state now (permission revoked, folder
  /// gone) first, then the failure of the newest attempt.
  FolderProblem? get problem {
    if (state.damaged) return FolderProblem.damaged;
    if (!state.configured) return null;
    return access?.problem ?? state.lastProblem;
  }
}

/// The folder copy for the screen: its state and what the user can do.
class FolderBackupController extends AsyncNotifier<FolderBackupView> {
  @override
  Future<FolderBackupView> build() async {
    if (!ref.watch(folderBackupSupportedProvider)) {
      return const FolderBackupView();
    }
    final states = await _states();
    final state = await states.load();
    FolderAccess? access;
    final uri = state.uri;
    if (uri != null) {
      try {
        access = (await ref.read(folderBackupPlatformProvider).check(uri))
            .access;
      } on FolderBackupException {
        access = null;
      }
    }
    return FolderBackupView(supported: true, state: state, access: access);
  }

  Future<FolderBackupStateStore> _states() async => FolderBackupStateStore(
    await ref.read(folderBackupStateFileProvider.future),
  );

  Future<FolderBackupEngine> get _engine =>
      ref.read(folderBackupEngineProvider.future);

  /// Asks the folder and the state file again.
  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  /// "Elegir carpeta": the system picker; with a folder, it is kept (the old
  /// one's permission given back), the daily copy is registered and a first
  /// copy is made. `null` when the user went back; otherwise how the first
  /// copy went. Throws a [FolderBackupException] when the picker failed.
  Future<FolderBackupOutcome?> choose() async {
    final platform = ref.read(folderBackupPlatformProvider);
    final picked = await platform.pick();
    if (picked == null) return null;
    final states = await _states();
    final engine = await _engine;
    final old = await engine.locked(() async {
      String? old;
      await states.update((s) {
        old = s.uri;
        return s.withFolder(picked.uri, picked.name);
      });
      return old;
    });
    if (old != null && old != picked.uri) await platform.release(old);
    await _schedule(true);
    final outcome = await engine.run(FolderBackupTrigger.manual);
    await refresh();
    return outcome;
  }

  /// "Copiar ahora en la carpeta".
  Future<FolderBackupOutcome> backupNow() async {
    final outcome = await (await _engine).run(FolderBackupTrigger.manual);
    await refresh();
    return outcome;
  }

  /// "Dejar de copiar en esta carpeta": forgets the folder, gives its
  /// permission back and stops the daily copy. The copies already in the
  /// folder stay there.
  Future<void> stop() async {
    final states = await _states();
    final uri = await (await _engine).locked(() async {
      final uri = (await states.load()).uri;
      await states.save(const FolderBackupState());
      return uri;
    });
    if (uri != null) {
      await ref.read(folderBackupPlatformProvider).release(uri);
    }
    await _schedule(false);
    await refresh();
  }

  Future<void> _schedule(bool enabled) async {
    try {
      await ref.read(folderBackupSchedulerProvider).setEnabled(enabled);
    } catch (error, stack) {
      // The foreground copies still work; the next app start tries again.
      unawaited(
        ref
            .read(crashReporterProvider)
            .record(redactError(error), stack, fatal: false)
            .catchError((_) {}),
      );
    }
  }

  /// "Probar restauración" of the copy this app wrote last (by its document
  /// id; the newest own copy by name, dates in the future left out, when that
  /// one is gone): read, decoded in an isolate (the folder is outside the app:
  /// anybody with access to it may have changed the file) and rebuilt in a
  /// scratch database. Writes nothing. `null` when the folder has no copy of
  /// Turnly yet.
  Future<RestoreVerification?> verifyLatest() async {
    final state = await (await _states()).load();
    final uri = state.uri;
    if (uri == null) return null;
    final platform = ref.read(folderBackupPlatformProvider);
    final FolderFile? newest;
    try {
      final files = await platform.list(uri);
      newest =
          files.where((f) => f.id == state.lastFileId).firstOrNull ??
          ownFolderCopies(files, now: ref.read(clockProvider)()).firstOrNull;
    } on FolderBackupException catch (e) {
      return VerificationFailed(e);
    }
    if (newest == null) return null;
    try {
      final bytes = await platform.read(uri, newest);
      final tools = await ref.read(backupToolsProvider.future);
      // Rejects a damaged or foreign file off the UI isolate first.
      await tools.service.decodeFile(bytes, codec: tools.codec);
      return await tools.service.verifyBytes(
        bytes,
        today: CivilDate.fromDateTime(ref.read(clockProvider)()),
      );
    } on BackupException catch (e) {
      return VerificationFailed(e);
    } on FolderBackupException catch (e) {
      return VerificationFailed(e);
    }
  }
}

final folderBackupControllerProvider =
    AsyncNotifierProvider<FolderBackupController, FolderBackupView>(
      FolderBackupController.new,
    );

/// Keeps the folder copy going for the whole life of the app (the host
/// watches it). With a folder chosen it:
/// - registers the daily background copy again at every start (WorkManager
///   keeps the task, but the dispatcher's callback handle must be stored again
///   after an update);
/// - copies to the folder after a good automatic copy on the phone, at most
///   every [FolderBackupPolicy.changeGap];
/// - answers the background task when the app is alive in the same process,
///   so the two never copy at once.
/// Inert where there is no folder copy (iOS, tests).
final folderBackupRunnerProvider = Provider<void>((ref) {
  if (!ref.watch(folderBackupSupportedProvider)) return;
  Future<void> run(FolderBackupTrigger trigger) async {
    final outcome = await (await ref.read(folderBackupEngineProvider.future))
        .run(trigger);
    if (outcome.kind == FolderBackupOutcomeKind.saved ||
        outcome.kind == FolderBackupOutcomeKind.failed ||
        outcome.kind == FolderBackupOutcomeKind.upToDate) {
      ref.invalidate(folderBackupControllerProvider);
    }
  }

  final relay = ref.watch(folderBackupRelayProvider)
    ..open(() => run(FolderBackupTrigger.daily));
  ref.onDispose(relay.close);

  unawaited(() async {
    try {
      final file = await ref.read(folderBackupStateFileProvider.future);
      final state = await FolderBackupStateStore(file).load();
      if (state.configured) {
        await ref.read(folderBackupSchedulerProvider).setEnabled(true);
      }
    } catch (_) {
      // Tried again at the next start; the foreground copies still work.
    }
  }());

  ref.listen<AutoBackupStatus>(autoBackupStatusProvider, (previous, next) {
    final finished = previous?.running == true && !next.running;
    if (finished && !next.failing) {
      unawaited(run(FolderBackupTrigger.change).catchError((_) {}));
    }
  });
});
