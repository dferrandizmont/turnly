import 'package:flutter/material.dart';

import '../../../core/format/app_date_format.dart';
import '../../../core/format/text_wrap.dart';
import '../../../core/icons/app_icons.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/choice_grid.dart';
import '../../../core/widgets/choice_pill.dart';
import '../../calendar/presentation/shift_badge.dart';
import '../../calendar/presentation/shift_format.dart';
import '../../schedule/domain/schedule_domain.dart';
import '../application/shift_run_options.dart';
import '../domain/pattern_application.dart';
import 'mini_month.dart';
import 'step_chips.dart';

/// The "which day of the cycle" picker, shared by the pattern wizard and the
/// first-use flow. It asks it in the way the person thinks about their
/// rotation:
///
/// 1. Which shift does that day have (Mañana, Tarde, Noche, Libre...), with
///    its colour, code and hours. Choosing one jumps straight to its only day
///    when the shift appears once.
/// 2. Only when that shift appears several times in the cycle, which of its
///    days it is. The options are one per day of the shift, **labelled by its
///    run** so nobody has to count: «2.º de 5 · Mañana» within a run, and
///    «Libre, después de Noche» when the shift has several runs (the run is
///    named by the shift before it; a one-day run needs no ordinal).
///
/// The numbered grid of the whole cycle (the old "day number" question) stays
/// behind «Ver el ciclo completo», and the result is previewed live with the
/// same [PatternMonthPreview] the wizard shows.
///
/// [steps] are the days of the pattern (shift type ids), [shiftOf] resolves a
/// shift id to the type to draw (the first-use flow passes its own so the
/// factory catalogue talks the app's language, see
/// `shiftTypeForFirstUse`), [offset] is the chosen day and [onOffsetChanged]
/// is told about every tap.
class CycleStartPicker extends StatefulWidget {
  const CycleStartPicker({
    super.key,
    required this.steps,
    required this.shiftOf,
    required this.offset,
    required this.onOffsetChanged,
    required this.start,
    required this.plan,
    this.keyPrefix = '',
    this.showPreview = true,
  });

  final List<List<String>> steps;
  final ShiftType? Function(String id) shiftOf;
  final int offset;
  final ValueChanged<int> onOffsetChanged;

  /// The day the rotation starts (for the date in the help line).
  final CivilDate start;

  /// What applying the choice would give, for the live preview; `null` while
  /// there is nothing to show.
  final PatternApplication? plan;

  /// `'onboarding-'` in the first-use flow, `''` in the wizard: keys the
  /// tests use.
  final String keyPrefix;

  /// Whether the live month preview is drawn under the picker. The pattern
  /// wizard already shows it on its last step with the same plan, so it asks
  /// for the picker without the preview to avoid the same two months twice.
  final bool showPreview;

  @override
  State<CycleStartPicker> createState() => _CycleStartPickerState();
}

class _CycleStartPickerState extends State<CycleStartPicker> {
  /// The whole cycle (the numbered grid) is only shown on demand.
  bool _fullCycle = false;

  /// The shift the person tapped, to keep it selected when the chosen day
  /// holds another shift as well (a day can have two). `null`: the first
  /// shift of the day.
  String? _chosenShiftId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final type = context.type;
    final colors = context.colors;
    final format = AppDateFormat.of(context);
    final steps = widget.steps;
    // A pattern with no days has nothing to ask: never divide by zero.
    if (steps.isEmpty) return const SizedBox.shrink();
    final offset = widget.offset % steps.length;
    final date = format.weekdayDayMonth(
      DateTime(widget.start.year, widget.start.month, widget.start.day),
    );

    List<ShiftType> shiftsAt(int i) => [
      for (final id in steps[i]) ?widget.shiftOf(id),
    ];

    // Shifts of the cycle, in the order they first appear.
    final order = <String>[];
    final seen = <String>{};
    for (final step in steps) {
      for (final id in step) {
        if (seen.add(id)) order.add(id);
      }
    }

    final currentIds = steps[offset];
    // A day can hold more than one shift: keep the one the person tapped (it
    // may not be the first of the day), falling back to the first.
    final chosen = _chosenShiftId;
    final currentShiftId = currentIds.isEmpty
        ? null
        : (chosen != null && currentIds.contains(chosen)
              ? chosen
              : currentIds.first);
    final currentShift = currentShiftId == null
        ? null
        : widget.shiftOf(currentShiftId);
    // One option per day of the chosen shift, labelled by its run.
    final runOptions = currentShiftId == null
        ? const <ShiftRunOption>[]
        : shiftRunOptions(steps, currentShiftId);

