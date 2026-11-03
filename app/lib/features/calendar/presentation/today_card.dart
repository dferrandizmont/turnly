import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/app_date_format.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/providers.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/motion_size.dart';
import '../../../core/icons/month_icons.dart';
import '../application/month_presentation.dart';
import '../application/off_outlook.dart';
import '../application/schedule_controller.dart';
import '../application/today_status.dart';
import 'day_cell.dart' show textHeight;
import 'off_outlook_text.dart';
import 'shift_format.dart';

/// The card at the top of the month (`docs/diseno.md`, "Tarjeta de hoy"): the
/// shift that matters now, with a badge, a countdown chip that refreshes every
/// minute and the line for tomorrow. Its label says the moment: AHORA (shift
/// in progress), ESTA NOCHE (starts from 20:00), HOY (starts earlier), HOY
/// LIBRE (nothing left today: shows the next shift), HOY TERMINADO (today's
/// shift is over: says which one and shows the next).
///
/// With [collapsible] (the month in one column) a button folds it to one line
/// and unfolds it again; the choice is remembered between openings
/// ([todayCardCollapsedProvider]). Until the person chooses, [foldByDefault]
/// decides: the month screen folds it when the whole month would not fit with
/// the card open (decision 28).
class TodayCard extends ConsumerStatefulWidget {
  const TodayCard({
    super.key,
    this.collapsible = false,
    this.foldByDefault = false,
  });

  /// Shows the fold button and honours the remembered fold.
  final bool collapsible;

  /// Whether the card starts folded while the person has not chosen.
  final bool foldByDefault;

  /// The height of the open card at the user's text size, for deciding
  /// whether the month fits (`month_fit.dart`). It assumes the usual card of a
  /// work day: the moment, the shift, its hours, the countdown and tomorrow's
  /// line (which share two lines on a phone), and the line of the next day
  /// off with the fold button. Kept here, next to the layout it mirrors.
  static double openHeightEstimate(BuildContext context) {
    final type = context.type;
    final scaler = MediaQuery.textScalerOf(context);
    double line(TextStyle style) => textHeight(style, scaler);
    final chip = line(type.body) + 2 * Sp.xs;
    return Sp.xs + // the margin above the card
        (Sp.xl - Sp.hair) + // top padding
        line(type.label) +
        Sp.hair +
        line(type.display) +
        line(type.bodyStrong) +
        Sp.m +
        chip +
        line(type.body) + // tomorrow, on a second line
        Sp.s +
        math.max(Sp.touch, line(type.meta)) + // the next day off + button
        Sp.s +
        Sp.cardBar;
  }

  @override
  ConsumerState<TodayCard> createState() => _TodayCardState();
}

