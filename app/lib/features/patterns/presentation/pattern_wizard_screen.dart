import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/app_date_format.dart';
import '../../../core/format/text_measure.dart';
import '../../../core/icons/app_icons.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/button_row.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/content_app_bar.dart';
import '../../../core/widgets/date_sheet.dart';
import '../../../core/widgets/page_body.dart';
import '../../../core/widgets/value_row.dart';
import '../../../core/widgets/whole_word_text.dart';
import '../../calendar/application/schedule_controller.dart';
import '../../calendar/application/visible_month.dart';
import '../../calendar/presentation/shift_format.dart';
import '../../review/application/review_providers.dart';
import '../../schedule/domain/schedule_domain.dart';
import '../application/pattern_wizard.dart';
import '../domain/pattern_catalog.dart';
import 'cycle_start_picker.dart';
import 'rotation_start_details.dart';
import 'pattern_builder.dart';
import 'step_chips.dart';
import 'weeks_per_shift_editor.dart';
import '../../../core/widgets/app_snack_bar.dart';

/// "Asistente de patrón" (turnos-spec.md section 4, screen 3): 1) choose a
/// preset or build your own, 2) start day and the day of the cycle you are
/// on, 3) the end and what to do with the days changed by hand. The result
/// is previewed live (whole months covering the cycle) and
/// applied as ONE undoable step.
class PatternWizardScreen extends ConsumerStatefulWidget {
  const PatternWizardScreen({super.key, this.start, this.shiftId});

  /// Day to start on (the one tapped after a long press on a puck).
  final CivilDate? start;

  /// Shift of the puck that was long-pressed: its typical patterns go first.
  final String? shiftId;

  @override
  ConsumerState<PatternWizardScreen> createState() =>
      _PatternWizardScreenState();
}

class _PatternWizardScreenState extends ConsumerState<PatternWizardScreen> {
  PatternWizardArgs get _args => PatternWizardArgs(start: widget.start, shiftId: widget.shiftId);
  bool _confirming = false;
  // Where the list of patterns was when a sub-form opened over it.
  double _listOffset = 0;
  Timer? _tapTimer;
  Completer<void>? _tapsSettled;

  void _restartTapTimer() {
    if (_tapsSettled == null) return;
    _tapTimer?.cancel();
    _tapTimer = Timer(kDoubleTapTimeout, () => _tapsSettled?.complete());
  }

