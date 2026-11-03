import 'dart:async';
import 'dart:typed_data';

import '../../../core/background/isolate_mutex.dart';
import '../data/folder_backup_channel.dart';
import '../data/folder_backup_state_store.dart';
import '../domain/backup_warnings.dart';
import '../domain/folder_backup.dart';

/// The bytes of a `.turnly` ready to go to the folder, already decoded back
/// once (so they are a good copy), and the checksum of their data.
class FolderPayload {
  const FolderPayload(this.bytes, this.checksum, {this.warnings = const []});

  final Uint8List bytes;
  final String checksum;

  /// What the copy left out (attachments whose file is lost); empty for a
  /// whole copy.
  final List<BackupWarning> warnings;
}

/// Makes the payload; `null` when there is nothing that may be read now (the
/// background task found no database, or one on another schema version that
/// only the app may migrate): the run is skipped without a failure.
typedef FolderPayloadMaker = Future<FolderPayload?> Function();

/// How a run ended.
enum FolderBackupOutcomeKind {
  /// No folder chosen.
  notConfigured,

  /// The folder got a copy too recently for this trigger.
  notDue,

  /// Nothing to read right now ([FolderPayloadMaker] gave `null`), or another
  /// isolate of this process holds the run lock ([FolderRunLock]).
  skipped,

  /// The data is the same as the newest copy, which is still in the folder.
  upToDate,

  /// A new copy was written, read back and the old ones rotated.
  saved,

  /// It did not work: [FolderBackupOutcome.problem] says why (recorded in the
  /// state, shown on the backup screen).
  failed,
}

class FolderBackupOutcome {
  const FolderBackupOutcome(
    this.kind, {
    this.problem,
    this.file,
    this.warnings = const [],
  });

  final FolderBackupOutcomeKind kind;
  final FolderProblem? problem;

  /// The copy written ([FolderBackupOutcomeKind.saved]).
  final FolderFile? file;

  /// What the copy left out (`AttachmentsSkipped`): the folder copy goes on
  /// without the attachments whose file is lost, and says so.
  final List<BackupWarning> warnings;

  @override
  String toString() => 'FolderBackupOutcome(${kind.name}, ${problem?.code})';
}

/// The lock that covers a whole run, between the isolates of this process
/// (the app and the background task): only one of them copies at a time.
abstract interface class FolderRunLock {
  /// Takes it; with [wait], keeps trying for a while (a manual copy waits for
  /// a background one to end). `false` if it could not.
  Future<bool> acquire({required bool wait});

  void release();
}

/// No lock (tests, and a single isolate).
class NoFolderRunLock implements FolderRunLock {
  const NoFolderRunLock();

  @override
  Future<bool> acquire({required bool wait}) async => true;

  @override
  void release() {}
}

/// Name of the run lock in the process-wide `IsolateNameServer`.
const String folderRunLockName = 'es.cuadrante.app/backup.folder.lock';

/// [FolderRunLock] over an [IsolateMutex]. A waiting acquire gives up after
/// [maxWait].
class IsolateFolderRunLock implements FolderRunLock {
  IsolateFolderRunLock({
    IsolateMutex? mutex,
    this.maxWait = const Duration(minutes: 2),
  }) : _mutex = mutex ?? IsolateMutex(folderRunLockName);

  final IsolateMutex _mutex;
  final Duration maxWait;

  @override
  Future<bool> acquire({required bool wait}) =>
      _mutex.acquire(wait: wait ? maxWait : Duration.zero);

  @override
  void release() => _mutex.release();
}

/// One folder copy, from the state file to the folder, with every dependency
/// injected (the app passes the backup tools; the background task, a
/// read-only database). Runs one at a time per engine.
///
/// The order is what makes it safe:
/// 1. no folder or not due: nothing happens;
/// 2. the folder is checked first (permission revoked, folder gone, read-only:
///    recorded as such, never silent);
/// 3. the payload is made and was already decoded back;
/// 4. the same data as the newest copy still in the folder: nothing written,
///    only "checked" (so the rotation keeps ten **different** versions);
/// 5. a new file with a free own name is written, **read back and compared
///    byte by byte**: a copy that does not read back is deleted and the run
///    fails (a bad copy never looks like a good one);
/// 6. only then the oldest own copies beyond [FolderBackupPolicy.keep] go
///    (best effort: a file that cannot be deleted stays for the next run);
/// 7. the state records the success; any failure records the problem.
class FolderBackupEngine {
  FolderBackupEngine({
    required this.platform,
    required this.states,
    required this.payload,
    required this.now,
    this.policy = const FolderBackupPolicy(),
    this.lock = const NoFolderRunLock(),
    this.onError,
  });

  final FolderBackupPlatform platform;
  final FolderBackupStateStore states;
  final FolderPayloadMaker payload;
  final DateTime Function() now;
  final FolderBackupPolicy policy;

  /// Held for the whole run, so the app and the background task never copy
  /// (nor write the state) at the same time.
  final FolderRunLock lock;

  /// Unexpected errors (not a [FolderBackupException]), for the crash
  /// reporter: the type and the trace only.
  final void Function(Object error, StackTrace stack)? onError;

  Future<void> _last = Future<void>.value();

