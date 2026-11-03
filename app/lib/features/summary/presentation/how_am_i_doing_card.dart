import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/app_date_format.dart';
import '../../../core/icons/app_icons.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/app_card.dart';
import '../application/summary_providers.dart';
import '../domain/hours_goal.dart';
import '../domain/period_hours.dart';
import '../domain/summary_range.dart';
import 'hours_goal_section.dart';
import 'summary_format.dart';
import 'summary_stat_row.dart';

/// «¿Cómo voy?» (design 5A, B5): the first card of the summary. The hours
/// worked in big, the planned ones after them in the same bar (striped), the
/// mark of the goal and, with a goal, a chip with the difference («Te faltan
/// 42 h»). A period that has not started shows its planned hours in big.
/// Without a goal, a quiet button to set one.
///
/// [range] is the period (for a month or a year, all its days); [span] says
/// how the goal is shared out.
class HowAmIDoingCard extends ConsumerWidget {
  const HowAmIDoingCard({super.key, required this.span, required this.range});

  final GoalSpan span;
  final SummaryRange range;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = context.colors;
    final type = context.type;
    final hours = ref.watch(periodHoursProvider(range));
    final goalValue = ref.watch(hoursGoalProvider);
    final goal = goalValue.value;
    final progress = goal == null
        ? null
        : GoalProgress(
            targetMinutes: goalMinutesFor(span, goal, range),
            hours: hours,
          );

    final tense = hours.tense;
    final bigMinutes = tense == PeriodTense.future
        ? hours.plannedMinutes
        : hours.doneMinutes;
    final caption = switch (tense) {
      PeriodTense.past => l10n.summaryHowWorked,
      PeriodTense.current => l10n.summaryHowWorkedToDate,
      PeriodTense.future => l10n.summaryHowPlanned,
    };
    final big = formatHours(l10n, bigMinutes);
    final lastDay = AppDateFormat.of(context)
        .shortDate(DateTime(range.to.year, range.to.month, range.to.day));

    final legend = <_LegendItem>[
      if (tense != PeriodTense.future)
        _LegendItem(
          kind: _Swatch.worked,
          label: l10n.summaryGoalDone,
          value: formatHours(l10n, hours.doneMinutes),
          valueKey: 'summary-legend-done',
        ),
      if (tense != PeriodTense.past)
        _LegendItem(
          kind: _Swatch.planned,
          label: l10n.summaryGoalPlanned,
          value: formatHours(l10n, hours.plannedMinutes),
          valueKey: 'summary-legend-planned',
        ),
      if (progress != null)
        _LegendItem(
          kind: _Swatch.goal,
          label: l10n.summaryGoalTarget,
          value: formatHours(l10n, progress.targetMinutes),
          valueKey: 'summary-goal-target-value',
        ),
    ];
    final showBar = hours.totalMinutes > 0 || progress != null;

    return AppCard(
      key: const ValueKey('summary-how'),
      radius: Rad.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    l10n.summaryHowTitle.toUpperCase(),
                    key: const ValueKey('summary-how-title'),
                    style: type.label.copyWith(color: colors.textMuted),
                  ),
                ),
              ),
              if (goal != null)
                IconButton(
                  key: const ValueKey('summary-goal-edit'),
                  tooltip: l10n.summaryGoalEdit,
                  icon: Icon(AppIcons.edit, size: IconSize.inline),
                  onPressed: () => editHoursGoal(context, ref, goal),
                ),
            ],
          ),
          if (goal == null) const SizedBox(height: Sp.xs),
          Semantics(
            container: true,
            label: '$big $caption',
            excludeSemantics: true,
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: Sp.s,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    big,
                    key: const ValueKey('summary-hours'),
                    style: AppTypography.tabular(type.display),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: Sp.xs),
                  child: Text(
                    caption,
                    key: const ValueKey('summary-hours-title'),
                    style: type.body.copyWith(color: colors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          if (tense == PeriodTense.current) ...[
            const SizedBox(height: Sp.xs),
            Text(
              l10n.summaryHowPlannedRest(
                formatHours(l10n, hours.plannedMinutes),
                lastDay,
              ),
              key: const ValueKey('summary-planned-rest'),
              style: AppTypography.tabular(
                type.body.copyWith(color: colors.textSecondary),
              ),
            ),
          ],
          if (showBar) ...[
            const SizedBox(height: Sp.l),
            Semantics(
              container: true,
              label: [
                l10n.summaryHowBarLabel(
                  formatHours(l10n, hours.doneMinutes),
                  formatHours(l10n, hours.plannedMinutes),
                ),
                if (progress != null)
                  '${l10n.summaryGoalTarget}: '
                      '${formatHours(l10n, progress.targetMinutes)}',
              ].join('. '),
              excludeSemantics: true,
              child: HoursBar(
                doneMinutes: hours.doneMinutes,
                plannedMinutes: hours.plannedMinutes,
                goalMinutes: progress?.targetMinutes,
              ),
            ),
            const SizedBox(height: Sp.s),
            Wrap(
              spacing: Sp.m,
              runSpacing: Sp.xs,
              children: [for (final item in legend) item],
            ),
          ],
          if (goalValue.hasValue) ...[
            const SizedBox(height: Sp.m),
            Divider(height: 1, color: colors.border),
            const SizedBox(height: Sp.m),
            if (progress == null)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  key: const ValueKey('summary-goal-add'),
                  onPressed: () => editHoursGoal(context, ref, null),
                  icon: Icon(AppIcons.add, size: IconSize.button),
                  label: Text(l10n.summaryGoalAdd),
                ),
              )
            else ...[
              _GoalVerdict(
                verdict: goalVerdict(l10n, progress),
                explanation: goalExplanation(l10n, span, goal!, range.days),
              ),
              _HoursBag(range: range),
            ],
          ],
        ],
      ),
    );
  }
}

