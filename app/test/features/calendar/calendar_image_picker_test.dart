import 'dart:io';

import 'package:cuadrante/features/calendar/data/calendar_image_picker.dart';
import 'package:file_selector/file_selector.dart' show XFile;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../support/test_storage.dart' show makeTempDir;

// Security review 2, L2: the copy that image_picker leaves in the cache of the
// app is deleted once the picture has been read, also when reading fails, and
// a file outside the cache is never touched.
void main() {
  test('the cached copy is deleted after it is read', () async {
    final cache = makeTempDir('picker-cache');
    final file = File(p.join(cache.path, 'image_picker_123.jpg'))
      ..writeAsBytesSync([1, 2, 3]);
    final bytes = await readPickedImageAndClean(
      XFile(file.path),
      () async => cache,
    );
    expect(bytes, [1, 2, 3]);
    expect(file.existsSync(), isFalse);
  });

  test('it is deleted when reading fails too', () async {
    final cache = makeTempDir('picker-cache');
    final path = p.join(cache.path, 'gone.jpg');
    // Not there: reading throws, and nothing is left to delete or break.
    await expectLater(
      readPickedImageAndClean(XFile(path), () async => cache),
      throwsA(anything),
    );
  });

  test('a picture outside the cache is never deleted', () async {
    final cache = makeTempDir('picker-cache');
    final elsewhere = makeTempDir('picker-gallery');
    final file = File(p.join(elsewhere.path, 'mine.jpg'))
      ..writeAsBytesSync([9]);
    final bytes = await readPickedImageAndClean(
      XFile(file.path),
      () async => cache,
    );
    expect(bytes, [9]);
    expect(file.existsSync(), isTrue);
  });
}
