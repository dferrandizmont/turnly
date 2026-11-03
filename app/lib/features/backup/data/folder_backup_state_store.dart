import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

import '../domain/folder_backup.dart';

/// Folder in Application Support with the folder copy's state, its lock and
/// its temporary files. Kept out of the system backup (`backup_rules.xml`,
/// `data_extraction_rules.xml`): the folder's permission does not travel to
/// another phone, so neither does the record of it.
const String folderBackupDirName = 'folder_backup';

/// File name of the folder copy's state, inside [folderBackupDirName].
const String folderBackupStateFileName = 'state.json';

/// File name of the lock that guards [folderBackupStateFileName].
const String folderBackupLockFileName = 'state.lock';

/// Keeps [FolderBackupState] in a small JSON file. The app and the background
/// task both write it, so:
/// - every write goes to a temporary file with a name of its own (process id
///   and a random number) and is renamed over the state: atomic, and two
///   writers never share a temporary file;
/// - [save] and [update] hold an exclusive lock on [folderBackupLockFileName]
///   (`RandomAccessFile.lock`, between processes) and run one at a time in this
///   isolate; between isolates of the same process (file locks belong to the
///   process) the folder copy's `IsolateMutex` covers every writer;
/// - [update] reads the newest content under the lock right before writing,
///   so a status from an old folder never overwrites a folder chosen
///   meanwhile.
///
/// A file that exists but cannot be read is [FolderBackupState.damaged],
/// never an empty state: the screen tells the user.
class FolderBackupStateStore {
  FolderBackupStateStore(this.file);

  final File file;

  static final Map<String, Future<void>> _queues = {};
  static final Random _random = Random();

  File get _lockFile =>
      File(p.join(file.parent.path, folderBackupLockFileName));

  /// The state; empty when there is no file, damaged when it cannot be read.
  Future<FolderBackupState> load() async {
    final String text;
    try {
      if (!await file.exists()) return const FolderBackupState();
      text = await file.readAsString();
    } catch (_) {
      return const FolderBackupState.damaged();
    }
    try {
      return FolderBackupState.fromJson(jsonDecode(text));
    } catch (_) {
      return const FolderBackupState.damaged();
    }
  }

  /// Replaces the state. Throws if it could not be written.
  Future<void> save(FolderBackupState state) => _locked(() => _write(state));

  /// Reads the newest state, changes it with [change] and writes it back, all
  /// under the lock.
  Future<FolderBackupState> update(
    FolderBackupState Function(FolderBackupState current) change,
  ) => _locked(() async {
    final next = change(await load());
    await _write(next);
    return next;
  });

  Future<void> _write(FolderBackupState state) async {
    final temp = File('${file.path}.$pid.${_random.nextInt(1 << 32)}.tmp');
    try {
      await temp.writeAsString(jsonEncode(state.toJson()), flush: true);
      await temp.rename(file.path);
    } catch (_) {
      try {
        if (await temp.exists()) await temp.delete();
      } catch (_) {
        // Left behind; it is in the excluded folder and never read.
      }
      rethrow;
    }
  }

  /// One at a time in this isolate, and under the file lock between
  /// processes.
  Future<T> _locked<T>(Future<T> Function() work) {
    final key = file.absolute.path;
    final result = (_queues[key] ?? Future<void>.value()).then(
      (_) => _withFileLock(work),
    );
    _queues[key] = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  Future<T> _withFileLock<T>(Future<T> Function() work) async {
    await file.parent.create(recursive: true);
    final lock = await _lockFile.open(mode: FileMode.append);
    try {
      await lock.lock(FileLock.blockingExclusive);
      try {
        return await work();
      } finally {
        await lock.unlock();
      }
    } finally {
      await lock.close();
    }
  }
}
