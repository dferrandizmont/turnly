import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/providers.dart';
import '../../schedule/domain/civil_date.dart';
import '../data/attachment_store.dart';
import '../data/day_tasks_repository.dart';
import '../data/note_attachments_repository.dart';
import '../domain/day_task.dart';
import '../domain/note_attachment.dart';
import 'day_task_list.dart';
import 'note_attachments_service.dart';

/// A day of a calendar: the key of the lists of notes (the attachments and
/// the tasks of a day).
class DayKey {
  const DayKey(this.calendarId, this.date);

  final String calendarId;
  final CivilDate date;

  @override
  bool operator ==(Object other) =>
      other is DayKey && other.calendarId == calendarId && other.date == date;

  @override
  int get hashCode => Object.hash(calendarId, date);

  @override
  String toString() => 'DayKey($calendarId $date)';
}

/// The files of the attachments of the notes (the `attachments` folder inside
/// `Application Support`). Tests override it with a temporary folder.
///
/// Without the plugin of the system (a plain unit test) the files go to the
/// temporary folder of the system: the provider must never fail, or every
/// copy of the app would fail with it.
final attachmentStoreProvider = FutureProvider<AttachmentStore>((ref) async {
  final support = await _supportDirectory();
  return AttachmentStore(
    Directory(p.join(support.path, attachmentsDirectoryName)),
  );
});

Future<Directory> _supportDirectory() async {
  try {
    return await getApplicationSupportDirectory();
  } catch (_) {
    return Directory.systemTemp;
  }
}

/// The rows of the attachments of the notes.
final noteAttachmentsRepositoryProvider = Provider<NoteAttachmentsRepository>(
  (ref) => NoteAttachmentsRepository(ref.watch(appDatabaseProvider)),
);

/// The rows of the tasks of the days.
final dayTasksRepositoryProvider = Provider<DayTasksRepository>(
  (ref) => DayTasksRepository(ref.watch(appDatabaseProvider)),
);

/// The attachments of the notes: the files and the rows.
final noteAttachmentsServiceProvider = FutureProvider<NoteAttachmentsService>((
  ref,
) async {
  return NoteAttachmentsService(
    store: await ref.watch(attachmentStoreProvider.future),
    repository: ref.watch(noteAttachmentsRepositoryProvider),
    now: ref.watch(clockProvider),
  );
});

/// The task list of a day, with its undo. It lives as long as the app: the
/// undo of a day must survive the screen that made the change.
final dayTaskListProvider = Provider<DayTaskList>(
  (ref) => DayTaskList(
    ref.watch(dayTasksRepositoryProvider),
    now: ref.watch(clockProvider),
  ),
);

/// Files younger than this are not swept at start-up.
const Duration attachmentSweepMinAge = Duration(minutes: 1);

/// Empties the store of the files that no row points at (the leftovers of a
/// deleted day or calendar, or of a write that failed). It runs once when the
/// app starts and never fails.
final attachmentSweepProvider = FutureProvider<void>((ref) async {
  try {
    final service = await ref.read(noteAttachmentsServiceProvider.future);
    // A file younger than a minute may belong to an attachment being added
    // right now (its file goes in before its row): it is not a leftover.
    await service.sweep(minAge: attachmentSweepMinAge);
  } catch (_) {
    // Housekeeping only.
  }
});

/// The attachments of a day: the list and what can be done with them.
class DayAttachmentsController extends AsyncNotifier<List<NoteAttachment>> {
  DayAttachmentsController(this.key);

  /// The day the list belongs to.
  final DayKey key;

  @override
  Future<List<NoteAttachment>> build() => _read();

  Future<List<NoteAttachment>> _read() => ref
      .read(noteAttachmentsRepositoryProvider)
      .forDay(key.calendarId, key.date);

  /// Adds a file to the note of the day. Throws
  /// [AttachmentStoreException] when the file is too big or the store is
  /// full.
  Future<NoteAttachment> add({
    required AttachmentKind kind,
    required Uint8List bytes,
    required String mimeType,
    String? displayName,
  }) async {
    final service = await ref.read(noteAttachmentsServiceProvider.future);
    final attachment = await service.add(
      calendarId: key.calendarId,
      date: key.date,
      kind: kind,
      bytes: bytes,
      mimeType: mimeType,
      displayName: displayName,
    );
    state = AsyncData(await _read());
    return attachment;
  }

  /// Removes an attachment (its file goes too when nobody else uses it).
  Future<void> remove(String id) async {
    final service = await ref.read(noteAttachmentsServiceProvider.future);
    await service.remove(id);
    state = AsyncData(await _read());
  }
}

/// The attachments of a day.
final dayAttachmentsProvider = AsyncNotifierProvider.autoDispose
    .family<DayAttachmentsController, List<NoteAttachment>, DayKey>(
      DayAttachmentsController.new,
    );

/// The tasks of a day: the list, what can be done with them and the undo.
class DayTasksController extends AsyncNotifier<List<DayTask>> {
  DayTasksController(this.key);

  /// The day the list belongs to.
  final DayKey key;

  @override
  Future<List<DayTask>> build() => _read();

  Future<List<DayTask>> _read() =>
      ref.read(dayTaskListProvider).load(key.calendarId, key.date);

  /// Adds a task at the end of the list of the day.
  Future<void> add(String title) async {
    await ref.read(dayTaskListProvider).add(key.calendarId, key.date, title);
    state = AsyncData(await _read());
  }

  /// Ticks (or unticks) a task.
  Future<void> setDone(String id, {required bool done}) async {
    await ref
        .read(dayTaskListProvider)
        .setDone(id, done: done, calendarId: key.calendarId, date: key.date);
    state = AsyncData(await _read());
  }

  /// Moves a task to [index] in the list (0 = first).
  Future<void> move(String id, int index) async {
    await ref
        .read(dayTaskListProvider)
        .move(key.calendarId, key.date, id, index);
    state = AsyncData(await _read());
  }

  /// Deletes a task.
  Future<void> remove(String id) async {
    await ref
        .read(dayTaskListProvider)
        .remove(id, calendarId: key.calendarId, date: key.date);
    state = AsyncData(await _read());
  }

  /// Puts the list of the day back as it was before its last change.
  Future<bool> undo() async {
    final undone = await ref
        .read(dayTaskListProvider)
        .undo(key.calendarId, key.date);
    state = AsyncData(await _read());
    return undone;
  }

  /// Whether the last change of the day can be undone.
  bool get canUndo =>
      ref.read(dayTaskListProvider).canUndo(key.calendarId, key.date);
}

/// The tasks of a day.
final dayTasksProvider = AsyncNotifierProvider.autoDispose
    .family<DayTasksController, List<DayTask>, DayKey>(DayTasksController.new);
