import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../domain/backup_codec.dart';

/// Why [readAndDeleteIncomingTempFile] gave no bytes.
class IncomingTempFileException implements Exception {
  const IncomingTempFileException({required this.tooLarge});

  /// Over the cap of an import (`BackupCodec.maxImportBytes`, or
  /// `maxFileBytes` when it is not a container). Otherwise it is unreadable.
  final bool tooLarge;

  @override
  String toString() => 'IncomingTempFileException(tooLarge: $tooLarge)';
}

/// Name of the folder of the app's cache where the native side streams the
/// files that reach the app (a `.turnly` another app hands over, a copy read
/// from the chosen folder): `cacheDir/incoming/`.
const String incomingTempDirName = 'incoming';

/// Extension of those files.
const String incomingTempSuffix = '.turnly';

/// Whether [path] is where the native side leaves the files it streams: an
/// absolute path to a `*.turnly` directly in a folder called `incoming`.
/// Nothing else is ever read or deleted through this door, whatever a channel
/// reply says.
bool isIncomingTempPath(String path) =>
    p.isAbsolute(path) &&
    p.basename(p.dirname(path)) == incomingTempDirName &&
    p.basename(path).endsWith(incomingTempSuffix);

/// Reads the file the native side streamed to [path] and **deletes it**, also
/// when reading fails: a copy of the user's data must not stay behind in the
/// cache.
///
/// The native side already refused anything over the cap while streaming (it
/// never held the file in memory); this checks again, with the size on disk,
/// before reading a byte: over `BackupCodec.maxImportBytes` is too large, and
/// so is anything over `BackupCodec.maxFileBytes` that is not a container (a
/// ZIP). Throws [IncomingTempFileException] for those and for a path that is
/// not one of ours; any other failure (the file is gone, an I/O error, no
/// memory) is also reported as [IncomingTempFileException] with
/// `tooLarge: false` (`true` for the memory case), so the callers answer
/// `tooLarge` or `unreadable` and never crash.
Future<Uint8List> readAndDeleteIncomingTempFile(String path) async {
  if (!isIncomingTempPath(path)) {
    throw const IncomingTempFileException(tooLarge: false);
  }
  final file = File(path);
  try {
    final length = await file.length();
    if (length > BackupCodec.maxImportBytes) {
      throw const IncomingTempFileException(tooLarge: true);
    }
    // Only a container may pass the cap of a plain file: look at its first
    // bytes before reading all of it.
    if (length > BackupCodec.maxFileBytes) {
      final head = <int>[];
      await for (final chunk in file.openRead(0, 4)) {
        head.addAll(chunk);
      }
      if (!BackupCodec.fitsImportLimit(length, head)) {
        throw const IncomingTempFileException(tooLarge: true);
      }
    }
    final bytes = await file.readAsBytes();
    if (!BackupCodec.fitsImportLimit(bytes.length, bytes)) {
      throw const IncomingTempFileException(tooLarge: true);
    }
    return bytes;
  } on IncomingTempFileException {
    rethrow;
  } on OutOfMemoryError {
    throw const IncomingTempFileException(tooLarge: true);
  } catch (_) {
    throw const IncomingTempFileException(tooLarge: false);
  } finally {
    await _deleteQuietly(file);
  }
}

/// Deletes [path] if it is one of ours and still there (best effort).
Future<void> deleteIncomingTempFile(String path) async {
  if (!isIncomingTempPath(path)) return;
  await _deleteQuietly(File(path));
}

Future<void> _deleteQuietly(File file) async {
  try {
    if (await file.exists()) await file.delete();
  } catch (_) {
    // The native side sweeps what is left (older than an hour) at the next start.
  }
}
