import 'dart:io';
import 'dart:typed_data';

import 'package:cuadrante/core/database/app_database.dart';
import 'package:cuadrante/features/backup/application/backup_service.dart';
import 'package:cuadrante/features/backup/data/backup_repository.dart';
import 'package:cuadrante/features/backup/data/local_file_backup_store.dart';
import 'package:cuadrante/features/backup/domain/backup_codec.dart';
import 'package:cuadrante/features/backup/domain/backup_container.dart';
import 'package:cuadrante/features/backup/domain/backup_data.dart';
import 'package:cuadrante/features/backup/domain/backup_errors.dart';
import 'package:cuadrante/features/notes/data/attachment_store.dart';
import 'package:cuadrante/features/notes/data/note_attachments_repository.dart';
import 'package:cuadrante/features/notes/domain/note_attachment.dart';
import 'package:cuadrante/features/schedule/domain/civil_date.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'backup_test_support.dart';

const _day = CivilDate(2026, 11, 3);

Uint8List _bytes(List<int> values) => Uint8List.fromList(values);

/// A repository over [db] with the store of the attachments in [store].
BackupRepository _repository(
  AppDatabase db,
  Directory safety, {
  AttachmentStore? store,
  DateTime Function()? now,
}) => BackupRepository(
  db,
  safetyDirectory: safety,
  appVersion: testAppVersion,
  attachmentStore: store,
  now: now ?? () => DateTime.utc(2026, 11, 10, 9),
  runner: runOnThisIsolate,
);

/// An attachment in [db], with its file in [store].
Future<NoteAttachment> _addAttachment(
  AppDatabase db,
  AttachmentStore store, {
  String id = 'att-1',
  Uint8List? bytes,
  CivilDate date = _day,
}) async {
  final content = bytes ?? _bytes([1, 2, 3]);
  final path = await store.put(content);
  final attachment = NoteAttachment(
    id: id,
    calendarId: 'main',
    date: date,
    kind: AttachmentKind.photo,
    relativePath: path,
    mimeType: 'image/jpeg',
    sizeBytes: content.length,
    sha256: store.hashOf(content),
    createdAt: 1000,
  );
  await NoteAttachmentsRepository(db).save(attachment);
  return attachment;
}

