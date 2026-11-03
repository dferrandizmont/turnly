import 'dart:io';

import 'package:cuadrante/core/database/app_database.dart';
import 'package:cuadrante/features/backup/data/platform_backup_channel.dart';
import 'package:cuadrante/features/backup/application/backup_providers.dart';
import 'package:cuadrante/features/backup/application/backup_service.dart';
import 'package:cuadrante/features/backup/application/folder_backup_engine.dart';
import 'package:cuadrante/features/backup/data/backup_repository.dart';
import 'package:cuadrante/features/backup/data/folder_backup_channel.dart';
import 'package:cuadrante/features/backup/data/folder_backup_state_store.dart';
import 'package:cuadrante/features/backup/data/folder_backup_task.dart';
import 'package:cuadrante/features/backup/data/local_file_backup_store.dart';
import 'package:cuadrante/features/backup/domain/backup_codec.dart';
import 'package:cuadrante/features/backup/domain/backup_container.dart';
import 'package:cuadrante/features/backup/domain/backup_data.dart';
import 'package:cuadrante/features/backup/domain/backup_errors.dart';
import 'package:cuadrante/features/backup/domain/folder_backup.dart';
import 'package:cuadrante/features/notes/application/note_attachments_service.dart';
import 'package:cuadrante/features/notes/application/notes_providers.dart';
import 'package:cuadrante/features/notes/data/attachment_store.dart';
import 'package:cuadrante/features/notes/data/note_attachments_repository.dart';
import 'package:cuadrante/features/notes/domain/note_attachment.dart';
import 'package:cuadrante/features/schedule/domain/civil_date.dart';
import 'package:file_selector/file_selector.dart' show XFile;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'backup_test_support.dart';

// The security review of P2 (docs/revisiones/2026-11-02-seguridad-p2-notas.md):
// the caps of the import and export, the name of a file as a function of its
// hash, the hashing off the UI isolate, and copies and restores that go on
// when an attachment's file is lost.

const _day = CivilDate(2026, 11, 3);
final _clock = DateTime.utc(2026, 11, 10, 9);

Uint8List _bytes(List<int> values) => Uint8List.fromList(values);

/// Incompressible-looking bytes of [length] (so the size is what counts).
Uint8List _noise(int length, {int seed = 1}) {
  final out = Uint8List(length);
  var x = seed * 2654435761 & 0xffffffff;
  for (var i = 0; i < length; i++) {
    x = (x * 1103515245 + 12345) & 0x7fffffff;
    out[i] = (x >> 16) & 0xff;
  }
  return out;
}