  /// «Semanas por turno» opens over the list with its own scroll position: at
  /// its top, and the list gets its place back when you return (0.11.0 QA,
  /// F12: the sub-form opened scrolled to the bottom).
  void _weeksTemplateChanged(bool opened) {
    // The route's own scroll controller (status-bar tap, Page Down), not
    // one of ours: the steps keep using it.
    final scroll = PrimaryScrollController.maybeOf(context);
    if (scroll == null || scroll.positions.length != 1) return;
    if (opened) _listOffset = scroll.offset;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || scroll.positions.length != 1) return;
      final target = opened
          ? 0.0
          : _listOffset.clamp(0.0, scroll.position.maxScrollExtent);
      scroll.jumpTo(target);
    });
  }

  @override
  void dispose() {
    _tapTimer?.cancel();
    if (_tapsSettled?.isCompleted == false) _tapsSettled!.complete();
    super.dispose();
  }

  Future<void> _leave() async {
    final controller = ref.read(patternWizardProvider(_args).notifier);
    if (_confirming || ref.read(patternWizardProvider(_args)).applying) return;
    _confirming = true;
    final discard = await confirmDiscardSequence(context, controller);
    if (mounted && discard) Navigator.pop(context);
    _confirming = false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = patternWizardProvider(_args);
    ref.listen(provider.select((s) => s.weeksTemplate), (before, after) {
      if (before != null && before != after) _weeksTemplateChanged(after);
    });
    final wizard = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final last = wizard.step == WizardStep.end;
    final savingCopy =
        wizard.step == WizardStep.choose &&
        wizard.building &&
        wizard.editingCopy;
    final nextLabel = savingCopy
        ? l10n.patternSaveAsNew
        : last
        ? l10n.patternApply
        : l10n.patternNext;
    final actionIcons =
        ActionIconTheme.of(context) ?? const ActionIconThemeData();

    return PopScope(
      canPop: !wizard.applying && !controller.hasDraftChanges,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && ModalRoute.of(context)?.isCurrent == true) _leave();
      },
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => _restartTapTimer(),
        child: AbsorbPointer(
          absorbing: wizard.applying,
          child: Scaffold(
            appBar: ContentAppBar.adaptive(
              context,
              title: Text(l10n.patternTitle),
              titleIdentifier: 'rotation-screen',
              backButton: TooltipTheme(
                data: TooltipTheme.of(context)
                    .copyWith(excludeFromSemantics: true),
                child: ActionIconTheme(
                  data: actionIcons.copyWith(
                    backButtonIconBuilder: (context) => Semantics(
                      label: l10n.back,
                      child:
                          actionIcons.backButtonIconBuilder?.call(context) ??
                          Icon(AppIcons.back),
                    ),
                  ),
                  child: const BackButton(),
                ),
              ),
            ),
            body: PageBody(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final building =
                      wizard.step == WizardStep.choose && wizard.building;
                  // Pinned only while it leaves most of the height to the
                  // step: on a short screen (a phone on its side, large
                  // text) it joins the page and scrolls away with it, as the
                  // builder's already does (0.11.0 QA, F6/F7).
                  final pinned =
                      !building &&
                      constraints.maxHeight >=
                          _stepIndicatorHeight(
                                context,
                                wizard.step,
                                constraints.maxWidth,
                              ) *
                              _pinnedIndicatorShare;
                  final indicator = _StepIndicator(step: wizard.step);
                  return Column(
                    children: [
                      // Same slot either way, so the scroll position survives
                      // a turn of the phone.
                      pinned ? indicator : const SizedBox.shrink(),
                      Expanded(
                        child: building
                            ? PatternBuilderViewport(
                                args: _args,
                                header: indicator,
                              )
                            : SingleChildScrollView(
                                key: ValueKey(
                                  'pattern-step-${wizard.step.name}',
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    pinned
                                        ? const SizedBox.shrink()
                                        : indicator,
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        Sp.page,
                                        Sp.s,
                                        Sp.page,
                                        Sp.section,
                                      ),
                                      child: switch (wizard.step) {
                                        WizardStep.choose => _ChooseStep(
                                          args: _args,
                                        ),
                                        WizardStep.start => _StartStep(
                                          args: _args,
                                        ),
                                        WizardStep.end => _EndStep(args: _args),
                                      },
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
            bottomNavigationBar: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PageBody(
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Sp.page,
                        Sp.s,
                        Sp.page,
                        Sp.m,
                      ),
                      // «Atrás» next to «Siguiente», or one under the other when
                      // the words do not fit side by side («Atr / ás» at x2.0 on
                      // 320 dp, H-T06-3); then the main action is on top.
                      child: AdaptiveButtonRow(
                        gap: Sp.m,
                        primaryFirstWhenStacked: true,
                        items: [
                          if (wizard.step != WizardStep.choose)
                            ButtonRowItem(
                              label: l10n.patternBack,
                              child: SecondaryButton(
                                key: const ValueKey('pattern-back'),
                                label: l10n.patternBack,
                                onPressed: wizard.applying
                                    ? null
                                    : controller.back,
                              ),
                            ),
                          ButtonRowItem(
                            flex: 2,
                            label: nextLabel,
                            child: PrimaryButton(
                              key: ValueKey(
                                last ? 'pattern-apply' : 'pattern-next',
                              ),
                              label: nextLabel,
                              loading: wizard.applying,
                              onPressed: wizard.applying || !wizard.hasChoice
                                  ? null
                                  : savingCopy
                                  ? () async {
                                      final saved = await controller.saveCopy(
                                        fallbackName:
                                            l10n.patternBuilderDefaultName,
                                        copyName: l10n.patternCopyName,
                                      );
                                      if (!saved && context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                              appSnackBar(
                                                content: Text(l10n.saveFailed),
                                              ),
                                            );
                                      }
                                    }
                                  : last
                                  ? _apply
                                  : controller.next,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _apply() async {
    if (ref.read(patternWizardProvider(_args)).applying) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final provider = patternWizardProvider(_args);
    final day = ref.read(provider).start;
    final schedule = ref.read(scheduleControllerProvider.notifier);
    final month = ref.read(visibleMonthProvider.notifier);
    final review = ref.read(reviewServiceProvider);
    final step = await ref
        .read(provider.notifier)
        .apply(fallbackName: l10n.patternBuilderDefaultName);
    if (!context.mounted) return;
    if (step == null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(appSnackBar(content: Text(l10n.patternApplyFailed)));
      return;
    }
    // Keep consuming the whole burst on this route. Showing Undo immediately
    // would let the remaining taps land on the next screen at the same place.
    _tapsSettled = Completer<void>();
    _restartTapTimer();
    await _tapsSettled!.future;
    _tapsSettled = null;
    if (!mounted) return;
    month.goTo(day);
    router.pop();
    // A rotation applied from the wizard (never the first-use flow, which has
    // its own step) is a success moment for the store review.
    unawaited(review.maybeAskAfterSuccess());
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        appSnackBar(
          context: context,
          content: Text(l10n.patternApplied),
          action: SnackBarAction(
            label: l10n.undo,
            // Only while the pattern is still the latest thing done.
            onPressed: () => schedule.undoIfLast(step),
          ),
        ),
      );
  }
}

/// The indicator stays pinned while the page is at least this many times
/// taller than it; below that it scrolls with the step.
const double _pinnedIndicatorShare = 4;

/// Height of [_StepIndicator] at the reader's text size, to decide whether it
/// stays pinned.
double _stepIndicatorHeight(
  BuildContext context,
  WizardStep step,
  double width,
) {
  final l10n = context.l10n;
  final type = context.type;
  double heightOf(String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: effectiveTextStyle(context, style)),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: math.max(0, width - Sp.page * 2));
    final height = painter.height;
    painter.dispose();
    return height;
  }

  final title = switch (step) {
    WizardStep.choose => l10n.patternStepChoose,
    WizardStep.start => l10n.patternStepStart,
    WizardStep.end => l10n.patternStepEnd,
  };
  return Sp.s * 2 +
      Sp.xs +
      Sp.s +
      heightOf(
        l10n.patternStepOf(step.index + 1, WizardStep.values.length),
        type.label,
      ) +
      heightOf(title, type.headline);
}

/// "Paso 2 de 3" with three segments.
class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.step});

  final WizardStep step;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final title = switch (step) {
      WizardStep.choose => l10n.patternStepChoose,
      WizardStep.start => l10n.patternStepStart,
      WizardStep.end => l10n.patternStepEnd,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.page, Sp.s, Sp.page, Sp.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (final s in WizardStep.values) ...[
                Expanded(
                  child: SizedBox(
                    height: Sp.xs,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: s.index <= step.index
                            ? colors.accent
                            : colors.border,
                        borderRadius: Rad.pill,
                      ),
                    ),
                  ),
                ),
                if (s != WizardStep.values.last) const SizedBox(width: Sp.xs),
              ],
            ],
          ),
          const SizedBox(height: Sp.s),
          Semantics(
            header: true,
            child: Text(
              l10n.patternStepOf(step.index + 1, WizardStep.values.length),
              style: context.type.label.copyWith(color: colors.textMuted),
            ),
          ),
          WholeWordText(
            title,
            key: const ValueKey('pattern-step-title'),
            style: context.type.headline,
          ),
        ],
      ),
    );
  }
}

