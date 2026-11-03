import 'dart:io' show Directory;
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../import/data/import_file_picker.dart' show deleteIfCached;

/// Asks the person for a picture of the gallery for the calendar background
/// (UX · Extras visuales). Returns its bytes, or `null` when they cancel.
///
/// The provider that holds it is overridden in the tests with a fake, so the
/// plugin is never called from a widget test.
typedef CalendarImagePicker = Future<Uint8List?> Function();

/// Longest side the picked picture is kept at: a photo of the phone shrinks to
/// this before it is read, so the background is never a 50 MP file.
const int calendarBackgroundMaxSide = 2560;

/// The system gallery picker (`image_picker`, the official flutter.dev one).
///
/// On Android it opens the system photo picker, so no storage permission is
/// asked; on iOS it needs `NSPhotoLibraryUsageDescription` (Info.plist).
Future<Uint8List?> pickCalendarImage() async {
  final picked = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: calendarBackgroundMaxSide.toDouble(),
    maxHeight: calendarBackgroundMaxSide.toDouble(),
  );
  if (picked == null) return null;
  return readPickedImageAndClean(picked, getTemporaryDirectory);
}

/// Reads the picture and then deletes the copy that `image_picker` left in the
/// cache of the app (a photo can be 10 MB or more), also when reading fails.
/// Only a file inside [cacheDir] is deleted, never one of the user's own.
Future<Uint8List> readPickedImageAndClean(
  XFile picked,
  Future<Directory> Function() cacheDir,
) async {
  try {
    return await picked.readAsBytes();
  } finally {
    await deleteIfCached(picked.path, cacheDir);
  }
}
