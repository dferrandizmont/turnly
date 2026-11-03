import 'package:flutter/services.dart';

import '../domain/backup_codec.dart';
import '../domain/folder_backup.dart';
import 'incoming_temp_file.dart';

/// How the chosen folder is right now.
enum FolderAccess {
  /// Permission held, folder there, takes new files.
  ok,

  /// The persisted permission is gone.
  revoked,

  /// The folder (or its provider) is gone.
  missing,

  /// The folder does not take new files.
  unwritable;

  /// The problem a copy would hit, or `null` for [ok].
  FolderProblem? get problem => switch (this) {
    FolderAccess.ok => null,
    FolderAccess.revoked => FolderProblem.revoked,
    FolderAccess.missing => FolderProblem.missing,
    FolderAccess.unwritable => FolderProblem.unwritable,
  };
}

/// The answer of [FolderBackupPlatform.check].
class FolderCheck {
  const FolderCheck(this.access, {this.name});

  final FolderAccess access;

  /// The folder's name as the provider shows it (when it can be asked).
  final String? name;
}

/// The folder the user picked in the system picker.
class PickedFolder {
  const PickedFolder({required this.uri, required this.name});

  /// Tree URI, with a persistable read and write permission already taken.
  final String uri;
  final String name;
}

/// The folder of the automatic folder copies, on the platform. Android: the
/// plugin `turnly_folder_access` (Storage Access Framework). iOS: no folder
/// access yet (iCloud Drive is done on the Mac): every call fails with
/// [FolderProblem.unsupported] and the screen does not offer the block.
///
/// Every failure is a [FolderBackupException]; nothing else is thrown.
abstract interface class FolderBackupPlatform {
  /// Opens the system folder picker; `null` when the user goes back.
  Future<PickedFolder?> pick();

  /// How the folder of [uri] is. Never throws for the folder's own state
  /// (that is the answer); only when there is no platform at all.
  Future<FolderCheck> check(String uri);

  /// The plain files directly in the folder.
  Future<List<FolderFile>> list(String uri);

  /// Writes a new file [name] (one of Turnly's own names) with [bytes].
  Future<FolderFile> write(String uri, String name, Uint8List bytes);

  /// The bytes of the file [file] of the folder (only Turnly's own names).
  Future<Uint8List> read(String uri, FolderFile file);

  /// Deletes [file] (only Turnly's own names; a missing file is fine).
  Future<void> delete(String uri, FolderFile file);

  /// Gives back the persisted permission of [uri] (best effort).
  Future<void> release(String uri);
}

/// [FolderBackupPlatform] over the channel `app.cuadrante/folder_backup`
/// (contract in docs/copia-de-seguridad.md, section 11). Checks what the
/// platform sends back as well: shapes, own names, sizes.
class MethodChannelFolderBackupPlatform implements FolderBackupPlatform {
  const MethodChannelFolderBackupPlatform({
    this.channel = const MethodChannel(folderBackupChannelName),
  });

  final MethodChannel channel;

  Future<T?> _call<T>(String method, [Map<String, Object?>? args]) async {
    try {
      return await channel.invokeMethod<T>(method, args);
    } on PlatformException catch (e) {
      throw FolderBackupException(_problemFor(e.code));
    } on MissingPluginException {
      throw const FolderBackupException(FolderProblem.unsupported);
    }
  }

  static FolderProblem _problemFor(String code) => switch (code) {
    'revoked' || 'not_persistable' => FolderProblem.revoked,
    'missing' => FolderProblem.missing,
    'unwritable' => FolderProblem.unwritable,
    'no_space' => FolderProblem.noSpace,
    'too_large' => FolderProblem.tooLarge,
    _ => FolderProblem.failed,
  };