// ---- step 1 -----------------------------------------------------------------

class _ChooseStep extends ConsumerWidget {
  const _ChooseStep({required this.args});

  final PatternWizardArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = context.colors;
    final type = context.type;
    final format = AppDateFormat.of(context);
    final provider = patternWizardProvider(args);
    final wizard = ref.watch(provider);
    if (wizard.building) return PatternBuilder(args: args);
    if (wizard.weeksTemplate) return WeeksPerShiftEditor(args: args);
    final controller = ref.read(provider.notifier);
    final schedule = ref.watch(
      scheduleControllerProvider.select((s) => s.schedule),
    );
    final usedIds = ref.watch(usedPatternIdsProvider).value;

    final shiftId = args.shiftId;
    final shiftName = shiftId == null
        ? null
        : schedule.shiftTypeById(shiftId)?.name;
    // Patterns that begin with the shift of the puck; when none does, the
    // ones that at least include it. Keep Correturnos under Industry beside
    // its configurable weeks template.
    final startsWith = <PatternPreset>[
      if (shiftId != null)
        for (final p in patternPresets)
          if (p.id != 'correturnos' && startsWithShift(p.steps, shiftId)) p,
    ];
    final includes = <PatternPreset>[
      if (shiftId != null && startsWith.isEmpty)
        for (final p in patternPresets)
          if (p.id != 'correturnos' && containsShift(p.steps, shiftId)) p,
    ];
    final typical = startsWith.isNotEmpty ? startsWith : includes;
    final typicalIds = {for (final p in typical) p.id};
    final saved = [
      for (final p in schedule.patterns)
        if (!isCatalogPatternId(p.id)) p,
    ];
    final byStart = startsWith.isNotEmpty || includes.isEmpty;
    final typicalSaved = [
      if (shiftId != null)
        for (final p in saved)
          if (byStart
              ? startsWithShift(p.steps, shiftId)
              : containsShift(p.steps, shiftId))
            p,
    ];
    final restSaved = [
      for (final p in saved)
        if (!typicalSaved.contains(p)) p,
    ];

