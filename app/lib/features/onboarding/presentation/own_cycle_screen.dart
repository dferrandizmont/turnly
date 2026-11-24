import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/icons/app_icons.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/content_app_bar.dart';
import '../../../core/widgets/page_body.dart';
import '../../calendar/application/schedule_controller.dart';
import '../../patterns/application/pattern_wizard.dart';
import '../../patterns/domain/pattern_blocks.dart';
import '../../patterns/domain/pattern_catalog.dart';
import '../../patterns/presentation/pattern_builder.dart';
import '../../patterns/presentation/pattern_builder_shifts.dart';
import '../../schedule/domain/schedule_domain.dart';
import '../application/onboarding_controller.dart';
import '../domain/profession.dart';

/// What «Tu ciclo» hands back: the days built and the name (never empty).
typedef OwnCycle = ({List<List<String>> steps, String name});

/// «Tu ciclo» (first use, over «¿Cómo es tu rotación?»): the pattern builder of
/// the wizard (`PatternBuilderViewport`, with its pinned palette) in a screen
/// of its own, with a close button and «Usar este ciclo». It is a screen inside
/// step 2 of 3, not a step: it closes with the cycle built (the caller keeps it
/// in the onboarding state) or with nothing.
///
/// Nothing is written here: the draft lives in the wizard's provider family
/// under [firstUseWizardArgs] (its own key, so it never shares a draft with a
/// wizard opened before), and the shift types it draws are the ones the flow
/// will leave at the end, not the stored ones (see [PatternBuilderShifts]).
class OwnCycleScreen extends ConsumerStatefulWidget {
  const OwnCycleScreen({super.key, this.initialSteps, this.initialName = ''});

  /// The cycle to start from («Ajustar» on a catalogue rotation, «Editar» on
  /// the own one); `null` starts empty.
  final List<List<String>>? initialSteps;
  final String initialName;

  /// Opens «Tu ciclo» over the current screen. Resolves to the cycle built
  /// with «Usar este ciclo», or `null` when it was closed.
  static Future<OwnCycle?> open(
    BuildContext context, {
    List<List<String>>? initialSteps,
    String initialName = '',
  }) => Navigator.of(context).push<OwnCycle>(
    MaterialPageRoute(
      builder: (_) =>
          OwnCycleScreen(initialSteps: initialSteps, initialName: initialName),
      settings: const RouteSettings(name: '/primer-uso/tu-ciclo'),
    ),
  );

  @override
  ConsumerState<OwnCycleScreen> createState() => _OwnCycleScreenState();
}

class _OwnCycleScreenState extends ConsumerState<OwnCycleScreen> {
  static final _provider = patternWizardProvider(firstUseWizardArgs);
  bool _confirming = false;

  // The draft is set up right after the first frame (a provider cannot be
  // modified while the tree builds); the builder appears with it, so its name
  // field reads the draft name when it is created.
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      final controller = ref.read(_provider.notifier);
      final steps = widget.initialSteps;
      if (steps == null || steps.isEmpty) {
        controller.startBuilding();
      } else {
        controller.editAsCopy(
          Pattern(id: 'first-use', name: widget.initialName, steps: steps),
        );
      }
      setState(() => _ready = true);
    });
  }

  /// The close button and the system back: with changes not used, the
  /// question the wizard asks.
  Future<void> _leave() async {
    if (_confirming) return;
    _confirming = true;
    // The question puts the keyboard away: «Seguir editando» gives the focus
    // back to the field the person was typing in.
    final focused = FocusManager.instance.primaryFocus;
    final discard = await confirmDiscardSequence(
      context,
      ref.read(_provider.notifier),
    );
    if (mounted && discard) {
      Navigator.pop(context);
    } else if (mounted && focused != null && focused.context?.mounted == true) {
      focused.requestFocus();
    }
    _confirming = false;
  }

  void _use(String fallbackName) {
    final wizard = ref.read(_provider);
    if (wizard.draft.isEmpty || wizard.draft.length > maxPatternCycleDays) {
      return;
    }
    final name = wizard.draftName.trim();
    Navigator.pop<OwnCycle>(context, (
      steps: [for (final day in wizard.draft) List<String>.of(day)],
      name: name.isEmpty ? fallbackName : name,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final wizard = ref.watch(_provider);
    final controller = ref.read(_provider.notifier);

    // The shift types as the flow will leave them: the factory ones (never
    // what an import or an earlier edit left in the stored palette) with the
    // job's hours and order and the names in the app's language, without
    // absences, which are no part of a rotation.
    final stored = ref.watch(
      scheduleControllerProvider.select((s) => s.schedule),
    );
    final profession = ref.watch(
      onboardingControllerProvider.select((s) => s.profession),
    );
    final schedule = scheduleWithProfession(stored, profession);
    final factory = [
      for (final template in shiftTemplates)
        if (template.category != ShiftCategory.absence)
          ?shiftTypeForFirstUse(schedule, template.key),
    ];
    final order = profession == null
        ? [for (final t in factory) t.id]
        : professionPaletteOrder(factory, profession);
    final palette = [
      for (final id in order) factory.firstWhere((t) => t.id == id),
    ];
    final defaultName = l10n.onboardingOwnCycleName;
    final canUse =
        wizard.draft.isNotEmpty && wizard.draft.length <= maxPatternCycleDays;

    return PopScope(
      canPop: !controller.hasDraftChanges,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        appBar: ContentAppBar.adaptive(
          context,
          title: Text(l10n.onboardingOwnCycleTitle),
          titleIdentifier: 'own-cycle-screen',
          backButton: IconButton(
            key: const ValueKey('own-cycle-close'),
            tooltip: l10n.close,
            icon: Icon(AppIcons.close),
            onPressed: _leave,
          ),
        ),
        body: !_ready
            ? const SizedBox.shrink()
            : PageBody(
                child: PatternBuilderShifts(
                  palette: palette,
                  shiftOf: (id) => shiftTypeForFirstUse(schedule, id),
                  defaultName: defaultName,
                  child: PatternBuilderViewport(
                    args: firstUseWizardArgs,
                    header: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Sp.page,
                        Sp.s,
                        Sp.page,
                        0,
                      ),
                      child: Text(
                        l10n.onboardingOwnCycleHours,
                        key: const ValueKey('own-cycle-hours-hint'),
                        style: context.type.meta,
                      ),
                    ),
                  ),
                ),
              ),
        // In a column of its own height: a PageBody alone would take the
        // whole screen.
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
                  child: PrimaryButton(
                    key: const ValueKey('own-cycle-use'),
                    label: l10n.onboardingOwnCycleUse,
                    onPressed: canUse ? () => _use(defaultName) : null,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
