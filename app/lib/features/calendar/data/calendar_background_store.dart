import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

/// Folder of the app that holds the picture drawn behind the month
/// (`<Application Support>/calendar_background/`).
const String calendarBackgroundDirectoryName = 'calendar_background';

/// Biggest file the calendar background accepts (a photo of the gallery).
const int maxCalendarBackgroundBytes = 20 * 1024 * 1024;

/// Whether [name] can name a file of the background folder: one segment of
/// letters, digits, `.`, `_` and `-`, not starting with a dot, without `..`
/// and without a path separator. A name read from the database is untrusted:
/// it can never leave the folder.
bool isSafeCalendarBackgroundName(String name) {
  if (name.isEmpty || name.length > 128) return false;
  if (name.contains('..') || name.contains('/') || name.contains('\\')) {
    return false;
  }
  return RegExp(r'^[A-Za-z0-9_][A-Za-z0-9._-]*$').hasMatch(name);
}

/// Why the background picture could not be stored.
enum CalendarBackgroundProblem { tooLarge }

/// The picture of the calendar background could not be stored.
class CalendarBackgroundException implements Exception {
  const CalendarBackgroundException(this.problem, this.message);

  final CalendarBackgroundProblem problem;
  final String message;

  @override
  String toString() => 'CalendarBackgroundException(${problem.name}): $message';
}

/// The picture drawn behind the month, kept in its own folder of the app.
///
/// The file is written atomically (to a temporary file flushed to disk, then
/// renamed), so a crash never leaves half a picture there; the name carries
/// the moment it was saved so a new one never reuses the cache of an old one.
class CalendarBackgroundStore {
  CalendarBackgroundStore(this.root);

  /// The folder that holds the pictures.
  final Directory root;

  /// Writes [bytes] and returns the name of the file. [stamp] (milliseconds)
  /// makes the name unique, so the image cache of a replaced picture is never
  /// handed back.
  ///
  /// Throws [CalendarBackgroundException] ([CalendarBackgroundProblem.tooLarge])
  /// when the file is bigger than [maxCalendarBackgroundBytes].
  Future<String> save(Uint8List bytes, {required int stamp}) async {
    if (bytes.length > maxCalendarBackgroundBytes) {
      throw CalendarBackgroundException(
        CalendarBackgroundProblem.tooLarge,
        '${bytes.length} bytes',
      );
    }
    await root.create(recursive: true);
    final name = 'bg-$stamp.img';
    final target = File(p.join(root.path, name));
    final temp = File(p.join(root.path, '.bg-$stamp.part'));
    try {
      await temp.writeAsBytes(bytes, flush: true);
      await temp.rename(target.path);
    } catch (_) {
      if (await temp.exists()) await temp.delete();
      rethrow;
    }
    return name;
  }

  /// The file of [name], whether or not it exists.
  File file(String name) => File(p.join(root.path, name));

  /// Whether the file of [name] is there.
  Future<bool> exists(String name) async {
    if (!isSafeCalendarBackgroundName(name)) return false;
    return file(name).exists();
  }

  /// Deletes the file of [name]. Returns whether a file went.
  Future<bool> delete(String name) async {
    if (!isSafeCalendarBackgroundName(name)) return false;
    final target = file(name);
    if (!await target.exists()) return false;
    await target.delete();
    return true;
  }

  /// Deletes every file that is not [keep] (the picture of a replaced
  /// background, or of one that was removed). [keep] may be `null`.
  Future<void> sweep(String? keep) async {
    if (!await root.exists()) return;
    await for (final entity in root.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (name == keep) continue;
      try {
        await entity.delete();
      } on FileSystemException {
        // A file that cannot be deleted stays; the next sweep tries again.
      }
    }
  }
}
