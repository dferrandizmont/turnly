import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../domain/note_attachment.dart';

export '../domain/note_attachment.dart'
    show maxAttachmentFiles, maxAttachmentStoreBytes;

/// The folder of the app that holds the files of the attachments
/// (`<Application Support>/attachments/`).
const String attachmentsDirectoryName = 'attachments';

/// Why an attachment could not be stored (or read).
enum AttachmentProblem {
  /// The file is bigger than [maxAttachmentBytes].
  tooLarge,

  /// The store is full: its files would go over [maxAttachmentStoreBytes] or
  /// [maxAttachmentFiles].
  storeFull,

  /// The path is not a safe one (it could leave the folder of the app).
  unsafePath,

  /// What is stored is not what the row says (the SHA-256 does not match).
  hashMismatch,

  /// The file is not in the store.
  missing,
}

/// An attachment that could not be stored (or read). The screens show the
/// [problem] (translated); nothing else is said about it.
class AttachmentStoreException implements Exception {
  const AttachmentStoreException(this.problem, this.message);

  final AttachmentProblem problem;
  final String message;

  @override
  String toString() => 'AttachmentStoreException(${problem.name}): $message';
}

/// The files of the attachments (photos, drawings and documents) of the app:
/// the `attachments` folder inside `Application Support`.
///
/// Every file is named after the **SHA-256 of its bytes** (the first two hex
/// digits, a slash and the whole hash), so:
///
/// - the same content is never stored twice ([put] writes it once);
/// - a file can be checked against its row at any moment (the hash is in the
///   name and in the row);
/// - the folder can be swept: the files no row points at are leftovers.
///
/// The path of a row is unique in the table (`note_attachments.relative_path`),
/// so a second attachment with the same content gets its own copy
/// ([putCopy]): the bytes are the same, the files are two (`<path>-2`,
/// `<path>-3`...). `isCanonicalAttachmentPath` is the rule for those names.
///
/// Nothing here writes outside [root]: every path is checked with
/// [isSafeAttachmentPath] before it is used.
class AttachmentStore {
  AttachmentStore(
    this.root, {
    this.maxFileBytes = maxAttachmentBytes,
    this.maxTotalBytes = maxAttachmentStoreBytes,
    this.maxFiles = maxAttachmentFiles,
  });

  /// The folder of the app that holds the files.
  final Directory root;

  /// Most bytes one file may have.
  final int maxFileBytes;

  /// Most bytes the whole store may have.
  final int maxTotalBytes;

  /// Most files the whole store may have.
  final int maxFiles;

  /// Where the files are written before they are moved to their place (same
  /// folder, so the move is atomic). Never part of the store's contents.
  static const String _incomingFolder = '.incoming';

  /// What the store holds, measured once (walking the folder) and kept up to
  /// date by every write, delete and sweep of this instance: a write must not
  /// walk the whole store (a restore writes thousands of files). `null` until
  /// measured, and again after a sweep. The app has one instance of the store
  /// (`attachmentStoreProvider`); another process only reads.
  ({int bytes, int files})? _usage;

  /// The end of the queue of changes: they run one after another, so
  /// [_usage] is never read half way through another write.
  Future<void> _tail = Future<void>.value();

  int _tempCounter = 0;

  Future<T> _exclusive<T>(Future<T> Function() body) {
    final previous = _tail;
    final done = Completer<void>();
    _tail = done.future;
    return previous.then((_) => body()).whenComplete(done.complete);
  }

  /// The path of [bytes] inside the store: `<hash[0:2]>/<hash>`.
  String pathOf(Uint8List bytes) => pathOfHash(hashOf(bytes));

  /// The path of the file whose SHA-256 is [hash] (lowercase hex): the same
  /// path [pathOf] gives, without hashing the bytes again.
  String pathOfHash(String hash) => attachmentPathOfHash(hash);

  /// The SHA-256 of [bytes], in lowercase hex: what a row keeps so a file can
  /// be checked at any time.
  String hashOf(Uint8List bytes) => sha256.convert(bytes).toString();