/// The hours bag (P9): the hours worked minus the goal, added up month by
/// month up to the end of the period (or of this month, while the period is
/// still running), with the balance of December carried over to January.
/// It shows nothing before the period starts.
class _HoursBag extends ConsumerWidget {
  const _HoursBag({required this.range});

  final SummaryRange range;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = context.colors;
    final today = ref.watch(summaryTodayProvider);
    if (range.from.isAfter(today)) return const SizedBox.shrink();
    final end = range.to.isAfter(today) ? today : range.to;
    final month = end.firstDayOfMonth;
    final bag = ref.watch(hoursBalanceProvider(month)).value;
    if (bag == null) return const SizedBox.shrink();

    final minutes = bag.balanceMinutes;
    final value = minutes > 0
        ? l10n.moneyBagFavour(formatHours(l10n, minutes))
        : minutes < 0
        ? l10n.moneyBagOwed(formatHours(l10n, -minutes))
        : l10n.moneyBagEven;
    final monthName = AppDateFormat.of(context)
        .monthYear(DateTime(month.year, month.month));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: Sp.m),
        Divider(height: 1, color: colors.border),
        SummaryStatRow(
          id: 'summary-bag',
          label: l10n.moneyBagTitle,
          value: value,
          detail: l10n.moneyBagNote(monthName),
        ),
      ],
    );
  }
}

/// The chip with the difference and, under it, how the goal of the period
/// comes out of the user's goal.
class _GoalVerdict extends StatelessWidget {
  const _GoalVerdict({required this.verdict, required this.explanation});

  final String verdict;
  final String explanation;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    return Column(
      key: const ValueKey('summary-goal'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.highlight,
            borderRadius: Rad.countdownRadius,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Sp.m,
              vertical: Sp.s,
            ),
            child: Text(
              verdict,
              key: const ValueKey('summary-goal-verdict'),
              style: AppTypography.tabular(
                type.bodyStrong.copyWith(color: colors.onHighlight),
              ),
            ),
          ),
        ),
        const SizedBox(height: Sp.s),
        Text(
          explanation,
          key: const ValueKey('summary-goal-target-detail'),
          style: type.meta.copyWith(color: colors.textSecondary),
        ),
      ],
    );
  }
}

enum _Swatch { worked, planned, goal }

