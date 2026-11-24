import 'package:flutter/material.dart';

import '../../../core/format/app_date_format.dart';
import '../../../core/format/money.dart';
import '../../../core/format/text_wrap.dart';
import '../../../core/icons/app_icons.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/app_card.dart';
import '../../calendar/presentation/shift_format.dart';
import '../../schedule/domain/schedule_domain.dart';
import '../domain/month_summary.dart';
import '../domain/period_hours.dart';
import 'summary_format.dart';

/// The year as a list of cards, for large text (see `YearTable`): a tappable
/// card per month with its figures in two short lines, and the total.
///
/// The five columns of the table do not fit a phone from text x1.3, and a
/// table that scrolls sideways hides the euros with no sign that there is
/// more and loses the month column (H-T08-2). Here nothing is hidden, the
/// name of the month is always next to its numbers, and every line wraps
/// between words like any other text.
class YearMonthCards extends StatelessWidget {
  const YearMonthCards({
    super.key,
    required this.totals,
    required this.splits,
    required this.onOpenMonth,
  });

  final YearTotals totals;

  /// The twelve months split at today, in the order of [totals].
  final List<PeriodSplit> splits;
  final ValueChanged<CivilDate> onOpenMonth;

  /// Spaces that must not break a line: «176 h 30 min» stays together.
  static String _together(String text) => text.replaceAll(' ', noBreakSpace);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final format = AppDateFormat.of(context);

    final yearSplit = SplitTotals(splits);

    String hours(int minutes) => _together(formatHours(l10n, minutes));

    /// «22 turnos · 176 h» (worked before today), then «y 2 previstos · 48 h
    /// previstas» when the period still has days from today on, and
    /// «56 h nocturnas · 2.180,00 € estimado».
    List<String> lines({
      required int doneShifts,
      required int plannedShifts,
      required int doneMinutes,
      required int plannedMinutes,
      required int nightMinutes,
      required int? earningsCents,
    }) => [
      '${_together(l10n.summaryShifts(doneShifts))} · ${hours(doneMinutes)}',
      if (plannedShifts > 0 || plannedMinutes > 0)
        [
          if (plannedShifts > 0)
            _together(l10n.summaryShiftsPlannedRest(plannedShifts)),
          if (plannedMinutes > 0)
            '${hours(plannedMinutes)} ${l10n.summaryHowPlanned}',
        ].join(' · '),
      [
        _together(l10n.summaryNightOf(hours(nightMinutes))),
        if (earningsCents != null)
          l10n.summaryYearEstimated(
            _together(formatMoneyCents(context, earningsCents)),
          ),
      ].join(' · '),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < totals.months.length; i++) ...[
          Builder(
            builder: (context) {
              final month = totals.months[i];
              final split = splits[i];
              final name = capitalize(
                format.monthName(DateTime(month.month.year, month.month.month)),
              );
              return _MonthCard(
                key: ValueKey('summary-year-card-${month.month.month}'),
                title: name,
                semantics: l10n.summaryYearMonthSemantics(
                  name,
                  split.shifts.plannedShifts > 0
                      ? '${l10n.summaryShifts(split.shifts.doneShifts)} '
                            '${l10n.summaryShiftsPlannedRest(split.shifts.plannedShifts)}'
                      : l10n.summaryShifts(split.shifts.doneShifts),
                  split.hours.plannedMinutes > 0
                      ? l10n.summaryHowBarLabel(
                          formatHours(l10n, split.hours.doneMinutes),
                          formatHours(l10n, split.hours.plannedMinutes),
                        )
                      : formatHours(l10n, split.hours.doneMinutes),
                ),
                lines: month.isEmpty
                    ? [l10n.summaryYearMonthEmpty]
                    : lines(
                        doneShifts: split.shifts.doneShifts,
                        plannedShifts: split.shifts.plannedShifts,
                        doneMinutes: split.hours.doneMinutes,
                        plannedMinutes: split.hours.plannedMinutes,
                        nightMinutes: month.nightMinutes,
                        earningsCents: month.earningsCents,
                      ),
                muted: month.isEmpty,
                onTap: () => onOpenMonth(month.month),
              );
            },
          ),
          const SizedBox(height: Sp.card),
        ],
        _MonthCard(
          key: const ValueKey('summary-year-total'),
          title: l10n.summaryYearTotal,
          lines: lines(
            doneShifts: yearSplit.doneShifts,
            plannedShifts: yearSplit.plannedShifts,
            doneMinutes: yearSplit.doneMinutes,
            plannedMinutes: yearSplit.plannedMinutes,
            nightMinutes: totals.nightMinutes,
            earningsCents: totals.earningsCents,
          ),
          color: colors.surfaceMuted,
        ),
      ],
    );
  }
}

class _MonthCard extends StatelessWidget {
  const _MonthCard({
    super.key,
    required this.title,
    required this.lines,
    this.semantics,
    this.onTap,
    this.muted = false,
    this.color,
  });

  final String title;
  final List<String> lines;
  final String? semantics;
  final VoidCallback? onTap;
  final bool muted;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final card = AppCard(
      color: color,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: Sp.l, vertical: Sp.m),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: type.bodyStrong.copyWith(
                    color: muted ? colors.textMuted : colors.textPrimary,
                  ),
                ),
                for (final line in lines)
                  Text(
                    line,
                    style: AppTypography.tabular(
                      type.meta.copyWith(
                        color: muted ? colors.textMuted : colors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: Sp.s),
            Icon(
              AppIcons.chevronRight,
              size: IconSize.inline,
              color: colors.textMuted,
            ),
          ],
        ],
      ),
    );
    if (onTap == null) return card;
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: semantics ?? title,
      onTap: onTap,
      child: card,
    );
  }
}