  /// Writes [bytes] in the store and returns its path. The same bytes always
  /// give the same path, and are written only once: a file that is already
  /// there with the same content is left as it is (one that is not what its
  /// name says is written again).
  ///
  /// Throws [AttachmentStoreException] when the file is too big
  /// ([AttachmentProblem.tooLarge]) or the store is full
  /// ([AttachmentProblem.storeFull]).
  Future<String> put(Uint8List bytes) async {
    final path = pathOf(bytes);
    final target = _fileOf(path);
    if (await target.exists()) {
      // The path is the hash of [bytes]: the same bytes there are the same
      // content (a byte comparison, not a second SHA-256 of both).
      if (_sameBytes(await target.readAsBytes(), bytes)) return path;
      // The file is not what its name says: it is written again.
    }
    await _write(path, bytes);
    return path;
  }

  /// Writes [bytes] in a file of its own and returns its path: for an
  /// attachment whose content is already in the store (the path of a row is
  /// unique, so two rows cannot share a file).
  Future<String> putCopy(Uint8List bytes) async {
    final path = pathOf(bytes);
    if (!await exists(path)) {
      await _write(path, bytes);
      return path;
    }
    for (var n = 2; n <= maxAttachmentCopies; n++) {
      final candidate = '$path-$n';
      if (!await exists(candidate)) {
        await _write(candidate, bytes);
        return candidate;
      }
    }
    throw const AttachmentStoreException(
      AttachmentProblem.storeFull,
      'too many copies of the same file',
    );
  }

  /// Writes [bytes] at [relativePath], the path a row of a restored backup
  /// brings (the restore does not rename anything: the rows and the files
  /// must agree).
  ///
  /// [bytes] must already be the verified content of the row (a restore
  /// checks them against their SHA-256 and the row's path against that hash
  /// before it gets here): a file that is already there with the same bytes
  /// is left as it is, and no hashing is needed on this isolate. One with a
  /// different content is never overwritten
  /// ([AttachmentProblem.hashMismatch]): the rows that point at it would
  /// point at something else. With [replaceDamaged] it is replaced: for the
  /// caller that knows [relativePath] is the canonical path of the hash of
  /// [bytes] (`isCanonicalAttachmentPath`), where a file with other bytes is a
  /// damaged one, and keeping it would block the restore of a good copy.
  ///
  /// Returns whether the file was written (a file that was already there is
  /// not written again: the caller knows then that it may delete it without
  /// touching what was there before).
  Future<bool> writeAt(
    String relativePath,
    Uint8List bytes, {
    bool replaceDamaged = false,
  }) async {
    if (!isSafeAttachmentPath(relativePath)) {
      throw AttachmentStoreException(
        AttachmentProblem.unsafePath,
        relativePath,
      );
    }
    final target = _fileOf(relativePath);
    if (await target.exists()) {
      if (_sameBytes(await target.readAsBytes(), bytes)) return false;
      if (!replaceDamaged) {
        throw AttachmentStoreException(
          AttachmentProblem.hashMismatch,
          relativePath,
        );
      }
    }
    await _write(relativePath, bytes);
    return true;
  }

  /// The bytes of the file at [relativePath].
  ///
  /// Throws [AttachmentStoreException] ([AttachmentProblem.missing]) when
  /// there is no such file.
  Future<Uint8List> read(String relativePath) async {
    if (!isSafeAttachmentPath(relativePath)) {
      throw AttachmentStoreException(
        AttachmentProblem.unsafePath,
        relativePath,
      );
    }
    final file = _fileOf(relativePath);
    if (!await file.exists()) {
      throw AttachmentStoreException(AttachmentProblem.missing, relativePath);
    }
    return file.readAsBytes();
  }

  /// Whether there is a file at [relativePath].
  Future<bool> exists(String relativePath) async {
    if (!isSafeAttachmentPath(relativePath)) return false;
    return _fileOf(relativePath).exists();
  }

  /// Deletes the file at [relativePath]. Returns whether a file went.
  Future<bool> delete(String relativePath) async {
    if (!isSafeAttachmentPath(relativePath)) return false;
    return _exclusive(() async {
      final file = _fileOf(relativePath);
      if (!await file.exists()) return false;
      final size = await file.length();
      await file.delete();
      final usage = _usage;
      if (usage != null) {
        _usage = (bytes: usage.bytes - size, files: usage.files - 1);
      }
      return true;
    });
  }

