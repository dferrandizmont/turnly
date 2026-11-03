import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/icons/app_icons.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/router.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/app_card.dart';
import '../../calendar/application/schedule_controller.dart';
import '../application/absence_providers.dart';
import 'absence_format.dart';
import 'absence_icons.dart';

/// «Te quedan 18 días de vacaciones» (P3): a compact card of the summary,
/// one line per balance of [year] of the calendar on screen. It opens the
/// screen of vacation and leave. It shows nothing while the balances load,
/// when they fail to load or when there are none (the screen is reached from
/// Ajustes then).
class AbsenceSummaryCard extends ConsumerWidget {
  const AbsenceSummaryCard({super.key, required this.year});

  /// The year of the period the summary shows.
  final int year;

  /// The most lines the card shows.
  static const int maxLines = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = context.colors;
    final type = context.type;
    final activeId = ref.watch(
      scheduleControllerProvider.select((s) => s.calendarId),
    );
    final statuses = [
      for (final status
          in ref.watch(absenceBalancesProvider(year)).value ?? const [])
        if (status.calendarId == activeId) status,
    ].take(maxLines).toList();
    if (statuses.isEmpty) return const SizedBox.shrink();

    final lines = [
      for (final status in statuses)
        l10n.absenceSummaryLeft(
          absenceSignedLeft(l10n, status.remainingDays),
          status.displayName.toLowerCase(),
        ),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: Sp.card),
      child: AppCard(
        key: const ValueKey('absence-summary'),
        semanticLabel: '${lines.join('. ')}. ${l10n.absenceSummaryOpen}',
        onTap: () => context.push(AppRoutes.settingsAbsences),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Icon(
                AbsenceIcons.vacation,
                size: IconSize.button,
                color: colors.accentText,
              ),
            ),
            const SizedBox(width: Sp.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < lines.length; i++) ...[
                    if (i > 0) const SizedBox(height: Sp.xs),
                    Text(
                      lines[i],
                      key: ValueKey('absence-summary-line-$i'),
                      style: type.bodyStrong,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: Sp.s),
            ExcludeSemantics(
              child: Icon(
                AppIcons.chevronRight,
                size: IconSize.inline,
                color: colors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
