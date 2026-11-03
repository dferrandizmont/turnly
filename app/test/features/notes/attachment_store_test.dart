import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cuadrante/core/database/app_database.dart';
import 'package:cuadrante/features/notes/application/note_attachments_service.dart';
import 'package:cuadrante/features/notes/data/attachment_store.dart';
import 'package:cuadrante/features/notes/data/note_attachments_repository.dart';
import 'package:cuadrante/features/notes/domain/note_attachment.dart';
import 'package:cuadrante/features/schedule/domain/civil_date.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../support/test_storage.dart';

const _day = CivilDate(2026, 11, 3);

Uint8List _bytes(String text) => Uint8List.fromList(utf8.encode(text));

void main() {
  group('the store of files', () {
    late Directory root;
    late AttachmentStore store;

    setUp(() {
      root = makeTempDir('attachments');
      store = AttachmentStore(root);
    });

    test('a file is named after the hash of its bytes', () async {
      final bytes = _bytes('hola');
      final path = store.pathOf(bytes);
      expect(path, matches(RegExp(r'^[0-9a-f]{2}/[0-9a-f]{64}$')));
      expect(path.substring(3), store.hashOf(bytes));

      expect(await store.put(bytes), path);
      expect(await store.read(path), bytes);
      expect(await store.list(), [path]);
      expect(await store.totalBytes(), 4);
    });

    test('the same content is stored once', () async {
      final bytes = _bytes('hola');
      final first = await store.put(bytes);
      final second = await store.put(bytes);
      expect(second, first);
      expect(await store.list(), hasLength(1));
    });

    test('a file that is not what its name says is written again', () async {
      final bytes = _bytes('hola');
      final path = await store.put(bytes);
      // The file is corrupted (or another content took its place).
      final file = File(p.joinAll([root.path, ...path.split('/')]));
      await file.writeAsBytes(_bytes('adios'));
      expect(await store.put(bytes), path);
      expect(await store.read(path), bytes);
    });

    test('a second file with the same content gets a name of its own', () async {
      final bytes = _bytes('hola');
      final first = await store.put(bytes);
      final copy = await store.putCopy(bytes);
      expect(copy, isNot(first));
      expect(copy, startsWith(first));
      expect(await store.read(copy), bytes);
      expect(await store.list(), hasLength(2));
    });

    test('a file too big is refused', () async {
      final small = AttachmentStore(root, maxFileBytes: 3);
      await expectLater(
        small.put(_bytes('hola')),
        throwsA(
          isA<AttachmentStoreException>().having(
            (e) => e.problem,
            'problem',
            AttachmentProblem.tooLarge,
          ),
        ),
      );
      expect(await small.list(), isEmpty);
    });

    test('a full store is refused', () async {
      final small = AttachmentStore(root, maxTotalBytes: 4);
      await small.put(_bytes('hola'));
      await expectLater(
        small.put(_bytes('adios')),
        throwsA(
          isA<AttachmentStoreException>().having(
            (e) => e.problem,
            'problem',
            AttachmentProblem.storeFull,
          ),
        ),
      );
      expect(await small.list(), hasLength(1));
    });

    test('a path that could leave the folder is refused', () async {
      for (final path in ['../fuera', '/abs', 'a/../b', '']) {
        await expectLater(
          store.writeAt(path, _bytes('x')),
          throwsA(
            isA<AttachmentStoreException>().having(
              (e) => e.problem,
              'problem',
              AttachmentProblem.unsafePath,
            ),
          ),
          reason: path,
        );
        await expectLater(
          store.read(path),
          throwsA(
            isA<AttachmentStoreException>().having(
              (e) => e.problem,
              'problem',
              AttachmentProblem.unsafePath,
            ),
          ),
          reason: path,
        );
      }
      expect(await store.list(), isEmpty);
    });

    test('a file that is not there says so', () async {
      await expectLater(
        store.read('ab/${'0' * 64}'),
        throwsA(
          isA<AttachmentStoreException>().having(
            (e) => e.problem,
            'problem',
            AttachmentProblem.missing,
          ),
        ),
      );
      expect(await store.exists('ab/${'0' * 64}'), isFalse);
      expect(await store.delete('ab/${'0' * 64}'), isFalse);
    });

    test('writing at a path of a backup keeps what is there', () async {
      final bytes = _bytes('hola');
      final path = store.pathOf(bytes);
      expect(await store.writeAt(path, bytes), isTrue);
      // The same content again: nothing is written.
      expect(await store.writeAt(path, bytes), isFalse);
      // Another content at the same path: never overwritten.
      await expectLater(
        store.writeAt(path, _bytes('adios')),
        throwsA(
          isA<AttachmentStoreException>().having(
            (e) => e.problem,
            'problem',
            AttachmentProblem.hashMismatch,
          ),
        ),
      );
      expect(await store.read(path), bytes);
    });

    test('nothing is left half written', () async {
      final path = await store.put(_bytes('hola'));
      expect(await store.list(), [path]);
      // The temporary folder is not part of the store.
      final incoming = Directory('${root.path}/.incoming');
      expect(incoming.existsSync(), isTrue);
      expect(await incoming.list().toList(), isEmpty);
    });

    test('the sweep deletes the files no row points at', () async {
      final used = await store.put(_bytes('hola'));
      final orphan = await store.put(_bytes('adios'));
      expect(await store.sweep({used}), 1);
      expect(await store.list(), [used]);
      expect(await store.exists(orphan), isFalse);
    });

    test('a file that is not ours is ignored', () async {
      final path = await store.put(_bytes('hola'));
      await File('${root.path}/.DS_Store').writeAsString('basura');
      expect(await store.list(), [path]);
    });
  });

  group('the service', () {
    late AppDatabase db;
    late AttachmentStore store;
    late NoteAttachmentsService service;

    setUp(() {
      db = openMemoryDatabase();
      addTearDown(db.close);
      final root = makeTempDir('attachments');
      store = AttachmentStore(root);
      service = NoteAttachmentsService(
        store: store,
        repository: NoteAttachmentsRepository(db),
        now: () => DateTime.utc(2026, 11, 10, 9),
      );
    });

    test('adding an attachment writes the file and the row', () async {
      final bytes = _bytes('hola');
      final attachment = await service.add(
        calendarId: 'main',
        date: _day,
        kind: AttachmentKind.photo,
        bytes: bytes,
        mimeType: 'image/jpeg',
      );
      expect(attachment.sha256, store.hashOf(bytes));
      expect(attachment.sizeBytes, bytes.length);
      expect(attachment.createdAt, DateTime.utc(2026, 11, 10, 9).millisecondsSinceEpoch);
      expect(await store.read(attachment.relativePath), bytes);
      expect(await service.forDay('main', _day), [attachment]);
    });

    test('the same file twice gives two rows and two files', () async {
      final bytes = _bytes('hola');
      final first = await service.add(
        calendarId: 'main',
        date: _day,
        kind: AttachmentKind.photo,
        bytes: bytes,
        mimeType: 'image/jpeg',
      );
      final second = await service.add(
        calendarId: 'main',
        date: _day,
        kind: AttachmentKind.photo,
        bytes: bytes,
        mimeType: 'image/jpeg',
      );
      expect(second.id, isNot(first.id));
      expect(second.relativePath, isNot(first.relativePath));
      expect(await store.list(), hasLength(2));
      expect(await service.forDay('main', _day), hasLength(2));
    });

    test('removing an attachment takes its file away', () async {
      final attachment = await service.add(
        calendarId: 'main',
        date: _day,
        kind: AttachmentKind.file,
        bytes: _bytes('hola'),
        mimeType: 'application/pdf',
        displayName: 'nomina.pdf',
      );
      expect(await service.remove(attachment.id), isTrue);
      expect(await service.remove(attachment.id), isFalse);
      expect(await service.forDay('main', _day), isEmpty);
      expect(await store.list(), isEmpty);
    });

    test('the sweep takes the files no row points at', () async {
      final attachment = await service.add(
        calendarId: 'main',
        date: _day,
        kind: AttachmentKind.photo,
        bytes: _bytes('hola'),
        mimeType: 'image/jpeg',
      );
      final orphan = await store.put(_bytes('adios'));
      expect(await service.sweep(), 1);
      expect(await store.exists(orphan), isFalse);
      expect(await store.exists(attachment.relativePath), isTrue);
    });

    test('the bytes of every attachment, by id', () async {
      final attachment = await service.add(
        calendarId: 'main',
        date: _day,
        kind: AttachmentKind.photo,
        bytes: _bytes('hola'),
        mimeType: 'image/jpeg',
      );
      expect(await service.bytesById(), {
        attachment.id: _bytes('hola'),
      });
    });

    test('an invalid MIME type leaves no file behind', () async {
      await expectLater(
        service.add(
          calendarId: 'main',
          date: _day,
          kind: AttachmentKind.photo,
          bytes: _bytes('hola'),
          mimeType: 'esto no es un mime',
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(await store.list(), isEmpty);
      expect(await service.forDay('main', _day), isEmpty);
    });

    test('a display name too long leaves no file behind', () async {
      await expectLater(
        service.add(
          calendarId: 'main',
          date: _day,
          kind: AttachmentKind.file,
          bytes: _bytes('hola'),
          mimeType: 'application/pdf',
          displayName: 'x' * (maxAttachmentNameLength + 1),
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(await store.list(), isEmpty);
      expect(await service.forDay('main', _day), isEmpty);
    });

    test('a day without calendar leaves no file behind', () async {
      await expectLater(
        service.add(
          calendarId: '',
          date: _day,
          kind: AttachmentKind.photo,
          bytes: _bytes('hola'),
          mimeType: 'image/jpeg',
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(await store.list(), isEmpty);
    });

    test('a calendar that does not exist leaves no file behind', () async {
      await expectLater(
        service.add(
          calendarId: 'other',
          date: _day,
          kind: AttachmentKind.photo,
          bytes: _bytes('hola'),
          mimeType: 'image/jpeg',
        ),
        throwsA(anything),
      );
      expect(await store.list(), isEmpty);
      expect(await service.forDay('other', _day), isEmpty);
    });

    test('a file too big is the store saying it, not an invalid attachment', () async {
      final small = AttachmentStore(
        makeTempDir('small-attachments'),
        maxFileBytes: 3,
      );
      final smallService = NoteAttachmentsService(
        store: small,
        repository: NoteAttachmentsRepository(db),
        now: () => DateTime.utc(2026, 11, 10, 9),
      );
      await expectLater(
        smallService.add(
          calendarId: 'main',
          date: _day,
          kind: AttachmentKind.photo,
          bytes: _bytes('hola'),
          mimeType: 'image/jpeg',
        ),
        throwsA(
          isA<AttachmentStoreException>().having(
            (e) => e.problem,
            'problem',
            AttachmentProblem.tooLarge,
          ),
        ),
      );
      expect(await small.list(), isEmpty);
    });
  });
}