  /// Every file of the store, by path (the ones that are not ours are
  /// ignored).
  Future<List<String>> list() async {
    if (!await root.exists()) return [];
    final found = <String>[];
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final relative = p
          .relative(entity.path, from: root.path)
          .replaceAll('\\', '/');
      if (relative.startsWith('$_incomingFolder/')) continue;
      if (!isSafeAttachmentPath(relative)) continue;
      found.add(relative);
    }
    found.sort();
    return found;
  }

  /// How many bytes the files of the store hold (walks the folder).
  Future<int> totalBytes() async => (await _measure()).bytes;

  Future<({int bytes, int files})> _measure() async {
    var bytes = 0;
    var files = 0;
    for (final relative in await list()) {
      final file = _fileOf(relative);
      if (await file.exists()) {
        bytes += await file.length();
        files++;
      }
    }
    return (bytes: bytes, files: files);
  }

  /// Deletes the files that no row points at (the leftovers of a deleted
  /// attachment, of a deleted calendar or of a restore that failed) and
  /// returns how many went.
  ///
  /// [used] holds the paths the rows use. A file (or half-written temporary
  /// file) modified less than [minAge] ago is left alone: a write in
  /// progress puts its file in place **before** its row, so a sweep that runs
  /// at the same time (the one at start-up) must not take it for a leftover.
  /// [now] is the clock for that comparison.
  Future<int> sweep(
    Set<String> used, {
    Duration minAge = Duration.zero,
    DateTime? now,
  }) => _exclusive(() async {
    final clock = now ?? DateTime.now();
    var deleted = 0;
    for (final relative in await list()) {
      if (used.contains(relative)) continue;
      final file = _fileOf(relative);
      try {
        if (await _isYoung(file, clock, minAge)) continue;
        await file.delete();
        deleted++;
      } on FileSystemException {
        // A file that cannot be deleted stays; the next sweep tries again.
      }
    }
    deleted += await _clearIncoming(minAge, clock);
    // What is left is measured again the next time it is needed.
    _usage = null;
    return deleted;
  });

  static Future<bool> _isYoung(
    File file,
    DateTime clock,
    Duration minAge,
  ) async {
    if (minAge <= Duration.zero) return false;
    final modified = await file.lastModified();
    return clock.difference(modified) < minAge;
  }

  /// Deletes what a write that failed half-way left in the incoming folder.
  Future<int> _clearIncoming(Duration minAge, DateTime clock) async {
    final incoming = Directory(p.join(root.path, _incomingFolder));
    if (!await incoming.exists()) return 0;
    var deleted = 0;
    await for (final entity in incoming.list(followLinks: false)) {
      if (entity is! File) continue;
      try {
        if (await _isYoung(entity, clock, minAge)) continue;
        await entity.delete();
        deleted++;
      } on FileSystemException {
        // Left for the next sweep.
      }
    }
    return deleted;
  }

  File _fileOf(String relativePath) {
    final segments = relativePath.split('/');
    return File(p.joinAll([root.path, ...segments]));
  }

  Future<void> _write(String relativePath, Uint8List bytes) async {
    if (!isSafeAttachmentPath(relativePath)) {
      throw AttachmentStoreException(
        AttachmentProblem.unsafePath,
        relativePath,
      );
    }
    if (bytes.length > maxFileBytes) {
      throw AttachmentStoreException(
        AttachmentProblem.tooLarge,
        '$relativePath is ${bytes.length} bytes',
      );
    }
    await _exclusive(() async {
      final target = _fileOf(relativePath);
      final existed = await target.exists();
      final already = existed ? await target.length() : 0;
      // The store is walked once; after that every write keeps the count.
      final usage = _usage ??= await _measure();
      final total = usage.bytes - already + bytes.length;
      final files = usage.files + (existed ? 0 : 1);
      if (total > maxTotalBytes) {
        throw AttachmentStoreException(
          AttachmentProblem.storeFull,
          'the store would hold $total bytes',
        );
      }
      if (files > maxFiles) {
        throw AttachmentStoreException(
          AttachmentProblem.storeFull,
          'the store would hold $files files',
        );
      }
      await target.parent.create(recursive: true);
      await _writeAtomically(target, bytes);
      _usage = (bytes: total, files: files);
    });
  }

  /// Writes [bytes] in [target] so a crash never leaves half a file there: to
  /// a temporary file in the same folder first, flushed to disk, then
  /// renamed.
  Future<void> _writeAtomically(File target, Uint8List bytes) async {
    final incoming = Directory(p.join(root.path, _incomingFolder));
    await incoming.create(recursive: true);
    // One temporary name per write: two writes of the same content must not
    // share a file.
    final temp = File(
      p.join(
        incoming.path,
        '${target.uri.pathSegments.last}.${_tempCounter++}.part',
      ),
    );
    try {
      await temp.writeAsBytes(bytes, flush: true);
      await temp.rename(target.path);
    } catch (_) {
      if (await temp.exists()) await temp.delete();
      rethrow;
    }
  }
}

