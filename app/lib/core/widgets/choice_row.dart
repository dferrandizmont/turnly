import 'package:flutter/material.dart';

import '../icons/app_icons.dart';
import '../theme/theme_context.dart';

/// One row of a single-choice list (the sheets of jobs, communities,
/// municipalities, holidays, currency and reports, and the job card of the
/// profession step): the label, and a check when it is the current one.
/// Announced by screen readers as an option of a mutually exclusive group
/// that can be activated; the chosen one is only in bold, with the mark.
///
/// The text starts [Sp.xs] inside the gutter of the sheet; in a sheet whose
/// list owns the whole width, wrap the row in a `Padding` of
/// [Sp.page] so the text lands at the same x.
class ChoiceRow extends StatelessWidget {
  const ChoiceRow({
    super.key,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.subtitle,
  });

  final String label;

  /// A second, quieter line (the province of a municipality whose name
  /// repeats).
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  /// Minimum height of a row (a comfortable touch target).
  static const double minHeight = 52;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    return Semantics(
      container: true,
      checked: selected,
      inMutuallyExclusiveGroup: true,
      excludeSemantics: true,
      label: subtitle == null ? label : '$label, $subtitle',
      onTap: onTap,
      child: InkWell(
        borderRadius: Rad.rowRadius,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: minHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Sp.xs,
              vertical: Sp.s,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        // Same size selected or not, only bolder: the row never jumps.
                        style: selected
                            ? type.body.copyWith(fontWeight: FontWeight.w700)
                            : type.body,
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: type.meta.copyWith(color: colors.textMuted),
                        ),
                    ],
                  ),
                ),
                if (selected)
                  Icon(AppIcons.check, color: colors.accentStrong, weight: 600),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
