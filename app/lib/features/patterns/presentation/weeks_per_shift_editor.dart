import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/icons/app_icons.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/choice_pill.dart';
import '../../calendar/application/schedule_controller.dart';
import '../../schedule/domain/schedule_domain.dart';
import '../application/pattern_wizard.dart';
import '../domain/pattern_blocks.dart';
import '../domain/pattern_catalog.dart';
import '../domain/weeks_per_shift.dart';
import 'cycle_strip.dart';

/// Template C: tapping chooses both the work shifts and their order.
class WeeksPerShiftEditor extends ConsumerWidget {
  const WeeksPerShiftEditor({super.key, required this.args});
  final PatternWizardArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final wizard = ref.watch(patternWizardProvider(args));
    final controller = ref.read(patternWizardProvider(args).notifier);
    final calendar = ref.watch(scheduleControllerProvider);
    final schedule = calendar.schedule;
    void check(bool accepted) {
      if (!accepted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(appSnackBar(content: Text(l10n.patternCycleLimit)));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          key: const ValueKey('weeks-back'),
          onPressed: controller.stopBuilding,
          icon: Icon(AppIcons.back, size: IconSize.button),
          label: Text(l10n.patternBuilderBack),
        ),
        Text(l10n.patternWeeksTitle, style: context.type.title),
        const SizedBox(height: Sp.m),
        Text(l10n.patternWeeksOrder, style: context.type.bodyStrong),
        Text(l10n.patternWeeksOrderHelp, style: context.type.meta),
        const SizedBox(height: Sp.s),
        for (final shift in calendar.palette)
          if (shift.category == ShiftCategory.work)
            Padding(
              padding: const EdgeInsets.only(bottom: Sp.s),
              child: AppCard(
                key: ValueKey('weeks-shift-${shift.id}'),
                semanticLabel: shift.name,
                selected: wizard.weekShiftIds.contains(shift.id),
                borderColor: wizard.weekShiftIds.contains(shift.id)
                    ? context.colors.todayRing
                    : null,
                onTap: () => check(controller.toggleWeekShift(shift.id)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // The line is always there, hidden until the shift is
                    // chosen: the card keeps its height, so the list does not
                    // move under the finger that taps it (0.11.0 QA, F12).
                    if (wizard.weekShiftIds.indexOf(shift.id) case final i
                        when i >= 0)
                      Text(
                        l10n.patternWeeksPosition(i + 1),
                        key: ValueKey('weeks-order-${shift.id}'),
                        style: context.type.bodyStrong,
                      )
                    else
                      ExcludeSemantics(
                        child: Visibility(
                          visible: false,
                          maintainSize: true,
                          maintainAnimation: true,
                          maintainState: true,
                          child: Text(
                            l10n.patternWeeksPosition(1),
                            style: context.type.bodyStrong,
                          ),
                        ),
                      ),
                    PatternShiftLabel(shift: shift),
                  ],
                ),
              ),
            ),
        if (wizard.weekShiftIds.isNotEmpty) ...[
          const SizedBox(height: Sp.l),
          Text(l10n.patternWeeksEach, style: context.type.bodyStrong),
          for (final (i, id) in wizard.weekShiftIds.indexed)
            Padding(
              padding: const EdgeInsets.only(top: Sp.m),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shiftTypeForDisplay(schedule, id)?.name ?? id,
                    style: context.type.bodyStrong,
                  ),
                  Wrap(
                    spacing: Sp.s,
                    runSpacing: Sp.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      IconButton(
                        key: ValueKey('weeks-minus-$id'),
                        tooltip: l10n.patternWeekLess,
                        onPressed: wizard.weekCounts[i] <= 1
                            ? null
                            : () => check(
                                controller.setWeekCount(
                                  i,
                                  wizard.weekCounts[i] - 1,
                                ),
                              ),
                        icon: Icon(AppIcons.remove),
                      ),
                      Text(
                        l10n.patternWeeks(wizard.weekCounts[i]),
                        style: context.type.body,
                      ),
                      IconButton(
                        key: ValueKey('weeks-plus-$id'),
                        tooltip: l10n.patternWeekMore,
                        onPressed:
                            wizard.weekCounts[i] >= 8 ||
                                wizard.draft.length + 7 > maxPatternCycleDays
                            ? null
                            : () => check(
                                controller.setWeekCount(
                                  i,
                                  wizard.weekCounts[i] + 1,
                                ),
                              ),
                        icon: Icon(AppIcons.add),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
        const SizedBox(height: Sp.l),
        Text(l10n.patternWeeksDays, style: context.type.bodyStrong),
        const SizedBox(height: Sp.s),
        for (final mode in WeeksPerShiftMode.values)
          Padding(
            padding: const EdgeInsets.only(bottom: Sp.s),
            child: ChoicePill(
              key: ValueKey('weeks-mode-${mode.name}'),
              label: mode == WeeksPerShiftMode.allDays
                  ? l10n.patternWeeksAllDays
                  : l10n.patternWeeksWeekdays,
              selected: wizard.weekMode == mode,
              expand: true,
              onTap: () => check(controller.setWeekMode(mode)),
            ),
          ),
        if (wizard.draft.isNotEmpty) ...[
          const SizedBox(height: Sp.l),
          Text(l10n.patternYourCycle, style: context.type.bodyStrong),
          Text(
            l10n.patternCycleDays(wizard.draft.length),
            style: context.type.meta,
          ),
          CycleStrip(
            steps: wizard.draft,
            shiftOf: (id) => shiftTypeForDisplay(schedule, id),
            keyPrefix: 'weeks-cycle-',
          ),
          TextButton(
            key: const ValueKey('weeks-adjust'),
            onPressed: controller.adjustWeeksByHand,
            child: Text(l10n.patternAdjustByHand),
          ),
        ],
      ],
    );
  }
}