/// Whether two byte lists hold the same bytes.
bool _sameBytes(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// What a check of the files needs to know about one attachment: its id, the
/// path of its file and the size and SHA-256 its row says.
typedef AttachmentFileRef = ({
  String id,
  String relativePath,
  int sizeBytes,
  String sha256,
});

/// The result of [readVerifiedAttachmentFiles].
class AttachmentFilesCheck {
  const AttachmentFilesCheck(this.files, this.broken);

  /// Attachment id -> bytes of the files that are there with the right size
  /// and SHA-256 (empty when the check was asked not to keep them).
  final Map<String, Uint8List> files;

  /// The attachments whose file is missing or is not what the row says.
  final List<BrokenAttachment> broken;
}

/// How [readVerifiedAttachmentFiles] reads one file (tests inject one that
/// fails; the default is a plain synchronous read).
typedef AttachmentBytesReader = Uint8List Function(File file);

Uint8List _readFileBytes(File file) => file.readAsBytesSync();

/// Reads the files of [items] from the store at [rootPath] and checks each
/// against its row (size and SHA-256), synchronously: **meant to run in a
/// background isolate** (`BackupTaskRunner`), never on the UI isolate, because
/// it hashes every file. It takes only plain data (a path and records), so it
/// can be sent to an isolate. A path that is not safe or a file that is not
/// there is [AttachmentFault.missing]; a file that is there but cannot be
/// read (an I/O error, a permission) is [AttachmentFault.unreadable], **not**
/// missing: it may be fine and nothing may treat it as lost; one with another
/// size or hash is [AttachmentFault.damaged]. Nothing is thrown for a bad
/// file. With [keepBytes] false the bytes are dropped after the check (only
/// the verdict is wanted).
AttachmentFilesCheck readVerifiedAttachmentFiles(
  String rootPath,
  List<AttachmentFileRef> items, {
  bool keepBytes = true,
  AttachmentBytesReader? read,
}) {
  final readBytes = read ?? _readFileBytes;
  final files = <String, Uint8List>{};
  final broken = <BrokenAttachment>[];
  for (final item in items) {
    if (!isSafeAttachmentPath(item.relativePath)) {
      broken.add(BrokenAttachment(item.id, AttachmentFault.missing));
      continue;
    }
    final file = File(p.joinAll([rootPath, ...item.relativePath.split('/')]));
    final Uint8List bytes;
    try {
      if (!file.existsSync()) {
        broken.add(BrokenAttachment(item.id, AttachmentFault.missing));
        continue;
      }
      bytes = readBytes(file);
    } on PathNotFoundException {
      // Gone between the check and the read.
      broken.add(BrokenAttachment(item.id, AttachmentFault.missing));
      continue;
    } on FileSystemException {
      // There, but it cannot be read now: not the same as lost.
      broken.add(BrokenAttachment(item.id, AttachmentFault.unreadable));
      continue;
    }
    if (bytes.length != item.sizeBytes ||
        sha256.convert(bytes).toString() != item.sha256) {
      broken.add(BrokenAttachment(item.id, AttachmentFault.damaged));
      continue;
    }
    if (keepBytes) files[item.id] = bytes;
  }
  return AttachmentFilesCheck(files, broken);
}
