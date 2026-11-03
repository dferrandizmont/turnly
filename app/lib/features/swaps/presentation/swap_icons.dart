import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/widgets.dart' show IconData;
import 'package:material_symbols_icons/symbols.dart';

/// The glyphs of the swap book (P4), picked the same way as [AppIcons]
/// (`app_icons.dart`): SF-Symbols-style on iOS and macOS, Material Symbols
/// rounded elsewhere. Kept in its own file, like `AbsenceIcons`, so branches
/// that grow `AppIcons` in parallel do not collide with it.
class SwapIcons {
  const SwapIcons._();

  static bool get _apple =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  static IconData _pick(IconData apple, IconData material) =>
      _apple ? apple : material;

  /// «Libro de cambios».
  static IconData get swaps =>
      _pick(CupertinoIcons.arrow_left_right, Symbols.swap_horiz_rounded);

  /// A change of shift (the row of the book).
  static IconData get swap =>
      _pick(CupertinoIcons.arrow_2_circlepath, Symbols.sync_alt_rounded);

  /// The favour came back.
  static IconData get returned =>
      _pick(CupertinoIcons.arrow_uturn_left, Symbols.undo_rounded);
}
