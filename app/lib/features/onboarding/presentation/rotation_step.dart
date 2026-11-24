import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/app_date_format.dart';
import '../../../core/icons/app_icons.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/app_card.dart';
import '../../calendar/application/schedule_controller.dart';
import '../../patterns/domain/pattern_catalog.dart';
import '../../patterns/presentation/cycle_start_picker.dart';
import '../../patterns/presentation/rotation_start_details.dart';
import '../../patterns/presentation/pattern_wizard_screen.dart'
    show PatternCard, PatternDateTile, patternFullDate, pickPatternDate;
import '../../patterns/presentation/step_chips.dart';
import '../../schedule/domain/schedule_domain.dart';
import '../application/onboarding_controller.dart';
import '../domain/profession.dart';
import 'onboarding_widgets.dart';
import 'own_cycle_screen.dart';
import 'profession_step.dart';

/// «¿Cómo es tu rotación?» (second screen of «Usar una rotación», after the place): the job
/// (optional, compact), «Crear mi ciclo» (the pattern builder on «Tu ciclo»,
/// over this screen), the catalogue (the same cards as the pattern wizard)
/// with the patterns of the job first when one is chosen, or «Lo pinto a
/// mano».
class RotationStep extends ConsumerWidget {
  const RotationStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);
    final schedule = ref.watch(
      scheduleControllerProvider.select((s) => s.schedule),
    );

    final typicalIds = state.profession?.presetIds ?? const <String>[];
    final typical = [for (final id in typicalIds) patternPresetById(id)];
    final others = [
      for (final p in patternPresets)
        if (!typicalIds.contains(p.id)) p,
    ];

    Widget card(PatternPreset p) => Padding(
      padding: const EdgeInsets.only(bottom: Sp.card),
      child: PatternCard(
        key: ValueKey('onboarding-pattern-${p.id}'),
        name: p.name,
        description: p.description,
        steps: p.steps,
        schedule: schedule,
        // The factory catalogue talks the app's language from the first
        // frame, not the phone's (the seeded type may be in another one).
        shiftOf: (id) => shiftTypeForFirstUse(schedule, id),
        selected: state.presetId == p.id,
        onTap: () => controller.selectPreset(p.id),
        // «Ajustar»: the same builder as «Crear mi ciclo», with this rotation
        // loaded. The result is always an own cycle; the catalogue one stays.
        onEdit: () => _openOwnCycle(
          context,
          ref,
          // With the work shift the person chose, as the wizard does (not
          // the factory morning of the catalogue).
          steps: presetPattern(
            schedule,
            p,
            workShiftId: workShiftOf(p, state.workShiftId),
          ).steps,
        ),
        editLabel: l10n.onboardingOwnCycleAdjust,
      ),
    );

    // The own cycle built before: its card, chosen or not, and the way to
    // build another one.
    final customSteps = state.customSteps;
    final Widget ownCycle = customSteps == null
        ? OwnCycleEntry(
            key: const ValueKey('onboarding-own-cycle-new'),
            onTap: () => _openOwnCycle(context, ref),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: Sp.card),
                child: PatternCard(
                  key: const ValueKey('onboarding-own-cycle'),
                  name: state.customName,
                  description: null,
                  steps: customSteps,
                  schedule: schedule,
                  shiftOf: (id) => shiftTypeForFirstUse(schedule, id),
                  selected: state.hasOwnCycle,
                  onTap: controller.selectOwnCycle,
                  onEdit: () => _openOwnCycle(
                    context,
                    ref,
                    steps: customSteps,
                    name: state.customName,
                  ),
                  onRemove: controller.removeOwnCycle,
                ),
              ),
              OwnCycleEntry(
                key: const ValueKey('onboarding-own-cycle-another'),
                title: l10n.onboardingOwnCycleAnother,
                onTap: () => _openOwnCycle(context, ref),
              ),
            ],
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StepHeader(
          title: l10n.onboardingRotationTitle,
          titleKey: const ValueKey('onboarding-title'),
          help: l10n.onboardingRotationHelp,
        ),
        // The job first: it orders the list below («Lo habitual en tu
        // trabajo») and sets the hours the rotation is drawn with.
        const ProfessionSection(compact: true),
        // Right under the job and over the lists, so it is on the first
        // screen without scrolling: whoever knows their cycle does not have
        // to find it in the catalogue.
        const SizedBox(height: Sp.m),
        ownCycle,
        if (typical.isNotEmpty) ...[
          GroupLabel(l10n.onboardingRotationTypical),
          for (final p in typical) card(p),
        ],
        const SizedBox(height: Sp.s),
        AppCard(
          key: const ValueKey('onboarding-by-hand'),
          onTap: controller.paintByHand,
          semanticLabel: l10n.onboardingByHand,
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: context.colors.surfaceRaised,
                  borderRadius: Rad.squareRadius(Disc.m),
                ),
                child: SizedBox.square(
                  dimension: Disc.m,
                  child: Icon(
                    AppIcons.paint,
                    color: context.colors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: Sp.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.onboardingByHand, style: context.type.bodyStrong),
                    Text(l10n.onboardingByHandHint, style: context.type.meta),
                  ],
                ),
              ),
            ],
          ),
        ),
        GroupLabel(
          typical.isEmpty
              ? l10n.onboardingRotationAll
              : l10n.onboardingRotationOthers,
        ),
        for (final p in others) card(p),
        // For whoever went through the whole list without finding theirs.
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            key: const ValueKey('onboarding-own-cycle-end'),
            onPressed: () => _openOwnCycle(context, ref),
            child: Text(l10n.onboardingOwnCycleNotHere),
          ),
        ),
      ],
    );
  }

  /// Opens «Tu ciclo» over this screen. With a cycle built it is the rotation
  /// and the flow goes on to «¿Cuándo empiezas?».
  static Future<void> _openOwnCycle(
    BuildContext context,
    WidgetRef ref, {
    List<List<String>>? steps,
    String name = '',
  }) async {
    final controller = ref.read(onboardingControllerProvider.notifier);
    final cycle = await OwnCycleScreen.open(
      context,
      initialSteps: steps,
      initialName: name,
    );
    if (cycle != null) controller.useOwnCycle(cycle.steps, cycle.name);
  }
}

