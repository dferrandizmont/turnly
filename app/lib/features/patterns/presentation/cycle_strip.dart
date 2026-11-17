import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/format/app_date_format.dart';
import '../../../core/format/text_measure.dart';
import '../../../core/format/text_wrap.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/theme_context.dart';
import '../../calendar/presentation/shift_format.dart';
import '../../calendar/presentation/shift_badge.dart';
import '../../schedule/domain/schedule_domain.dart';
import 'step_chips.dart';

String patternDuration(BuildContext context, int days) {
  final l10n = context.l10n;
  final label = l10n.patternCycleDays(days);
  return days > 0 && days % 7 == 0
      ? l10n.patternDuration(label, l10n.patternWeeks(days ~/ 7))
      : label;
}

/// Seven cycle days per row, never weekdays. Narrow screens scroll the whole
/// strip horizontally so every target remains at least 48 dp wide.
class CycleStrip extends StatefulWidget {
  const CycleStrip({
    super.key,
    required this.steps,
    required this.shiftOf,
    this.offset,
    this.onOffsetChanged,
    this.keyPrefix = '',
    this.fadeColor,
  });

  final List<List<String>> steps;
  final ShiftType? Function(String) shiftOf;
  final int? offset;
  final ValueChanged<int>? onOffsetChanged;
  final String keyPrefix;

  /// The colour the edge fades go to: that of the surface the strip sits on
  /// (the page background unless told otherwise; a sheet or dialog is
  /// `surface`).
  final Color? fadeColor;

  @override
  State<CycleStrip> createState() => _CycleStripState();
}

class _CycleStripState extends State<CycleStrip> {
  final _scroll = ScrollController();
  bool _expanded = false;
  (int?, double, double)? _lastSelectionLayout;

