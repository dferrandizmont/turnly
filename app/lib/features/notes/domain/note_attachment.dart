import '../../schedule/domain/civil_date.dart';

/// What a file attached to the note of a day is (schema v6, docs/datos.md).
/// The name is what is stored: never rename or remove a value.
enum AttachmentKind {
  /// A photo taken or picked from the gallery.
  photo,

  /// Any other file (a PDF, a payslip...).
  file,

  /// A drawing made in the app.
  sketch,
}

/// Biggest file an attachment may be (also the most a backup accepts per
/// file).
const int maxAttachmentBytes = 50 * 1024 * 1024;

/// Most bytes the whole store of attachment files may hold (every attachment
/// of every calendar).
///
/// It is below the size a backup container may have
/// (`BackupContainer.maxContainerBytes` is this plus 9 MiB) so a copy of
/// everything the app holds always fits in one container: the JSON of the data
/// (up to 8 MiB compressed) plus the files.
const int maxAttachmentStoreBytes = 128 * 1024 * 1024;

/// Most files the store may hold, one per attachment row. A backup container
/// lists them all (`BackupContainer.maxAttachmentEntries`), so the store never
/// takes more than a copy can carry.
const int maxAttachmentFiles = 2000;

/// Longest MIME type and display name of an attachment.
const int maxAttachmentMimeLength = 255;
const int maxAttachmentNameLength = 255;

/// Longest relative path of an attachment file.
const int maxAttachmentPathLength = 512;

final RegExp _safeId = RegExp(r'^[A-Za-z0-9_-]{1,64}$');
final RegExp _safeSegment = RegExp(r'^[A-Za-z0-9_][A-Za-z0-9._-]{0,127}$');
final RegExp _sha256Hex = RegExp(r'^[0-9a-f]{64}$');
final RegExp _mimeType = RegExp(
  r'^[a-z0-9][a-z0-9!#$&^_.+-]*/[a-z0-9][a-z0-9!#$&^_.+-]*$',
);

/// Whether [id] can name an attachment: 1-64 letters, digits, `_` or `-`.
/// It also names the file inside a backup container (`attachments/<id>`), so
/// nothing else is accepted.
bool isSafeAttachmentId(String id) => _safeId.hasMatch(id);

/// Whether [path] is a safe path **relative to the attachments folder of the
/// app** (`<Application Support>/attachments/`): segments of letters, digits,
/// `.`, `_` and `-` separated by `/`, none starting with a dot (no hidden
/// files), no `..` anywhere (not even inside a name: the table's CHECK
/// refuses it too), no leading `/`, no `\`, at most
/// [maxAttachmentPathLength]. A path read from a backup is untrusted: it can
/// never leave the folder. Always at least as strict as the CHECK of
/// `note_attachments.relative_path`, so what passes here can be inserted.
bool isSafeAttachmentPath(String path) {
  if (path.isEmpty || path.length > maxAttachmentPathLength) return false;
  if (path.contains('..')) return false;
  return path.split('/').every(_safeSegment.hasMatch);
}

/// Why the file of an attachment cannot be used.
enum AttachmentFault {
  /// The file is not in the store.
  missing,

  /// The file is there but its size or SHA-256 is not the row's.
  damaged,

  /// The file is there but could not be read this time (an I/O error, a
  /// permission, a disk that hiccuped). It may be perfectly good: it is never
  /// treated as lost (no row is removed for it, no file is swept for it, and
  /// a restore does not go on without a copy of it).
  unreadable,
}

/// An attachment whose file is missing or damaged: what a copy that skipped
/// it, or a check of the store, reports. Only the id and the fault (never the
/// name of the file or its content).
class BrokenAttachment {
  const BrokenAttachment(this.id, this.fault);

  final String id;
  final AttachmentFault fault;

  @override
  bool operator ==(Object other) =>
      other is BrokenAttachment && other.id == id && other.fault == fault;

  @override
  int get hashCode => Object.hash(id, fault);

  @override
  String toString() => 'BrokenAttachment($id, ${fault.name})';
}

/// Whether [hash] is a lowercase hexadecimal SHA-256.
bool isSha256Hex(String hash) => _sha256Hex.hasMatch(hash);

/// Most copies of the same content the store keeps (`<path>-2` ...
/// `<path>-999`, `AttachmentStore.putCopy`).
const int maxAttachmentCopies = 999;

final RegExp _copySuffix = RegExp(r'^-([1-9][0-9]{0,2})$');

/// The path the store gives the file whose SHA-256 is [hash]:
/// `<hash[0:2]>/<hash>` (the same as `AttachmentStore.pathOfHash`).
String attachmentPathOfHash(String hash) => '${hash.substring(0, 2)}/$hash';