    Widget presetCard(PatternPreset p) => PatternCard(
      key: ValueKey('pattern-card-${p.id}'),
      name: p.name,
      description: p.description,
      steps: p.steps,
      schedule: schedule,
      selected: wizard.presetId == p.id,
      onTap: () => controller.selectPreset(p.id),
      onEdit: () => controller.editAsCopy(
        presetPattern(
          schedule,
          p,
          workShiftId: workShiftOf(
            p,
            wizard.workShiftId,
            openedWith: controller.openedWorkShift,
          ),
        ),
      ),
    );

    Widget savedCard(Pattern p) => PatternCard(
      key: ValueKey('pattern-card-${p.id}'),
      name: p.name,
      description: null,
      steps: p.steps,
      schedule: schedule,
      selected: wizard.customId == p.id,
      onTap: () => controller.selectCustom(p.id),
      onEdit: () => controller.editAsCopy(p),
      onRemove: usedIds == null || usedIds.contains(p.id)
          ? null
          : () => _remove(context, ref, p),
      inUse: usedIds?.contains(p.id) ?? false,
    );

    final groupLabels = {
      PatternGroup.health: l10n.patternGroupHealth,
      PatternGroup.police: l10n.patternGroupPolice,
      PatternGroup.firefighters: l10n.patternGroupFirefighters,
      PatternGroup.industry: l10n.patternGroupIndustry,
      PatternGroup.security: l10n.patternGroupSecurity,
    };

    final sections = <Widget>[];
    void section(String label, List<Widget> cards, {Key? key}) {
      if (cards.isEmpty) return;
      sections
        ..add(
          Padding(
            padding: const EdgeInsets.only(top: Sp.section, bottom: Sp.s),
            child: Semantics(
              header: true,
              child: Text(
                label.toUpperCase(),
                key: key,
                style: type.label.copyWith(color: colors.textMuted),
              ),
            ),
          ),
        )
        ..addAll([
          for (final card in cards)
            Padding(
              padding: const EdgeInsets.only(bottom: Sp.card),
              child: card,
            ),
        ]);
    }