  void _revealSelection(double cellWidth, double viewportWidth) {
    final layout = (widget.offset, cellWidth, viewportWidth);
    if (_lastSelectionLayout == layout) return;
    _lastSelectionLayout = layout;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients || widget.offset == null) return;
      final left = (widget.offset! % 7) * cellWidth;
      final right = left + cellWidth;
      final current = _scroll.offset;
      final target =
          (left < current
                  ? left
                  : right > current + viewportWidth
                  ? right - viewportWidth
                  : current)
              .clamp(0.0, _scroll.position.maxScrollExtent)
              .toDouble();
      if (target == current) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        _scroll.jumpTo(target);
      } else {
        _scroll.animateTo(target, duration: Motion.state, curve: Motion.curve);
      }
    });
  }

  static const _foldRows = 12;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.steps.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final format = AppDateFormat.of(context);
    final rows = (widget.steps.length / 7).ceil();
    final visibleRows = _expanded
        ? rows
        : math.min(rows, math.max(_foldRows, ((widget.offset ?? 0) ~/ 7) + 1));
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final codes = <String>{for (final day in widget.steps) ...day};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final width = math.max(Sp.touch * scale, constraints.maxWidth / 7);
            _revealSelection(width, constraints.maxWidth);
            final overflows = width * 7 > constraints.maxWidth + 0.5;
            final strip = Scrollbar(
              controller: _scroll,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(bottom: Sp.m),
                child: SizedBox(
                  width: width * 7,
                  child: Column(
                    children: [
                      for (var row = 0; row < visibleRows; row++)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var col = 0; col < 7; col++)
                              SizedBox(
                                width: width,
                                child: row * 7 + col >= widget.steps.length
                                    ? null
                                    : _cell(context, row * 7 + col, format),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            );
            return Semantics(
              label: overflows ? l10n.patternCycleScrollable : null,
              child: overflows
                  ? Stack(
                      children: [
                        strip,
                        _edgeFade(context, atStart: true),
                        _edgeFade(context, atStart: false),
                      ],
                    )
                  : strip,
            );
          },
        ),
        if (rows > _foldRows)
          TextButton(
            key: ValueKey('${widget.keyPrefix}cycle-toggle'),
            onPressed: () => setState(() => _expanded = !_expanded),
            child: Text(
              _expanded
                  ? l10n.patternCollapseCycle
                  : l10n.patternShowWeeks(rows),
            ),
          ),
        for (final id in codes)
          if (widget.shiftOf(id) case final shift?)
            Padding(
              padding: const EdgeInsets.only(top: Sp.xs),
              child: PatternShiftLabel(shift: shift),
            ),
        if (widget.steps.any((day) => day.isEmpty))
          Text(l10n.calendarNoShift, style: context.type.meta),
      ],
    );
  }

  /// A fade over the edge where more days wait: the thin scrollbar was the
  /// only sign that the strip scrolls (1.2.0 QA, iPad F2). It shows at the
  /// start only once the strip has moved, and at the end until it has
  /// reached it.
  Widget _edgeFade(BuildContext context, {required bool atStart}) {
    final background = widget.fadeColor ?? context.colors.background;
    return Positioned.directional(
      textDirection: Directionality.of(context),
      start: atStart ? 0 : null,
      end: atStart ? null : 0,
      top: 0,
      bottom: Sp.m,
      width: Sp.x3,
      child: IgnorePointer(
        child: ListenableBuilder(
          listenable: _scroll,
          builder: (context, _) {
            final position = _scroll.hasClients ? _scroll.position : null;
            final ready = position != null && position.hasContentDimensions;
            final visible = atStart
                ? ready && position.pixels > 1
                : !ready || position.pixels < position.maxScrollExtent - 1;
            return AnimatedOpacity(
              opacity: visible ? 1 : 0,
              duration: Motion.of(context, Motion.state),
              child: DecoratedBox(
                key: ValueKey(
                  '${widget.keyPrefix}cycle-fade-${atStart ? 'start' : 'end'}',
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: atStart
                        ? AlignmentDirectional.centerStart
                        : AlignmentDirectional.centerEnd,
                    end: atStart
                        ? AlignmentDirectional.centerEnd
                        : AlignmentDirectional.centerStart,
                    colors: [background, background.withValues(alpha: 0)],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _cell(BuildContext context, int i, AppDateFormat format) {
    final shifts = [for (final id in widget.steps[i]) ?widget.shiftOf(id)];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Sp.xs),
      child: StepChip(
        key: ValueKey('${widget.keyPrefix}offset-$i'),
        size: Disc.m,
        shifts: shifts,
        caption: '${i + 1}',
        selected: widget.offset == i,
        semanticsLabel: context.l10n.patternCycleDayLabel(
          i + 1,
          widget.steps.length,
          shifts.isEmpty
              ? context.l10n.calendarNoShift
              : shifts
                    .map(
                      (shift) =>
                          [shift.name, ?shift.timeRange(format)].join(', '),
                    )
                    .join('; '),
        ),
        onTap: widget.onOffsetChanged == null
            ? null
            : () => widget.onOffsetChanged!(i),
      ),
    );
  }
}

/// Code and hours accompany the colour, including in the strip's legend.
class PatternShiftLabel extends StatelessWidget {
  const PatternShiftLabel({super.key, required this.shift});
  final ShiftType shift;

  @override
  Widget build(BuildContext context) {
    final times =
        shift.timeRange(AppDateFormat.of(context)) ??
        context.l10n.summaryNoTimes;
    final badge = ShiftBadge(shift: shift, size: Disc.s);
    return LayoutBuilder(
      builder: (context, constraints) {
        const badgeWidth = Disc.s;
        final fits =
            textWidth(context, times, context.type.meta) <=
            constraints.maxWidth - badgeWidth - Sp.s;
        final name = Text(shift.name, style: context.type.body);
        final time = Text(
          keepTimeRangesTogether(times),
          style: context.type.meta,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                badge,
                const SizedBox(width: Sp.s),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [name, if (fits) time],
                  ),
                ),
              ],
            ),
            if (!fits)
              Padding(
                padding: const EdgeInsets.only(top: Sp.xs),
                child: time,
              ),
          ],
        );
      },
    );
  }
}