    /// «Día 2 de 5» inside a run, «Día 1 de 2, después de Libre» or
    /// «Después de Noche» when the shift has several runs. The shift's name is
    /// in the question above, not in every option, and the position is a plain
    /// number: the person names the shifts, so an ordinal could not agree with
    /// them («1.ª tarde», «1.er libre»). With several runs the label is numbered
    /// («Tanda 2 · …»): two runs of the same shift can share the shift before
    /// them (two Mañanas after Libre), and then the run is the only thing
    /// telling them apart.
    String optionLabel(ShiftRunOption option) {
      final name = currentShift?.name ?? currentShiftId ?? '';
      final severalRuns = option.runCount > 1;
      if (!severalRuns && option.count == 1) return name;
      if (!severalRuns) {
        return l10n.patternOccurrenceInRun(option.position, option.count);
      }
      final previous = [
        for (final prevId in option.previousShiftIds)
          widget.shiftOf(prevId)?.name ?? prevId,
      ].join(' + ');
      // A run whose previous day is empty (or only its own shift) keeps the
      // plain label, never a dangling «después de ».
      final String label;
      if (previous.isEmpty) {
        label = option.count == 1
            ? name
            : l10n.patternOccurrenceInRun(option.position, option.count);
      } else {
        label = option.count == 1
            ? l10n.patternOccurrenceAfter(previous)
            : l10n.patternOccurrenceInRunAfter(
                option.position,
                option.count,
                previous,
              );
      }
      return l10n.patternOccurrenceRun(option.runIndex + 1, label);
    }