  /// Runs [work] after any run already going on this engine.
  Future<T> _exclusive<T>(Future<T> Function() work) {
    final result = _last.then((_) => work());
    _last = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  /// A folder copy for [trigger]. Never throws. Without the run lock it is
  /// [FolderBackupOutcomeKind.skipped]: a manual copy waits for it a while,
  /// the daily and change ones do not (the other isolate is copying).
  Future<FolderBackupOutcome> run(FolderBackupTrigger trigger) => _exclusive(
    () async {
      final bool held;
      try {
        held = await lock.acquire(wait: trigger == FolderBackupTrigger.manual);
      } catch (_) {
        return const FolderBackupOutcome(FolderBackupOutcomeKind.skipped);
      }
      if (!held) {
        return const FolderBackupOutcome(FolderBackupOutcomeKind.skipped);
      }
      try {
        return await _run(trigger);
      } finally {
        lock.release();
      }
    },
  );

  /// Runs [work] (choosing or forgetting the folder) under the same lock as
  /// a run, waiting for it; if it cannot be had, [work] runs anyway (the
  /// state file has its own lock and every status checks the folder).
  Future<T> locked<T>(Future<T> Function() work) => _exclusive(() async {
    var held = false;
    try {
      held = await lock.acquire(wait: true);
    } catch (_) {
      held = false;
    }
    try {
      return await work();
    } finally {
      if (held) lock.release();
    }
  });

  Future<FolderBackupOutcome> _run(FolderBackupTrigger trigger) async {
    final start = await states.load();
    final uri = start.uri;
    // A damaged record has no folder to copy to: the screen asks for one.
    if (uri == null) {
      return const FolderBackupOutcome(FolderBackupOutcomeKind.notConfigured);
    }
    final at = now();
    if (!policy.isDue(trigger, lastDoneAt: start.lastDoneAt, now: at)) {
      return const FolderBackupOutcome(FolderBackupOutcomeKind.notDue);
    }
    try {
      final access = (await platform.check(uri)).access;
      if (access.problem case final problem?) {
        throw FolderBackupException(problem);
      }
      final made = await payload();
      if (made == null) {
        return const FolderBackupOutcome(FolderBackupOutcomeKind.skipped);
      }
      final files = await platform.list(uri);
      if (trigger != FolderBackupTrigger.manual &&
          made.checksum == start.lastChecksum &&
          start.lastCopyIn(files)) {
        await _record(uri, (s) => s.checked(at));
        return FolderBackupOutcome(
          FolderBackupOutcomeKind.upToDate,
          warnings: made.warnings,
        );
      }
      final name = freeFolderBackupName(at, files.map((f) => f.name));
      final written = await platform.write(uri, name, made.bytes);
      if (written.name != name) {
        // Renamed by the provider ("... (1).turnly"): out of the rotation for
        // ever. The platform refuses that already; this is the backstop.
        await _discard(uri, written);
        throw const FolderBackupException(FolderProblem.failed);
      }
      await _readBack(uri, written, made.bytes);
      await _rotate(uri, written, at);
      await _record(uri, (s) => s.succeeded(at, written, made.checksum));
      return FolderBackupOutcome(
        FolderBackupOutcomeKind.saved,
        file: written,
        warnings: made.warnings,
      );
    } on FolderBackupException catch (e) {
      await _record(uri, (s) => s.failed(at, e.problem));
      return FolderBackupOutcome(
        FolderBackupOutcomeKind.failed,
        problem: e.problem,
      );
    } catch (error, stack) {
      onError?.call(error, stack);
      await _record(uri, (s) => s.failed(at, FolderProblem.failed));
      return const FolderBackupOutcome(
        FolderBackupOutcomeKind.failed,
        problem: FolderProblem.failed,
      );
    }
  }

  Future<void> _readBack(
    String uri,
    FolderFile written,
    Uint8List bytes,
  ) async {
    var same = false;
    try {
      same = _equal(await platform.read(uri, written), bytes);
    } catch (_) {
      same = false;
    }
    if (same) return;
    await _discard(uri, written);
    throw const FolderBackupException(FolderProblem.failed);
  }

  Future<void> _discard(String uri, FolderFile written) async {
    try {
      await platform.delete(uri, written);
    } catch (_) {
      // It stays; an own name is rotated out like any other copy.
    }
  }

  Future<void> _rotate(String uri, FolderFile written, DateTime at) async {
    try {
      final files = await platform.list(uri);
      for (final old in folderCopiesToRotate(
        files,
        keep: policy.keep,
        keepId: written.id,
        now: at,
      )) {
        try {
          await platform.delete(uri, old);
        } catch (_) {
          // Left for the next run.
        }
      }
    } catch (_) {
      // The new copy is saved; the rotation waits for the next run.
    }
  }

  /// Records [change] only while the folder is still [uri]: a status from a
  /// folder the user has just replaced is dropped.
  Future<void> _record(
    String uri,
    FolderBackupState Function(FolderBackupState) change,
  ) async {
    try {
      await states.update((s) => s.uri == uri ? change(s) : s);
    } catch (error, stack) {
      onError?.call(error, stack);
    }
  }

  static bool _equal(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
