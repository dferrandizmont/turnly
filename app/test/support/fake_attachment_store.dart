import 'dart:io';
import 'dart:typed_data';

import 'package:cuadrante/features/notes/data/attachment_store.dart';

/// The store of the files of the attachments, but **in memory**.
///
/// A test of a widget never writes a file: the fake time of `testWidgets` and
/// the E/S of the system do not mix (`docs/ola3-pantallas.md`, «Pruebas
/// obligatorias»). The real store has its own tests
/// (`test/features/notes/attachment_store_test.dart`), which do write files.
///
/// The paths are the ones of the real store (`<hash[0:2]>/<hash>`), so the
/// rows and the files agree exactly as they do in the app.
class FakeAttachmentStore extends AttachmentStore {
  FakeAttachmentStore() : super(Directory.systemTemp);

  /// The files of the store, by path.
  final Map<String, Uint8List> files = {};

  @override
  Future<String> put(Uint8List bytes) async {
    final path = pathOf(bytes);
    files[path] = bytes;
    return path;
  }

  @override
  Future<String> putCopy(Uint8List bytes) async {
    final path = pathOf(bytes);
    if (!files.containsKey(path)) {
      files[path] = bytes;
      return path;
    }
    for (var n = 2; n < 1000; n++) {
      final candidate = '$path-$n';
      if (!files.containsKey(candidate)) {
        files[candidate] = bytes;
        return candidate;
      }
    }
    throw const AttachmentStoreException(
      AttachmentProblem.storeFull,
      'too many copies of the same file',
    );
  }

  @override
  Future<Uint8List> read(String relativePath) async {
    final bytes = files[relativePath];
    if (bytes == null) {
      throw const AttachmentStoreException(
        AttachmentProblem.missing,
        'no such file in the store',
      );
    }
    return bytes;
  }

  @override
  Future<bool> exists(String relativePath) async =>
      files.containsKey(relativePath);

  @override
  Future<bool> delete(String relativePath) async =>
      files.remove(relativePath) != null;

  @override
  Future<List<String>> list() async {
    final found = files.keys.toList()..sort();
    return found;
  }

  @override
  Future<int> totalBytes() async {
    var total = 0;
    for (final bytes in files.values) {
      total += bytes.length;
    }
    return total;
  }

  @override
  Future<int> sweep(
    Set<String> used, {
    Duration minAge = Duration.zero,
    DateTime? now,
  }) async {
    final leftovers = files.keys
        .where((path) => !used.contains(path))
        .toList(growable: false);
    for (final path in leftovers) {
      files.remove(path);
    }
    return leftovers.length;
  }
}
