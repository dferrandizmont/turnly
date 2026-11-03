import 'dart:io';

import 'package:cuadrante/features/backup/data/folder_backup_channel.dart';
import 'package:cuadrante/features/backup/data/incoming_temp_file.dart';
import 'package:cuadrante/features/backup/data/platform_backup_channel.dart';
import 'package:cuadrante/features/backup/domain/backup_codec.dart';
import 'package:cuadrante/features/backup/domain/folder_backup.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'backup_test_support.dart';

// Security review 2, M1: Android streams the incoming file (or the copy read
// from the folder) to `cacheDir/incoming/*.turnly` and answers with the path;
// Dart reads it from disk within the same caps and deletes it afterwards, also
// when reading fails.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory cache;

  /// A file where the native side leaves them: `<cache>/incoming/x.turnly`.
  File temp(String name, List<int> bytes) {
    final file = File(p.join(cache.path, incomingTempDirName, name))
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes);
    return file;
  }

  /// A file of [length] bytes without writing them all (a sparse file).
  File bigTemp(String name, int length) {
    final file = File(p.join(cache.path, incomingTempDirName, name))
      ..createSync(recursive: true);
    final handle = file.openSync(mode: FileMode.write)..truncateSync(length);
    handle.closeSync();
    return file;
  }

  setUp(() => cache = makeTempDir('incoming'));

  group('readAndDeleteIncomingTempFile', () {
    test('reads the file and deletes it', () async {
      final file = temp('incoming-1.turnly', [1, 2, 3]);
      expect(await readAndDeleteIncomingTempFile(file.path), [1, 2, 3]);
      expect(file.existsSync(), isFalse);
    });

    test('a file over the cap is too large and is deleted too', () async {
      final file = bigTemp('incoming-2.turnly', BackupCodec.maxFileBytes + 1);
      await expectLater(
        readAndDeleteIncomingTempFile(file.path),
        throwsA(
          isA<IncomingTempFileException>().having(
            (e) => e.tooLarge,
            'tooLarge',
            isTrue,
          ),
        ),
      );
      expect(file.existsSync(), isFalse);
    });

    test('over the cap of a container is too large even as a ZIP', () async {
      final file = bigTemp('incoming-3.turnly', BackupCodec.maxImportBytes + 1);
      await expectLater(
        readAndDeleteIncomingTempFile(file.path),
        throwsA(isA<IncomingTempFileException>()),
      );
      expect(file.existsSync(), isFalse);
    });

    test('a file that is gone is unreadable, not a crash', () async {
      final path = p.join(cache.path, incomingTempDirName, 'gone.turnly');
      await expectLater(
        readAndDeleteIncomingTempFile(path),
        throwsA(
          isA<IncomingTempFileException>().having(
            (e) => e.tooLarge,
            'tooLarge',
            isFalse,
          ),
        ),
      );
    });

    test('only files of the incoming folder are ever read or deleted', () async {
      // A file of the user's, a relative path and a wrong extension.
      final other = File(p.join(cache.path, 'photo.turnly'))
        ..writeAsBytesSync([1]);
      final wrongExt = temp('notes.txt', [1]);
      for (final path in [other.path, wrongExt.path, 'incoming/x.turnly']) {
        await expectLater(
          readAndDeleteIncomingTempFile(path),
          throwsA(isA<IncomingTempFileException>()),
        );
      }
      expect(other.existsSync(), isTrue);
      expect(wrongExt.existsSync(), isTrue);
      await deleteIncomingTempFile(other.path);
      expect(other.existsSync(), isTrue);
    });
  });

  group('the backup channel', () {
    const channel = MethodChannel('test/incoming');
    final platform = MethodChannelBackupChannel(channel);
    late Object? reply;

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => reply);
    });
    tearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    test('a path is read from disk and the file deleted', () async {
      final file = temp('incoming-4.turnly', [9, 8, 7]);
      reply = {'path': file.path, 'sender': 'WhatsApp (com.whatsapp)'};
      final incoming = (await platform.takeIncomingFile())!;
      expect(incoming.bytes, [9, 8, 7]);
      expect(incoming.sender, 'WhatsApp (com.whatsapp)');
      expect(file.existsSync(), isFalse);
    });

    test('a file over the cap is tooLarge and does not stay', () async {
      final file = bigTemp('incoming-5.turnly', BackupCodec.maxFileBytes + 1);
      reply = {'path': file.path};
      expect(
        (await platform.takeIncomingFile())!.problem,
        IncomingFileProblem.tooLarge,
      );
      expect(file.existsSync(), isFalse);
    });

    test('a path that is not there is unreadable', () async {
      reply = {'path': p.join(cache.path, incomingTempDirName, 'no.turnly')};
      expect(
        (await platform.takeIncomingFile())!.problem,
        IncomingFileProblem.unreadable,
      );
    });
  });

  group('the folder channel', () {
    const channel = MethodChannel('test/incoming-folder');
    const platform = MethodChannelFolderBackupPlatform(channel: channel);
    const name = 'turnly-auto-20261102-030000.turnly';
    late Object? reply;

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => reply);
    });
    tearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    test('read follows the path the platform answers and deletes it', () async {
      final file = temp('folder-1.turnly', [4, 5, 6]);
      reply = file.path;
      final bytes = await platform.read(
        'content://t',
        const FolderFile(id: 'a', name: name, sizeBytes: 3),
      );
      expect(bytes, [4, 5, 6]);
      expect(file.existsSync(), isFalse);
    });

    test('a path over the cap is tooLarge and does not stay', () async {
      final file = bigTemp('folder-2.turnly', BackupCodec.maxFileBytes + 1);
      reply = file.path;
      await expectLater(
        platform.read(
          'content://t',
          const FolderFile(id: 'a', name: name, sizeBytes: 3),
        ),
        throwsA(
          isA<FolderBackupException>().having(
            (e) => e.problem,
            'problem',
            FolderProblem.tooLarge,
          ),
        ),
      );
      expect(file.existsSync(), isFalse);
    });
  });
}
