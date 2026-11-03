import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui' show IsolateNameServer;

import 'package:cuadrante/core/background/isolate_mutex.dart';
import 'package:cuadrante/features/alarms/data/alarm_foreground_relay.dart';
import 'package:cuadrante/features/backup/data/folder_backup_state_store.dart';
import 'package:cuadrante/features/backup/domain/folder_backup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../support/test_storage.dart';

// P10, review M1/M2: the app and the background task never copy (nor write
// the state) at once, the relay never stays disconnected, and a damaged state
// file is never read as "no folder".

void main() {
  group('FolderBackupStateStore', () {
    late Directory dir;
    late File file;
    late FolderBackupStateStore store;

    setUp(() {
      dir = Directory(
        p.join(makeTempDir('folder-state').path, 'folder_backup'),
      );
      file = File(p.join(dir.path, folderBackupStateFileName));
      store = FolderBackupStateStore(file);
    });

    test('no file is an empty state; a damaged one says so', () async {
      expect((await store.load()).damaged, isFalse);
      dir.createSync(recursive: true);
      file.writeAsStringSync('{"uri": "content://x", trunc');
      final damaged = await store.load();
      expect(damaged.damaged, isTrue);
      expect(damaged.configured, isFalse);
      file.writeAsStringSync('[1, 2]');
      expect((await store.load()).damaged, isTrue);
    });

    test('writing again repairs a damaged file', () async {
      dir.createSync(recursive: true);
      file.writeAsStringSync('garbage');
      await store.update((s) => s.withFolder('content://x', 'C'));
      final back = await store.load();
      expect(back.damaged, isFalse);
      expect(back.uri, 'content://x');
    });

    test(
      'concurrent updates are not lost and leave no temporary files',
      () async {
        await store.save(const FolderBackupState(uri: 'u', name: ''));
        await Future.wait([
          for (var i = 0; i < 25; i++)
            store.update(
              (s) => FolderBackupState(uri: s.uri, name: '${s.name ?? ''}x'),
            ),
        ]);
        expect((await store.load()).name, 'x' * 25);
        final leftovers = [for (final f in dir.listSync()) p.basename(f.path)]
          ..sort();
        expect(
          leftovers,
          unorderedEquals([
            folderBackupLockFileName,
            folderBackupStateFileName,
          ]),
        );
      },
    );

    test('two stores on the same file also take turns', () async {
      final other = FolderBackupStateStore(File(file.path));
      await store.save(const FolderBackupState(uri: 'u', name: ''));
      await Future.wait([
        for (var i = 0; i < 10; i++) ...[
          store.update(
            (s) => FolderBackupState(uri: s.uri, name: '${s.name ?? ''}a'),
          ),
          other.update(
            (s) => FolderBackupState(uri: s.uri, name: '${s.name ?? ''}b'),
          ),
        ],
      ]);
      expect((await store.load()).name, hasLength(20));
    });
  });

  group('IsolateMutex', () {
    const name = 'test/folder-mutex';
    tearDown(() => IsolateNameServer.removePortNameMapping(name));

    test('one holder at a time; free again after release', () async {
      final a = IsolateMutex(name);
      final b = IsolateMutex(name, probe: const Duration(milliseconds: 200));
      expect(await a.tryAcquire(), isTrue);
      expect(await b.tryAcquire(), isFalse, reason: 'a is alive and holds it');
      a.release();
      expect(await b.tryAcquire(), isTrue);
      b.release();
      expect(IsolateNameServer.lookupPortByName(name), isNull);
    });

    test('a waiting acquire gets it once the holder releases', () async {
      final a = IsolateMutex(name);
      final b = IsolateMutex(
        name,
        probe: const Duration(milliseconds: 100),
        retryEvery: const Duration(milliseconds: 20),
      );
      await a.tryAcquire();
      Timer(const Duration(milliseconds: 150), a.release);
      expect(await b.acquire(wait: const Duration(seconds: 5)), isTrue);
      b.release();
    });

    test('a waiting acquire gives up after its wait', () async {
      final a = IsolateMutex(name);
      final b = IsolateMutex(
        name,
        probe: const Duration(milliseconds: 50),
        retryEvery: const Duration(milliseconds: 20),
      );
      await a.tryAcquire();
      expect(await b.acquire(wait: const Duration(milliseconds: 200)), isFalse);
      a.release();
    });

    test('a holder that died with it is taken over', () async {
      final orphan = ReceivePort(); // never answers the ping
      addTearDown(orphan.close);
      IsolateNameServer.registerPortWithName(orphan.sendPort, name);
      final b = IsolateMutex(name, probe: const Duration(milliseconds: 50));
      expect(await b.tryAcquire(), isTrue);
      b.release();
    });
  });

  group('AlarmForegroundRelay (shared with the folder copy)', () {
    const name = 'test/folder-relay';
    tearDown(() => IsolateNameServer.removePortNameMapping(name));

    test('answerFirst answers before the work ends', () async {
      final work = Completer<void>();
      var started = false;
      final relay = AlarmForegroundRelay(portName: name, answerFirst: true)
        ..open(() async {
          started = true;
          await work.future;
        });
      addTearDown(relay.close);
      expect(
        await askForegroundToResync(
          portName: name,
          timeout: const Duration(seconds: 5),
        ),
        isTrue,
      );
      expect(started, isTrue);
      expect(work.isCompleted, isFalse, reason: 'answered while working');
      work.complete();
    });

    test('a background side that gave up does not leave the app '
        'disconnected', () async {
      final work = Completer<void>();
      final relay = AlarmForegroundRelay(portName: name)
        ..open(() => work.future);
      addTearDown(relay.close);
      // The background side times out while the app is busy and forgets the
      // mapping.
      expect(
        await askForegroundToResync(
          portName: name,
          timeout: const Duration(milliseconds: 50),
        ),
        isFalse,
      );
      expect(IsolateNameServer.lookupPortByName(name), isNull);
      // Once the app is done it registers again, and answers the next one.
      work.complete();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(IsolateNameServer.lookupPortByName(name), isNotNull);
      expect(await askForegroundToResync(portName: name), isTrue);
    });

    test('listen() registers again a lost mapping', () async {
      final relay = AlarmForegroundRelay(portName: name)..listen();
      addTearDown(relay.close);
      IsolateNameServer.removePortNameMapping(name);
      relay.listen();
      expect(IsolateNameServer.lookupPortByName(name), isNotNull);
    });

    test('it never takes the name back from a newer relay', () async {
      final old = AlarmForegroundRelay(portName: name)..open(() async {});
      final current = AlarmForegroundRelay(portName: name)..open(() async {});
      addTearDown(old.close);
      addTearDown(current.close);
      final now = IsolateNameServer.lookupPortByName(name);
      old.listen();
      old.attach(() async {});
      expect(IsolateNameServer.lookupPortByName(name), now);
    });
  });
}
