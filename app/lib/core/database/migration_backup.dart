import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

/// Number of pre-migration backups kept.
const int migrationBackupsToKeep = 3;

// `-<n>` (2, 3...) after the date: a second copy made in the same second
// next to one that could not be checked, which is never overwritten.
final _backupName = RegExp(
  r'^pre-v(\d+)-a-v(\d+)-(\d{8}-\d{6})(?:-(\d+))?\.sqlite$',
);

/// `PRAGMA user_version` of the SQLite file at [file] (the version Drift
/// stores there), or `null` when the file does not exist or is empty.
///
/// Reads with `package:sqlite3` before Drift opens the database, so this must
/// not need the generated code. Opened read-write on purpose: a journal left
/// by a crash makes a read-only open fail (the app would not start), while a
/// read-write open lets SQLite recover it, so the backup copies a consistent
/// file.
int? readUserVersion(File file) {
  if (!file.existsSync() || file.lengthSync() == 0) return null;
  final db = sqlite3.open(file.path, mode: OpenMode.readWrite);
  try {
    return db.select('PRAGMA user_version').first.values.first as int;
  } finally {
    db.close();
  }
}

/// Copies [databaseFile] to
/// `[backupsDirectory]/pre-v{from}-a-v{to}-{yyyyMMdd-HHmmss}.sqlite` when the
/// file is on an older schema than [targetVersion] (and not brand new:
/// `user_version` > 0), then keeps only the [keep] newest backups.
///
/// **One copy per target.** If a verified copy for the target already
/// exists, none is made: a migration that keeps failing midway (v1 -> v2 done,
/// v2 -> v3 failing) would otherwise write a new copy, already at v2, on every
/// launch and, three launches later, prune the only copy of the data as it was
/// before the first step (`pre-v1-a-v3-*`). The copy that exists is the
/// oldest, so it is the one that matters. Pruning never deletes the oldest
/// copy of the current target either ([pruneMigrationBackups]).
///
/// An existing copy is deleted only when the check **proves** it incomplete
/// (a truncated file, a damaged header, SQLite reporting it corrupt). When
/// the check cannot tell (the file is locked, a read fails), the copy stays
/// and a new one is made next to it: it may be the only copy of the data as
/// it was before the first step.
///
/// Returns the backup, or `null` when none was needed. Throws if the copy
/// fails, so the migration never runs without its safety copy.
Future<File?> backupBeforeMigration({
  required File databaseFile,
  required int targetVersion,
  required Directory backupsDirectory,
  DateTime Function()? now,
  int keep = migrationBackupsToKeep,
}) async {
  final from = readUserVersion(databaseFile);
  if (from == null || from <= 0 || from >= targetVersion) return null;

  await backupsDirectory.create(recursive: true);
  final incomplete = <File>[];
  await for (final (file, version) in _backupsFor(
    backupsDirectory,
    targetVersion,
  )) {
    switch (_checkCopy(file, version)) {
      case _CopyCheck.complete:
        return null;
      case _CopyCheck.incomplete:
        incomplete.add(file);
      case _CopyCheck.unknown:
        break;
    }
  }
  final stamp = _stamp((now ?? DateTime.now)().toUtc());
  // When copies of this second exist (ones that could not be checked), the
  // new one gets the next suffix above all of them: the rename below never
  // replaces a file, and the new copy sorts as the newest of that second.
  var suffix = 0;
  await for (final entity in backupsDirectory.list()) {
    if (entity is! File) continue;
    final match = _backupName.firstMatch(p.basename(entity.path));
    if (match == null || match[3] != stamp) continue;
    final n = int.parse(match[4] ?? '1');
    if (n > suffix) suffix = n;
  }
  File named(int n) => File(
    p.join(
      backupsDirectory.path,
      'pre-v$from-a-v$targetVersion-$stamp${n == 0 ? '' : '-$n'}.sqlite',
    ),
  );
  var target = named(suffix == 0 ? 0 : suffix + 1);
  while (await target.exists()) {
    target = named(++suffix + 1);
  }
  final partial = File(
    p.join(backupsDirectory.path, 'pre-v$targetVersion.sqlite.partial'),
  );
  try {
    await databaseFile.copy(partial.path);
    final handle = await partial.open(mode: FileMode.append);
    try {
      await handle.flush();
    } finally {
      await handle.close();
    }
    if (await partial.length() != await databaseFile.length() ||
        _checkCopy(partial, from) != _CopyCheck.complete) {
      throw FileSystemException('Incomplete migration backup', partial.path);
    }
    await partial.rename(target.path);
  } finally {
    if (await partial.exists()) await partial.delete();
  }
  for (final file in incomplete) {
    if (file.path != target.path) await file.delete();
  }
  await pruneMigrationBackups(
    backupsDirectory,
    keep,
    protectOldestOfTarget: targetVersion,
    protect: target,
  );
  return target;
}

