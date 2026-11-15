import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/app_date_format.dart';
import '../../../core/format/text_measure.dart';
import '../../../core/icons/app_icons.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/app_card.dart';
import '../../schedule/domain/schedule_domain.dart';
import '../../summary/presentation/summary_format.dart';
import '../application/month_strip.dart';
import '../application/visible_month.dart';
import 'month_destinations.dart';

/// How [MonthSummaryStrip] is drawn in a given width and room: its lines of
/// text, whether it is a card or a bare line, and the height it takes.
class MonthStripLayout {
  const MonthStripLayout._(
    this._lines, {
    required this.bare,
    required this.height,
  });

  final List<_StripLine> _lines;

  /// One line of text without the card around it: what is left when the
  /// month leaves almost no room under its days.
  final bool bare;

  /// The height of the strip, its gap above included.
  final double height;

  /// Lines of text it takes.
  int get textLines => _lines.fold(0, (sum, line) => sum + line.lines);
}

/// The strip under the month (`docs/diseno.md`, «Tira del mes»): three facts
/// of the month on screen, in one compact card that opens its summary.
///
/// - **shifts** worked («18 turnos»);
/// - **hours**: «128 h» or, with an hours goal, «128 / 160 h» and what is
///   missing or left over («Por completar: 32 h»), the numbers of the summary;
/// - **next day off**: «Próximo libre: sáb 14, en 2 días» in the current
///   month, «Primer libre: sáb 3» in a month to come, nothing in one gone by.
///
/// It never takes more than two lines of text: when the facts do not fit in
/// them (a narrow phone, large text) it drops what is missing of the goal,
/// or else the day off (the card of today says it too), or both, and in the
/// end the shifts. Text only wraps between facts, or between words when one
/// fact is wider than the strip.
///
/// **It never pushes the days of the month away** (decision 28: the grid
/// rules). The month screen says how much room the grid has to spare
/// ([layoutFor]) and the strip takes the tallest form that fits in it: the
/// card with two lines, the card with one, or one bare line of text. With no
/// room for a full [Sp.touch] target plus its gap, it is not shown.
/// Where the month already scrolls (or
/// in the list) there is no limit and it is the card.
class MonthSummaryStrip extends ConsumerWidget {
  const MonthSummaryStrip({super.key, this.layout});

  /// What [layoutFor] gave for the room the month has; without it the strip
  /// lays itself out as the card, in the width it gets.
  final MonthStripLayout? layout;

  /// The most lines of text the strip takes.
  static const int maxLines = 2;

  static const double _gapAbove = Sp.s;
  static const double _bareGapAbove = Sp.xs;
  static const EdgeInsets _margin = EdgeInsets.symmetric(horizontal: Sp.l);
  static const EdgeInsets _padding = EdgeInsets.symmetric(
    horizontal: Sp.m,
    vertical: Sp.s,
  );
  static const double _iconGap = Sp.s;

  static TextStyle _style(BuildContext context) => AppTypography.tabular(
    context.type.meta,
  ).copyWith(color: context.colors.textSecondary, fontWeight: FontWeight.w600);

  /// The width left for the text in a strip [width] wide (the same in the
  /// card and in the bare line, so the text starts at the same place).
  static double _textWidth(double width) =>
      width -
      _margin.horizontal -
      _padding.horizontal -
      2 * (IconSize.inline + _iconGap);

