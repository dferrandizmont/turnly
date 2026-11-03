import 'dart:typed_data';

import '../../schedule/domain/schedule_domain.dart';
import '../data/backup_repository.dart';
import '../domain/backup_codec.dart';
import '../domain/backup_errors.dart';
import '../domain/backup_store.dart';
import '../domain/backup_task_runner.dart';
import '../domain/backup_warnings.dart';
import '../domain/restore_summary.dart';

export '../data/backup_repository.dart' show BackupEncoding;
export '../domain/backup_task_runner.dart';
export '../domain/backup_warnings.dart';

/// A file read and ready to restore: what it holds and what restoring would
/// replace. Nothing has been written yet.
class PendingRestore {
  const PendingRestore({required this.file, required this.summary});

  final BackupFile file;
  final RestoreSummary summary;
}

/// The backup operations the screens need, over a [BackupRepository], a
/// [BackupCodec] and a [BackupStore] (local files now, iCloud on iOS later).
class BackupService {
  BackupService({
    required this._repository,
    required this._store,
    required this._appVersion,
    this._codec = const BackupCodec(),
    BackupTaskRunner? runner,
    DateTime Function()? now,
  }) : _runner = runner ?? runInBackgroundIsolate,
       _now = now ?? DateTime.now;

  final BackupRepository _repository;
  final BackupStore _store;
  final String _appVersion;
  final BackupCodec _codec;
  final BackupTaskRunner _runner;
  final DateTime Function() _now;

  /// What the newest copy this service made left out
  /// ([AttachmentsSkipped]): empty when it was whole. Set by [backupNow]; the
  /// screens read it after the copy.
  List<BackupWarning> lastWarnings = const [];

  /// The `.cuadrante` bytes of the current data, e.g. to share. **Strict**: if
  /// an attachment has no usable file it throws [BrokenAttachments] naming
  /// them, instead of handing over a file that lacks them without saying so.
  Future<Uint8List> exportBytes() async =>
      (await exportDetailed(strict: true)).bytes;

  /// The current data as a `.turnly`, with what was left out. Without
  /// [strict], the attachments whose file is missing or damaged are skipped
  /// and reported in [BackupEncoding.warnings] (the folder copy uses it: it
  /// must go on).
  Future<BackupEncoding> exportDetailed({bool strict = false}) =>
      _encodeCurrent(_now(), strict: strict);

  Future<BackupEncoding> _encodeCurrent(
    DateTime at, {
    required bool strict,
  }) async {
    final data = await _repository.readAll();
    // The attachments travel with the data (the container of the copy); their
    // files are read and checked in the same background job that encodes.
    return _repository.encodeCurrent(
      data,
      at: at,
      strict: strict,
      appVersion: _appVersion,
    );
  }

  /// Decode a persisted file through the same runner as imported files.
  Future<BackupFile> decodeFile(Uint8List bytes, {BackupCodec? codec}) {
    final reader = codec ?? _codec;
    return _runner(() => reader.decode(bytes));
  }

  /// Exports the current data into the store. Throws if it could not be
  /// saved.
  ///
  /// An automatic copy never stops for an attachment whose file is already
  /// lost: it leaves it out and sets [lastWarnings].
  Future<BackupEntry> backupNow() async {
    final now = _now();
    final encoding = await _encodeCurrent(now, strict: false);
    final entry = await _store.save(encoding.bytes, at: now);
    lastWarnings = encoding.warnings;
    return entry;
  }

  /// Reads [bytes] (an imported file or a stored backup) without writing
  /// anything. Throws a [BackupException] if it is unusable.
  ///
  /// The decoding (inflate, JSON, canonical form and checksum, validation) is
  /// the expensive part and the bytes may come from anyone, so it runs through
  /// the runner (an isolate in the app), never on the UI isolate. Only the
  /// database summary, which is cheap, runs here.
  Future<PendingRestore> inspect(Uint8List bytes) async {
    final file = await decodeFile(bytes);
    return PendingRestore(
      file: file,
      summary: await _repository.preview(file.data),
    );
  }

  /// Replaces the current data with [pending]'s. The caller reloads the
  /// schedule afterwards.
  ///
  /// The attachments of the file (when it is a container) are written in the
  /// store of the app before the rows that point at them.
  ///
  /// Returns what the safety copy made before the restore left out
  /// ([AttachmentsSkipped]: attachments whose file was already lost).
  Future<List<BackupWarning>> restore(PendingRestore pending) =>
      _repository.restore(
        pending.file.data,
        attachmentFiles: pending.file.attachmentFiles,
        // The codec checked every file against its row in an isolate.
        verified: true,
      );

  /// "Probar restauración" on the newest stored backup, or `null` when the
  /// store has none.
  Future<RestoreVerification?> verifyLatest({required CivilDate today}) async {
    final latest = await _store.latest();
    if (latest == null) return null;
    return _repository.verifyRestore(await _store.read(latest), today: today);
  }

  /// "Probar restauración" on [bytes] kept somewhere else (the newest copy in
  /// the folder of the automatic folder copy). Writes nothing.
  Future<RestoreVerification> verifyBytes(
    Uint8List bytes, {
    required CivilDate today,
  }) => _repository.verifyRestore(bytes, today: today);
}
