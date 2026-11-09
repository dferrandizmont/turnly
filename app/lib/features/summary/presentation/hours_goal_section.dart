import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/choice_grid.dart';
import '../../../core/widgets/choice_pill.dart';
import '../../../core/widgets/labeled_field.dart';
import '../application/summary_providers.dart';
import '../domain/hours_goal.dart';
import '../domain/summary_range.dart';
import 'summary_format.dart';

/// Which kind of period the summary shows, for the goal's share of it.
enum GoalSpan { month, year, range }

/// The goal of [span] for the days of [range], in minutes.
int goalMinutesFor(GoalSpan span, HoursGoal goal, SummaryRange range) =>
    switch (span) {
      GoalSpan.month => goalMinutesForMonth(goal),
      GoalSpan.year => goalMinutesForYear(goal),
      GoalSpan.range => goalMinutesForRange(goal, range.from, range.to),
    };

/// How the goal of the period comes out of the user's goal: «Objetivo
/// mensual», «1642 h al año, entre 12», «1642 h al año, la parte de 31
/// días».
String goalExplanation(
  AppLocalizations l10n,
  GoalSpan span,
  HoursGoal goal,
  int days,
) {
  final goalHours = formatHours(l10n, goal.hours * 60);
  final yearly = goal.period == HoursGoalPeriod.year;
  return switch (span) {
    GoalSpan.month =>
      yearly ? l10n.summaryGoalFromYear(goalHours) : l10n.summaryGoalPerMonth,
    GoalSpan.year =>
      yearly ? l10n.summaryGoalPerYear : l10n.summaryGoalFromMonth(goalHours),
    GoalSpan.range =>
      yearly
          ? l10n.summaryGoalRangeFromYear(goalHours, days)
          : l10n.summaryGoalRangeFromMonth(goalHours, days),
  };
}

/// «Te faltan 24 h», «Con lo previsto, 10 h de más»…: the goal against the
/// worked and the planned hours of the period.
String goalVerdict(AppLocalizations l10n, GoalProgress progress) {
  final difference = progress.differenceMinutes;
  final amount = formatHours(l10n, difference.abs());
  final planned = progress.includesPlanned;
  if (difference < 0) {
    return planned
        ? l10n.summaryGoalShortPlanned(amount)
        : l10n.summaryGoalShort(amount);
  }
  if (difference > 0) {
    return planned
        ? l10n.summaryGoalOverPlanned(amount)
        : l10n.summaryGoalOver(amount);
  }
  return planned ? l10n.summaryGoalMetPlanned : l10n.summaryGoalMet;
}

/// What the goal sheet returns: a goal to save, or `null` to remove it.
class _GoalChoice {
  const _GoalChoice(this.goal);

  final HoursGoal? goal;
}

/// Opens the sheet to set, change or remove the hours goal and stores what
/// the user chose. A failed write says so and keeps the previous goal.
Future<void> editHoursGoal(
  BuildContext context,
  WidgetRef ref,
  HoursGoal? current,
) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final controller = ref.read(hoursGoalProvider.notifier);
  final choice = await showAppSheet<_GoalChoice>(
    context: context,
    padded: true,
    builder: (_) => _GoalSheet(initial: current),
  );
  if (choice == null) return;
  try {
    final goal = choice.goal;
    if (goal == null) {
      await controller.clear();
    } else {
      await controller.set(goal);
    }
  } catch (_) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(appSnackBar(content: Text(l10n.summaryGoalSaveFailed)));
  }
}

class _GoalSheet extends StatefulWidget {
  const _GoalSheet({required this.initial});

  final HoursGoal? initial;

  @override
  State<_GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends State<_GoalSheet> {
  late HoursGoalPeriod _period = widget.initial?.period ?? HoursGoalPeriod.year;
  late final TextEditingController _hours = TextEditingController(
    text: widget.initial == null ? '' : '${widget.initial!.hours}',
  );

  /// The last "Guardar" found the number out of range.
  bool _invalid = false;

  @override
  void dispose() {
    _hours.dispose();
    super.dispose();
  }

  void _save() {
    final goal = HoursGoal(_period, int.tryParse(_hours.text.trim()) ?? 0);
    if (!goal.isValid) {
      setState(() => _invalid = true);
      return;
    }
    Navigator.pop(context, _GoalChoice(goal));
  }

  void _choose(HoursGoalPeriod period) => setState(() {
    _period = period;
    _invalid = false;
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final type = context.type;
    final yearly = _period == HoursGoalPeriod.year;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(l10n.summaryGoalTitle, style: type.headline),
        ),
        const SizedBox(height: Sp.m),
        ChoiceGrid.pills(
          sizing: ChoiceGridSizing.wholeLabel,
          maxColumns: 2,
          pills: [
            ChoicePill(
              expand: true,
              reserveIcon: true,
              key: const ValueKey('summary-goal-year'),
              label: l10n.summaryGoalChoiceYear,
              selected: yearly,
              onTap: () => _choose(HoursGoalPeriod.year),
            ),
            ChoicePill(
              expand: true,
              reserveIcon: true,
              key: const ValueKey('summary-goal-month'),
              label: l10n.summaryGoalChoiceMonth,
              selected: !yearly,
              onTap: () => _choose(HoursGoalPeriod.month),
            ),
          ],
        ),
        const SizedBox(height: Sp.l),
        LabeledField(
          label: yearly
              ? l10n.summaryGoalHoursYear
              : l10n.summaryGoalHoursMonth,
          helper: yearly ? l10n.summaryGoalHelpYear : l10n.summaryGoalHelpMonth,
          child: TextField(
            key: const ValueKey('summary-goal-field'),
            controller: _hours,
            autofocus: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            decoration: InputDecoration(
              // The unit shows before anything is typed, like the other
              // number fields.
              hintText: l10n.summaryGoalUnit,
              suffixText: l10n.summaryGoalUnit,
              errorText: _invalid
                  ? l10n.summaryGoalInvalid(_period.maxHours)
                  : null,
            ),
            onChanged: (_) {
              if (_invalid) setState(() => _invalid = false);
            },
            onSubmitted: (_) => _save(),
          ),
        ),
        const SizedBox(height: Sp.l),
        PrimaryButton(
          key: const ValueKey('summary-goal-save'),
          label: l10n.save,
          onPressed: _save,
        ),
        if (widget.initial != null) ...[
          const SizedBox(height: Sp.s),
          SecondaryButton(
            key: const ValueKey('summary-goal-remove'),
            label: l10n.summaryGoalRemove,
            onPressed: () => Navigator.pop(context, const _GoalChoice(null)),
          ),
        ],
      ],
    );
  }
}