  /// The height of one line of [style] at the user's text size.
  static double _lineHeight(BuildContext context, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: '0', style: effectiveTextStyle(context, style)),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final height = painter.height;
    painter.dispose();
    return height;
  }

  /// How the strip of [data] (the facts of [month]) is drawn in a month
  /// [width] wide that has [room] to spare under its days (no limit by
  /// default), or `null` when there is nothing to show or no room for it.
  static MonthStripLayout? layoutFor(
    BuildContext context,
    CivilDate month,
    MonthStripData data,
    double width, {
    double room = double.infinity,
  }) {
    if (data.shifts == 0 &&
        data.workedMinutes == 0 &&
        data.goal == null &&
        data.off == null) {
      return null;
    }
    final line = _lineHeight(context, _style(context));
    // The row is never shorter than its icons.
    double text(int lines) =>
        (lines * line).clamp(IconSize.inline, double.infinity);
    double card(_StripPlan plan) =>
        _gapAbove +
        (_padding.vertical + text(plan.textLines)).clamp(
          Sp.touch,
          double.infinity,
        );

    // The card with as many facts as two lines hold.
    final two = _plan(context, month, data, width, maxLines);
    if (card(two) <= room) {
      return MonthStripLayout._(two.lines, bare: false, height: card(two));
    }
    // Less room: the facts that fit in one line, in the card or, when not
    // even that fits, on their own.
    final one = _plan(context, month, data, width, 1);
    if (one.textLines > 1) return null;
    if (card(one) <= room) {
      return MonthStripLayout._(one.lines, bare: false, height: card(one));
    }
    final bare = _bareGapAbove + text(1).clamp(Sp.touch, double.infinity);
    if (bare > room) return null;
    return MonthStripLayout._(one.lines, bare: true, height: bare);
  }

  /// The hours of the month: «128 h», or «128 / 160 h» with an hours goal.
  static String _hours(AppLocalizations l10n, MonthStripData data) {
    final goal = data.goal;
    if (goal == null) return formatHours(l10n, data.workedMinutes);
    final worked = goal.hours.totalMinutes;
    final target = goal.targetMinutes;
    // «128 / 160 h» when both are whole hours; «128 h 30 min / 136 h 50 min»
    // otherwise.
    return l10n.monthStripHoursGoal(
      worked % 60 == 0 && target % 60 == 0
          ? '${worked ~/ 60}'
          : formatHours(l10n, worked),
      formatHours(l10n, target),
    );
  }

  /// What is missing or left over («Por completar: 32 h», «8 h de más»);
  /// `null` without a goal or when it is met exactly.
  static String? _goalDifference(AppLocalizations l10n, MonthStripData data) {
    final difference = data.goal?.differenceMinutes ?? 0;
    if (difference == 0) return null;
    final amount = formatHours(l10n, difference.abs());
    return difference < 0
        ? l10n.monthStripShort(amount)
        : l10n.monthStripOver(amount);
  }

  static String? _off(
    AppLocalizations l10n,
    AppDateFormat format,
    CivilDate month,
    MonthStripOff? off,
  ) {
    if (off == null) return null;
    final date = DateTime(off.date.year, off.date.month, off.date.day);
    // «sáb 14», with the month when it is not the one on screen.
    final day = off.date.firstDayOfMonth == month.firstDayOfMonth
        ? format.weekdayDay(date)
        : format.shortDate(date);
    return switch (off.daysAway) {
      null => l10n.monthStripFirstOff(day),
      0 => l10n.offToday,
      1 => l10n.offTomorrow,
      final days => l10n.monthStripNextOff(day, days),
    };
  }

  /// Every fact in full, for the screen reader.
  static List<String> _facts(
    AppLocalizations l10n,
    AppDateFormat format,
    CivilDate month,
    MonthStripData data,
  ) => [
    l10n.summaryShifts(data.shifts),
    _hours(l10n, data),
    ?_goalDifference(l10n, data),
    ?_off(l10n, format, month, data.off),
  ];

  /// The lines the strip draws in [width] with at most [lines] lines of
  /// text: the most facts that fit in them.
  static _StripPlan _plan(
    BuildContext context,
    CivilDate month,
    MonthStripData data,
    double width,
    int lines,
  ) {
    final l10n = context.l10n;
    final format = AppDateFormat.of(context);
    final style = _style(context);
    final room = _textWidth(width);

    final shifts = l10n.summaryShifts(data.shifts);
    final hours = _hours(l10n, data);
    final difference = _goalDifference(l10n, data);
    final off = _off(l10n, format, month, data.off);
    // From everything to the least: the first that fits in the lines.
    final candidates = <List<String>>[
      [shifts, hours, ?difference, ?off],
      if (difference != null && off != null) [shifts, hours, off],
      if (difference != null && off != null) [shifts, hours, difference],
      if (difference != null || off != null) [shifts, hours],
      [hours],
    ];

    // A dp to spare: a line measured to the last fraction would be cut.
    bool fits(String text) => textWidth(context, text, style) + 1 <= room;

    _StripPlan pack(List<String> facts) {
      final packed = <_StripLine>[];
      var current = '';
      void flush() {
        if (current.isEmpty) return;
        packed.add(_StripLine(current, 1));
        current = '';
      }

      for (final fact in facts) {
        if (!fits(fact)) {
          // Wider than the strip on its own: it wraps between its words.
          flush();
          packed.add(
            _StripLine(fact, textLineCount(context, fact, style, room)),
          );
          continue;
        }
        final joined = current.isEmpty
            ? fact
            : l10n.monthStripFacts(current, fact);
        if (current.isEmpty || fits(joined)) {
          current = joined;
        } else {
          flush();
          current = fact;
        }
      }
      flush();
      return _StripPlan(packed);
    }

    late _StripPlan plan;
    for (final facts in candidates) {
      plan = pack(facts);
      if (plan.textLines <= lines) return plan;
    }
    // Not even one fact fits in the two lines (a tiny window): it is cut
    // there. One line is never forced: the caller does without the strip.
    if (lines < maxLines) return plan;
    return _StripPlan([_StripLine(plan.lines.first.text, lines)]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(visibleMonthProvider);
    final data = ref.watch(monthStripProvider(month));
    final given = layout;
    if (given != null) return _draw(context, ref, month, data, given);
    return LayoutBuilder(
      builder: (context, box) {
        final own = layoutFor(context, month, data, box.maxWidth);
        return own == null
            ? const SizedBox.shrink()
            : _draw(context, ref, month, data, own);
      },
    );
  }

  Widget _draw(
    BuildContext context,
    WidgetRef ref,
    CivilDate month,
    MonthStripData data,
    MonthStripLayout layout,
  ) {
    final l10n = context.l10n;
    final colors = context.colors;
    final style = _style(context);
    final label = l10n.monthStripLabel(
      _facts(l10n, AppDateFormat.of(context), month, data).join(', '),
    );
    void open() => openMonthDestination(context, ref, MonthDestination.summary);
    final content = ExcludeSemantics(
      child: Row(
        children: [
          Icon(
            AppIcons.summary,
            size: IconSize.inline,
            color: colors.textMuted,
          ),
          const SizedBox(width: _iconGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (index, line) in layout._lines.indexed)
                  Text(
                    line.text,
                    key: ValueKey('month-strip-line-$index'),
                    style: style,
                    // The plan already fits; the limit only cuts the last
                    // resort (one fact on a tiny window).
                    maxLines: line.lines,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: _iconGap),
          Icon(
            AppIcons.chevronRight,
            size: IconSize.inline,
            color: colors.textMuted,
          ),
        ],
      ),
    );
    if (layout.bare) {
      // No card: one line under the days, where a card does not fit. The
      // whole line is the button.
      return Padding(
        padding: _margin + const EdgeInsets.only(top: _bareGapAbove),
        child: Semantics(
          container: true,
          button: true,
          label: label,
          child: InkWell(
            key: const ValueKey('month-strip'),
            borderRadius: Rad.chipSmallRadius,
            onTap: open,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: _padding.left),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: Sp.touch),
                child: content,
              ),
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: _margin + const EdgeInsets.only(top: _gapAbove),
      child: AppCard(
        key: const ValueKey('month-strip'),
        padding: _padding,
        semanticLabel: label,
        onTap: open,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: Sp.touch - _padding.vertical),
          child: content,
        ),
      ),
    );
  }
}

class _StripLine {
  const _StripLine(this.text, this.lines);

  final String text;

  /// Lines of text it takes: 1, or more for a fact wider than the strip.
  final int lines;
}

class _StripPlan {
  const _StripPlan(this.lines);

  final List<_StripLine> lines;

  int get textLines => lines.fold(0, (sum, line) => sum + line.lines);
}