Future<NoteAttachment> _addAttachment(
  AppDatabase db,
  AttachmentStore store, {
  String id = 'att-1',
  Uint8List? bytes,
  bool copy = false,
}) async {
  final content = bytes ?? _bytes([1, 2, 3]);
  final path = copy ? await store.putCopy(content) : await store.put(content);
  final attachment = NoteAttachment(
    id: id,
    calendarId: 'main',
    date: _day,
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

/// The path ends of the files whose read fails in [_flakyRead].
final Set<String> _flaky = {};

/// A read that fails (an I/O error, not a missing file) for the files in
/// [_flaky] and works for the rest.
Uint8List _flakyRead(File file) {
  if (_flaky.any((end) => file.path.endsWith(end))) {
    throw FileSystemException('Input/output error', file.path);
  }
  return file.readAsBytesSync();
}

File _fileOf(AttachmentStore store, NoteAttachment a) =>
    File(p.joinAll([store.root.path, ...a.relativePath.split('/')]));

void main() {
  late Directory dir;
  late AppDatabase db;
  late AttachmentStore store;
  late BackupRepository repository;
  late int runs;

  Future<R> counting<R>(R Function() task) async {
    runs++;
    return task();
  }

  BackupRepository repositoryOver(
    AppDatabase database,
    AttachmentStore attachments,
    String backups,
  ) => BackupRepository(
    database,
    safetyDirectory: Directory(p.join(dir.path, backups)),
    appVersion: testAppVersion,
    attachmentStore: attachments,
    now: () => _clock,
    runner: counting,
  );

  BackupService serviceOver(BackupRepository repo, String copies) =>
      BackupService(
        repository: repo,
        store: LocalFileBackupStore(Directory(p.join(dir.path, copies))),
        appVersion: testAppVersion,
        runner: counting,
        now: () => _clock,
      );

  setUp(() {
    dir = makeTempDir('backup-attachment-security');
    db = openMemoryDatabase();
    store = AttachmentStore(Directory(p.join(dir.path, 'attachments')));
    repository = repositoryOver(db, store, 'backups');
    runs = 0;
  });
  tearDown(() => db.close());

  group('HIGH: one cap for every import and export path', () {
    test('the caps are consistent with the container and the store', () {
      expect(BackupCodec.maxFileBytes, 8 * 1024 * 1024);
      expect(
        BackupContainer.maxContainerBytes,
        maxAttachmentStoreBytes +
            BackupCodec.maxFileBytes +
            BackupContainer.zipOverheadBytes,
      );
      expect(BackupCodec.maxImportBytes, BackupContainer.maxContainerBytes);
      expect(BackupCodec.maxImportBytes, greaterThan(maxAttachmentStoreBytes));
      expect(BackupContainer.maxAttachmentEntries, maxAttachmentFiles);
      expect(maxAttachmentFiles, 2000);
      // A plain file stays at 8 MiB; a ZIP may go up to the import cap.
      final zip = [0x50, 0x4b, 0x03, 0x04];
      expect(
        BackupCodec.fitsImportLimit(BackupCodec.maxFileBytes, [0]),
        isTrue,
      );
      expect(
        BackupCodec.fitsImportLimit(BackupCodec.maxFileBytes + 1, [0, 0, 0, 0]),
        isFalse,
      );
      expect(
        BackupCodec.fitsImportLimit(BackupCodec.maxFileBytes + 1, zip),
        isTrue,
      );
      expect(
        BackupCodec.fitsImportLimit(BackupCodec.maxImportBytes + 1, zip),
        isFalse,
      );
    });

    test('a copy with a 9 MiB photo round-trips: encode, picked file, '
        'inspect and restore', () async {
      final photo = _noise(9 * 1024 * 1024);
      final attachment = await _addAttachment(db, store, bytes: photo);
      final service = serviceOver(repository, 'copies');

      final bytes = await service.exportBytes();
      expect(bytes.length, greaterThan(BackupCodec.maxFileBytes));
      expect(BackupContainer.looksLikeContainer(bytes), isTrue);

      // The file picker: the 9 MiB container is read, the same size of
      // anything else is not.
      final file = File(p.join(dir.path, 'picked.turnly'))
        ..writeAsBytesSync(bytes);
      final picked = await readPickedBackupFile(XFile(file.path));
      expect(picked.problem, isNull);
      expect(picked.bytes, bytes);
      final plain = File(p.join(dir.path, 'plain.turnly'))
        ..writeAsBytesSync(Uint8List(9 * 1024 * 1024));
      expect(
        (await readPickedBackupFile(XFile(plain.path))).problem,
        IncomingFileProblem.tooLarge,
      );

      // The preview and the restore into another phone.
      final other = openMemoryDatabase();
      addTearDown(other.close);
      final otherStore = AttachmentStore(
        Directory(p.join(dir.path, 'other-attachments')),
      );
      final otherService = serviceOver(
        repositoryOver(other, otherStore, 'other-backups'),
        'copies2',
      );
      final pending = await otherService.inspect(picked.bytes!);
      expect(pending.file.attachmentFiles[attachment.id], photo);
      await otherService.restore(pending);
      final rows = await NoteAttachmentsRepository(other).all();
      expect(rows.single.id, attachment.id);
      expect(await otherStore.read(rows.single.relativePath), photo);
    });

    test(
      'the folder copy writes, lists and reads back a 9 MiB container',
      () async {
        final photo = _noise(9 * 1024 * 1024, seed: 2);
        await _addAttachment(db, store, bytes: photo);

        // The platform side, in memory, behind the real Dart channel class.
        const channel = MethodChannel('test/folder-9mib');
        final files = <String, ({String name, Uint8List bytes})>{};
        TestWidgetsFlutterBinding.ensureInitialized();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              final args = (call.arguments as Map?) ?? const {};
              switch (call.method) {
                case 'check':
                  return {'state': 'ok', 'name': 'Copias'};
                case 'list':
                  return [
                    for (final e in files.entries)
                      {
                        'id': e.key,
                        'name': e.value.name,
                        'sizeBytes': e.value.bytes.length,
                        'modifiedAtMs': _clock.millisecondsSinceEpoch,
                      },
                  ];
                case 'write':
                  final name = args['name']! as String;
                  final bytes = args['bytes']! as Uint8List;
                  files['doc-${files.length + 1}'] = (name: name, bytes: bytes);
                  return {
                    'id': 'doc-${files.length}',
                    'name': name,
                    'sizeBytes': bytes.length,
                  };
                case 'read':
                  return files[args['id']]!.bytes;
                case 'delete':
                  files.remove(args['id']);
                  return null;
              }
              return null;
            });
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(channel, null),
        );

        final states = FolderBackupStateStore(
          File(p.join(dir.path, folderBackupStateFileName)),
        );
        await states.save(
          const FolderBackupState().withFolder('content://t/tree', 'Copias'),
        );
        final engine = FolderBackupEngine(
          platform: const MethodChannelFolderBackupPlatform(channel: channel),
          states: states,
          now: () => _clock,
          payload: () => folderPayloadFrom(
            db,
            support: dir,
            appVersion: testAppVersion,
            at: _clock,
          ),
        );
        // The store lives in `<support>/attachments`, where the task reads it.
        Directory(p.join(dir.path, 'attachments')).existsSync();
        final outcome = await engine.run(FolderBackupTrigger.manual);

        expect(outcome.kind, FolderBackupOutcomeKind.saved, reason: '$outcome');
        expect(outcome.warnings, isEmpty);
        final written = files.values.single.bytes;
        expect(written.length, greaterThan(BackupCodec.maxFileBytes));
        final decoded = const BackupCodec().decode(written);
        expect(decoded.attachmentFiles.values.single, photo);
      },
    );
  });

  group('MEDIUM: the name on disk is a function of the verified hash', () {
    BackupNoteAttachment row(String path, Uint8List bytes) =>
        BackupNoteAttachment(
          id: 'att-1',
          calendarId: 'main',
          date: _day,
          kind: AttachmentKind.photo,
          relativePath: path,
          mimeType: 'image/jpeg',
          sizeBytes: bytes.length,
          sha256: store.hashOf(bytes),
          createdAt: 1,
        );

    test('validate refuses a path that is not the hash of the file', () {
      final x = _bytes([1, 2, 3]);
      final y = _bytes([9, 9, 9]);
      final canonical = store.pathOf(x);
      expect(
        BackupData(noteAttachments: [row(canonical, x)]).validate,
        returnsNormally,
      );
      expect(
        BackupData(noteAttachments: [row('$canonical-2', x)]).validate,
        returnsNormally,
      );
      for (final path in [
        store.pathOf(y), // the name of another file
        'ab/cd',
        'main/att-1.bin',
        '$canonical-1',
        '$canonical-1000',
        '${canonical}x',
      ]) {
        expect(
          BackupData(noteAttachments: [row(path, x)]).validate,
          throwsA(isA<CorruptBackup>()),
          reason: path,
        );
      }
    });

    test('a restore with a planted name writes nothing', () async {
      final x = _bytes([1, 2, 3]);
      final y = _bytes([9, 9, 9]);
      // Content X under the name of Y.
      final crafted = BackupData(noteAttachments: [row(store.pathOf(y), x)]);
      final target = AttachmentStore(Directory(p.join(dir.path, 'target')));
      final other = openMemoryDatabase();
      addTearDown(other.close);
      final repo = repositoryOver(other, target, 'target-backups');
      final before = await dumpAllTables(other);

      await expectLater(
        repo.restore(crafted, attachmentFiles: {'att-1': x}),
        throwsA(isA<CorruptBackup>()),
      );
      expect(await target.list(), isEmpty);
      expect(await dumpAllTables(other), before);
      // The codec does not write such a file either.
      expect(
        () => const BackupCodec().encode(
          crafted,
          appVersion: testAppVersion,
          exportedAt: _clock,
          attachmentFiles: {'att-1': x},
        ),
        throwsA(isA<CorruptBackup>()),
      );
    });

    test('the copy putCopy makes of a second row is accepted', () async {
      final first = await _addAttachment(db, store);
      final second = await _addAttachment(db, store, id: 'att-2', copy: true);
      expect(second.relativePath, '${first.relativePath}-2');
      final data = await repository.readAll();
      expect(data.validate, returnsNormally);
      final bytes = (await repository.encodeCurrent(data, at: _clock)).bytes;
      final file = const BackupCodec().decode(bytes);
      expect(file.data.noteAttachments, hasLength(2));
    });
  });

  group('MEDIUM: no SHA-256 of the store on the UI isolate', () {
    test('reading and checking the files goes through the runner', () async {
      await _addAttachment(db, store);
      final data = await repository.readAll();
      runs = 0;
      final files = await repository.attachmentBytes(data);
      expect(files, hasLength(1));
      expect(runs, 1);

      runs = 0;
      final encoding = await repository.encodeCurrent(data, at: _clock);
      // One job reads, checks and encodes.
      expect(runs, 1);
      expect(encoding.warnings, isEmpty);
    });

    test('a restore of a decoded file does not hash the files again; one '
        'that was not decoded is hashed through the runner', () async {
      final attachment = await _addAttachment(db, store);
      final data = await repository.readAll();
      final files = await repository.attachmentBytes(data);

      final target = AttachmentStore(Directory(p.join(dir.path, 'target')));
      final other = openMemoryDatabase();
      addTearDown(other.close);
      final repo = repositoryOver(other, target, 'target-backups');

      runs = 0;
      await repo.restore(data, attachmentFiles: files, verified: true);
      final verifiedRuns = runs;
      expect(await target.list(), [attachment.relativePath]);

      final again = openMemoryDatabase();
      addTearDown(again.close);
      final target2 = AttachmentStore(Directory(p.join(dir.path, 'target2')));
      final repo2 = repositoryOver(again, target2, 'target2-backups');
      runs = 0;
      await repo2.restore(data, attachmentFiles: files);
      // One more job: the SHA-256 of the files.
      expect(runs, verifiedRuns + 1);

      // And a file that is not what its row says is refused, nothing written.
      final tampered = openMemoryDatabase();
      addTearDown(tampered.close);
      final target3 = AttachmentStore(Directory(p.join(dir.path, 'target3')));
      final repo3 = repositoryOver(tampered, target3, 'target3-backups');
      await expectLater(
        repo3.restore(
          data,
          attachmentFiles: {
            attachment.id: _bytes([3, 2, 1]),
          },
        ),
        throwsA(isA<CorruptBackup>()),
      );
      expect(await target3.list(), isEmpty);
    });
  });

  group('MEDIUM: a lost file does not block copies or restores', () {
    late NoteAttachment good;
    late NoteAttachment gone;
    late NoteAttachment damaged;

    setUp(() async {
      good = await _addAttachment(db, store, id: 'a-good', bytes: _bytes([1]));
      gone = await _addAttachment(db, store, id: 'a-gone', bytes: _bytes([2]));
      damaged = await _addAttachment(
        db,
        store,
        id: 'a-damaged',
        bytes: _bytes([3]),
      );
      await store.delete(gone.relativePath);
      _fileOf(store, damaged).writeAsBytesSync([7, 7, 7]);
    });

    List<BrokenAttachment> skipped(List<BackupWarning> warnings) =>
        (warnings.single as AttachmentsSkipped).attachments;

    test('the manual export is strict and says which attachments are '
        'broken', () async {
      final service = serviceOver(repository, 'copies');
      await expectLater(
        service.exportBytes(),
        throwsA(
          isA<BrokenAttachments>().having(
            (e) => e.attachments,
            'attachments',
            unorderedEquals([
              const BrokenAttachment('a-gone', AttachmentFault.missing),
              const BrokenAttachment('a-damaged', AttachmentFault.damaged),
            ]),
          ),
        ),
      );
      // Still a CorruptBackup for whoever only knows that.
      await expectLater(service.exportBytes(), throwsA(isA<CorruptBackup>()));
      // Nothing was changed.
      expect(await NoteAttachmentsRepository(db).all(), hasLength(3));
    });

    test(
      'the lenient export leaves them out, keeps their rows and warns',
      () async {
        final service = serviceOver(repository, 'copies');
        final encoding = await service.exportDetailed();
        expect(
          skipped(encoding.warnings),
          unorderedEquals([
            const BrokenAttachment('a-gone', AttachmentFault.missing),
            const BrokenAttachment('a-damaged', AttachmentFault.damaged),
          ]),
        );
        final file = const BackupCodec().decode(encoding.bytes);
        expect(file.data.noteAttachments.map((a) => a.id), ['a-good']);
        expect(file.attachmentFiles['a-good'], _bytes([1]));
        // The rows are still in the database: only a repair removes them.
        expect(await NoteAttachmentsRepository(db).all(), hasLength(3));
        expect(good.id, 'a-good');
      },
    );

    test('the automatic copy is made and says what it left out', () async {
      final service = serviceOver(repository, 'copies');
      final entry = await service.backupNow();
      expect(entry.sizeBytes, greaterThan(0));
      expect(skipped(service.lastWarnings), hasLength(2));
      // The copy on the phone reads back with the attachment that was whole.
      final stored = await LocalFileBackupStore(
        Directory(p.join(dir.path, 'copies')),
      ).read(entry);
      final file = const BackupCodec().decode(stored);
      expect(file.data.noteAttachments.map((a) => a.id), ['a-good']);
    });

    test(
      'the copy of the folder (foreground and background) goes on',
      () async {
        // The store is where the background task looks: <support>/attachments.
        final support = makeTempDir('folder-support');
        final bgStore = AttachmentStore(
          Directory(p.join(support.path, attachmentsDirectoryName)),
        );
        final bgDb = openMemoryDatabase();
        addTearDown(bgDb.close);
        await _addAttachment(bgDb, bgStore, id: 'ok', bytes: _bytes([1]));
        final lost = await _addAttachment(
          bgDb,
          bgStore,
          id: 'lost',
          bytes: _bytes([2]),
        );
        await bgStore.delete(lost.relativePath);

        final payload = await folderPayloadFrom(
          bgDb,
          support: support,
          appVersion: testAppVersion,
          at: _clock,
        );
        expect(skipped(payload.warnings), [
          const BrokenAttachment('lost', AttachmentFault.missing),
        ]);
        final file = const BackupCodec().decode(payload.bytes);
        expect(file.data.noteAttachments.map((a) => a.id), ['ok']);

        // The foreground engine: lenient too.
        final service = serviceOver(repository, 'copies2');
        expect((await service.exportDetailed()).warnings, isNotEmpty);
      },
    );

    test('the safety copy before a restore skips them and the restore '
        'goes on', () async {
      // A copy to restore: made on another phone.
      final source = openMemoryDatabase();
      addTearDown(source.close);
      final sourceStore = AttachmentStore(
        Directory(p.join(dir.path, 'source-attachments')),
      );
      await _addAttachment(source, sourceStore, id: 'new', bytes: _bytes([5]));
      final sourceRepo = repositoryOver(source, sourceStore, 'source-backups');
      final incoming = const BackupCodec().decode(
        (await sourceRepo.encodeCurrent(
          await sourceRepo.readAll(),
          at: _clock,
        )).bytes,
      );

      final warnings = await repository.restore(
        incoming.data,
        attachmentFiles: incoming.attachmentFiles,
        verified: true,
      );
      expect(skipped(warnings), hasLength(2));
      // Restored.
      final rows = await NoteAttachmentsRepository(db).all();
      expect(rows.map((a) => a.id), ['new']);
      // The safety copy exists and carries the attachment that was whole.
      final copies = Directory(p.join(dir.path, 'backups'))
          .listSync()
          .whereType<File>()
          .toList();
      expect(copies, hasLength(1));
      final safety = const BackupCodec().decode(
        copies.single.readAsBytesSync(),
      );
      expect(safety.data.noteAttachments.map((a) => a.id), ['a-good']);
    });

    test(
      'restoring over a damaged file replaces it with the good one',
      () async {
        // The copy that comes brings the good bytes of the damaged attachment.
        final source = openMemoryDatabase();
        addTearDown(source.close);
        final sourceStore = AttachmentStore(
          Directory(p.join(dir.path, 'source-attachments')),
        );
        await _addAttachment(
          source,
          sourceStore,
          id: 'a-damaged',
          bytes: _bytes([3]),
        );
        final sourceRepo = repositoryOver(
          source,
          sourceStore,
          'source-backups',
        );
        final incoming = const BackupCodec().decode(
          (await sourceRepo.encodeCurrent(
            await sourceRepo.readAll(),
            at: _clock,
          )).bytes,
        );
        expect(_fileOf(store, damaged).readAsBytesSync(), [7, 7, 7]);

        await repository.restore(
          incoming.data,
          attachmentFiles: incoming.attachmentFiles,
          verified: true,
        );
        expect(_fileOf(store, damaged).readAsBytesSync(), [3]);
        final check = readVerifiedAttachmentFiles(store.root.path, [
          (
            id: damaged.id,
            relativePath: damaged.relativePath,
            sizeBytes: 1,
            sha256: damaged.sha256,
          ),
        ]);
        expect(check.broken, isEmpty);
      },
    );

    test(
      'repair removes the rows without a file and leaves the rest',
      () async {
        final service = NoteAttachmentsService(
          store: store,
          repository: NoteAttachmentsRepository(db),
          now: () => _clock,
        );
        final repair = await service.repair(runner: runOnThisIsolate);
        expect(repair.removed, [
          const BrokenAttachment('a-gone', AttachmentFault.missing),
        ]);
        expect(repair.remaining, [
          const BrokenAttachment('a-damaged', AttachmentFault.damaged),
        ]);
        final left = await NoteAttachmentsRepository(db).all();
        expect(left.map((a) => a.id), unorderedEquals(['a-good', 'a-damaged']));
        // The damaged file is still there until the user decides.
        expect(_fileOf(store, damaged).existsSync(), isTrue);

        final all = await service.repair(
          removeDamaged: true,
          runner: runOnThisIsolate,
        );
        expect(all.removed, [
          const BrokenAttachment('a-damaged', AttachmentFault.damaged),
        ]);
        expect((await NoteAttachmentsRepository(db).all()).map((a) => a.id), [
          'a-good',
        ]);
        // Nothing left to repair.
        final none = await service.repair(runner: runOnThisIsolate);
        expect(none.removed, isEmpty);
        expect(none.remaining, isEmpty);
      },
    );
  });

  group('LOW: the store', () {
    test('a write does not walk the whole store', () async {
      final counting = _CountingStore(Directory(p.join(dir.path, 'counting')));
      for (var i = 0; i < 30; i++) {
        await counting.put(_noise(64, seed: i + 1));
      }
      // Walked once to measure it, never again.
      expect(counting.lists, 1);
      expect((await counting.list()), hasLength(30));
    });

    test('the running total follows deletes and the limits hold', () async {
      final small = AttachmentStore(
        Directory(p.join(dir.path, 'small')),
        maxTotalBytes: 10,
        maxFiles: 2,
      );
      final a = await small.put(_bytes([1, 1, 1, 1, 1, 1]));
      await expectLater(
        small.put(_bytes([2, 2, 2, 2, 2])),
        throwsA(
          isA<AttachmentStoreException>().having(
            (e) => e.problem,
            'problem',
            AttachmentProblem.storeFull,
          ),
        ),
      );
      await small.delete(a);
      // The deleted file's bytes are free again.
      await small.put(_bytes([2, 2, 2, 2, 2, 2]));
      await small.put(_bytes([3]));
      // Two files is the most.
      await expectLater(
        small.put(_bytes([4])),
        throwsA(
          isA<AttachmentStoreException>().having(
            (e) => e.problem,
            'problem',
            AttachmentProblem.storeFull,
          ),
        ),
      );
    });

    test(
      'the start-up sweep leaves files younger than a minute alone',
      () async {
        expect(attachmentSweepMinAge, const Duration(minutes: 1));
        final young = await store.put(_bytes([1]));
        final old = await store.put(_bytes([2]));
        File(p.join(store.root.path, '.incoming', 'x.part'))
          ..createSync(recursive: true)
          ..writeAsBytesSync([1]);
        File(p.joinAll([store.root.path, ...old.split('/')]))
            .setLastModifiedSync(
              DateTime.now().subtract(const Duration(minutes: 5)),
            );

        final swept = await store.sweep({}, minAge: attachmentSweepMinAge);
        expect(swept, 1);
        expect(await store.list(), [young]);
        // The half-written temporary file of a write in progress stays too.
        expect(
          File(p.join(store.root.path, '.incoming', 'x.part')).existsSync(),
          isTrue,
        );
        // Without an age (a restore that ends) everything unused goes.
        expect(await store.sweep({}), 2);
        expect(await store.list(), isEmpty);
      },
    );
  });

  group('MEDIUM: a read error is not a lost file', () {
    late NoteAttachment good;
    late NoteAttachment flaky;
    late BackupRepository flakyRepository;

    Future<BackupFile> incomingCopy() async {
      final source = openMemoryDatabase();
      addTearDown(source.close);
      final sourceStore = AttachmentStore(
        Directory(p.join(dir.path, 'source-attachments')),
      );
      await _addAttachment(source, sourceStore, id: 'new', bytes: _bytes([5]));
      final sourceRepo = repositoryOver(source, sourceStore, 'source-backups');
      return const BackupCodec().decode(
        (await sourceRepo.encodeCurrent(
          await sourceRepo.readAll(),
          at: _clock,
        )).bytes,
      );
    }

    setUp(() async {
      good = await _addAttachment(db, store, id: 'a-good', bytes: _bytes([1]));
      flaky = await _addAttachment(
        db,
        store,
        id: 'a-flaky',
        bytes: _bytes([2]),
      );
      _flaky
        ..clear()
        ..add(flaky.relativePath.split('/').last);
      flakyRepository = BackupRepository(
        db,
        safetyDirectory: Directory(p.join(dir.path, 'backups')),
        appVersion: testAppVersion,
        attachmentStore: store,
        now: () => _clock,
        runner: counting,
        readAttachmentFile: _flakyRead,
      );
    });
    tearDown(_flaky.clear);

    test('a file that is there but cannot be read is unreadable, not '
        'missing', () {
      final refs = [
        for (final a in [good, flaky])
          (
            id: a.id,
            relativePath: a.relativePath,
            sizeBytes: a.sizeBytes,
            sha256: a.sha256,
          ),
      ];
      final check = readVerifiedAttachmentFiles(
        store.root.path,
        refs,
        read: _flakyRead,
      );
      expect(check.broken, [
        const BrokenAttachment('a-flaky', AttachmentFault.unreadable),
      ]);
      expect(check.files.keys, ['a-good']);
      // A file that vanishes between the check and the read is missing.
      final vanished = readVerifiedAttachmentFiles(
        store.root.path,
        refs,
        read: (f) => throw PathNotFoundException(f.path, const OSError()),
      );
      expect(
        vanished.broken.map((b) => b.fault).toSet(),
        {AttachmentFault.missing},
      );
    });

    test('the automatic copy goes on and says what it could not read', () async {
      final service = BackupService(
        repository: flakyRepository,
        store: LocalFileBackupStore(Directory(p.join(dir.path, 'copies'))),
        appVersion: testAppVersion,
        runner: counting,
        now: () => _clock,
      );
      await service.backupNow();
      expect(
        (service.lastWarnings.single as AttachmentsSkipped).attachments,
        [const BrokenAttachment('a-flaky', AttachmentFault.unreadable)],
      );
    });

    test('a restore does not go on without a copy of a file it could not '
        'read: nothing changes and nothing is deleted', () async {
      final incoming = await incomingCopy();
      await expectLater(
        flakyRepository.restore(
          incoming.data,
          attachmentFiles: incoming.attachmentFiles,
          verified: true,
        ),
        throwsA(
          isA<BrokenAttachments>().having(
            (e) => e.attachments,
            'attachments',
            [const BrokenAttachment('a-flaky', AttachmentFault.unreadable)],
          ),
        ),
      );
      // The data and every file are as they were.
      final rows = await NoteAttachmentsRepository(db).all();
      expect(rows.map((a) => a.id), unorderedEquals(['a-good', 'a-flaky']));
      expect(_fileOf(store, flaky).readAsBytesSync(), [2]);
      expect(_fileOf(store, good).readAsBytesSync(), [1]);
      expect(await store.list(), hasLength(2));
      // No safety copy was left half done.
      final backups = Directory(p.join(dir.path, 'backups'));
      expect(
        backups.existsSync() ? backups.listSync().whereType<File>() : [],
        isEmpty,
      );
      // Once the file reads again, the same restore works.
      _flaky.clear();
      await flakyRepository.restore(
        incoming.data,
        attachmentFiles: incoming.attachmentFiles,
        verified: true,
      );
      final after = await NoteAttachmentsRepository(db).all();
      expect(after.map((a) => a.id), ['new']);
    });

    test('the files the safety copy left out are not swept after a '
        'restore', () async {
      // Lost and damaged files: skipped by the safety copy (the lenient case).
      await store.delete(flaky.relativePath);
      _flaky.clear();
      final damaged = await _addAttachment(
        db,
        store,
        id: 'a-damaged',
        bytes: _bytes([3]),
      );
      _fileOf(store, damaged).writeAsBytesSync([7, 7, 7]);
      final incoming = await incomingCopy();

      final warnings = await repository.restore(
        incoming.data,
        attachmentFiles: incoming.attachmentFiles,
        verified: true,
      );
      expect(
        (warnings.single as AttachmentsSkipped).attachments,
        unorderedEquals([
          const BrokenAttachment('a-flaky', AttachmentFault.missing),
          const BrokenAttachment('a-damaged', AttachmentFault.damaged),
        ]),
      );
      // The damaged file (skipped, so not in the safety copy) is still there.
      expect(_fileOf(store, damaged).existsSync(), isTrue);
      // The file the safety copy does hold is swept, as before.
      expect(_fileOf(store, good).existsSync(), isFalse);
    });
  });

  group('LOW: the version of a copy with attachments', () {
    test('is read from the first bytes of the container', () async {
      await _addAttachment(db, store, bytes: _noise(5000));
      final data = await repository.readAll();
      final bytes = (await repository.encodeCurrent(data, at: _clock)).bytes;
      expect(BackupContainer.looksLikeContainer(bytes), isTrue);
      // What the list of copies reads: the first 512 bytes.
      final head = Uint8List.sublistView(
        bytes,
        0,
        BackupCodec.peekCompressedBytes,
      );
      expect(BackupCodec.peekAppVersion(head), testAppVersion);
      expect(BackupCodec.peekAppVersion(bytes), testAppVersion);
      // Garbage that looks like a ZIP is nothing, never an error.
      expect(
        BackupCodec.peekAppVersion(
          Uint8List.fromList([0x50, 0x4b, 0x03, 0x04, ...List.filled(60, 0)]),
        ),
        isNull,
      );
      expect(
        BackupCodec.peekAppVersion(
          Uint8List.fromList([0x50, 0x4b, 0x03, 0x04]),
        ),
        isNull,
      );
    });
  });
}

class _CountingStore extends AttachmentStore {
  _CountingStore(super.root);

  int lists = 0;

  @override
  Future<List<String>> list() {
    lists++;
    return super.list();
  }
}