  @override
  Future<PickedFolder?> pick() async {
    final answer = await _call<Map<Object?, Object?>>('pick');
    if (answer == null) return null;
    final uri = answer['uri'];
    final name = answer['name'];
    if (uri is! String || uri.isEmpty) {
      throw const FolderBackupException(FolderProblem.failed);
    }
    return PickedFolder(uri: uri, name: name is String ? name : '');
  }

  @override
  Future<FolderCheck> check(String uri) async {
    final answer = await _call<Map<Object?, Object?>>('check', {'uri': uri});
    final state = answer?['state'];
    final name = answer?['name'];
    final access = switch (state) {
      'ok' => FolderAccess.ok,
      'revoked' => FolderAccess.revoked,
      'unwritable' => FolderAccess.unwritable,
      _ => FolderAccess.missing,
    };
    return FolderCheck(access, name: name is String ? name : null);
  }

  @override
  Future<List<FolderFile>> list(String uri) async {
    final answer = await _call<List<Object?>>('list', {'uri': uri});
    return [for (final item in answer ?? const <Object?>[]) ?_fileFrom(item)];
  }

  static FolderFile? _fileFrom(Object? item) {
    if (item is! Map) return null;
    final id = item['id'];
    final name = item['name'];
    final size = item['sizeBytes'];
    final modified = item['modifiedAtMs'];
    if (id is! String || id.isEmpty || name is! String) return null;
    return FolderFile(
      id: id,
      name: name,
      sizeBytes: size is int && size >= 0 ? size : 0,
      modifiedAt: modified is int && modified > 0
          ? DateTime.fromMillisecondsSinceEpoch(modified, isUtc: true)
          : null,
    );
  }

  @override
  Future<FolderFile> write(String uri, String name, Uint8List bytes) async {
    if (!isFolderBackupName(name)) {
      throw const FolderBackupException(FolderProblem.failed);
    }
    if (!BackupCodec.fitsImportLimit(bytes.length, bytes)) {
      throw const FolderBackupException(FolderProblem.tooLarge);
    }
    final answer = await _call<Map<Object?, Object?>>('write', {
      'uri': uri,
      'name': name,
      'bytes': bytes,
    });
    final file = _fileFrom(answer);
    if (file == null) throw const FolderBackupException(FolderProblem.failed);
    return file;
  }

  @override
  Future<Uint8List> read(String uri, FolderFile file) async {
    // Only Turnly's own copies are ever read (the platform checks it too).
    if (!isFolderBackupName(file.name)) {
      throw const FolderBackupException(FolderProblem.failed);
    }
    if (file.sizeBytes > BackupCodec.maxImportBytes) {
      throw const FolderBackupException(FolderProblem.tooLarge);
    }
    // Android streams the copy to a file in the app's cache and answers with
    // its path (the copy never exists as one byte array on the native heap);
    // Dart reads it and deletes it. Bytes are still accepted.
    final reply = await _call<Object>('read', {'uri': uri, 'id': file.id});
    if (reply is String) {
      try {
        return await readAndDeleteIncomingTempFile(reply);
      } on IncomingTempFileException catch (e) {
        throw FolderBackupException(
          e.tooLarge ? FolderProblem.tooLarge : FolderProblem.failed,
        );
      }
    }
    if (reply is! Uint8List) {
      throw const FolderBackupException(FolderProblem.failed);
    }
    if (!BackupCodec.fitsImportLimit(reply.length, reply)) {
      throw const FolderBackupException(FolderProblem.tooLarge);
    }
    return reply;
  }

  @override
  Future<void> delete(String uri, FolderFile file) async {
    if (!isFolderBackupName(file.name)) return;
    await _call<void>('delete', {'uri': uri, 'id': file.id});
  }

  @override
  Future<void> release(String uri) async {
    try {
      await _call<void>('release', {'uri': uri});
    } on FolderBackupException {
      // Nothing to give back, or no platform.
    }
  }
}

/// Name of the channel of the plugin `turnly_folder_access`.
const String folderBackupChannelName = 'app.cuadrante/folder_backup';