/// `yyyyMMdd-HHmmss` (UTC).
String _stamp(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year.toString().padLeft(4, '0')}${two(t.month)}${two(t.day)}'
      '-${two(t.hour)}${two(t.minute)}${two(t.second)}';
}

/// The backups in [directory] whose name says they go to [target].
Stream<(File, int)> _backupsFor(Directory directory, int target) async* {
  await for (final entity in directory.list()) {
    if (entity is! File) continue;
    final match = _backupName.firstMatch(p.basename(entity.path));
    if (match != null && int.parse(match[2]!) == target) {
      yield (entity, int.parse(match[1]!));
    }
  }
}

/// What checking a copy found out.
enum _CopyCheck {
  /// A whole, consistent copy at the expected version.
  complete,

  /// Proven broken: shorter than its header says, not a SQLite file, or
  /// reported corrupt. Safe to replace.
  incomplete,

  /// The check could not tell (locked file, failed read, another version
  /// than the name says). The file must be kept.
  unknown,
}

// SQLite primary result codes that prove the file itself is damaged.
const _sqliteCorrupt = 11;
const _sqliteNotADatabase = 26;

_CopyCheck _checkCopy(File file, int version) {
  final Uint8List header;
  final int length;
  try {
    length = file.lengthSync();
    final handle = file.openSync();
    try {
      header = handle.readSync(100);
    } finally {
      handle.closeSync();
    }
  } on FileSystemException {
    return _CopyCheck.unknown;
  }
  final headerCheck = _checkHeader(header, length);
  if (headerCheck != null) return headerCheck;
  try {
    final db = sqlite3.open(file.path, mode: OpenMode.readOnly);
    try {
      if (db.select('PRAGMA user_version').single.values.single != version) {
        return _CopyCheck.unknown;
      }
      final result = db.select('PRAGMA quick_check');
      return result.length == 1 && result.single.values.single == 'ok'
          ? _CopyCheck.complete
          : _CopyCheck.incomplete;
    } finally {
      db.close();
    }
  } on SqliteException catch (error) {
    return switch (error.resultCode) {
      _sqliteCorrupt || _sqliteNotADatabase => _CopyCheck.incomplete,
      _ => _CopyCheck.unknown,
    };
  }
}

/// [_CopyCheck.incomplete] when the first bytes of a SQLite file prove it is
/// broken: shorter than the header, a wrong magic string, or shorter than
/// the size the header records. `null` when the header looks whole.
_CopyCheck? _checkHeader(Uint8List header, int length) {
  const magic = 'SQLite format 3\u0000';
  if (header.length < 100 || length < 100) return _CopyCheck.incomplete;
  for (var i = 0; i < magic.length; i++) {
    if (header[i] != magic.codeUnitAt(i)) return _CopyCheck.incomplete;
  }
  final bytes = ByteData.sublistView(header);
  final rawPageSize = bytes.getUint16(16);
  final pageSize = rawPageSize == 1 ? 65536 : rawPageSize;
  final pageCount = bytes.getUint32(28);
  // The page count is only valid when the change counter matches the
  // "version valid for" field (SQLite 3.7.0 and later).
  final countValid = bytes.getUint32(24) == bytes.getUint32(92);
  if (countValid && pageCount > 0 && length < pageSize * pageCount) {
    return _CopyCheck.incomplete;
  }
  return null;
}

/// Deletes all but the [keep] newest backups (by the date in the name, then
/// the `-<n>` suffix; ties by name). Files that do not look like ours are left alone. With
/// [protectOldestOfTarget], the oldest backup that goes to that version is
/// kept even when it is not among the newest: it is the data as it was before
/// the first step of that migration chain. [protect] (the copy just made)
/// is never deleted either.
@visibleForTesting
Future<void> pruneMigrationBackups(
  Directory directory,
  int keep, {
  int? protectOldestOfTarget,
  File? protect,
}) async {
  final backups = <(String, File, int, int)>[];
  await for (final entity in directory.list()) {
    if (entity is! File) continue;
    final match = _backupName.firstMatch(p.basename(entity.path));
    if (match != null) {
      backups.add((
        match[3]!,
        entity,
        int.parse(match[2]!),
        int.parse(match[4] ?? '1'),
      ));
    }
  }
  backups.sort((a, b) {
    final byDate = b.$1.compareTo(a.$1);
    if (byDate != 0) return byDate;
    final bySuffix = b.$4.compareTo(a.$4);
    return bySuffix != 0 ? bySuffix : b.$2.path.compareTo(a.$2.path);
  });
  // Newest first, so the oldest of the target is the last one that matches.
  final protected = protectOldestOfTarget == null
      ? null
      : backups.where((b) => b.$3 == protectOldestOfTarget).lastOrNull;
  for (final backup in backups.skip(keep)) {
    if (identical(backup, protected)) continue;
    if (protect != null && p.equals(backup.$2.path, protect.path)) continue;
    await backup.$2.delete();
  }
}