    Widget dayChip(int i, {required String keyPrefix}) => StepChip(
      key: ValueKey('${widget.keyPrefix}$keyPrefix$i'),
      size: Disc.m,
      shifts: shiftsAt(i),
      selected: i == offset,
      caption: '${i + 1}',
      semanticsLabel: l10n.patternChipDay(
        i + 1,
        shiftsLine(l10n, format, shiftsAt(i)),
      ),
      onTap: () => widget.onOffsetChanged(i),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(l10n.patternStartShiftTitle, style: type.bodyStrong),
        ),
        const SizedBox(height: Sp.xs),
        Text(l10n.patternStartShiftHelp(date), style: type.meta),
        const SizedBox(height: Sp.m),
        // Cells as wide as their longest name or hours at the reader's text
        // size, so a word never breaks inside a cell (QA 0.9.5, F1).
        ChoiceGrid.forLabels(
          sizing: ChoiceGridSizing.wholeLabel,
          compact: true,
          hasLeading: true,
          leadingSize: Disc.s,
          labels: [
            for (final id in order)
              if (widget.shiftOf(id) case final shift?) shift.name,
          ],
          details: [
            for (final id in order)
              if (widget.shiftOf(id) case final shift?)
                ?shift.timeRange(format),
          ],
          children: [
            for (final id in order)
              if (widget.shiftOf(id) case final shift?)
                Builder(
                  builder: (context) {
                    final times = shift.timeRange(format);
                    return ChoicePill(
                      key: ValueKey('${widget.keyPrefix}shift-$id'),
                      label: shift.name,
                      // Not kept together: the cell is sized to fit the hours
                      // on one line, and when even one column is too narrow
                      // (huge text) they wrap at the dash, not inside a time.
                      detail: times,
                      expand: true,
                      compact: true,
                      selected: id == currentShiftId,
                      radius: Rad.inputRadius,
                      leading: ShiftBadge(shift: shift, size: Disc.s),
                      onTap: () {
                        // Tapping the shift already chosen keeps the day that
                        // is chosen: only a different shift moves the offset.
                        if (id == currentShiftId) return;
                        final options = shiftRunOptions(steps, id);
                        if (options.isEmpty) return;
                        // A day can hold two shifts: remember which one was
                        // tapped so its pill stays selected even when the offset
                        // does not move (the tapped shift shares the chosen day
                        // with the one that was selected).
                        setState(() => _chosenShiftId = id);
                        widget.onOffsetChanged(options.first.offset);
                      },
                    );
                  },
                ),
          ],
        ),
        if (runOptions.length > 1) ...[
          const SizedBox(height: Sp.m),
          Semantics(
            header: true,
            child: Text(
              l10n.patternStartOccurrenceTitle(
                currentShift?.name ?? currentShiftId ?? '',
              ),
              style: type.bodyStrong,
            ),
          ),
          const SizedBox(height: Sp.xs),
          Text(l10n.patternStartOccurrenceHelp, style: type.meta),
          const SizedBox(height: Sp.m),
          ChoiceGrid.forLabels(
            sizing: ChoiceGridSizing.wholeLabel,
            labels: [for (final option in runOptions) optionLabel(option)],
            children: [
              for (final option in runOptions)
                ChoicePill(
                  expand: true,
                  reserveIcon: true,
                  key: ValueKey(
                    '${widget.keyPrefix}occurrence-${option.offset}',
                  ),
                  label: optionLabel(option),
                  selected: option.offset == offset,
                  radius: Rad.inputRadius,
                  onTap: () => widget.onOffsetChanged(option.offset),
                ),
            ],
          ),
        ],
        const SizedBox(height: Sp.s),
        AppCard.tinted(
          key: ValueKey('${widget.keyPrefix}cycle-toggle'),
          onTap: () => setState(() => _fullCycle = !_fullCycle),
          semanticLabel: _fullCycle
              ? l10n.patternHideCycle
              : l10n.patternShowCycle,
          child: Row(
            children: [
              Icon(AppIcons.pattern, color: colors.textSecondary),
              const SizedBox(width: Sp.s),
              Expanded(
                child: Text(
                  _fullCycle ? l10n.patternHideCycle : l10n.patternShowCycle,
                  style: type.bodyStrong,
                ),
              ),
              Icon(
                _fullCycle ? AppIcons.arrowUp : AppIcons.arrowDown,
                color: colors.textMuted,
              ),
            ],
          ),
        ),
        if (_fullCycle) ...[
          const SizedBox(height: Sp.m),
          Semantics(
            header: true,
            child: Text(l10n.patternOffsetTitle, style: type.bodyStrong),
          ),
          const SizedBox(height: Sp.xs),
          Text(l10n.patternOffsetHelp(date), style: type.meta),
          const SizedBox(height: Sp.m),
          Wrap(
            // The cells are 48 dp wide to the touch: their own margin is the
            // gap.
            runSpacing: Sp.xs,
            children: [
              for (var i = 0; i < steps.length; i++)
                dayChip(i, keyPrefix: 'offset-'),
            ],
          ),
        ],
        const SizedBox(height: Sp.m),
        Text(
          // «Mañana 06:00–14:00» wrapped between the hours at the dash.
          keepTimeRangesTogether(
            l10n.patternOffsetThatDay(
              shiftsLine(l10n, format, shiftsAt(offset)),
            ),
          ),
          key: ValueKey('${widget.keyPrefix}offset-result'),
          style: type.body.copyWith(color: colors.textSecondary),
        ),
        if (widget.showPreview) ...[
          const SizedBox(height: Sp.section),
          PatternMonthPreview(
            key: ValueKey('${widget.keyPrefix}pattern-preview'),
            start: widget.start,
            plan: widget.plan,
          ),
        ],
      ],
    );
  }
}

/// The result before applying, as a live preview: the start month and the next
/// one with the same month cells as the month screen, plus the note about the
/// automatic saliente. [plan] is what `planPatternApplication` would give
/// (the wizard's `patternPreviewProvider`, or the first-use equivalent);
/// `null` while there is nothing to show.
class PatternMonthPreview extends StatelessWidget {
  const PatternMonthPreview({
    super.key,
    required this.start,
    required this.plan,
  });

  final CivilDate start;
  final PatternApplication? plan;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final type = context.type;
    final colors = context.colors;
    final first = start.firstDayOfMonth;
    final second = first.addDays(first.daysInMonth);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(l10n.patternPreviewTitle, style: type.bodyStrong),
        ),
        const SizedBox(height: Sp.s),
        if (plan == null)
          Text(
            l10n.patternPreviewNone,
            style: type.body.copyWith(color: colors.textMuted),
          )
        else ...[
          if (plan!.postNightDays.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: Sp.s),
              child: Text(
                l10n.patternPreviewPostNight(plan!.postNightDays.length),
                key: const ValueKey('pattern-preview-post-night'),
                style: type.meta,
              ),
            ),
          MiniMonth(month: first, schedule: plan!.schedule),
          const SizedBox(height: Sp.l),
          MiniMonth(month: second, schedule: plan!.schedule),
        ],
      ],
    );
  }
}
