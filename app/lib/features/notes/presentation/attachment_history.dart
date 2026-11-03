import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/notes_providers.dart';
import '../domain/note_attachment.dart';

/// An attachment that was taken off a day, with the bytes that were read
/// before its file went away: the undo puts the very same file back.
class RemovedAttachment {
  const RemovedAttachment({required this.attachment, required this.bytes});

  /// The row as it was.
  final NoteAttachment attachment;

  /// The bytes of the file, read before it was deleted.
  final Uint8List bytes;
}

/// The last attachment removed from each day: the «Deshacer» of the section
/// puts it back.
///
/// It lives as long as the app (the undo of a day must survive the screen
/// that made the change), like the history of the tasks
/// (`dayTaskListProvider`).
final dayAttachmentHistoryProvider =
    NotifierProvider<DayAttachmentHistory, Map<String, RemovedAttachment>>(
      DayAttachmentHistory.new,
    );

/// The removals of the days, by day.
class DayAttachmentHistory extends Notifier<Map<String, RemovedAttachment>> {
  @override
  Map<String, RemovedAttachment> build() => const {};

  /// What was removed from [key] last (`null` when there is nothing to undo).
  RemovedAttachment? lastOf(DayKey key) => state[attachmentHistoryKey(key)];

  /// Remembers what was removed from [key].
  void remember(DayKey key, RemovedAttachment removed) {
    state = {...state, attachmentHistoryKey(key): removed};
  }

  /// Forgets the removal of [key] (the undo put it back).
  void forget(DayKey key) {
    final next = {...state}..remove(attachmentHistoryKey(key));
    state = next;
  }
}

/// The key of a day in the history of the removals.
String attachmentHistoryKey(DayKey key) => '${key.calendarId}|${key.date}';
