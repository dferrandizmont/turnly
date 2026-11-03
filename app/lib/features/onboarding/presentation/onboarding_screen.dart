import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/icons/app_icons.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/router.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/page_body.dart';
import '../../calendar/application/paint_controller.dart';
import '../application/onboarding_controller.dart';
import 'choose_step.dart';
import 'import_ready_steps.dart';
import 'place_step.dart';
import 'rotation_step.dart';

/// First use (turnos-spec.md section 4, «Primer uso»; docs/diseno.md, 2A):
/// one question, «¿Cómo empiezas tu cuadrante?», with three ways (import,
/// rotation, by hand) and «Recuperar una copia de seguridad». Each way has
/// its own screens, then an optional last step (holidays and job) and
/// «Listo». Every screen after the question can be skipped ("Saltar") and
/// undone. Nothing is written until the last step is left.
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  /// Below this height (landscape on a phone) the top bar scrolls with the
  /// step instead of staying fixed.
  static const double compactHeight = 480;

  /// From this text scale the top bar and «Siguiente» scroll with the step.
  static const double compactTextScale = 1.5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);
    final stage = state.stage;
    final ready = stage == OnboardingStage.ready;

    final label = switch (stage) {
      OnboardingStage.importCalendar ||
      OnboardingStage.place => l10n.onboardingContinue,
      OnboardingStage.ready => l10n.onboardingOpenCalendar,
      _ => l10n.onboardingNext,
    };

    // «Pintar a mano» (or «Lo pinto a mano») lands on the month ready to
    // paint.
    void openCalendar() {
      if (state.byHand) ref.read(paintControllerProvider.notifier).enter();
      context.go(AppRoutes.home);
    }

    // With big text or a short screen (landscape) the bar and the title
    // would take most of the screen and leave a card and a half of the list
    // (H-T01-6): the bar then scrolls away with the list. With big text
    // «Siguiente» goes with them, to the end of the content: fixed under the
    // list it would leave two bars and little else on a 320 dp phone.
    final media = MediaQuery.of(context);
    final bigText = media.textScaler.scale(14) / 14 >= compactTextScale - 0.001;
    final compact = media.size.height < compactHeight || bigText;

    // The first question has its own top (the language) and no main
    // button: its cards go on by themselves.
    final choose = stage == OnboardingStage.choose;
    final header = choose
        ? const SizedBox.shrink()
        : _Header(state: state, busy: state.finishing);
    final step = switch (stage) {
      OnboardingStage.choose => const ChooseStep(),
      OnboardingStage.place => const PlaceStep(),
      OnboardingStage.rotation => const RotationStep(),
      OnboardingStage.start => const StartStep(),
      OnboardingStage.importCalendar => const ImportStep(),
      OnboardingStage.ready => const ReadyStep(),
    };
    const buttonPadding = EdgeInsets.fromLTRB(Sp.page, Sp.s, Sp.page, Sp.m);

    final Widget next = choose
        ? const SizedBox(height: Sp.m)
        : Padding(
            padding: buttonPadding,
            child: PrimaryButton(
              key: const ValueKey('onboarding-next'),
              label: label,
              loading: state.finishing,
              onPressed: ready
                  ? openCalendar
                  : !controller.canAdvance
                  ? null
                  : controller.next,
            ),
          );

    return PopScope(
      // The first question leaves the app; "Listo" is already saved and ends.
      canPop: choose,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (ready) {
          openCalendar();
        } else {
          controller.back();
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: PageBody(
            child: compact
                ? _compactBody(header, step, next, stage, nextInside: bigText)
                : _fixedBody(header, step, next, stage),
          ),
        ),
      ),
    );
  }

  /// The bar and the step scroll; «Siguiente» is under them, fixed.
  static Widget _fixedBody(
    Widget header,
    Widget step,
    Widget next,
    OnboardingStage stage, {
    bool barScrolls = false,
  }) => Column(
    children: [
      if (!barScrolls) header,
      Expanded(
        child: SingleChildScrollView(
          key: ValueKey('onboarding-${stage.name}'),
          padding: barScrolls ? EdgeInsets.zero : _stepPadding,
          child: barScrolls
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    header,
                    Padding(padding: _stepPadding, child: step),
                  ],
                )
              : step,
        ),
      ),
      next,
    ],
  );

  static const EdgeInsets _stepPadding = EdgeInsets.fromLTRB(
    Sp.page,
    Sp.l,
    Sp.page,
    Sp.section,
  );

  /// The bar scrolls away with the step; with [nextInside] «Siguiente» does
  /// too, at the end of the content (or at the bottom of the screen when the
  /// step is short).
  static Widget _compactBody(
    Widget header,
    Widget step,
    Widget next,
    OnboardingStage stage, {
    required bool nextInside,
  }) {
    if (!nextInside) {
      return _fixedBody(header, step, next, stage, barScrolls: true);
    }
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        key: ValueKey('onboarding-${stage.name}'),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  header,
                  Padding(padding: _stepPadding, child: step),
                ],
              ),
              next,
            ],
          ),
        ),
      ),
    );
  }
}

/// Back arrow, progress dots and «Saltar». «Listo» has none of them: its
/// choices are saved and its only way is the calendar.
class _Header extends ConsumerWidget {
  const _Header({required this.state, required this.busy});

  final OnboardingState state;
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = context.colors;
    final controller = ref.read(onboardingControllerProvider.notifier);
    final ready = state.stage == OnboardingStage.ready;
    final current = state.stepNumber;
    final total = state.steps.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.xs, Sp.xs, Sp.xs, 0),
      child: Row(
        children: [
          SizedBox(
            width: Sp.touch + Sp.s,
            child: ready
                ? null
                : IconButton(
                    key: const ValueKey('onboarding-back'),
                    tooltip: l10n.back,
                    icon: Icon(AppIcons.back),
                    onPressed: busy ? null : controller.back,
                  ),
          ),
          // The dots yield space (they scale down) before «Saltar» does.
          Expanded(
            child: current == null
                ? const SizedBox.shrink()
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Semantics(
                      label: l10n.onboardingProgress(current, total),
                      excludeSemantics: true,
                      child: Row(
                        key: const ValueKey('onboarding-dots'),
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 1; i <= total; i++)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: Sp.xs,
                              ),
                              // The current step is a longer dash, so it is
                              // not told by colour alone.
                              child: AnimatedContainer(
                                duration: Motion.of(context, Motion.state),
                                width: i == current ? Sp.xl : Sp.s,
                                height: Sp.s,
                                decoration: BoxDecoration(
                                  color: i <= current
                                      ? colors.accent
                                      : colors.borderStrong,
                                  borderRadius: Rad.pill,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
          ),
          // Its own width, never squeezed: one line at any width and scale.
          ready
              ? const SizedBox(width: Sp.touch + Sp.s)
              : ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: Sp.touch + Sp.s),
                  child: TextButton(
                    key: const ValueKey('onboarding-skip'),
                    onPressed: busy ? null : controller.skip,
                    child: Text(
                      l10n.onboardingSkip,
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}
