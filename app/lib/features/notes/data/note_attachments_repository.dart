import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../schedule/domain/civil_date.dart';
import '../domain/note_attachment.dart';

extension NoteAttachmentRowMapper on NoteAttachmentRow {
  NoteAttachment toAttachment() => NoteAttachment(
    id: id,
    calendarId: calendarId,
    date: date,
    kind: kind,
    relativePath: relativePath,
    mimeType: mimeType,
    sizeBytes: sizeBytes,
    sha256: sha256,
    displayName: displayName,
    sortOrder: sortOrder,
    createdAt: createdAt,
  );
}

extension NoteAttachmentMapper on NoteAttachment {
  NoteAttachmentsCompanion toCompanion() => NoteAttachmentsCompanion.insert(
    id: id,
    calendarId: calendarId,
    date: date,
    kind: kind,
    relativePath: relativePath,
    mimeType: mimeType,
    sizeBytes: sizeBytes,
    sha256: sha256,
    displayName: Value(displayName),
    sortOrder: Value(sortOrder),
    createdAt: createdAt,
  );
}

/// The `note_attachments` rows (schema v6). Only the database side: the
/// files themselves are written and deleted by the attachment store (P2),
/// which calls this after the file is safely in place (and before deleting
/// it).
class NoteAttachmentsRepository {
  NoteAttachmentsRepository(this._db, {String Function()? newId})
    : _newId = newId ?? (() => 'att-${const Uuid().v4()}');

  final AppDatabase _db;
  final String Function() _newId;

  /// A fresh id for a new attachment ([isSafeAttachmentId]).
  String newId() => _newId();

  /// The attachments of [date] in [calendarId], in their order.
  Future<List<NoteAttachment>> forDay(String calendarId, CivilDate date) =>
      _ordered(
        (t) => t.calendarId.equals(calendarId) & t.date.equals(date.toIso()),
      );

  /// The attachments of [calendarId] from [from] to [to] (both included), by
  /// day and then in their order.
  Future<List<NoteAttachment>> inRange(
    String calendarId,
    CivilDate from,
    CivilDate to,
  ) => _ordered(
    (t) =>
        t.calendarId.equals(calendarId) &
        t.date.isBetweenValues(from.toIso(), to.toIso()),
  );

  /// Every attachment of every calendar.
  Future<List<NoteAttachment>> all() => _ordered((_) => const Constant(true));

  Future<NoteAttachment?> byId(String id) async {
    final row = await (_db.select(
      _db.noteAttachments,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row?.toAttachment();
  }

  /// The attachment whose file is at [relativePath], or `null` when there is
  /// none (the path of a row is unique: two rows cannot share a file).
  Future<NoteAttachment?> byPath(String relativePath) async {
    final row = await (_db.select(
      _db.noteAttachments,
    )..where((t) => t.relativePath.equals(relativePath))).getSingleOrNull();
    return row?.toAttachment();
  }

  /// Inserts or replaces [attachment] (by id). Throws [ArgumentError] when it
  /// is not valid ([NoteAttachment.problem]), without writing; a calendar
  /// that does not exist or a path already used by another attachment fail
  /// in the database.
  Future<void> save(NoteAttachment attachment) async {
    final problem = attachment.problem;
    if (problem != null) {
      throw ArgumentError.value(attachment, 'attachment', problem);
    }
    await _db
        .into(_db.noteAttachments)
        .insertOnConflictUpdate(attachment.toCompanion());
  }

  /// Removes the row of [id] (nothing if there is none). Returns whether a
  /// row went.
  Future<bool> delete(String id) async =>
      await (_db.delete(
        _db.noteAttachments,
      )..where((t) => t.id.equals(id))).go() >
      0;

  Future<List<NoteAttachment>> _ordered(
    Expression<bool> Function($NoteAttachmentsTable t) filter,
  ) async {
    final rows =
        await (_db.select(_db.noteAttachments)
              ..where(filter)
              ..orderBy([
                (t) => OrderingTerm.asc(t.date),
                (t) => OrderingTerm.asc(t.sortOrder),
                (t) => OrderingTerm.asc(t.createdAt),
                (t) => OrderingTerm.asc(t.id),
              ]))
            .get();
    return [for (final row in rows) row.toAttachment()];
  }
}
