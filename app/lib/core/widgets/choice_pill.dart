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
    this.detail,
    this.expand = false,
    this.compact = false,
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

  /// Corner radius, or `null` for [Rad.chipSmall] (a rounded rectangle, like
  /// the other chips). A choice of longer labels can ask for a larger one.
  final BorderRadiusGeometry? radius;

  /// A second, quieter line under the label (a shift's hours), so a pill in
  /// a narrow grid column never has to squeeze «Mañana 07:00–15:00» on one
  /// line.
  final String? detail;

  /// Fills the width it is given (a cell of an aligned grid) instead of
  /// hugging its label.
  final bool expand;

  /// For narrow grid cells: 12 dp sides instead of 16 and, with a
  /// [leading], the check drawn on its corner instead of in a slot of its
  /// own, so «Mañana» and its hours fit two to a row on a 360 dp phone.
  final bool compact;

  /// Horizontal room the pill itself takes around its texts (padding,
  /// [leading] and its gap, the check slot, the selected ring), for a grid
  /// sizing its columns.
  static double chromeWidth({
    required bool compact,
    required bool hasLeading,
    double leadingSize = 0,
  }) {
    final side = compact ? Sp.m : Sp.l;
    final lead = hasLeading ? leadingSize + Sp.s : 0;
    final slot = compact && hasLeading ? 0 : IconSize.inline + Sp.s;
    return 2 * side + lead + slot + 2 * Sp.ring;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final shape =
        RoundedRectangleBorder(borderRadius: radius ?? Rad.chipSmallRadius)
            .copyWith(
              side: BorderSide(
                color: selected ? colors.todayRing : colors.borderStrong,
                width: selected ? Sp.ring : 1,
              ),
            );
    final glyph = selected ? AppIcons.check : icon;
    // Compact with a leading: the check rides on the leading's corner.
    final checkOnLeading = compact && leading != null;
    // A grid cell without a leading: label centred, 12 dp sides and no empty
    // slot kept for the check (it only appears on the chosen cell), so a long
    // job name gets the whole cell and reads as a block, not pushed right.
    final centered = expand && leading == null;
    final showIconSlot =
        !checkOnLeading && (glyph != null || (reserveIcon && !centered));
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      enabled: onTap != null,
      excludeSemantics: true,
      label: detail == null ? label : '$label, $detail',
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
              padding: EdgeInsets.symmetric(
                horizontal: compact || centered ? Sp.m : Sp.l,
              ),
              child: Row(
                mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: centered
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  if (leading != null) ...[
                    if (checkOnLeading)
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(
                              top: IconSize.inline,
                            ),
                            child: leading!,
                          ),
                          if (selected)
                            Positioned(
                              right: -Sp.xs,
                              top: 0,
                              child: DecoratedBox(
                                key: const ValueKey('choice-pill-check'),
                                decoration: BoxDecoration(
                                  color: colors.todayRing,
                                  borderRadius: Rad.squareRadius(
                                    IconSize.inline,
                                  ),
                                ),
                                child: SizedBox.square(
                                  dimension: IconSize.inline,
                                  child: Icon(
                                    AppIcons.check,
                                    size: IconSize.inline - Sp.xs,
                                    color: colors.surface,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      )
                    else
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
                    child: Padding(
                      // A grid cell (expand) can wrap its label onto two or
                      // three lines: keep air above and below it, as with a
                      // detail line, so the text never touches the border.
                      padding: detail == null && !expand
                          ? EdgeInsets.zero
                          : const EdgeInsets.symmetric(vertical: Sp.s),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: centered
                            ? CrossAxisAlignment.center
                            : CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            textAlign: centered
                                ? TextAlign.center
                                : TextAlign.start,
                            style: context.type.body.copyWith(
                              fontWeight: selected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                            ),
                          ),
                          if (detail != null)
                            Text(
                              detail!,
                              style: context.type.meta.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                        ],
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
