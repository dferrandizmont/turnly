import 'package:flutter/material.dart';

import '../../../core/icons/app_icons.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/theme_context.dart';
import '../../schedule/domain/schedule_domain.dart';
import 'puck_label.dart';
import 'shift_format.dart';
import 'shift_icon_glyph.dart';

/// The palette of the day detail, inside the same sheet (or pane): opened by
/// «Añadir turno» (add or double) or by «Cambiar» in the menu of a shift row
/// (swap that shift). [title] says which; [hint] goes under the pucks.
///
/// The pucks wrap onto as many lines as they need (H-T17-3, H-T21-9): a
/// single scrolling row cut the last name at large text, in landscape or in
/// Basque, with nothing to say it scrolled. The sheet scrolls vertically, so
/// any number of shift types is reachable.
class DayPalettePanel extends StatelessWidget {
  const DayPalettePanel({
    super.key,
    required this.title,
    required this.palette,
    required this.taken,
    required this.onPick,
    required this.onClose,
    this.hint,
  });

  final String title;
  final List<ShiftType> palette;

  /// Shifts the day already has: greyed out and not tappable.
  final Set<String> taken;
  final ValueChanged<String> onPick;
  final VoidCallback onClose;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final type = context.type;
    return DecoratedBox(
      key: const ValueKey('day-palette'),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: Rad.rowRadius,
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Sp.m, Sp.xs, Sp.xs, Sp.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(title, style: type.bodyStrong),
                  ),
                ),
                IconButton(
                  key: const ValueKey('day-palette-close'),
                  tooltip: l10n.close,
                  icon: Icon(AppIcons.close, color: colors.textMuted),
                  onPressed: onClose,
                ),
              ],
            ),
            Wrap(
              key: const ValueKey('day-add-wrap'),
              spacing: Sp.xs,
              runSpacing: Sp.xs,
              children: [
                for (final shift in palette)
                  DayAddPuck(
                    key: ValueKey('day-add-${shift.id}'),
                    shift: shift,
                    onTap: taken.contains(shift.id)
                        ? null
                        : () => onPick(shift.id),
                  ),
              ],
            ),
            if (hint != null)
              Padding(
                padding: const EdgeInsets.only(top: Sp.s, right: Sp.s),
                child: Text(hint!, style: type.meta),
              ),
          ],
        ),
      ),
    );
  }
}

/// A shift of the palette as a round puck (disc + ink code, name below).
/// Greyed out and not tappable when [onTap] is null (the day has it).
class DayAddPuck extends StatelessWidget {
  const DayAddPuck({super.key, required this.shift, required this.onTap});

  final ShiftType shift;
  final VoidCallback? onTap;

  static const double _minWidth = Disc.l + 2 * Sp.m;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final swatch = shift.swatch(colors.brightness);
    final labelStyle = type.caption.copyWith(color: colors.textMuted);
    // Grows with the text size and the name: never abbreviated.
    final width = puckWidth(
      context,
      label: shift.name,
      style: labelStyle,
      minWidth: _minWidth,
    );
    return Semantics(
      container: true,
      button: true,
      enabled: onTap != null,
      excludeSemantics: true,
      label: shift.name,
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.4 : 1,
        child: InkWell(
          customBorder: RoundedRectangleBorder(borderRadius: Rad.inputRadius),
          onTap: onTap,
          child: SizedBox(
            width: width,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: Sp.xs),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: swatch.disc,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox.square(
                    dimension: Disc.l,
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Padding(
                          padding: const EdgeInsets.all(Sp.xs),
                          child: ShiftCodeWithIcon(
                            shift: shift,
                            iconSize: 11,
                            style: type.bodyStrong.copyWith(
                              color: swatch.ink,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: Sp.xs),
                PuckLabel(label: shift.name, style: labelStyle),
                const SizedBox(height: Sp.xs),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