    if (typical.isNotEmpty || typicalSaved.isNotEmpty) {
      final label = byStart
          ? l10n.patternGroupTypical(shiftName ?? '')
          : l10n.patternGroupIncluding(shiftName ?? '');
      section(label, [
        for (final p in typical) presetCard(p),
        for (final p in typicalSaved) savedCard(p),
      ], key: const ValueKey('pattern-group-typical'));
    }
    for (final entry in patternGroupPresets.entries) {
      section(groupLabels[entry.key]!, [
        if (entry.key == PatternGroup.industry)
          AppCard(
            key: const ValueKey('pattern-card-$weeksPerShiftTemplateId'),
            semanticLabel:
                '${l10n.patternWeeksTitle}, ${l10n.patternWeeksHint}',
            onTap: () => controller.startWeeksTemplate(l10n.patternWeeksTitle),
            child: ValueRow(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.patternWeeksTitle, style: type.bodyStrong),
                  Text(l10n.patternWeeksHint, style: type.meta),
                ],
              ),
              trailing: Icon(AppIcons.chevronRight, size: IconSize.inline),
            ),
          ),
        for (final id in entry.value)
          if (!typicalIds.contains(id)) presetCard(patternPresetById(id)),
      ]);
    }
    section(l10n.patternGroupOther, [
      for (final p in ungroupedPresets())
        if (!typicalIds.contains(p.id)) presetCard(p),
    ]);
    section(l10n.patternGroupMine, [for (final p in restSaved) savedCard(p)]);

    final from = args.start;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (from != null)
          Padding(
            padding: const EdgeInsets.only(bottom: Sp.m),
            child: Text(
              key: const ValueKey('pattern-from-day'),
              l10n.patternFromDay(
                format.weekdayDayMonth(
                  DateTime(from.year, from.month, from.day),
                ),
              ),
              style: type.body.copyWith(color: colors.textSecondary),
            ),
          ),
        AppCard(
          key: const ValueKey('pattern-create-own'),
          onTap: controller.startBuilding,
          semanticLabel: l10n.patternCreateOwn,
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surfaceRaised,
                  borderRadius: Rad.squareRadius(Disc.m),
                ),
                child: SizedBox.square(
                  dimension: Disc.m,
                  child: Icon(AppIcons.add, color: colors.textPrimary),
                ),
              ),
              const SizedBox(width: Sp.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.patternCreateOwn, style: type.bodyStrong),
                    Text(l10n.patternCreateOwnHint, style: type.meta),
                  ],
                ),
              ),
            ],
          ),
        ),
        ...sections,
      ],
    );
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    Pattern pattern,
  ) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(l10n.patternRemoveTitle(pattern.name)),
        content: Text(l10n.patternRemoveHint),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            key: const ValueKey('pattern-remove-confirm'),
            style: TextButton.styleFrom(foregroundColor: context.colors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.patternRemove),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final wizard = ref.read(patternWizardProvider(args).notifier);
    final removed = await ref
        .read(scheduleControllerProvider.notifier)
        .deletePatternIfUnused(pattern.id);
    if (!context.mounted) return;
    if (removed) {
      wizard.forgetCustom(pattern.id);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(appSnackBar(content: Text(l10n.patternRemoveUnavailable)));
    }
  }
}

/// A pattern to pick: name, length, a line about it and its days as chips.
class PatternCard extends StatelessWidget {
  const PatternCard({
    super.key,
    required this.name,
    required this.description,
    required this.steps,
    required this.schedule,
    required this.selected,
    required this.onTap,
    this.shiftOf,
    this.onEdit,
    this.editLabel,
    this.onRemove,
    this.inUse = false,
  });

  final String name;
  final String? description;
  final List<List<String>> steps;
  final Schedule schedule;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onEdit;

  /// Text of the [onEdit] button; «Editar» when `null` (the first-use
  /// catalogue says «Ajustar»).
  final String? editLabel;
  final VoidCallback? onRemove;
  final bool inUse;

  /// Resolves a shift id to the type to draw for the chips; the first-use
  /// flow passes [shiftTypeForFirstUse] so a factory type talks the app's
  /// language. `null`: the stored type ([shiftTypeForDisplay]).
  final ShiftType? Function(String id)? shiftOf;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final type = context.type;
    return AppCard(
      onTap: onTap,
      borderColor: selected ? colors.todayRing : null,
      semanticLabel: '$name, ${l10n.patternCycleDays(steps.length)}',
      selected: selected,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name and length on one line while the name's words fit beside
          // it, the length under the name when they do not («Correturno /
          // s» next to «21 días» at x2.0 on 320 dp, H-T06-3).
          ValueRow(
            title: Text(name, style: type.bodyStrong),
            value: Text(l10n.patternCycleDays(steps.length), style: type.meta),
            trailing: selected
                ? Icon(AppIcons.check, color: colors.textPrimary)
                : null,
          ),
          if (description != null) ...[
            const SizedBox(height: Sp.xs),
            Text(description!, style: type.meta),
          ],
          const SizedBox(height: Sp.m),
          SequenceChips(steps: steps, schedule: schedule, shiftOf: shiftOf),
          if (onEdit != null || onRemove != null)
            Wrap(
              spacing: Sp.s,
              children: [
                if (onEdit != null)
                  TextButton(
                    onPressed: onEdit,
                    child: Text(editLabel ?? l10n.patternEdit),
                  ),
                if (onRemove != null)
                  TextButton(
                    onPressed: onRemove,
                    style: TextButton.styleFrom(foregroundColor: colors.danger),
                    child: Text(l10n.patternRemove),
                  ),
              ],
            ),
          if (inUse) Text(l10n.patternUsedHint, style: type.meta),
        ],
      ),
    );
  }
}

