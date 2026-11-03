import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:cuadrante/core/database/app_database.dart';
import 'package:cuadrante/features/notes/data/day_tasks_repository.dart';
import 'package:cuadrante/features/notes/data/note_attachments_repository.dart';
import 'package:cuadrante/features/notes/domain/day_task.dart';
import 'package:cuadrante/features/notes/domain/note_attachment.dart';
import 'package:cuadrante/features/schedule/domain/civil_date.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_storage.dart';

const _day = CivilDate(2026, 11, 3);

/// A SHA-256 per id, so every test attachment has its own canonical path.
String _hashOf(String id) => sha256.convert(utf8.encode(id)).toString();

NoteAttachment _attachment(
  String id, {
  CivilDate date = _day,
  String calendarId = 'main',
  int sortOrder = 0,
  String? path,
  String mime = 'image/jpeg',
  int size = 10,
  String? sha,
  String? name,
}) => NoteAttachment(
  id: id,
  calendarId: calendarId,
  date: date,
  kind: AttachmentKind.photo,
  relativePath:
      path ??
      (isSha256Hex(sha ?? _hashOf(id))
          ? attachmentPathOfHash(sha ?? _hashOf(id))
          : '$calendarId/$id.jpg'),
  mimeType: mime,
  sizeBytes: size,
  sha256: sha ?? _hashOf(id),
  displayName: name,
  sortOrder: sortOrder,
  createdAt: 100,
);

DayTask _task(
  String id, {
  CivilDate date = _day,
  String title = 'Comprar pan',
  int sortOrder = 0,
  bool done = false,
}) => DayTask(
  id: id,
  calendarId: 'main',
  date: date,
  title: title,
  done: done,
  sortOrder: sortOrder,
  createdAt: 1,
  updatedAt: 1,
);

