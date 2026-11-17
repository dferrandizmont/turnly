import 'package:flutter/material.dart';

import '../../../core/format/app_date_format.dart';
import '../../../core/format/text_wrap.dart';
import '../../../core/icons/app_icons.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/theme_context.dart';
import '../../calendar/presentation/shift_format.dart';
import '../../schedule/domain/schedule_domain.dart';
import '../domain/pattern_application.dart';
import 'mini_month.dart';
import 'cycle_strip.dart';

/// Choose the cycle day directly, shared by all three rotation flows.
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
    this.fadeColor,
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

  /// Whether the live month preview is drawn under the picker. The wizard
  /// supplies its own preview with the chosen cycle's length.
  final bool showPreview;

  /// The surface the picker sits on, for the fades of the strip (see
  /// [CycleStrip.fadeColor]); the page background by default.
  final Color? fadeColor;

  @override
  State<CycleStartPicker> createState() => _CycleStartPickerState();
}

class _CycleStartPickerState extends State<CycleStartPicker> {
  @override
  Widget build(BuildContext context) {
    final steps = widget.steps;
    if (steps.isEmpty) return const SizedBox.shrink();
    final offset = widget.offset % steps.length;
    final l10n = context.l10n;
    final format = AppDateFormat.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(l10n.patternOffsetTitle, style: context.type.bodyStrong),
        ),
        const SizedBox(height: Sp.xs),
        Text(l10n.patternCyclePickHelp, style: context.type.meta),
        const SizedBox(height: Sp.m),
        CycleStrip(
          steps: steps,
          shiftOf: widget.shiftOf,
          offset: offset,
          onOffsetChanged: widget.onOffsetChanged,
          keyPrefix: widget.keyPrefix,
          fadeColor: widget.fadeColor,
        ),
        const SizedBox(height: Sp.m),
        Semantics(
          liveRegion: true,
          child: Text(
            keepTimeRangesTogether(
              l10n.patternOffsetThatDay(
                shiftsLine(l10n, format, [
                  for (final id in steps[offset]) ?widget.shiftOf(id),
                ]),
              ),
            ),
            key: ValueKey('${widget.keyPrefix}offset-result'),
            style: context.type.body.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
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

/// The result before applying: whole months through the end of one cycle,
/// with the same month cells as the month screen, plus the note about the
/// automatic saliente. [plan] is what `planPatternApplication` would give
/// (the wizard's `patternPreviewProvider`, or the first-use equivalent);
/// `null` while there is nothing to show.
class PatternMonthPreview extends StatelessWidget {
  const PatternMonthPreview({
    super.key,
    required this.start,
    required this.plan,
    this.cycleDays,
    this.markOverrides = false,
  });

  final CivilDate start;
  final PatternApplication? plan;

  /// Omitted by older callers that preview two months.
  final int? cycleDays;
  final bool markOverrides;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final type = context.type;
    final colors = context.colors;
    final first = start.firstDayOfMonth;
    final last = cycleDays == null
        ? first.addDays(first.daysInMonth)
        : start.addDays(cycleDays! - 1).firstDayOfMonth;
    final months = <CivilDate>[];
    for (
      var month = first;
      !month.isAfter(last);
      month = month.addDays(month.daysInMonth)
    ) {
      months.add(month);
    }
    final hasManualChanges =
        plan?.schedule.entries.values.any(
          (entry) =>
              entry.shiftTypeIds != null &&
              !entry.date.isBefore(first) &&
              !entry.date.isAfter(last.addDays(last.daysInMonth - 1)) &&
              !plan!.postNightDays.contains(entry.date),
        ) ??
        false;
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
          if (markOverrides && hasManualChanges)
            Padding(
              padding: const EdgeInsets.only(bottom: Sp.s),
              child: Row(
                children: [
                  Icon(AppIcons.edit, size: IconSize.inline),
                  const SizedBox(width: Sp.s),
                  Expanded(
                    child: Text(l10n.patternManualChange, style: type.meta),
                  ),
                ],
              ),
            ),
          if (plan!.postNightDays.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: Sp.s),
              child: Text(
                l10n.patternPreviewPostNight(plan!.postNightDays.length),
                key: const ValueKey('pattern-preview-post-night'),
                style: type.meta,
              ),
            ),
          for (final month in months) ...[
            MiniMonth(
              month: month,
              schedule: plan!.schedule,
              markOverrides: markOverrides,
              automaticDays: plan!.postNightDays,
            ),
            if (month != months.last) const SizedBox(height: Sp.l),
          ],
        ],
      ],
    );
  }
}
