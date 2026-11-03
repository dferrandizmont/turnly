import 'package:cuadrante/features/backup/data/folder_backup_channel.dart';
import 'package:cuadrante/features/backup/domain/backup_codec.dart';
import 'package:cuadrante/features/backup/domain/folder_backup.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// P10: the Dart side of the channel `app.cuadrante/folder_backup` checks what
// it sends and what comes back, and turns every platform error into a typed
// problem.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/folder_backup');
  const platform = MethodChannelFolderBackupPlatform(channel: channel);
  final calls = <MethodCall>[];
  late Future<Object?> Function(MethodCall call) answer;

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) {
          calls.add(call);
          return answer(call);
        });
  });

  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  Future<FolderProblem> problemOf(Future<Object?> Function() call) async {
    try {
      await call();
    } on FolderBackupException catch (e) {
      return e.problem;
    }
    fail('expected a FolderBackupException');
  }

  test('error codes become problems', () async {
    const codes = {
      'revoked': FolderProblem.revoked,
      'not_persistable': FolderProblem.revoked,
      'missing': FolderProblem.missing,
      'unwritable': FolderProblem.unwritable,
      'no_space': FolderProblem.noSpace,
      'too_large': FolderProblem.tooLarge,
      'busy': FolderProblem.failed,
      'something_new': FolderProblem.failed,
    };
    for (final MapEntry(:key, :value) in codes.entries) {
      answer = (_) async => throw PlatformException(code: key);
      expect(await problemOf(() => platform.list('content://t')), value);
    }
  });

  test('no plugin (iOS, tests) is "unsupported"', () async {
    const missing = MethodChannelFolderBackupPlatform(
      channel: MethodChannel('test/nobody-listens'),
    );
    expect(await problemOf(missing.pick), FolderProblem.unsupported);
    expect(
      await problemOf(() => missing.check('content://t')),
      FolderProblem.unsupported,
    );
  });

  test('pick: a folder, or null when the user goes back', () async {
    answer = (_) async => {'uri': 'content://p/tree/1', 'name': 'Copias'};
    final picked = await platform.pick();
    expect(picked!.uri, 'content://p/tree/1');
    expect(picked.name, 'Copias');
    answer = (_) async => null;
    expect(await platform.pick(), isNull);
    answer = (_) async => {'uri': ''};
    expect(await problemOf(platform.pick), FolderProblem.failed);
  });

  test('check maps the states; anything unknown is "missing"', () async {
    for (final (state, access) in [
      ('ok', FolderAccess.ok),
      ('revoked', FolderAccess.revoked),
      ('unwritable', FolderAccess.unwritable),
      ('missing', FolderAccess.missing),
      ('weird', FolderAccess.missing),
    ]) {
      answer = (_) async => {'state': state, 'name': 'Copias'};
      expect((await platform.check('content://t')).access, access);
    }
  });

  test('list drops entries that are not files', () async {
    answer = (_) async => [
      {
        'id': 'a',
        'name': 'turnly-auto-20261031-030000.turnly',
        'sizeBytes': 7,
        'modifiedAtMs': 1000,
      },
      {'id': '', 'name': 'x'},
      {'name': 'no id'},
      'rubbish',
      {'id': 'b', 'name': 'otro.txt', 'sizeBytes': -5},
    ];
    final files = await platform.list('content://t');
    expect(files.map((f) => f.id), ['a', 'b']);
    expect(files.first.sizeBytes, 7);
    expect(files.first.modifiedAt, DateTime.utc(1970, 1, 1, 0, 0, 1));
    expect(files.last.sizeBytes, 0);
  });

  test(
    'write refuses foreign names and oversize files before calling',
    () async {
      answer = (_) async => {'id': 'n', 'name': 'x', 'sizeBytes': 1};
      expect(
        await problemOf(
          () => platform.write('content://t', 'notas.txt', Uint8List(1)),
        ),
        FolderProblem.failed,
      );
      expect(
        await problemOf(
          () => platform.write(
            'content://t',
            'turnly-auto-20261031-030000.turnly',
            Uint8List(BackupCodec.maxFileBytes + 1),
          ),
        ),
        FolderProblem.tooLarge,
      );
      expect(calls, isEmpty);
      final file = await platform.write(
        'content://t',
        'turnly-auto-20261031-030000.turnly',
        Uint8List.fromList([1, 2]),
      );
      expect(file.id, 'n');
      expect(calls.single.arguments, {
        'uri': 'content://t',
        'name': 'turnly-auto-20261031-030000.turnly',
        'bytes': Uint8List.fromList([1, 2]),
      });
    },
  );

  /// Zeros that start like a ZIP, so they count as a container.
  Uint8List zipLike(int length) =>
      Uint8List(length)..setRange(0, 4, const [0x50, 0x4b, 0x03, 0x04]);

  test('a container (a copy with photos) goes through up to the import cap, '
      'a plain file only up to the plain cap', () async {
    const name = 'turnly-auto-20261031-030000.turnly';
    answer = (_) async => {'id': 'n', 'name': name, 'sizeBytes': 1};
    // ~9 MiB: over the plain cap, a container.
    final nineMiB = zipLike(9 * 1024 * 1024);
    final written = await platform.write('content://t', name, nineMiB);
    expect(written.id, 'n');
    expect(
      (calls.single.arguments as Map)['bytes'],
      hasLength(9 * 1024 * 1024),
    );
    // The same size that is not a ZIP is not a backup.
    expect(
      await problemOf(
        () => platform.write('content://t', name, Uint8List(9 * 1024 * 1024)),
      ),
      FolderProblem.tooLarge,
    );
    // Over the cap of a container nothing goes.
    expect(
      await problemOf(
        () => platform.write(
          'content://t',
          name,
          zipLike(BackupCodec.maxImportBytes + 1),
        ),
      ),
      FolderProblem.tooLarge,
    );
    // And it reads back: the listed size is within the cap, the bytes too.
    calls.clear();
    answer = (_) async => nineMiB;
    final read = await platform.read(
      'content://t',
      FolderFile(id: 'n', name: name, sizeBytes: nineMiB.length),
    );
    expect(read, hasLength(9 * 1024 * 1024));
    // A plain 9 MiB read is refused after the read.
    answer = (_) async => Uint8List(9 * 1024 * 1024);
    expect(
      await problemOf(
        () => platform.read(
          'content://t',
          FolderFile(id: 'n', name: name, sizeBytes: 9 * 1024 * 1024),
        ),
      ),
      FolderProblem.tooLarge,
    );
  });

  test('read checks the size before and after', () async {
    const big = FolderFile(
      id: 'a',
      name: 'turnly-auto-20261031-030000.turnly',
      sizeBytes: BackupCodec.maxImportBytes + 1,
    );
    answer = (_) async => Uint8List(1);
    expect(
      await problemOf(() => platform.read('content://t', big)),
      FolderProblem.tooLarge,
    );
    expect(calls, isEmpty);
    answer = (_) async => Uint8List(BackupCodec.maxFileBytes + 1);
    expect(
      await problemOf(
        () => platform.read(
          'content://t',
          const FolderFile(
            id: 'a',
            name: 'turnly-auto-20261031-030000.turnly',
            sizeBytes: 10,
          ),
        ),
      ),
      FolderProblem.tooLarge,
    );
  });

  test('delete never asks for a foreign file', () async {
    answer = (_) async => null;
    await platform.delete(
      'content://t',
      const FolderFile(id: 'x', name: 'mis turnos.pdf', sizeBytes: 1),
    );
    expect(calls, isEmpty);
    await platform.delete(
      'content://t',
      const FolderFile(
        id: 'y',
        name: 'turnly-auto-20261031-030000.turnly',
        sizeBytes: 1,
      ),
    );
    expect(calls.single.method, 'delete');
  });

  test('release never fails', () async {
    answer = (_) async => throw PlatformException(code: 'failed');
    await platform.release('content://t');
  });
}
