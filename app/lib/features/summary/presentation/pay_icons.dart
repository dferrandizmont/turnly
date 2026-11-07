import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/widgets.dart' show IconData;
import 'package:material_symbols_icons/symbols.dart';

/// The glyphs of the payroll rules (propuestas 2 y 8): the closing day, the
/// cap of the overtime and the templates of pluses. Picked like [AbsenceIcons]
/// (SF-Symbols-style on iOS and macOS, Material Symbols rounded elsewhere)
/// and kept in their own file so branches that grow `AppIcons` do not collide.
class PayIcons {
  const PayIcons._();

  static bool get _apple =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  static IconData _pick(IconData apple, IconData material) =>
      _apple ? apple : material;

  /// «Día de cierre».
  static IconData get closingDay =>
      _pick(CupertinoIcons.calendar_badge_minus, Symbols.event_rounded);

  /// «Tope de horas extra».
  static IconData get overtimeCap =>
      _pick(CupertinoIcons.gauge, Symbols.speed_rounded);

  /// «Plantilla de pluses».
  static IconData get template =>
      _pick(CupertinoIcons.doc_text, Symbols.description_rounded);
}
