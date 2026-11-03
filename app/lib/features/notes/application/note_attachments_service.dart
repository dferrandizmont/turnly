import 'dart:typed_data';

import '../../backup/domain/backup_task_runner.dart';
import '../../schedule/domain/civil_date.dart';
import '../data/attachment_store.dart';
import '../data/note_attachments_repository.dart';
import '../domain/note_attachment.dart';

/// What [NoteAttachmentsService.repair] did.
class AttachmentRepair {
  const AttachmentRepair({required this.removed, required this.remaining});

  /// The attachments whose row was deleted (their file was missing, or
  /// damaged when that was asked).
  final List<BrokenAttachment> removed;

  /// The broken attachments that were left as they are (a damaged file when
  /// only the missing ones were to go).
  final List<BrokenAttachment> remaining;
}

/// The attachments of the notes: the files (in the store) and the rows that
/// say which day each file belongs to.
///
/// The order is always the same, and it is the one that keeps the notes
/// whole:
///
/// - a file is written **before** its row (a row without its file would be a
///   broken note); if the row cannot be written, the file goes away again;
/// - a row is deleted **before** its file, and the file only when no other
///   row uses it.
class NoteAttachmentsService {
  NoteAttachmentsService({
    required this.store,
    required this.repository,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// Where the files live.
  final AttachmentStore store;

  /// The rows.
  final NoteAttachmentsRepository repository;

  final DateTime Function() _now;

  /// The attachments of [date] in [calendarId], in their order.
  Future<List<NoteAttachment>> forDay(String calendarId, CivilDate date) =>
      repository.forDay(calendarId, date);

  /// Every attachment of every calendar.
  Future<List<NoteAttachment>> all() => repository.all();

  /// Adds a file to the note of a day.
  ///
  /// The bytes go to the store first (named after their SHA-256, so the same
  /// content is never stored twice) and the row after them. When another
  /// attachment already uses that file, this one gets a copy of its own: the
  /// path of a row is unique in the table.
  ///
  /// The metadata is checked **before** the file is written: an attachment
  /// that is not valid never leaves a file in the store. The size is not
  /// checked there (the store limits it and says it better: a file that is
  /// too big is an [AttachmentStoreException], not an invalid attachment).
  ///
  /// Throws [AttachmentStoreException] when the file is too big or the store
  /// is full, and [ArgumentError] when the attachment would not be valid
  /// ([NoteAttachment.problem]).
  Future<NoteAttachment> add({
    required String calendarId,
    required CivilDate date,
    required AttachmentKind kind,
    required Uint8List bytes,
    required String mimeType,
    String? displayName,
  }) async {
    final id = repository.newId();
    final sha256 = store.hashOf(bytes);
    final createdAt = _now().toUtc().millisecondsSinceEpoch;
    final draft = NoteAttachment(
      id: id,
      calendarId: calendarId,
      date: date,
      kind: kind,
      relativePath: store.pathOfHash(sha256),
      mimeType: mimeType,
      sizeBytes: bytes.length,
      sha256: sha256,
      displayName: displayName,
      createdAt: createdAt,
    );
    final draftProblem = draft.problemWithoutSize;
    if (draftProblem != null) {
      // Nothing is written: the attachment is not valid.
      throw ArgumentError.value(draft, 'attachment', draftProblem);
    }

    final canonical = draft.relativePath;
    final owner = await repository.byPath(canonical);
    final path = owner == null
        ? await store.put(bytes)
        : await store.putCopy(bytes);
    final attachment = NoteAttachment(
      id: id,
      calendarId: calendarId,
      date: date,
      kind: kind,
      relativePath: path,
      mimeType: mimeType,
      sizeBytes: bytes.length,
      sha256: sha256,
      displayName: displayName,
      createdAt: createdAt,
    );
    final problem = attachment.problem;
    if (problem != null) {
      // The file must not stay alone: no row points at it.
      await _deleteIfUnused(path);
      throw ArgumentError.value(attachment, 'attachment', problem);
    }
    try {
      await repository.save(attachment);
    } catch (_) {
      // The row did not go in: the file must not stay alone.
      await _deleteIfUnused(path);
      rethrow;
    }
    return attachment;
  }

  /// Removes the attachment: its row first, then its file (when no other row
  /// uses it). Returns whether there was something to remove.
  Future<bool> remove(String id) async {
    final attachment = await repository.byId(id);
    if (attachment == null) return false;
    await repository.delete(id);
    await _deleteIfUnused(attachment.relativePath);
    return true;
  }

  /// Deletes the files that no row points at (the leftovers of a deleted
  /// attachment, of a deleted calendar or of a restore that failed) and
  /// returns how many went.
  ///
  /// A file modified less than [minAge] ago is left alone (the sweep of the
  /// start-up passes a minute): a write in progress puts its file in place
  /// before its row.
  Future<int> sweep({Duration minAge = Duration.zero}) async {
    final used = {for (final a in await repository.all()) a.relativePath};
    return store.sweep(used, minAge: minAge);
  }

  /// The bytes of every attachment, by id (unchecked: a backup reads and
  /// verifies them through `BackupRepository.encodeCurrent`).
  Future<Map<String, Uint8List>> bytesById() async {
    final files = <String, Uint8List>{};
    for (final attachment in await repository.all()) {
      files[attachment.id] = await store.read(attachment.relativePath);
    }
    return files;
  }

  /// "Repair attachments": deletes the rows whose file is **missing** (a note
  /// that shows an attachment that cannot be opened, and that every backup
  /// has to skip), and with [removeDamaged] also the ones whose file is not
  /// what the row says (size or SHA-256). Nothing else changes: the files
  /// that are fine, and the damaged files when [removeDamaged] is `false`, stay.
  ///
  /// The files are read and hashed through [runner] (a background isolate by
  /// default), never on the UI isolate. A damaged file whose row went is a
  /// leftover that the next [sweep] removes.
  Future<AttachmentRepair> repair({
    bool removeDamaged = false,
    BackupTaskRunner runner = runInBackgroundIsolate,
  }) async {
    final rows = await repository.all();
    if (rows.isEmpty) {
      return const AttachmentRepair(removed: [], remaining: []);
    }
    final rootPath = store.root.path;
    final refs = <AttachmentFileRef>[
      for (final a in rows)
        (
          id: a.id,
          relativePath: a.relativePath,
          sizeBytes: a.sizeBytes,
          sha256: a.sha256,
        ),
    ];
    final check = await runner(
      () => readVerifiedAttachmentFiles(rootPath, refs, keepBytes: false),
    );
    final removed = <BrokenAttachment>[];
    final remaining = <BrokenAttachment>[];
    for (final broken in check.broken) {
      // A file that is there but could not be read this time is never removed
      // (it may be fine): it stays, and a later repair tries again.
      final remove =
          broken.fault == AttachmentFault.missing ||
          (broken.fault == AttachmentFault.damaged && removeDamaged);
      if (remove) {
        await repository.delete(broken.id);
        removed.add(broken);
      } else {
        remaining.add(broken);
      }
    }
    return AttachmentRepair(removed: removed, remaining: remaining);
  }

  Future<void> _deleteIfUnused(String relativePath) async {
    final owner = await repository.byPath(relativePath);
    if (owner == null) await store.delete(relativePath);
  }
}
