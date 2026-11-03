import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/application/preferences_controller.dart';

/// Plays the click of the system when a day is painted, if «Sonido al pintar»
/// is on (UX · Extras visuales). `SystemSound` follows the silent mode of the
/// phone, and a device without a sound never breaks the stroke: the same rule
/// as the haptics of the grid.
void playPaintSound(WidgetRef ref) {
  if (!ref.read(preferencesProvider).paintSound) return;
  unawaited(SystemSound.play(SystemSoundType.click).catchError((Object _) {}));
}
