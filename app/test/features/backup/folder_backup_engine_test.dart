import 'dart:io';
import 'dart:typed_data';

import 'package:cuadrante/features/backup/application/folder_backup_engine.dart';
import 'package:cuadrante/features/backup/data/folder_backup_state_store.dart';
import 'package:cuadrante/features/backup/domain/folder_backup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../support/test_storage.dart';
import 'folder_backup_support.dart';

// P10: one folder copy, from the state file to the folder: rotation,
// timing, the "same data" skip, read-back, and every failure recorded.

void main() {
  late FakeFolderPlatform folder;
  late FolderBackupStateStore states;
  late DateTime now;
  late String checksum;
  late List<Object> errors;
  Future<FolderPayload?> Function()? payloadOverride;

  FolderBackupEngine engine({FolderRunLock lock = const NoFolderRunLock()}) =>
      FolderBackupEngine(
        platform: folder,
        states: states,
        now: () => now,
        lock: lock,
        onError: (e, _) => errors.add(e),
        payload: () async {
          final o = payloadOverride;
          if (o != null) return o();
          return FolderPayload(
            Uint8List.fromList(checksum.codeUnits),
            checksum,
          );
        },
      );

  Future<void> chooseFolder() =>
      states.save(const FolderBackupState().withFolder(folder.uri, 'Copias'));

  setUp(() {
    folder = FakeFolderPlatform();
    states = FolderBackupStateStore(
      File(
        p.join(makeTempDir('folder-engine').path, folderBackupStateFileName),
      ),
    );
    now = DateTime.utc(2026, 10, 31, 3);
    checksum = 'sha256:one';
    errors = [];
    payloadOverride = null;
  });

  test('no folder: nothing happens', () async {
    final out = await engine().run(FolderBackupTrigger.daily);
    expect(out.kind, FolderBackupOutcomeKind.notConfigured);
    expect(folder.checks, 0);
  });

  test('a copy is written, read back and recorded', () async {
    await chooseFolder();
    final out = await engine().run(FolderBackupTrigger.daily);
    expect(out.kind, FolderBackupOutcomeKind.saved);
    expect(folder.names, ['turnly-auto-${_stamp(now)}.turnly']);
    final state = await states.load();
    expect(state.lastSuccessAt, now);
    expect(state.lastFileName, out.file!.name);
    expect(state.lastChecksum, 'sha256:one');
    expect(state.lastFileId, out.file!.id);
    expect(state.lastFileSize, out.file!.sizeBytes);
    expect(state.lastProblem, isNull);
  });

  test(
    'keeps the 10 newest own copies and leaves foreign files alone',
    () async {
      await chooseFolder();
      folder
        ..addFile('mis turnos.pdf')
        ..addFile('turnly-2026-10-01-120000.turnly');
      final e = engine();
      for (var i = 0; i < 13; i++) {
        checksum = 'sha256:$i';
        now = now.add(const Duration(days: 1));
        expect(
          (await e.run(FolderBackupTrigger.daily)).kind,
          FolderBackupOutcomeKind.saved,
        );
      }
      final own = folder.names.where(isFolderBackupName).toList();
      expect(own, hasLength(10));
      expect(folder.names, contains('mis turnos.pdf'));
      expect(folder.names, contains('turnly-2026-10-01-120000.turnly'));
      // The three oldest went.
      expect(
        own.first,
        'turnly-auto-${_stamp(DateTime.utc(2026, 11, 4, 3))}.turnly',
      );
    },
  );

  test('a delete that fails does not fail the copy', () async {
    await chooseFolder();
    for (var d = 1; d <= 10; d++) {
      folder.addFile(folderBackupFileName(DateTime(2026, 9, d)));
    }
    folder.deleteFails = true;
    final out = await engine().run(FolderBackupTrigger.manual);
    expect(out.kind, FolderBackupOutcomeKind.saved);
    expect(folder.names.where(isFolderBackupName), hasLength(11));
  });

  group('timing', () {
    test('daily skips within 20 h of the last copy; manual does not', () async {
      await chooseFolder();
      final e = engine();
      await e.run(FolderBackupTrigger.daily);
      now = now.add(const Duration(hours: 10));
      checksum = 'sha256:two';
      expect(
        (await e.run(FolderBackupTrigger.daily)).kind,
        FolderBackupOutcomeKind.notDue,
      );
      expect(
        (await e.run(FolderBackupTrigger.change)).kind,
        FolderBackupOutcomeKind.saved,
      );
      now = now.add(const Duration(hours: 1));
      expect(
        (await e.run(FolderBackupTrigger.change)).kind,
        FolderBackupOutcomeKind.notDue,
      );
      expect(
        (await e.run(FolderBackupTrigger.manual)).kind,
        FolderBackupOutcomeKind.saved,
      );
    });

    test('the same data as the newest copy is not written again', () async {
      await chooseFolder();
      final e = engine();
      await e.run(FolderBackupTrigger.daily);
      now = now.add(const Duration(days: 1));
      final out = await e.run(FolderBackupTrigger.daily);
      expect(out.kind, FolderBackupOutcomeKind.upToDate);
      expect(folder.writes, 1);
      final state = await states.load();
      expect(state.lastCheckedAt, now);
      expect(state.lastSuccessAt, now.subtract(const Duration(days: 1)));
    });

    test('same data, but the newest copy was deleted: written again', () async {
      await chooseFolder();
      final e = engine();
      await e.run(FolderBackupTrigger.daily);
      folder.docs.clear();
      now = now.add(const Duration(days: 1));
      expect(
        (await e.run(FolderBackupTrigger.daily)).kind,
        FolderBackupOutcomeKind.saved,
      );
    });

    test('runs on one engine never overlap', () async {
      await chooseFolder();
      final e = engine();
      final results = await Future.wait([
        e.run(FolderBackupTrigger.manual),
        e.run(FolderBackupTrigger.manual),
      ]);
      expect(
        results.map((r) => r.kind),
        everyElement(FolderBackupOutcomeKind.saved),
      );
      expect(folder.names.toSet(), hasLength(2));
    });
  });

  group('failures are recorded, never silent', () {
    Future<FolderBackupState> failWith(void Function() breakIt) async {
      await chooseFolder();
      breakIt();
      final out = await engine().run(FolderBackupTrigger.daily);
      expect(out.kind, FolderBackupOutcomeKind.failed);
      final state = await states.load();
      expect(state.lastProblem, out.problem);
      expect(state.lastProblemAt, now);
      expect(state.uri, folder.uri, reason: 'the folder is not forgotten');
      return state;
    }

    test('permission revoked', () async {
      final s = await failWith(() => folder.revoked = true);
      expect(s.lastProblem, FolderProblem.revoked);
      expect(folder.writes, 0);
    });

    test('folder deleted', () async {
      final s = await failWith(() => folder.deleted = true);
      expect(s.lastProblem, FolderProblem.missing);
    });

    test('read-only folder', () async {
      final s = await failWith(() => folder.readOnly = true);
      expect(s.lastProblem, FolderProblem.unwritable);
    });

    test('no space', () async {
      final s = await failWith(() => folder.writeFails = FolderProblem.noSpace);
      expect(s.lastProblem, FolderProblem.noSpace);
      expect(folder.names, isEmpty);
    });

    test('a copy that does not read back is deleted', () async {
      final s = await failWith(() => folder.corruptReads = true);
      expect(s.lastProblem, FolderProblem.failed);
      expect(folder.names, isEmpty, reason: 'a bad copy must not stay');
    });

    test('an unexpected error is reported and recorded as failed', () async {
      payloadOverride = () async => throw StateError('database');
      final s = await failWith(() {});
      expect(s.lastProblem, FolderProblem.failed);
      expect(errors, [isA<StateError>()]);
    });

    test('a later success clears the problem', () async {
      await failWith(() => folder.writeFails = FolderProblem.noSpace);
      folder.writeFails = null;
      expect(
        (await engine().run(FolderBackupTrigger.manual)).kind,
        FolderBackupOutcomeKind.saved,
      );
      expect((await states.load()).lastProblem, isNull);
    });
  });

  test('nothing to read: skipped, nothing recorded', () async {
    await chooseFolder();
    payloadOverride = () async => null;
    final out = await engine().run(FolderBackupTrigger.daily);
    expect(out.kind, FolderBackupOutcomeKind.skipped);
    final state = await states.load();
    expect(state.lastAttemptAt, isNull);
    expect(state.lastProblem, isNull);
  });

  test('same data, but the newest copy changed size: written again', () async {
    await chooseFolder();
    final e = engine();
    final first = await e.run(FolderBackupTrigger.daily);
    folder.tamper(first.file!.id, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13]);
    now = now.add(const Duration(days: 1));
    expect(
      (await e.run(FolderBackupTrigger.daily)).kind,
      FolderBackupOutcomeKind.saved,
    );
  });

  test('a copy the provider renamed is removed and the run fails', () async {
    await chooseFolder();
    folder.renameOnWrite = true;
    final out = await engine().run(FolderBackupTrigger.daily);
    expect(out.kind, FolderBackupOutcomeKind.failed);
    expect(folder.names, isEmpty);
    expect((await states.load()).lastProblem, FolderProblem.failed);
  });

  test(
    'a planted copy dated in the future does not push real ones out',
    () async {
      await chooseFolder();
      folder.addFile(folderBackupFileName(DateTime(2031, 1, 1)));
      final e = engine();
      for (var i = 0; i < 11; i++) {
        checksum = 'sha256:$i';
        now = now.add(const Duration(days: 1));
        await e.run(FolderBackupTrigger.daily);
      }
      expect(folder.names.where(isFolderBackupName), hasLength(11));
      expect(
        folder.names,
        contains(folderBackupFileName(DateTime(2031, 1, 1))),
      );
    },
  );

  group('run lock', () {
    test('without it a daily copy is skipped, nothing recorded', () async {
      await chooseFolder();
      final lock = _FakeLock()..free = false;
      final out = await engine(lock: lock).run(FolderBackupTrigger.daily);
      expect(out.kind, FolderBackupOutcomeKind.skipped);
      expect(lock.waits, [false]);
      expect(folder.checks, 0);
      expect((await states.load()).lastAttemptAt, isNull);
    });

    test('a manual copy asks to wait for it, and releases it', () async {
      await chooseFolder();
      final lock = _FakeLock();
      final out = await engine(lock: lock).run(FolderBackupTrigger.manual);
      expect(out.kind, FolderBackupOutcomeKind.saved);
      expect(lock.waits, [true]);
      expect(lock.held, isFalse);
    });

    test('released also when the run fails', () async {
      await chooseFolder();
      folder.revoked = true;
      final lock = _FakeLock();
      await engine(lock: lock).run(FolderBackupTrigger.daily);
      expect(lock.held, isFalse);
    });

    test('locked() runs the work under the lock, and without it too', () async {
      final lock = _FakeLock();
      final e = engine(lock: lock);
      expect(await e.locked(() async => lock.held), isTrue);
      expect(lock.held, isFalse);
      lock.free = false;
      expect(await e.locked(() async => 7), 7);
    });
  });

  test('a status for a folder replaced meanwhile is dropped', () async {
    await chooseFolder();
    payloadOverride = () async {
      // The user picks another folder while the copy is being made.
      await states.save(
        const FolderBackupState().withFolder('content://new', 'Otra'),
      );
      return FolderPayload(Uint8List.fromList([1]), 'sha256:x');
    };
    await engine().run(FolderBackupTrigger.daily);
    final state = await states.load();
    expect(state.uri, 'content://new');
    expect(state.lastSuccessAt, isNull);
    expect(state.lastProblem, isNull);
  });
}

String _stamp(DateTime at) {
  final t = at.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year}${two(t.month)}${two(t.day)}-'
      '${two(t.hour)}${two(t.minute)}${two(t.second)}';
}

class _FakeLock implements FolderRunLock {
  bool free = true;
  bool held = false;
  final List<bool> waits = [];

  @override
  Future<bool> acquire({required bool wait}) async {
    waits.add(wait);
    if (!free || held) return false;
    held = true;
    return true;
  }

  @override
  void release() => held = false;
}
