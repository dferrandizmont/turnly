import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/providers.dart';
import '../../settings/application/preferences_controller.dart';
import '../data/calendar_background_store.dart';
import '../data/calendar_image_picker.dart';
import 'calendar_background_service.dart';

/// The files of the calendar background (the `calendar_background` folder
/// inside `Application Support`). Tests override it with a temporary folder.
///
/// Without the plugin of the system (a plain unit test) the files go to the
/// temporary folder of the system: the provider must never fail.
final calendarBackgroundStoreProvider = FutureProvider<CalendarBackgroundStore>(
  (ref) async {
    final support = await _supportDirectory();
    return CalendarBackgroundStore(
      Directory(p.join(support.path, calendarBackgroundDirectoryName)),
    );
  },
);

Future<Directory> _supportDirectory() async {
  try {
    return await getApplicationSupportDirectory();
  } catch (_) {
    return Directory.systemTemp;
  }
}

/// The gallery picker (UX · Extras visuales). Tests override it with a fake, so
/// the system picker is never opened.
final calendarImagePickerProvider = Provider<CalendarImagePicker>(
  (ref) => pickCalendarImage,
);

/// The file of the calendar background, or `null` when none is set (or the
/// stored file is gone). The month layer and the settings thumbnail watch it.
final calendarBackgroundFileProvider = FutureProvider<File?>((ref) async {
  final path = ref.watch(
    preferencesProvider.select((p) => p.calendarBackgroundPath),
  );
  if (path == null) return null;
  final store = await ref.watch(calendarBackgroundStoreProvider.future);
  if (!await store.exists(path)) return null;
  return store.file(path);
});

/// Stores and removes the background picture, keeping the preference in step.
final calendarBackgroundServiceProvider =
    FutureProvider<CalendarBackgroundService>((ref) async {
      return CalendarBackgroundService(
        store: await ref.watch(calendarBackgroundStoreProvider.future),
        now: ref.watch(clockProvider),
        applyPath: (path) =>
            ref.read(preferencesProvider.notifier).setCalendarBackground(path),
      );
    });
