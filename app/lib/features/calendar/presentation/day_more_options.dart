import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/icons/app_icons.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/theme_context.dart';
import '../../notes/presentation/attachments_section.dart';
import '../../notes/presentation/day_tasks_section.dart';
import '../../schedule/domain/schedule_domain.dart';
import '../../swaps/presentation/day_swap_section.dart';

/// A section that a feature adds to «Más opciones» of the day detail
/// (`docs/diseno.md`, «Detalle del día»): attachments (C7), the swap book
/// (C10), an extra amount for the day...
///
/// The section shows under the built-in ones (extra hours, own holiday,
/// reminder, alarm) and above «Duplicar en otro día» / «Borrar día», in the
/// sheet and in the tablet pane alike, and its [name] joins the folded line
/// that says what «Más opciones» holds. It saves its own changes, one undo
/// step each through `ScheduleController`, and writes anything pending in its
/// `dispose`: the sheet can close, or «Más opciones» fold, at any moment.
@immutable
class DayMoreSection {
  const DayMoreSection({
    required this.id,
    required this.name,
    required this.builder,
  });

  /// Stable id; the section is wrapped in a `KeyedSubtree` keyed
  /// `day-more-<id>`.
  final String id;

  /// Short name in the folded line («Adjuntos»), from the ARB files.
  final String Function(AppLocalizations l10n) name;

  /// The section for [date]. It gets the page gutter from the sheet.
  final Widget Function(BuildContext context, CivilDate date) builder;
}

/// The hook for future packages: **one line per feature** in this list, for
/// example
///
/// ```dart
/// DayMoreSection(id: 'attachments', name: attachmentsName, builder: attachmentsSection),
/// ```
///
/// with `attachmentsName` and `attachmentsSection` two top-level functions of
/// that feature. Nothing else in the day detail changes. Tests override it to
/// check a section shows and is named.
final dayMoreSectionsProvider = Provider<List<DayMoreSection>>(
  (ref) => const [
    // C7 adjuntos, importe extra por día: aquí.
    DayMoreSection(
      id: 'attachments',
      name: noteAttachmentsSectionName,
      builder: noteAttachmentsSection,
    ),
    DayMoreSection(
      id: 'tasks',
      name: noteTasksSectionName,
      builder: noteTasksSection,
    ),
    // C10 libro de cambios (P4).
    DayMoreSection(
      id: 'swaps',
      name: swapDaySectionName,
      builder: swapDaySection,
    ),
  ],
);

/// «Más opciones» of the day detail: a row that says what it holds
/// ([summary]) and unfolds [children] under it when tapped.
class DayMoreOptions extends StatelessWidget {
  const DayMoreOptions({
    super.key,
    required this.open,
    required this.onToggle,
    required this.summary,
    required this.children,
  });

  final bool open;
  final VoidCallback onToggle;

  /// What it holds, «Horas extra · Festivo propio · Aviso · Duplicar ·
  /// Borrar», with the values that are set («Aviso: 21:00»).
  final String summary;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final type = context.type;
    final title = l10n.dayDetailMore;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(height: 1, thickness: 1, color: colors.border),
        Semantics(
          container: true,
          button: true,
          expanded: open,
          excludeSemantics: true,
          label: '$title. $summary',
          onTap: onToggle,
          child: InkWell(
            key: const ValueKey('day-more'),
            onTap: onToggle,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: Sp.touch + Sp.s),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Sp.s),
                // The icon and the chevron line up with the title, not with
                // the summary (which is a second line, indented under it).
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          AppIcons.settings,
                          size: IconSize.button,
                          color: colors.textSecondary,
                        ),
                        const SizedBox(width: Sp.m),
                        Expanded(child: Text(title, style: type.bodyStrong)),
                        const SizedBox(width: Sp.s),
                        AnimatedRotation(
                          turns: open ? -0.25 : 0.25,
                          duration: Motion.of(context, Motion.state),
                          curve: Motion.curve,
                          child: Icon(
                            AppIcons.chevronRight,
                            size: IconSize.button,
                            color: colors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Sp.hair),
                    Padding(
                      padding: const EdgeInsets.only(
                        left: IconSize.button + Sp.m,
                      ),
                      child: Text(
                        summary,
                        key: const ValueKey('day-more-summary'),
                        style: type.meta,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (open)
          Column(
            key: const ValueKey('day-more-content'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
      ],
    );
  }
}
