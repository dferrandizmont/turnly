import 'package:flutter/material.dart';

import '../icons/app_icons.dart';
import '../theme/theme_context.dart';

/// A bordered pill that is either selected or not: the selected one gets the
/// 2 dp `todayRing` border, a check and a bolder label (never colour alone),
/// like the "Doblar" chip of the paint tools. Used for single-choice groups
/// of a few short options (category, night override, ...).
class ChoicePill extends StatelessWidget {
  const ChoicePill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.leading,
    this.reserveIcon = false,
    this.radius,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  /// Shown when the pill is not selected (a check replaces it otherwise).
  final IconData? icon;

  /// Drawn before the label, selected or not (a shift's colour swatch, a
  /// badge): the pill says its colour while the icon still says whether it is
  /// chosen.
  final Widget? leading;

  /// Keeps the icon's room even when the pill has none of its own, so a row
  /// of pills does not shift sideways as the choice moves from one to the
  /// other.
  final bool reserveIcon;

  /// Corner radius, or `null` for the fully rounded pill ([StadiumBorder]).
  /// A choice of longer labels (the jobs of «¿A qué te dedicas?») reads
  /// better as a rounded rectangle, like the other selection chips.
  final BorderRadiusGeometry? radius;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final shape = (radius == null
            ? const StadiumBorder()
            : RoundedRectangleBorder(borderRadius: radius!))
        .copyWith(
          side: BorderSide(
            color: selected ? colors.todayRing : colors.borderStrong,
            width: selected ? Sp.ring : 1,
          ),
        );
    final glyph = selected ? AppIcons.check : icon;
    final showIconSlot = glyph != null || reserveIcon;
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      enabled: onTap != null,
      excludeSemantics: true,
      label: label,
      onTap: onTap,
      child: Material(
        color: selected ? colors.surfaceRaised : Colors.transparent,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: Sp.touch),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Sp.l),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (leading != null) ...[
                    leading!,
                    const SizedBox(width: Sp.s),
                  ],
                  if (showIconSlot) ...[
                    SizedBox(
                      width: IconSize.inline,
                      height: IconSize.inline,
                      child: glyph == null
                          ? null
                          : Icon(
                              glyph,
                              size: IconSize.inline,
                              color: colors.textPrimary,
                            ),
                    ),
                    const SizedBox(width: Sp.s),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      style: context.type.body.copyWith(
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