/// The entrance to «Tu ciclo»: a card with a «+», its name and, when it is the
/// first one, a strip of sample days drawn with the real shift chips (so they
/// talk the app's language). With a [title] it is the plain row «Crear otro
/// ciclo»; without, «Crear mi ciclo».
class OwnCycleEntry extends ConsumerWidget {
  const OwnCycleEntry({super.key, this.title, required this.onTap});

  final String? title;
  final VoidCallback onTap;

  /// An example of a cycle: two mornings, two afternoons, two nights, the
  /// saliente and two days off (M M T T N N S L L).
  static const List<List<String>> sample = [
    ['morning'],
    ['morning'],
    ['afternoon'],
    ['afternoon'],
    ['night'],
    ['night'],
    ['postNight'],
    ['rest'],
    ['rest'],
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final schedule = ref.watch(
      scheduleControllerProvider.select((s) => s.schedule),
    );
    final label = title ?? l10n.onboardingOwnCycle;
    return AppCard(
      onTap: onTap,
      semanticLabel: label,
      child: Row(
        crossAxisAlignment: title == null
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: context.colors.surfaceRaised,
              borderRadius: Rad.squareRadius(Disc.m),
            ),
            child: SizedBox.square(
              dimension: Disc.m,
              child: Icon(AppIcons.add, color: context.colors.textPrimary),
            ),
          ),
          const SizedBox(width: Sp.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: context.type.bodyStrong),
                if (title == null) ...[
                  Text(l10n.onboardingOwnCycleHint, style: context.type.meta),
                  const SizedBox(height: Sp.s),
                  ExcludeSemantics(
                    child: SequenceChips(
                      steps: sample,
                      schedule: schedule,
                      shiftOf: (id) => shiftTypeForFirstUse(schedule, id),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// «¿Cuándo empiezas?»: the day the rotation starts and the day of the cycle that is
/// that day (the start step of the pattern wizard).
class StartStep extends ConsumerWidget {
  const StartStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final type = context.type;
    final format = AppDateFormat.of(context);
    final state = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);
    // The shift types as `finish` will leave them for the chosen job, so the
    // hours of "that day" are the ones the calendar will show.
    final schedule = scheduleWithProfession(
      ref.watch(scheduleControllerProvider.select((s) => s.schedule)),
      state.profession,
    );
    final id = state.presetId;
    if (id == null && !state.hasOwnCycle) return const SizedBox.shrink();
    // The own cycle has no catalogue entry: no suggested start day and no
    // work shift to choose.
    final preset = id == null || state.hasOwnCycle
        ? null
        : patternPresetById(id);
    final pattern = controller.request(schedule)!.pattern;
    final start = state.start;

    final suggested = preset?.suggestedStart;
    final weekdays = {
      DateTime.monday: l10n.patternWeekdayMonday,
      DateTime.tuesday: l10n.patternWeekdayTuesday,
      DateTime.wednesday: l10n.patternWeekdayWednesday,
      DateTime.thursday: l10n.patternWeekdayThursday,
      DateTime.friday: l10n.patternWeekdayFriday,
      DateTime.saturday: l10n.patternWeekdaySaturday,
      DateTime.sunday: l10n.patternWeekdaySunday,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StepHeader(
          title: l10n.onboardingStartTitle,
          titleKey: const ValueKey('onboarding-title'),
          help: l10n.onboardingStartHelp,
        ),
        PatternDateTile(
          key: const ValueKey('onboarding-start-date'),
          label: l10n.patternStartLabel,
          value: patternFullDate(format, start),
          onTap: () async {
            final picked = await pickPatternDate(context, start);
            if (picked != null) controller.setStart(picked);
          },
        ),
        RotationStartConfirmation(start: start),
        if (suggested != null && start.weekday != suggested)
          Padding(
            padding: const EdgeInsets.only(top: Sp.s),
            child: Text(
              l10n.patternSuggestedStart(weekdays[suggested]!),
              style: type.meta,
            ),
          ),
        const SizedBox(height: Sp.section),
        if (preset != null && preset.chooseWorkShift)
          RotationWorkShiftPicker(
            shifts: [
              for (final t in shiftTemplates)
                if (t.category == ShiftCategory.work)
                  shiftTypeForFirstUse(schedule, t.key)!,
            ],
            selectedId: workShiftOf(preset, state.workShiftId),
            onChanged: controller.setWorkShift,
          ),
        // The same picker and live preview as the pattern wizard: the factory
        // catalogue talks the app's language from the first frame.
        CycleStartPicker(
          keyPrefix: 'onboarding-',
          steps: pattern.steps,
          shiftOf: (id) => shiftTypeForFirstUse(schedule, id),
          offset: state.stepOffset,
          onOffsetChanged: controller.setStepOffset,
          start: start,
          plan: ref.watch(onboardingPreviewProvider),
        ),
      ],
    );
  }
}
