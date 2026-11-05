import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/widgets.dart' show IconData;
import 'package:material_symbols_icons/symbols.dart';

/// The glyphs of the «Borrar todo y empezar de cero» screen that the shared
/// sets do not have, picked the same way as `AppIcons`: SF-Symbols-style on
/// iOS and macOS, Material Symbols rounded elsewhere. The rest of the list
/// reuses `AppIcons` and `SettingsIcons`. Kept in its own file so the files
/// that grow `AppIcons` in parallel do not collide with it; fold these into
/// `AppIcons` whenever convenient.
class ResetIcons {
  const ResetIcons._();

  static bool get _apple =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  static IconData _pick(IconData apple, IconData material) =>
      _apple ? apple : material;

  /// Holidays, leaves and absences.
  static IconData get absences =>
      _pick(CupertinoIcons.sun_max, Symbols.beach_access_rounded);

  /// The swaps book («libro de cambios»).
  static IconData get swaps =>
      _pick(CupertinoIcons.arrow_left_right, Symbols.swap_horiz_rounded);

  /// The shared link.
  static IconData get shareLink =>
      _pick(CupertinoIcons.link, Symbols.link_rounded);

  /// The daily copy in a folder of the phone.
  static IconData get folder =>
      _pick(CupertinoIcons.folder, Symbols.folder_rounded);

  /// All the settings.
  static IconData get preferences =>
      _pick(CupertinoIcons.slider_horizontal_3, Symbols.tune_rounded);
}
