import 'dart:typed_data';

import 'package:cuadrante/features/backup/data/folder_backup_channel.dart';
import 'package:cuadrante/features/backup/data/folder_backup_task.dart';
import 'package:cuadrante/features/backup/domain/folder_backup.dart';

/// A folder held in memory, behaving like a Storage Access Framework tree:
/// documents with opaque ids, a permission that can be revoked, a folder
/// that can be deleted, a provider that can run out of space.
class FakeFolderPlatform implements FolderBackupPlatform {
  FakeFolderPlatform({this.uri = 'content://fake/tree/folder'});

  /// The folder the picker returns (and the only one that exists).
  String uri;
  String name = 'Copias';

  /// What the picker answers: `false` = the user goes back.
  bool pickChoosesFolder = true;

  /// Makes the picker fail.
  FolderProblem? pickFails;

  /// The permission was revoked / the folder deleted / it is read-only.
  bool revoked = false;
  bool deleted = false;
  bool readOnly = false;

  /// The next writes fail with this problem.
  FolderProblem? writeFails;

  /// Reads return other bytes than the ones written (a provider that
  /// mangles the file).
  bool corruptReads = false;

  /// Deleting fails (the rotation must not break the copy).
  bool deleteFails = false;

  /// The provider gives new files another name ("... (1).turnly").
  bool renameOnWrite = false;

  final Map<String, ({String name, Uint8List bytes})> docs = {};
  int _nextId = 1;

  final List<String> released = [];
  int picks = 0;
  int writes = 0;
  int checks = 0;

  /// Puts a file the user owns (or an old copy) in the folder.
  String addFile(String name, [List<int> bytes = const [1, 2, 3]]) {
    final id = 'doc-${_nextId++}';
    docs[id] = (name: name, bytes: Uint8List.fromList(bytes));
    return id;
  }

  List<String> get names => [for (final d in docs.values) d.name]..sort();

  void _guard(String uri) {
    if (revoked) throw const FolderBackupException(FolderProblem.revoked);
    if (deleted || uri != this.uri) {
      throw const FolderBackupException(FolderProblem.missing);
    }
  }

  @override
  Future<PickedFolder?> pick() async {
    picks++;
    final fails = pickFails;
    if (fails != null) throw FolderBackupException(fails);
    if (!pickChoosesFolder) return null;
    revoked = false;
    return PickedFolder(uri: uri, name: name);
  }

  @override
  Future<FolderCheck> check(String uri) async {
    checks++;
    if (revoked) return const FolderCheck(FolderAccess.revoked);
    if (deleted || uri != this.uri) {
      return const FolderCheck(FolderAccess.missing);
    }
    if (readOnly) return FolderCheck(FolderAccess.unwritable, name: name);
    return FolderCheck(FolderAccess.ok, name: name);
  }

  @override
  Future<List<FolderFile>> list(String uri) async {
    _guard(uri);
    return [
      for (final e in docs.entries)
        FolderFile(
          id: e.key,
          name: e.value.name,
          sizeBytes: e.value.bytes.length,
        ),
    ];
  }

  @override
  Future<FolderFile> write(String uri, String name, Uint8List bytes) async {
    _guard(uri);
    writes++;
    final fails = writeFails;
    if (fails != null) throw FolderBackupException(fails);
    if (readOnly) throw const FolderBackupException(FolderProblem.unwritable);
    final shown = renameOnWrite
        ? name.replaceFirst('.turnly', ' (1).turnly')
        : name;
    final id = addFile(shown, bytes);
    return FolderFile(id: id, name: shown, sizeBytes: bytes.length);
  }

  @override
  Future<Uint8List> read(String uri, FolderFile file) async {
    _guard(uri);
    final doc = docs[file.id];
    if (doc == null) throw const FolderBackupException(FolderProblem.missing);
    if (corruptReads) return Uint8List.fromList([9, 9, 9]);
    return doc.bytes;
  }

  /// Changes the bytes of a stored file in place (somebody edited it), so
  /// its size changes.
  void tamper(String id, List<int> bytes) =>
      docs[id] = (name: docs[id]!.name, bytes: Uint8List.fromList(bytes));

  @override
  Future<void> delete(String uri, FolderFile file) async {
    _guard(uri);
    if (deleteFails) throw const FolderBackupException(FolderProblem.failed);
    docs.remove(file.id);
  }

  @override
  Future<void> release(String uri) async => released.add(uri);
}

/// Records what the app asks of WorkManager.
class FakeFolderScheduling implements FolderBackupScheduling {
  final List<bool> calls = [];
  bool fail = false;

  @override
  Future<void> setEnabled(bool enabled) async {
    if (fail) throw StateError('WorkManager');
    calls.add(enabled);
  }
}