void main() {
  group('attachment paths and ids', () {
    test('safe relative paths', () {
      for (final path in [
        'a.jpg',
        'main/2026-11/att-1.jpg',
        'cal-x_1/a.b.c',
        '0/1/2',
      ]) {
        expect(isSafeAttachmentPath(path), isTrue, reason: path);
      }
    });

    test('anything that could leave the folder or hide a file', () {
      for (final path in [
        '',
        '/abs',
        '../x',
        'a/../b',
        'a/./b',
        '..',
        '.x',
        'a/.x',
        'a\\b',
        'a//b',
        'a/',
        'a b',
        'ñ.jpg',
        'a:b',
        'x' * 513,
        '${'x' * 129}/a',
      ]) {
        expect(isSafeAttachmentPath(path), isFalse, reason: path);
      }
    });

    test('every path the app accepts, the table accepts too', () async {
      final db = openMemoryDatabase();
      addTearDown(db.close);
      final candidates = [
        'a.jpg',
        'main/2026-11/att-1.jpg',
        'a..b.jpg',
        'a/b..',
        '..a',
        '../x',
        '/abs',
        '.x',
        'a/.x',
        'a\\b',
        'B.JPG',
        'x' * 512,
        'x' * 513,
      ];
      var i = 0;
      for (final path in candidates) {
        final dart = isSafeAttachmentPath(path);
        bool sql;
        try {
          await db.customStatement(
            'INSERT INTO note_attachments (id, calendar_id, date, kind, '
            'relative_path, mime_type, size_bytes, sha256, created_at) '
            "VALUES (?, 'main', '2026-11-03', 'photo', ?, 'image/jpeg', 1, "
            '?, 1)',
            ['p${i++}', path, '0' * 64],
          );
          sql = true;
        } catch (_) {
          sql = false;
        }
        if (dart) expect(sql, isTrue, reason: 'the table refuses "$path"');
      }
      expect(isSafeAttachmentPath('a..b.jpg'), isFalse);
    });

    test('the table refuses two paths that differ only in case', () async {
      final db = openMemoryDatabase();
      addTearDown(db.close);
      // The table's own rule (the Dart side only accepts the canonical path
      // of the hash): inserted straight into the table.
      await db
          .into(db.noteAttachments)
          .insert(_attachment('a', path: 'main/Foto.jpg').toCompanion());
      await expectLater(
        db
            .into(db.noteAttachments)
            .insert(_attachment('b', path: 'main/foto.JPG').toCompanion()),
        throwsA(anything),
      );
    });

    test('ids, hashes and MIME types', () {
      expect(isSafeAttachmentId('att-1_A'), isTrue);
      expect(isSafeAttachmentId('x' * 64), isTrue);
      for (final id in ['', 'a/b', 'a.b', 'x' * 65, 'á']) {
        expect(isSafeAttachmentId(id), isFalse, reason: id);
      }
      expect(isSha256Hex('ab' * 32), isTrue);
      expect(isSha256Hex('AB' * 32), isFalse);
      expect(isSha256Hex('ab' * 31), isFalse);
      expect(isAttachmentMimeType('image/jpeg'), isTrue);
      expect(isAttachmentMimeType('application/vnd.ms-excel'), isTrue);
      expect(isAttachmentMimeType('image/svg+xml'), isTrue);
      for (final mime in ['', 'image', 'Image/JPEG', 'image/ jpeg', '/x']) {
        expect(isAttachmentMimeType(mime), isFalse, reason: mime);
      }
    });

    test('problem names the first rule broken', () {
      expect(_attachment('a').problem, isNull);
      expect(_attachment('a/b').problem, 'unsafe id');
      expect(_attachment('a', path: '../a').problem, 'unsafe path');
      expect(
        _attachment('a', path: 'main/a.jpg').problem,
        'path does not match the SHA-256',
      );
      expect(_attachment('a', mime: 'jpeg').problem, 'invalid MIME type');
      expect(_attachment('a', size: -1).problem, 'size out of range');
      expect(
        _attachment('a', size: maxAttachmentBytes + 1).problem,
        'size out of range',
      );
      expect(_attachment('a', sha: 'x').problem, 'invalid SHA-256');
      expect(_attachment('a', name: ' ').problem, 'invalid display name');
      expect(_attachment('a', name: 'nómina.pdf').problem, isNull);
      // Control and bidirectional characters cannot hide in a name.
      for (final name in [
        'nomina\u202Efdp.exe',
        'a\u0000b',
        'a\nb',
        'a\u2066b',
        'a\u200Fb',
        'a\u007Fb',
      ]) {
        expect(
          _attachment('a', name: name).problem,
          'invalid display name',
          reason: name.codeUnits.toString(),
        );
      }
    });

    test('the path is a pure function of the verified hash', () {
      final hash = _hashOf('x');
      final base = '${hash.substring(0, 2)}/$hash';
      expect(isCanonicalAttachmentPath(base, hash), isTrue);
      // The suffix putCopy adds, 2 to 999 and nothing else.
      for (final n in [2, 3, 10, 999]) {
        expect(
          isCanonicalAttachmentPath('$base-$n', hash),
          isTrue,
          reason: '$n',
        );
      }
      for (final suffix in [
        '-1',
        '-0',
        '-1000',
        '-02',
        '-',
        '-a',
        '_2',
        '-2-3',
      ]) {
        expect(
          isCanonicalAttachmentPath('$base$suffix', hash),
          isFalse,
          reason: suffix,
        );
      }
      // Another hash's name, a wrong folder, another case, a bare hash.
      final other = _hashOf('y');
      expect(
        isCanonicalAttachmentPath('${other.substring(0, 2)}/$other', hash),
        isFalse,
      );
      expect(isCanonicalAttachmentPath('zz/$hash', hash), isFalse);
      expect(isCanonicalAttachmentPath(hash, hash), isFalse);
      expect(isCanonicalAttachmentPath(base.toUpperCase(), hash), isFalse);
      expect(isCanonicalAttachmentPath(base, 'x'), isFalse);
    });
  });

  group('tasks', () {
    test('problem and copyWith', () {
      expect(_task('t').problem, isNull);
      expect(_task('').problem, 'empty id');
      expect(_task('t', title: '  ').problem, 'empty title');
      expect(
        _task('t', title: 'x' * (maxDayTaskTitleLength + 1)).problem,
        'title too long',
      );
      final done = _task('t').copyWith(done: true, updatedAt: 9);
      expect(done.done, isTrue);
      expect(done.updatedAt, 9);
      expect(done.createdAt, 1);
      expect(done, isNot(_task('t')));
      expect(done.copyWith(done: false, updatedAt: 1), _task('t'));
    });
  });

  group('repositories', () {
    late AppDatabase db;
    setUp(() {
      db = openMemoryDatabase();
      addTearDown(db.close);
    });

    test('attachments: save, read by day and range, replace, delete', () async {
      final repo = NoteAttachmentsRepository(db, newId: () => 'att-new');
      expect(repo.newId(), 'att-new');
      expect(isSafeAttachmentId(NoteAttachmentsRepository(db).newId()), isTrue);
      final second = _attachment('b', sortOrder: 1);
      final first = _attachment('a', name: 'foto.jpg');
      final other = _attachment('c', date: _day.addDays(1));
      for (final a in [second, first, other]) {
        await repo.save(a);
      }
      expect(await repo.forDay('main', _day), [first, second]);
      expect(await repo.inRange('main', _day, _day.addDays(1)), [
        first,
        second,
        other,
      ]);
      expect(await repo.inRange('main', _day.addDays(2), _day.addDays(9)), []);
      expect(await repo.forDay('other', _day), isEmpty);
      expect(await repo.all(), hasLength(3));
      expect(await repo.byId('a'), first);

      final moved = _attachment('a', sortOrder: 5, name: 'otra.jpg');
      await repo.save(moved);
      expect(await repo.byId('a'), moved);
      expect(await repo.delete('a'), isTrue);
      expect(await repo.delete('a'), isFalse);
      expect(await repo.byId('a'), isNull);
    });

    test('attachments: an invalid one writes nothing; the database '
        'refuses a missing calendar and a shared file', () async {
      final repo = NoteAttachmentsRepository(db);
      await expectLater(
        repo.save(_attachment('a', path: '../../cuadrante.sqlite')),
        throwsArgumentError,
      );
      expect(await repo.all(), isEmpty);
      await db.customStatement('PRAGMA foreign_keys = ON');
      await expectLater(
        repo.save(_attachment('a', calendarId: 'ghost')),
        throwsA(anything),
      );
      await repo.save(_attachment('a', sha: _hashOf('same')));
      await expectLater(
        repo.save(_attachment('b', sha: _hashOf('same'))),
        throwsA(anything),
      );
      expect(await repo.all(), hasLength(1));
    });

    test('tasks: save, order, tick, delete', () async {
      final repo = DayTasksRepository(db, newId: () => 'task-new');
      expect(repo.newId(), 'task-new');
      final b = _task('b', sortOrder: 1, title: 'Segunda');
      final a = _task('a', title: 'Primera');
      final tomorrow = _task('c', date: _day.addDays(1));
      for (final t in [b, a, tomorrow]) {
        await repo.save(t);
      }
      expect(await repo.forDay('main', _day), [a, b]);
      expect(await repo.inRange('main', _day, _day.addDays(1)), [
        a,
        b,
        tomorrow,
      ]);
      expect(await repo.setDone('a', done: true, at: 50), isTrue);
      expect(await repo.setDone('ghost', done: true, at: 50), isFalse);
      expect(
        (await repo.forDay('main', _day)).first,
        a.copyWith(done: true, updatedAt: 50),
      );
      await repo.save(b.copyWith(title: 'Segunda bis', updatedAt: 60));
      expect((await repo.forDay('main', _day)).last.title, 'Segunda bis');
      expect(await repo.delete('b'), isTrue);
      expect(await repo.forDay('main', _day), hasLength(1));
      await expectLater(repo.save(_task('x', title: ' ')), throwsArgumentError);
    });

    test('tasks and attachments do not depend on the day row', () async {
      await DayTasksRepository(db).save(_task('a'));
      final rows = await db.select(db.dayEntries).get();
      expect(rows, isEmpty);
      expect(await DayTasksRepository(db).forDay('main', _day), hasLength(1));
    });
  });
}
