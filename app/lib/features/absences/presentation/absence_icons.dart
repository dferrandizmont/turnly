import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/widgets.dart' show IconData;
import 'package:material_symbols_icons/symbols.dart';

/// The glyphs of the wave 3 screens of vacation and leave (P3) and of hours
/// and money (P9), picked the same way as [AppIcons] (`app_icons.dart`):
/// SF-Symbols-style on iOS and macOS, Material Symbols rounded elsewhere.
/// Kept in its own file, like `ParityIcons`, so branches that grow `AppIcons`
/// in parallel do not collide with it.
class AbsenceIcons {
  const AbsenceIcons._();

  static bool get _apple =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  static IconData _pick(IconData apple, IconData material) =>
      _apple ? apple : material;

  /// «Vacaciones y permisos».
  static IconData get vacation =>
      _pick(CupertinoIcons.sun_max, Symbols.beach_access_rounded);

  /// A warning on a balance (days that expire, more planned than available).
  static IconData get warning =>
      _pick(CupertinoIcons.exclamationmark_triangle, Symbols.warning_rounded);

  /// «Horas y dinero» and the withholding.
  static IconData get money =>
      _pick(CupertinoIcons.percent, Symbols.percent_rounded);

  /// «Llevas ganado».
  static IconData get earned =>
      _pick(CupertinoIcons.money_euro_circle, Symbols.payments_rounded);

  /// The hours bank.
  static IconData get hoursBank =>
      _pick(CupertinoIcons.timer, Symbols.hourglass_top_rounded);
}