void main() {
  late Directory dir;
  late Directory safety;
  late AppDatabase db;
  late AttachmentStore store;
  late BackupRepository repository;
  var dbClosed = false;
  final clock = DateTime.utc(2026, 11, 10, 9);

  setUp(() {
    dir = makeTempDir('backup-attachments');
    safety = Directory(p.join(dir.path, 'backups'));
    db = openMemoryDatabase();
    dbClosed = false;
    store = AttachmentStore(Directory(p.join(dir.path, 'attachments')));
    repository = _repository(db, safety, store: store, now: () => clock);
  });
  tearDown(() async {
    if (!dbClosed) await db.close();
  });

  group('a copy with attachments', () {
    test('is a container that carries the files', () async {
      final attachment = await _addAttachment(db, store);
      final data = await repository.readAll();
      expect(data.noteAttachments, hasLength(1));

      const codec = BackupCodec();
      final files = await repository.attachmentBytes(data);
      expect(files.keys, [attachment.id]);
      final bytes = codec.encode(
        data,
        appVersion: testAppVersion,
        exportedAt: clock,
        attachmentFiles: files,
      );
      expect(BackupContainer.looksLikeContainer(bytes), isTrue);

      final file = codec.decode(bytes);
      expect(file.data.noteAttachments.single.id, attachment.id);
      expect(file.attachmentFiles[attachment.id], _bytes([1, 2, 3]));
    });

    test('of a database without attachments is still a plain file', () async {
      final data = await repository.readAll();
      final files = await repository.attachmentBytes(data);
      expect(files, isEmpty);
      final bytes = const BackupCodec().encode(
        data,
        appVersion: testAppVersion,
        exportedAt: clock,
        attachmentFiles: files,
      );
      expect(BackupContainer.looksLikeContainer(bytes), isFalse);
    });

    test('fails visibly when a file is not there', () async {
      final attachment = await _addAttachment(db, store);
      await store.delete(attachment.relativePath);
      await expectLater(
        repository.attachmentBytes(await repository.readAll()),
        throwsA(isA<CorruptBackup>()),
      );
    });

    test('fails visibly when a file is not what its row says', () async {
      final attachment = await _addAttachment(db, store);
      // Another content at the same path (the store would not do it: the row
      // and the file have to agree).
      final path = p.joinAll([
        store.root.path,
        ...attachment.relativePath.split('/'),
      ]);
      await File(path).writeAsBytes(_bytes([9, 9, 9]));
      await expectLater(
        repository.attachmentBytes(await repository.readAll()),
        throwsA(isA<CorruptBackup>()),
      );
    });
  });

  group('a restore with attachments', () {
    late AppDatabase other;
    late AttachmentStore otherStore;
    late BackupRepository otherRepository;

    setUp(() {
      other = openMemoryDatabase();
      otherStore = AttachmentStore(
        Directory(p.join(dir.path, 'other-attachments')),
      );
      otherRepository = _repository(
        other,
        Directory(p.join(dir.path, 'other-backups')),
        store: otherStore,
        now: () => clock,
      );
    });
    tearDown(() => other.close());

    test('puts the rows and the files back', () async {
      final attachment = await _addAttachment(db, store);
      const codec = BackupCodec();
      final data = await repository.readAll();
      final bytes = codec.encode(
        data,
        appVersion: testAppVersion,
        exportedAt: clock,
        attachmentFiles: await repository.attachmentBytes(data),
      );

      final file = codec.decode(bytes);
      await otherRepository.restore(
        file.data,
        attachmentFiles: file.attachmentFiles,
      );

      final rows = await NoteAttachmentsRepository(other).all();
      expect(rows.single.id, attachment.id);
      expect(rows.single.relativePath, attachment.relativePath);
      expect(
        await otherStore.read(rows.single.relativePath),
        _bytes([1, 2, 3]),
      );
    });

    test('goes through the service, like the screen does', () async {
      final attachment = await _addAttachment(db, store);
      final service = BackupService(
        repository: repository,
        store: LocalFileBackupStore(Directory(p.join(dir.path, 'copies'))),
        appVersion: testAppVersion,
        runner: runOnThisIsolate,
        now: () => clock,
      );
      final bytes = await service.exportBytes();
      final pending = await service.inspect(bytes);
      expect(pending.file.attachmentFiles.keys, [attachment.id]);

      final otherService = BackupService(
        repository: otherRepository,
        store: LocalFileBackupStore(Directory(p.join(dir.path, 'copies2'))),
        appVersion: testAppVersion,
        runner: runOnThisIsolate,
        now: () => clock,
      );
      await otherService.restore(pending);
      final rows = await NoteAttachmentsRepository(other).all();
      expect(rows.single.id, attachment.id);
      expect(
        await otherStore.read(rows.single.relativePath),
        _bytes([1, 2, 3]),
      );
    });

    test('writes the safety copy before touching anything', () async {
      // The database that is going to be restored has an attachment of its
      // own: the safety copy has to carry it.
      await _addAttachment(other, otherStore, id: 'att-own', bytes: _bytes([5]));
      await _addAttachment(db, store, id: 'att-new');
      const codec = BackupCodec();
      final data = await repository.readAll();
      final bytes = codec.encode(
        data,
        appVersion: testAppVersion,
        exportedAt: clock,
        attachmentFiles: await repository.attachmentBytes(data),
      );
      final file = codec.decode(bytes);
      await otherRepository.restore(
        file.data,
        attachmentFiles: file.attachmentFiles,
      );

      final copies = fileNames(Directory(p.join(dir.path, 'other-backups')));
      expect(copies, hasLength(1));
      expect(copies.single, startsWith('pre-restore-'));
      // The safety copy carries the attachments too.
      final safetyBytes = await File(
        p.join(dir.path, 'other-backups', copies.single),
      ).readAsBytes();
      expect(BackupContainer.looksLikeContainer(safetyBytes), isTrue);
      final safetyFile = codec.decode(safetyBytes);
      expect(safetyFile.data.noteAttachments.single.id, 'att-own');
      expect(safetyFile.attachmentFiles['att-own'], _bytes([5]));

      // And the database now has the attachment of the copy.
      final rows = await NoteAttachmentsRepository(other).all();
      expect(rows.single.id, 'att-new');
      expect(await otherStore.read(rows.single.relativePath), _bytes([1, 2, 3]));
    });

    test('deletes the files of the data it replaced', () async {
      final old = await _addAttachment(db, store, id: 'att-old');
      expect(await store.list(), hasLength(1));

      // A copy of a database without attachments: the restore replaces
      // everything, so the old file is left with nothing pointing at it.
      final data = await repository.readAll();
      const codec = BackupCodec();
      final plain = codec.encode(
        BackupData(calendars: data.calendars),
        appVersion: testAppVersion,
        exportedAt: clock,
      );
      final file = codec.decode(plain);
      await repository.restore(file.data);

      expect(await NoteAttachmentsRepository(db).all(), isEmpty);
      expect(await store.list(), isEmpty);
      expect(old.relativePath, isNotEmpty);
    });

    test('a file that does not match its row stops everything', () async {
      await _addAttachment(db, store);
      const codec = BackupCodec();
      final data = await repository.readAll();
      final good = codec.encode(
        data,
        appVersion: testAppVersion,
        exportedAt: clock,
        attachmentFiles: await repository.attachmentBytes(data),
      );
      // The same copy with another file: the SHA-256 does not match.
      final opened = BackupContainer.decode(good);
      final tampered = BackupContainer.encode(
        backup: opened.backup,
        files: {'att-1': _bytes([7, 7, 7])},
      );
      expect(() => codec.decode(tampered), throwsA(isA<CorruptBackup>()));

      // Nothing was restored.
      expect(await NoteAttachmentsRepository(other).all(), isEmpty);
      expect(await otherStore.list(), isEmpty);
    });

    test('a cut file is refused and nothing changes', () async {
      await _addAttachment(db, store);
      const codec = BackupCodec();
      final data = await repository.readAll();
      final good = codec.encode(
        data,
        appVersion: testAppVersion,
        exportedAt: clock,
        attachmentFiles: await repository.attachmentBytes(data),
      );
      final cut = Uint8List.sublistView(good, 0, good.length - 20);
      expect(() => codec.decode(cut), throwsA(isA<BackupException>()));
      expect(await NoteAttachmentsRepository(other).all(), isEmpty);
    });

    test('a store that cannot hold the file changes nothing', () async {
      final attachment = await _addAttachment(db, store);
      final full = AttachmentStore(
        Directory(p.join(dir.path, 'full')),
        maxTotalBytes: 1,
      );
      final fullRepository = _repository(
        other,
        Directory(p.join(dir.path, 'other-backups')),
        store: full,
        now: () => clock,
      );
      const codec = BackupCodec();
      final data = await repository.readAll();
      final bytes = codec.encode(
        data,
        appVersion: testAppVersion,
        exportedAt: clock,
        attachmentFiles: await repository.attachmentBytes(data),
      );
      final file = codec.decode(bytes);

      await expectLater(
        fullRepository.restore(
          file.data,
          attachmentFiles: file.attachmentFiles,
        ),
        throwsA(anything),
      );
      // Nothing was written and nothing was left behind.
      expect(await NoteAttachmentsRepository(other).all(), isEmpty);
      expect(await full.list(), isEmpty);
      expect(attachment.relativePath, isNotEmpty);
    });

    test('a store that fills up with the second file leaves no trash', () async {
      await _addAttachment(db, store, id: 'att-1', bytes: _bytes(List.filled(8, 1)));
      await _addAttachment(db, store, id: 'att-2', bytes: _bytes(List.filled(8, 2)));
      const codec = BackupCodec();
      final data = await repository.readAll();
      final bytes = codec.encode(
        data,
        appVersion: testAppVersion,
        exportedAt: clock,
        attachmentFiles: await repository.attachmentBytes(data),
      );
      final file = codec.decode(bytes);

      // The store of the phone that restores holds one of the two files, but
      // not the two.
      final targetStore = AttachmentStore(
        Directory(p.join(dir.path, 'target-attachments')),
        maxTotalBytes: 12,
      );
      final targetRepository = _repository(
        other,
        Directory(p.join(dir.path, 'other-backups')),
        store: targetStore,
        now: () => clock,
      );
      final before = await dumpAllTables(other);

      await expectLater(
        targetRepository.restore(
          file.data,
          attachmentFiles: file.attachmentFiles,
        ),
        throwsA(
          isA<AttachmentStoreException>().having(
            (e) => e.problem,
            'problem',
            AttachmentProblem.storeFull,
          ),
        ),
      );
      // The file that was written before the store filled up is gone: a
      // restore that fails leaves no trash.
      expect(await targetStore.list(), isEmpty);
      // And the database was not touched.
      expect(await dumpAllTables(other), before);
    });

    test('a restore that fails leaves no file behind', () async {
      final attachment = await _addAttachment(db, store);
      final data = await repository.readAll();
      final files = await repository.attachmentBytes(data);

      // The store of the phone that restores: it starts empty.
      final targetStore = AttachmentStore(
        Directory(p.join(dir.path, 'target-attachments')),
      );
      var closed = false;
      final failing = BackupRepository(
        db,
        safetyDirectory: safety,
        appVersion: testAppVersion,
        attachmentStore: targetStore,
        now: () => clock,
        runner: runOnThisIsolate,
        // The database goes away right after the safety copy is written: the
        // transaction of the restore cannot finish.
        readSafetyCopy: (file) async {
          final bytes = await file.readAsBytes();
          if (!closed) {
            closed = true;
            dbClosed = true;
            await db.close();
          }
          return bytes;
        },
      );

      await expectLater(
        failing.restore(data, attachmentFiles: files),
        throwsA(anything),
      );
      // The file that was written for the rows is gone: nothing is left.
      expect(await targetStore.list(), isEmpty);
      expect(attachment.relativePath, isNotEmpty);
    });

    test('a copy without the files of its rows is refused', () async {
      await _addAttachment(db, store);
      final data = await repository.readAll();
      await expectLater(
        otherRepository.restore(data),
        throwsA(isA<CorruptBackup>()),
      );
      expect(await NoteAttachmentsRepository(other).all(), isEmpty);
    });
  });
}
