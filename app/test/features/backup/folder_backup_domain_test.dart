import 'dart:convert';

import 'package:cuadrante/features/backup/domain/folder_backup.dart';
import 'package:flutter_test/flutter_test.dart';

// P10: the pure rules of the automatic folder copy (names, rotation, timing,
// state file).

FolderFile _f(String id, String name, [int size = 10]) =>
    FolderFile(id: id, name: name, sizeBytes: size);

final _now = DateTime(2026, 10, 31, 12);

void main() {
  group('names', () {
    test('the name carries the local moment and differs from exports', () {
      final name = folderBackupFileName(DateTime(2026, 10, 31, 3, 7, 9));
      expect(name, 'turnly-auto-20261031-030709.turnly');
      expect(isFolderBackupName(name), isTrue);
      expect(
        folderBackupFileName(DateTime(2026, 10, 31, 3, 7, 9), counter: 3),
        'turnly-auto-20261031-030709-3.turnly',
      );
    });

    test('only Turnly automatic copies count as own', () {
      for (final name in [
        'turnly-2026-10-31-030709.turnly', // a manual export
        'turnly-20261031-030709.turnly', // a phone copy
        'turnly-auto-20261031-030709.turnly.bak',
        'turnly-auto-20261031-030709 (1).turnly', // renamed by the provider
        'turnly-auto-2026103-030709.turnly',
        'mis turnos.pdf',
        '../turnly-auto-20261031-030709.turnly',
      ]) {
        expect(isFolderBackupName(name), isFalse, reason: name);
      }
    });

    test('an impossible date is not an own name', () {
      expect(folderBackupNameKey('turnly-auto-20261331-030709.turnly'), isNull);
      expect(folderBackupNameKey('turnly-auto-20260230-030709.turnly'), isNull);
    });

    test('a free name adds a counter when the second is taken', () {
      final at = DateTime(2026, 10, 31, 3, 7, 9);
      final first = folderBackupFileName(at);
      expect(freeFolderBackupName(at, const []), first);
      expect(
        freeFolderBackupName(at, [first, folderBackupFileName(at, counter: 2)]),
        folderBackupFileName(at, counter: 3),
      );
    });
  });

  group('rotation', () {
    test('keeps the newest ones and never touches foreign files', () {
      final files = [
        for (var d = 1; d <= 12; d++)
          _f('a$d', folderBackupFileName(DateTime(2026, 10, d, 3))),
        _f('x1', 'turnly-2026-10-01-030000.turnly'),
        _f('x2', 'notas.txt'),
      ];
      final drop = folderCopiesToRotate(files, keep: 10, now: _now);
      expect(drop.map((f) => f.id), unorderedEquals(['a1', 'a2']));
    });

    test('the copy just written is never deleted, whatever its name', () {
      final files = [
        for (var d = 1; d <= 10; d++)
          _f('a$d', folderBackupFileName(DateTime(2026, 10, d, 3))),
        // A clock that went back: the new copy looks like the oldest one.
        _f('new', folderBackupFileName(DateTime(2020, 1, 1))),
      ];
      final drop = folderCopiesToRotate(
        files,
        keep: 10,
        keepId: 'new',
        now: _now,
      );
      expect(drop.map((f) => f.id), ['a1']);
    });

    test('orders by moment, then by counter', () {
      final at = DateTime(2026, 10, 31, 3);
      final own = ownFolderCopies([
        _f('b', folderBackupFileName(at)),
        _f('c', folderBackupFileName(at, counter: 2)),
        _f('a', folderBackupFileName(DateTime(2026, 10, 30))),
        _f('z', 'other.turnly'),
      ]);
      expect(own.map((f) => f.id), ['c', 'b', 'a']);
    });

    test('names dated in the future are neither counted nor deleted', () {
      final files = [
        for (var d = 1; d <= 10; d++)
          _f('a$d', folderBackupFileName(DateTime(2026, 10, d, 3))),
        // Planted or from a clock in the future: it must not push a1 out.
        _f('f1', folderBackupFileName(DateTime(2030, 1, 1))),
        // Within a day: still counts.
        _f('soon', folderBackupFileName(DateTime(2026, 11, 1, 10))),
      ];
      final drop = folderCopiesToRotate(files, keep: 10, now: _now);
      expect(drop.map((f) => f.id), ['a1']);
      expect(
        ownFolderCopies(files, now: _now).map((f) => f.id),
        isNot(contains('f1')),
      );
      expect(ownFolderCopies(files, now: _now).first.id, 'soon');
    });

    test('fewer than keep: nothing to delete', () {
      expect(
        folderCopiesToRotate(
          [_f('a', folderBackupFileName(DateTime(2026, 10, 1)))],
          keep: 10,
          now: _now,
        ),
        isEmpty,
      );
    });
  });

  group('policy', () {
    const policy = FolderBackupPolicy();
    final now = DateTime.utc(2026, 10, 31, 12);

    test('daily waits 20 h, changes 6 h, manual never', () {
      final h = now.subtract(const Duration(hours: 5));
      expect(
        policy.isDue(FolderBackupTrigger.change, lastDoneAt: h, now: now),
        isFalse,
      );
      expect(
        policy.isDue(
          FolderBackupTrigger.change,
          lastDoneAt: now.subtract(const Duration(hours: 6)),
          now: now,
        ),
        isTrue,
      );
      expect(
        policy.isDue(
          FolderBackupTrigger.daily,
          lastDoneAt: now.subtract(const Duration(hours: 19)),
          now: now,
        ),
        isFalse,
      );
      expect(
        policy.isDue(
          FolderBackupTrigger.daily,
          lastDoneAt: now.subtract(const Duration(hours: 20)),
          now: now,
        ),
        isTrue,
      );
      expect(
        policy.isDue(FolderBackupTrigger.manual, lastDoneAt: now, now: now),
        isTrue,
      );
    });

    test('never done, or done "in the future", is due', () {
      expect(
        policy.isDue(FolderBackupTrigger.daily, lastDoneAt: null, now: now),
        isTrue,
      );
      expect(
        policy.isDue(
          FolderBackupTrigger.daily,
          lastDoneAt: now.add(const Duration(days: 2)),
          now: now,
        ),
        isTrue,
      );
    });
  });

  group('state', () {
    test('round-trips through JSON', () {
      final at = DateTime.utc(2026, 10, 31, 3);
      final state = const FolderBackupState()
          .withFolder('content://x/tree/1', 'Copias')
          .succeeded(
            at,
            _f('doc-7', 'turnly-auto-20261031-030000.turnly'),
            'sha256:ab',
          )
          .failed(at.add(const Duration(days: 1)), FolderProblem.noSpace);
      final back = FolderBackupState.fromJson(
        jsonDecode(jsonEncode(state.toJson())),
      );
      expect(back.uri, 'content://x/tree/1');
      expect(back.name, 'Copias');
      expect(back.lastSuccessAt, at);
      expect(back.lastFileName, 'turnly-auto-20261031-030000.turnly');
      expect(back.lastChecksum, 'sha256:ab');
      expect(back.lastFileId, 'doc-7');
      expect(back.lastFileSize, 10);
      expect(back.damaged, isFalse);
      expect(back.lastProblem, FolderProblem.noSpace);
      expect(back.lastProblemAt, at.add(const Duration(days: 1)));
    });

    test('a success clears the problem; a new folder clears the history', () {
      final at = DateTime.utc(2026, 10, 31);
      final failed = const FolderBackupState()
          .withFolder('u', 'n')
          .failed(at, FolderProblem.revoked);
      expect(failed.succeeded(at, _f('i', 'f'), 'c').lastProblem, isNull);
      final fresh = failed.withFolder('v', 'm');
      expect(fresh.lastProblem, isNull);
      expect(fresh.lastSuccessAt, isNull);
      expect(fresh.uri, 'v');
    });

    test('rubbish reads as an empty state, field by field', () {
      final damaged = FolderBackupState.fromJson('nope');
      expect(damaged.configured, isFalse);
      expect(damaged.damaged, isTrue);
      final odd = FolderBackupState.fromJson({
        'uri': 42,
        'lastSuccessAt': 'not a date',
        'lastProblem': 'something new',
      });
      expect(odd.uri, isNull);
      expect(odd.lastSuccessAt, isNull);
      expect(odd.lastProblem, FolderProblem.failed);
    });

    test('the last copy is found only with the same id, name and size', () {
      final s = const FolderBackupState()
          .withFolder('u', 'n')
          .succeeded(DateTime.utc(2026), _f('id1', 'a.turnly', 100), 'c');
      expect(s.lastCopyIn([_f('id1', 'a.turnly', 100)]), isTrue);
      expect(
        s.lastCopyIn([_f('id1', 'a.turnly', 0)]),
        isTrue,
        reason: 'size unknown',
      );
      expect(s.lastCopyIn([_f('id1', 'a.turnly', 99)]), isFalse);
      expect(s.lastCopyIn([_f('id2', 'a.turnly', 100)]), isFalse);
      expect(s.lastCopyIn([_f('id1', 'b.turnly', 100)]), isFalse);
      expect(
        const FolderBackupState().lastCopyIn([_f('id1', 'a.turnly')]),
        isFalse,
      );
    });

    test('lastDoneAt is the later of success and check', () {
      final a = DateTime.utc(2026, 10, 1);
      final b = DateTime.utc(2026, 10, 2);
      final s = const FolderBackupState().withFolder('u', 'n');
      expect(s.lastDoneAt, isNull);
      expect(s.succeeded(a, _f('i', 'f'), 'c').checked(b).lastDoneAt, b);
      expect(s.checked(a).succeeded(b, _f('i', 'f'), 'c').lastDoneAt, b);
    });
  });

  test('problem codes map back and say when a new folder is needed', () {
    for (final p in FolderProblem.values) {
      expect(FolderProblem.fromCode(p.code), p);
    }
    expect(FolderProblem.revoked.needsNewFolder, isTrue);
    expect(FolderProblem.missing.needsNewFolder, isTrue);
    expect(FolderProblem.unwritable.needsNewFolder, isTrue);
    expect(FolderProblem.damaged.needsNewFolder, isTrue);
    expect(FolderProblem.noSpace.needsNewFolder, isFalse);
    expect(FolderProblem.failed.needsNewFolder, isFalse);
  });
}