// ---- step 2 -----------------------------------------------------------------

String patternFullDate(AppDateFormat format, CivilDate d) {
  final date = DateTime.utc(d.year, d.month, d.day);
  return capitalize(
    format.locale.split(RegExp('[-_]')).first == 'eu'
        ? format.spokenDate(date)
        : '${format.weekdayDayMonth(date)} ${d.year}',
  );
}

/// Asks for the start day of a rotation (or, with [forStart] false, its last
/// day) in the sheet of the app (`showDateSheet`), 2000 to 2100 or from
/// [first]. `null` when the sheet is closed without a choice.
Future<CivilDate?> pickPatternDate(
  BuildContext context,
  CivilDate initial, {
  CivilDate? first,
  bool forStart = true,
}) {
  final l10n = context.l10n;
  return showDateSheet(
    context,
    initial: initial,
    first: first ?? dateSheetFirst,
    title: forStart ? l10n.patternStartLabel : l10n.patternUntilLabel,
    hint: forStart ? l10n.dateSheetStartHint : null,
    shortcuts: forStart,
  );
}

/// A tappable date with its calendar icon.
class PatternDateTile extends StatelessWidget {
  const PatternDateTile({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    return AppCard(
      onTap: onTap,
      semanticLabel: '$label: $value',
      child: Row(
        children: [
          Icon(AppIcons.calendar),
          const SizedBox(width: Sp.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                WholeWordText(label, style: type.meta),
                WholeWordText(value, style: type.bodyStrong),
              ],
            ),
          ),
          Icon(AppIcons.chevronRight),
        ],
      ),
    );
  }
}

class _StartStep extends ConsumerWidget {
  const _StartStep({required this.args});

  final PatternWizardArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final type = context.type;
    final format = AppDateFormat.of(context);
    final provider = patternWizardProvider(args);
    final wizard = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final schedule = ref.watch(
      scheduleControllerProvider.select((s) => s.schedule),
    );
    final pattern = controller.chosenPattern(
      schedule,
      fallbackName: l10n.patternBuilderDefaultName,
    );
    if (pattern == null) return const SizedBox.shrink();
    final preset = wizard.presetId == null
        ? null
        : patternPresetById(wizard.presetId!);
    // The work shift of the work days: the one the person chose, or the
    // default one (the shift the wizard opened with, or the preset's own).
    final workShift = preset == null
        ? (wizard.workShiftId ?? 'morning')
        : workShiftOf(
            preset,
            wizard.workShiftId,
            openedWith: controller.openedWorkShift,
          );
    final paletteIds = ref.watch(
      scheduleControllerProvider.select(
        (s) => {for (final t in s.palette) t.id},
      ),
    );

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
        PatternDateTile(
          key: const ValueKey('pattern-start-date'),
          label: l10n.patternStartLabel,
          value: patternFullDate(format, wizard.start),
          onTap: () async {
            final picked = await pickPatternDate(context, wizard.start);
            if (picked != null) controller.setStart(picked);
          },
        ),
        RotationStartConfirmation(start: wizard.start),
        if (suggested != null && wizard.start.weekday != suggested)
          Padding(
            padding: const EdgeInsets.only(top: Sp.s),
            child: Text(
              l10n.patternSuggestedStart(weekdays[suggested]!),
              style: type.meta,
            ),
          ),
        const SizedBox(height: Sp.section),
        if (preset?.chooseWorkShift ?? false)
          RotationWorkShiftPicker(
            shifts: [
              for (final shift in schedule.shiftTypes)
                if (shift.category == ShiftCategory.work &&
                    (paletteIds.contains(shift.id) || shift.id == workShift))
                  shift,
              if (schedule.shiftTypeById(workShift) == null)
                shiftTypeForDisplay(schedule, workShift)!,
            ],
            selectedId: workShift,
            onChanged: controller.setWorkShift,
          ),
        // The numbered strip and whole months share the planner used to apply.
        CycleStartPicker(
          steps: pattern.steps,
          shiftOf: (id) => shiftTypeForDisplay(schedule, id),
          offset: wizard.stepOffset,
          onOffsetChanged: controller.setStepOffset,
          start: wizard.start,
          plan: ref.watch(patternPreviewProvider(args)),
          showPreview: false,
        ),
        const SizedBox(height: Sp.section),
        PatternMonthPreview(
          key: const ValueKey('pattern-preview'),
          start: wizard.start,
          cycleDays: pattern.lengthDays,
          markOverrides: true,
          plan: ref.watch(patternPreviewProvider(args)),
        ),
      ],
    );
  }
}