/// Whether [path] is the one the store would give to a file with the
/// (verified) SHA-256 [hash]: `<hash[0:2]>/<hash>`, optionally followed by the
/// suffix `-<n>` (n from 2 to [maxAttachmentCopies]) that
/// `AttachmentStore.putCopy` adds for a second row with the same content.
///
/// The name of a file on disk is a pure function of its verified hash, never
/// something a backup chooses: a crafted file could otherwise plant the bytes
/// of one attachment under the name of another and make later restores fail
/// (or hide the file the user expects).
bool isCanonicalAttachmentPath(String path, String hash) {
  if (!isSha256Hex(hash)) return false;
  final base = attachmentPathOfHash(hash);
  if (path == base) return true;
  if (!path.startsWith(base)) return false;
  final match = _copySuffix.firstMatch(path.substring(base.length));
  if (match == null) return false;
  final n = int.parse(match.group(1)!);
  return n >= 2 && n <= maxAttachmentCopies;
}

/// Whether [name] can be shown as the name of a file: no control characters
/// and none of the Unicode bidirectional formatting characters, which can
/// make a name read as another (a right-to-left override in the middle).
bool isSafeDisplayName(String name) {
  for (final unit in name.codeUnits) {
    if (unit < 0x20 || (unit >= 0x7f && unit <= 0x9f)) return false;
    if (unit == 0x061c ||
        unit == 0x200e ||
        unit == 0x200f ||
        (unit >= 0x2028 && unit <= 0x202e) ||
        (unit >= 0x2066 && unit <= 0x2069)) {
      return false;
    }
  }
  return true;
}

/// Whether [mime] looks like a MIME type (`image/jpeg`), lowercase.
bool isAttachmentMimeType(String mime) =>
    mime.length <= maxAttachmentMimeLength && _mimeType.hasMatch(mime);

/// A file attached to the note of [date] in a calendar (a `note_attachments`
/// row). The bytes live in a file of the app ([relativePath]); this is what
/// the database and the backup know about it. One row per file; the day's
/// `day_entries` row does not need to exist (the attachments live on their
/// own, like the tasks).
class NoteAttachment {
  const NoteAttachment({
    required this.id,
    required this.calendarId,
    required this.date,
    required this.kind,
    required this.relativePath,
    required this.mimeType,
    required this.sizeBytes,
    required this.sha256,
    required this.createdAt,
    this.displayName,
    this.sortOrder = 0,
  });

  final String id;
  final String calendarId;
  final CivilDate date;
  final AttachmentKind kind;

  /// Path of the file inside `<Application Support>/attachments/`
  /// ([isSafeAttachmentPath]).
  final String relativePath;
  final String mimeType;
  final int sizeBytes;

  /// Lowercase hex SHA-256 of the bytes: the backup checks each file against
  /// it.
  final String sha256;

  /// Original name of a picked file (`nomina.pdf`); `null` for photos and
  /// drawings.
  final String? displayName;

  /// Position among the attachments of the day (ascending).
  final int sortOrder;

  /// Milliseconds since the epoch (UTC).
  final int createdAt;

  /// Why this attachment cannot be stored, or `null` when it is valid (the
  /// same rules as the table and the backup).
  String? get problem => _problem(checkSize: true);

  /// The same rules **without** the one of the size: the store of the files
  /// limits the size of a file already (`AttachmentStore.maxFileBytes`) and
  /// refuses it with a better message (`AttachmentProblem.tooLarge`), so
  /// whoever wants to know whether the rest of the metadata is valid asks
  /// here (before writing the file).
  String? get problemWithoutSize => _problem(checkSize: false);

  String? _problem({required bool checkSize}) {
    if (!isSafeAttachmentId(id)) return 'unsafe id';
    if (calendarId.isEmpty) return 'no calendar';
    if (!isSafeAttachmentPath(relativePath)) return 'unsafe path';
    if (isSha256Hex(sha256) &&
        !isCanonicalAttachmentPath(relativePath, sha256)) {
      return 'path does not match the SHA-256';
    }
    if (!isAttachmentMimeType(mimeType)) return 'invalid MIME type';
    if (checkSize && (sizeBytes < 0 || sizeBytes > maxAttachmentBytes)) {
      return 'size out of range';
    }
    if (!isSha256Hex(sha256)) return 'invalid SHA-256';
    final name = displayName;
    if (name != null &&
        (name.trim().isEmpty ||
            name.length > maxAttachmentNameLength ||
            !isSafeDisplayName(name))) {
      return 'invalid display name';
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is NoteAttachment &&
      other.id == id &&
      other.calendarId == calendarId &&
      other.date == date &&
      other.kind == kind &&
      other.relativePath == relativePath &&
      other.mimeType == mimeType &&
      other.sizeBytes == sizeBytes &&
      other.sha256 == sha256 &&
      other.displayName == displayName &&
      other.sortOrder == sortOrder &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(
    id,
    calendarId,
    date,
    kind,
    relativePath,
    mimeType,
    sizeBytes,
    sha256,
    displayName,
    sortOrder,
    createdAt,
  );

  @override
  String toString() => 'NoteAttachment($id, $calendarId $date, ${kind.name})';
}
