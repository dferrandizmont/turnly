import 'dart:typed_data';

import '../data/calendar_background_store.dart';

/// Stores and removes the picture drawn behind the month (UX · Extras
/// visuales), keeping the preference and the file in step: the file is written
/// first and the preference points at it after, so the month never asks for a
/// picture that is not there.
///
/// The file lives in the app's own folder and **does not travel in a backup**
/// (it has no attachment row, so a restored copy leaves the background unset).
class CalendarBackgroundService {
  CalendarBackgroundService({
    required this.store,
    required this.now,
    required this.applyPath,
  });

  final CalendarBackgroundStore store;

  /// The clock that names the file (the moment it was saved, so a replaced
  /// picture never reuses the cache of the old one).
  final DateTime Function() now;

  /// Points the preference at the stored file (or `null` to clear it).
  final Future<void> Function(String? path) applyPath;

  /// Stores the picked picture and points the preference at it; the previous
  /// file goes.
  ///
  /// Throws [CalendarBackgroundException] ([CalendarBackgroundProblem.tooLarge])
  /// when the picture is too big, leaving the file and the preference as they
  /// were.
  Future<void> setFromBytes(Uint8List bytes) async {
    final name = await store.save(bytes, stamp: now().millisecondsSinceEpoch);
    await applyPath(name);
    await store.sweep(name);
  }

  /// Removes the background: the preference is cleared and the file goes.
  Future<void> remove() async {
    await applyPath(null);
    await store.sweep(null);
  }
}