/// One entry of the legend under the bar: its mark, its name and its hours.
class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.kind,
    required this.label,
    required this.value,
    required this.valueKey,
  });

  final _Swatch kind;
  final String label;
  final String value;
  final String valueKey;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final style = type.meta.copyWith(color: colors.textSecondary);
    final mark = switch (kind) {
      _Swatch.worked => _box(colors.accent),
      _Swatch.planned => SizedBox.square(
        dimension: _markSize,
        child: CustomPaint(
          painter: _StripesPainter(colors: colors, radius: Rad.swatch),
        ),
      ),
      _Swatch.goal => Container(
        width: HoursBar.goalMarkWidth,
        height: _markSize + Sp.xs,
        decoration: BoxDecoration(
          color: colors.textPrimary,
          borderRadius: BorderRadius.circular(HoursBar.goalMarkWidth),
        ),
      ),
    };
    // With large text the name and the hours wrap under each other; the
    // mark stays by the first line.
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: Sp.hair),
          child: mark,
        ),
        const SizedBox(width: Sp.xs),
        Flexible(
          child: Wrap(
            spacing: Sp.xs,
            children: [
              Text(label, style: style),
              Text(
                value,
                key: ValueKey(valueKey),
                style: AppTypography.tabular(
                  style.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static const double _markSize = 10;

  static Widget _box(Color color) => Container(
    width: _markSize,
    height: _markSize,
    decoration: BoxDecoration(color: color, borderRadius: Rad.swatchRadius),
  );
}

/// The bar of «¿Cómo voy?»: the worked hours solid, the planned ones after
/// them striped, and the goal as a mark across the bar. The bar measures the
/// larger of the total and the goal, so going over the goal shows the mark
/// inside the bar.
class HoursBar extends StatelessWidget {
  const HoursBar({
    super.key,
    required this.doneMinutes,
    required this.plannedMinutes,
    this.goalMinutes,
  });

  final int doneMinutes;
  final int plannedMinutes;
  final int? goalMinutes;

  /// Height of the track and how far the goal mark sticks out of it.
  static const double trackHeight = 14;
  static const double goalOverhang = 6;
  static const double goalMarkWidth = 3;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      key: const ValueKey('summary-how-bar'),
      height: trackHeight + 2 * goalOverhang,
      width: double.infinity,
      child: CustomPaint(
        painter: _BarPainter(
          done: doneMinutes,
          planned: plannedMinutes,
          goal: goalMinutes,
          colors: colors,
        ),
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter({
    required this.done,
    required this.planned,
    required this.goal,
    required this.colors,
  });

  final int done;
  final int planned;
  final int? goal;
  final AppColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final track = Rect.fromLTWH(
      0,
      HoursBar.goalOverhang,
      size.width,
      HoursBar.trackHeight,
    );
    final rrect = RRect.fromRectAndRadius(
      track,
      const Radius.circular(HoursBar.trackHeight / 2),
    );
    canvas.drawRRect(rrect, Paint()..color = colors.surfaceRaised);
    final scale = math.max(done + planned, goal ?? 0);
    if (scale > 0) {
      final doneWidth = track.width * done / scale;
      final plannedWidth = track.width * planned / scale;
      canvas.save();
      canvas.clipRRect(rrect);
      canvas.drawRect(
        Rect.fromLTWH(track.left, track.top, doneWidth, track.height),
        Paint()..color = colors.accent,
      );
      _StripesPainter.stripes(
        canvas,
        Rect.fromLTWH(
          track.left + doneWidth,
          track.top,
          plannedWidth,
          track.height,
        ),
        colors,
      );
      canvas.restore();
    }
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = colors.border,
    );
    if (goal != null && scale > 0) {
      final x = (track.width * goal! / scale).clamp(
        HoursBar.goalMarkWidth / 2,
        track.width - HoursBar.goalMarkWidth / 2,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x, size.height / 2),
            width: HoursBar.goalMarkWidth,
            height: size.height,
          ),
          const Radius.circular(HoursBar.goalMarkWidth),
        ),
        Paint()..color = colors.textPrimary,
      );
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.done != done ||
      old.planned != planned ||
      old.goal != goal ||
      old.colors != colors;
}

/// The diagonal stripes of the planned hours (the bar and its legend).
class _StripesPainter extends CustomPainter {
  _StripesPainter({required this.colors, this.radius = 0});

  final AppColors colors;
  final double radius;

  /// Share of the accent in the stripes and in the soft fill under them.
  static const double stripeAlpha = 0.6;
  static const double fillAlpha = 0.16;
  static const double stripeWidth = 3;
  static const double stripeStep = 7;

  static void stripes(Canvas canvas, Rect rect, AppColors colors) {
    if (rect.width <= 0) return;
    canvas.save();
    canvas.clipRect(rect);
    canvas.drawRect(
      rect,
      Paint()..color = colors.accent.withValues(alpha: fillAlpha),
    );
    final paint = Paint()
      ..color = colors.accent.withValues(alpha: stripeAlpha)
      ..strokeWidth = stripeWidth;
    for (
      var x = rect.left - rect.height;
      x < rect.right + rect.height;
      x += stripeStep
    ) {
      canvas.drawLine(
        Offset(x, rect.bottom),
        Offset(x + rect.height, rect.top),
        paint,
      );
    }
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    stripes(canvas, rect, colors);
    canvas.restore();
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(0.5), Radius.circular(radius)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = colors.accent,
    );
  }

  @override
  bool shouldRepaint(_StripesPainter old) =>
      old.colors != colors || old.radius != radius;
}
