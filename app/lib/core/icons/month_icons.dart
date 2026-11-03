import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/widgets.dart' show IconData;
import 'package:material_symbols_icons/symbols.dart';

/// The glyphs of the redesigned month (bar of destinations, foldable «Hoy»
/// card) and of the two paint modes, picked the same way as `AppIcons`:
/// SF-Symbols-style on iOS and macOS, Material Symbols rounded elsewhere.
/// Kept in its own file so the branches that grow `AppIcons` in parallel do
/// not collide with it; fold these into `AppIcons` whenever convenient.
class MonthIcons {
  const MonthIcons._();

  static bool get _apple =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  static IconData _pick(IconData apple, IconData material) =>
      _apple ? apple : material;

  /// «Cambiar el turno»: the new shift replaces the one of the day.
  static IconData get replaceShift =>
      _pick(CupertinoIcons.arrow_right_arrow_left, Symbols.swap_horiz_rounded);

  /// «Añadir otro turno» (doblar): the new shift goes next to the one there.
  static IconData get addShift =>
      _pick(CupertinoIcons.plus_square_on_square, Symbols.library_add_rounded);

  /// The arrow of the paint preview («[M] → [N]»).
  static IconData get becomes =>
      _pick(CupertinoIcons.arrow_right, Symbols.arrow_forward_rounded);

  /// Unfold the «Hoy» card.
  static IconData get expand =>
      _pick(CupertinoIcons.chevron_down, Symbols.expand_more_rounded);

  /// Fold the «Hoy» card to one line.
  static IconData get collapse =>
      _pick(CupertinoIcons.chevron_up, Symbols.expand_less_rounded);
}