class _TodayCardState extends ConsumerState<TodayCard>
    with WidgetsBindingObserver {
  final _toggleKey = GlobalKey(debugLabel: 'today-card-toggle');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from the background the timer may be late: read the clock again.
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(minuteClockProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final type = context.type;
    final format = AppDateFormat.of(context);
    final schedule = ref.watch(
      scheduleControllerProvider.select((s) => s.schedule),
    );
    final now = ref.watch(minuteClockProvider);
    final status = todayStatus(schedule, now);
    final outlook = ref.watch(offOutlookProvider);
    final offLine = nextOffText(l10n, format, outlook);
    // The weekend and the streak share a second, quieter line.
    final extraLine = [
      freeWeekendText(l10n, format, outlook),
      streakText(l10n, outlook),
    ].nonNulls.join('  ·  ');

    final main = status.main;
    final swatch = main?.swatch(colors.brightness);
    final restSwatch = status.restShift?.swatch(colors.brightness);
    final timed = status.timed;

    final label = switch (status.phase) {
      TodayPhase.now => l10n.todayLabelNow,
      TodayPhase.tonight => l10n.todayLabelTonight,
      TodayPhase.today => l10n.todayLabelToday,
      TodayPhase.free => l10n.todayLabelFree,
      TodayPhase.done => l10n.todayLabelDone,
      TodayPhase.gap => l10n.todayLabelGap,
    }.toUpperCase();
    final labelColor = swatch?.ink ?? colors.textMuted;

    final title = main?.name ?? l10n.todayFreeTitle;

    // Second line: hours, "until" for a shift in progress, when it ended, or
    // the next shift when today is free.
    final String? detail = switch (status.phase) {
      TodayPhase.done => l10n.todayFinishedAt(
        format.time(status.finished!.end),
      ),
      TodayPhase.now => l10n.todayUntil(format.time(timed!.end)),
      TodayPhase.tonight || TodayPhase.today => main?.timeRange(format),
      TodayPhase.gap => l10n.todayBackAt(format.time(timed!.start)),
      TodayPhase.free =>
        timed == null
            ? l10n.todayNoNext
            : l10n.todayNext(
                timed.shift.name,
                format.weekdayShort(timed.start),
                format.time(timed.start),
              ),
    };

    final countdown = status.minutes == null
        ? null
        : switch (status.phase) {
            TodayPhase.now => l10n.todayEndsIn(
              durationText(l10n, status.minutes!),
            ),
            TodayPhase.gap => l10n.todayBackIn(
              durationText(l10n, status.minutes!),
            ),
            _ => l10n.todayStartsIn(durationText(l10n, status.minutes!)),
          };

    // Once today's shift is over, the next one is a line of its own.
    final nextShift = status.phase == TodayPhase.done && status.timed != null
        ? l10n.todayNext(
            status.timed!.shift.name,
            format.weekdayShort(status.timed!.start),
            format.time(status.timed!.start),
          )
        : null;
    final also = status.others.isEmpty
        ? null
        : status.others
              .map((s) => l10n.todayAlso(s.nameWithTimes(l10n, format)))
              .join('  ');

    // With the date, so that "mañana" (the next day) is never read as a shift
    // called Mañana.
    final tomorrowDate = format.weekdayDay(
      DateTime(now.year, now.month, now.day + 1),
    );
    final tomorrowText = status.tomorrow.isEmpty
        ? l10n.calendarHeaderTomorrowNone(tomorrowDate)
        : l10n.calendarHeaderTomorrow(
            tomorrowDate,
            status.tomorrow.map((s) => s.name).join(' + '),
          );

    final badgeSwatch = swatch ?? restSwatch;
    final badgeCode = main?.code ?? status.restShift?.code;
    final barColor = swatch?.bar ?? restSwatch?.bar ?? colors.borderStrong;

    final spoken = [
      label.toLowerCase(),
      title,
      ?detail,
      ?nextShift,
      ?also,
      ?countdown,
      tomorrowText,
      ?offLine,
      ?freeWeekendText(l10n, format, outlook),
      ?streakText(l10n, outlook),
    ].join(', ');

    final collapsed =
        widget.collapsible &&
        (ref.watch(todayCardCollapsedProvider) ?? widget.foldByDefault);
    final badge = badgeSwatch != null && badgeCode != null
        ? _Badge(code: badgeCode, swatch: badgeSwatch, compact: collapsed)
        : null;

    // Folded to one line (B1): the moment, the shift and its hours, the
    // countdown and the next day off. The tomorrow line, the other shifts
    // and the next shift after a finished one wait in the open card.
    final spokenCollapsed = [
      label.toLowerCase(),
      title,
      ?detail,
      ?countdown,
      ?offLine,
      if (extraLine.isNotEmpty) extraLine,
    ].join(', ');

    final Widget content;
    if (collapsed) {
      content = Padding(
        key: const ValueKey('today-card-collapsed'),
        padding: const EdgeInsets.fromLTRB(
          Sp.m,
          Sp.m,
          Sp.xs,
          Sp.m + Sp.cardBar,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (badge != null) ...[
                  ExcludeSemantics(child: badge),
                  const SizedBox(width: Sp.m),
                ],
                Expanded(
                  child: ExcludeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: type.label.copyWith(color: labelColor),
                        ),
                        const SizedBox(height: Sp.hair),
                        Wrap(
                          spacing: Sp.s,
                          runSpacing: Sp.xs,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text.rich(
                              key: const ValueKey('today-card-compact-title'),
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: title,
                                    style: type.bodyStrong.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  if (detail != null)
                                    TextSpan(
                                      text: '  $detail',
                                      style: AppTypography.tabular(
                                        type.body.copyWith(
                                          color: colors.textSecondary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (countdown != null)
                              _CountdownChip(text: countdown),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                _toggle(context, collapsed: true),
              ],
            ),
            if (offLine != null || extraLine.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: Sp.s, right: Sp.m),
                child: ExcludeSemantics(
                  child: Text.rich(
                    key: const ValueKey('today-off-compact'),
                    TextSpan(
                      children: [
                        if (offLine != null)
                          TextSpan(
                            text: offLine,
                            style: type.meta.copyWith(
                              color: colors.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        if (offLine != null && extraLine.isNotEmpty)
                          const TextSpan(text: '  ·  '),
                        if (extraLine.isNotEmpty)
                          TextSpan(
                            text: extraLine,
                            style: AppTypography.tabular(
                              type.meta.copyWith(color: colors.textMuted),
                            ),
                          ),
                      ],
                    ),
                    style: type.meta.copyWith(color: colors.textMuted),
                  ),
                ),
              ),
          ],
        ),
      );
    } else {
      final head = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: type.label.copyWith(color: labelColor)),
                const SizedBox(height: Sp.hair),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: type.display,
                ),
                if (detail != null)
                  Text(
                    detail,
                    style: type.bodyStrong.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                if (nextShift != null)
                  Padding(
                    padding: const EdgeInsets.only(top: Sp.xs),
                    child: Text(
                      nextShift,
                      style: AppTypography.tabular(type.meta),
                    ),
                  ),
                if (also != null)
                  Padding(
                    padding: const EdgeInsets.only(top: Sp.xs),
                    child: Text(also, style: AppTypography.tabular(type.meta)),
                  ),
              ],
            ),
          ),
          if (badge != null) ...[const SizedBox(width: Sp.m), badge],
        ],
      );
      final moments = Wrap(
        spacing: Sp.m,
        runSpacing: Sp.s,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (countdown != null) _CountdownChip(text: countdown),
          Text(
            tomorrowText,
            style: AppTypography.tabular(
              type.body.copyWith(color: colors.textMuted),
            ),
          ),
        ],
      );
      final hasOff = offLine != null || extraLine.isNotEmpty;
      final off = !hasOff
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (offLine != null)
                  Text(
                    offLine,
                    key: const ValueKey('today-off-line'),
                    style: type.meta.copyWith(
                      color: colors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                if (extraLine.isNotEmpty)
                  Text(
                    extraLine,
                    key: const ValueKey('today-off-extra'),
                    style: AppTypography.tabular(
                      type.meta.copyWith(color: colors.textMuted),
                    ),
                  ),
              ],
            );
      // The fold button closes the last line of the card: the one of the
      // next day off when there is one (as in the canvas), otherwise the
      // countdown and tomorrow.
      Widget withToggle(Widget line) => Row(
        children: [
          Expanded(child: ExcludeSemantics(child: line)),
          _toggle(context, collapsed: false),
        ],
      );
      content = Padding(
        key: const ValueKey('today-card-open'),
        padding: EdgeInsets.fromLTRB(
          Sp.xl - Sp.hair,
          Sp.xl - Sp.hair,
          widget.collapsible ? Sp.xs : Sp.xl - Sp.hair,
          (widget.collapsible ? Sp.s : Sp.l) + Sp.cardBar,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              // Keeps the badge where it was: the fold button on the lower
              // line takes the trailing padding.
              padding: EdgeInsets.only(
                right: widget.collapsible ? Sp.xl - Sp.hair - Sp.xs : 0,
              ),
              child: ExcludeSemantics(child: head),
            ),
            const SizedBox(height: Sp.m),
            if (!widget.collapsible) ...[
              moments,
              if (off != null) ...[const SizedBox(height: Sp.s), off],
            ] else if (off == null)
              withToggle(moments)
            else ...[
              Padding(
                padding: const EdgeInsets.only(right: Sp.xl - Sp.hair - Sp.xs),
                child: ExcludeSemantics(child: moments),
              ),
              const SizedBox(height: Sp.s),
              withToggle(off),
            ],
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.l, Sp.xs, Sp.l, 0),
      child: Semantics(
        container: true,
        label: collapsed ? spokenCollapsed : spoken,
        // Only the fold button is a node of its own inside the card.
        excludeSemantics: !widget.collapsible,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: Rad.cardRadius,
            border: Border.all(color: colors.border),
          ),
          child: ClipRRect(
            borderRadius: Rad.cardRadius,
            child: Stack(
              children: [
                MotionSize(child: content),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: Sp.cardBar,
                  child: ColoredBox(color: barColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Folds or unfolds the card. The same element in both layouts (a global
  /// key), so the keyboard focus and the screen reader stay on it.
  Widget _toggle(BuildContext context, {required bool collapsed}) {
    final l10n = context.l10n;
    return MergeSemantics(
      key: _toggleKey,
      child: Semantics(
        expanded: !collapsed,
        child: IconButton(
          key: const ValueKey('today-card-toggle'),
          tooltip: collapsed ? l10n.todayCardExpand : l10n.todayCardCollapse,
          icon: Icon(
            collapsed ? MonthIcons.expand : MonthIcons.collapse,
            color: context.colors.textMuted,
          ),
          onPressed: () =>
              ref.read(todayCardCollapsedProvider.notifier).set(!collapsed),
        ),
      ),
    );
  }
}

/// The 56 dp badge with the shift code: `disc` background, `ink` code.
class _Badge extends StatelessWidget {
  const _Badge({
    required this.code,
    required this.swatch,
    this.compact = false,
  });

  final String code;
  final ShiftSwatch swatch;

  /// The 44 dp badge of the folded card.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: swatch.disc,
        borderRadius: compact ? Rad.inputRadius : Rad.badgeRadius,
      ),
      child: SizedBox.square(
        dimension: compact ? Disc.l : Disc.badge,
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.all(Sp.xs),
              child: Text(
                code,
                maxLines: 1,
                style: (compact ? context.type.title : context.type.headline)
                    .copyWith(color: swatch.ink),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Empieza en 3 h 40 min" on `highlight`.
class _CountdownChip extends StatelessWidget {
  const _CountdownChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.highlight,
        borderRadius: Rad.countdownRadius,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Sp.m, vertical: Sp.xs),
        child: Text(
          text,
          style: AppTypography.tabular(
            context.type.body.copyWith(
              color: colors.onHighlight,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
