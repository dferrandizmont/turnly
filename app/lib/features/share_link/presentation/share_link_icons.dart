import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/widgets.dart' show IconData;
import 'package:material_symbols_icons/symbols.dart';

/// The glyphs of «Compartir por enlace», picked like `AppIcons`:
/// SF-Symbols-style on iOS and macOS, Material Symbols rounded elsewhere.
/// Kept in this feature so screens built in parallel do not collide on the
/// shared icon files.
class ShareLinkIcons {
  const ShareLinkIcons._();

  static bool get _apple =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  static IconData _pick(IconData apple, IconData material) =>
      _apple ? apple : material;

  /// The settings row and the link itself.
  static IconData get link => _pick(CupertinoIcons.link, Symbols.link_rounded);

  /// «Actualizar ahora».
  static IconData get refresh =>
      _pick(CupertinoIcons.arrow_clockwise, Symbols.refresh_rounded);

  /// «Revocar enlace».
  static IconData get revoke =>
      _pick(CupertinoIcons.xmark_circle, Symbols.link_off_rounded);

  /// Rest days in the feed.
  static IconData get rest =>
      _pick(CupertinoIcons.moon, Symbols.bedtime_rounded);

  /// Absences in the feed.
  static IconData get absence =>
      _pick(CupertinoIcons.eye_slash, Symbols.visibility_off_rounded);

  /// What goes out and what does not.
  static IconData get privacy =>
      _pick(CupertinoIcons.lock_shield, Symbols.shield_lock_rounded);
}