// ---- step 3 -----------------------------------------------------------------

class _EndStep extends ConsumerWidget {
  const _EndStep({required this.args});

  final PatternWizardArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final type = context.type;
    final format = AppDateFormat.of(context);
    final provider = patternWizardProvider(args);
    final wizard = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final endless = wizard.until == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _OptionTile(
          key: const ValueKey('pattern-end-never'),
          selected: endless,
          title: l10n.patternEndNever,
          subtitle: l10n.patternEndNeverHint,
          onTap: controller.setEndless,
        ),
        const SizedBox(height: Sp.card),
        _OptionTile(
          key: const ValueKey('pattern-end-until'),
          selected: !endless,
          title: l10n.patternEndUntil,
          subtitle: l10n.patternEndUntilHint,
          onTap: () {
            if (endless) controller.setUntil(wizard.start.addDays(89));
          },
        ),
        if (!endless) ...[
          const SizedBox(height: Sp.card),
          PatternDateTile(
            key: const ValueKey('pattern-until-date'),
            label: l10n.patternUntilLabel,
            value: patternFullDate(format, wizard.until!),
            onTap: () async {
              final picked = await pickPatternDate(
                context,
                wizard.until!,
                first: wizard.start,
                forStart: false,
              );
              if (picked != null) controller.setUntil(picked);
            },
          ),
        ],
        const SizedBox(height: Sp.section),
        Semantics(
          header: true,
          child: Text(l10n.patternOverridesTitle, style: type.bodyStrong),
        ),
        const SizedBox(height: Sp.s),
        _OptionTile(
          key: const ValueKey('pattern-keep-overrides'),
          selected: !wizard.clearOverrides,
          title: l10n.patternOverridesKeep,
          subtitle: l10n.patternOverridesKeepHint,
          onTap: () => controller.setClearOverrides(false),
        ),
        const SizedBox(height: Sp.card),
        _OptionTile(
          key: const ValueKey('pattern-replace-overrides'),
          selected: wizard.clearOverrides,
          title: l10n.patternOverridesReplace,
          subtitle: l10n.patternOverridesReplaceHint,
          onTap: () => controller.setClearOverrides(true),
        ),
        const SizedBox(height: Sp.section),
        PatternMonthPreview(
          key: const ValueKey('pattern-preview'),
          start: wizard.start,
          cycleDays: controller
              .chosenPattern(ref.watch(scheduleControllerProvider).schedule)
              ?.lengthDays,
          markOverrides: true,
          plan: ref.watch(patternPreviewProvider(args)),
        ),
      ],
    );
  }
}

/// A choice between a few options: selected, it gets the ring border and a
/// check (not colour alone).
class _OptionTile extends StatelessWidget {
  const _OptionTile({
    super.key,
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    return Semantics(
      selected: selected,
      child: AppCard(
        onTap: onTap,
        borderColor: selected ? colors.todayRing : null,
        semanticLabel: '$title. $subtitle',
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: type.bodyStrong),
                  const SizedBox(height: Sp.hair),
                  Text(subtitle, style: type.meta),
                ],
              ),
            ),
            if (selected) ...[
              const SizedBox(width: Sp.s),
              Icon(AppIcons.check, color: colors.textPrimary),
            ],
          ],
        ),
      ),
    );
  }
}
