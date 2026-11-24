import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/choice_pill.dart';
import '../../../core/widgets/choice_row.dart';
import '../../holidays/domain/holiday_country.dart';
import '../application/onboarding_controller.dart';
import '../domain/profession.dart';
import 'onboarding_widgets.dart';

/// «¿A qué te dedicas? Opcional»: one row per job of the country (Spain: the
/// Spanish sector's list; elsewhere a neutral one), each with its usual
/// hours underneath. It only sets the hours of the shift types (and which
/// rotations come first); tapping the chosen one again leaves none.
///
/// It is asked on the rotation screen when the person uses a rotation (so
/// «Lo habitual en tu trabajo» is already ordered there), and in the place
/// step on the other ways. The [compact] form (the rotation screen) has a smaller
/// title and no help line; to keep the rotation step short (so «Crear mi ciclo»
/// is on the first screen), the jobs are one row of chips that scrolls sideways
/// and the hours line is shown only for the chosen one, under it, while in the
/// normal form every job is a row with its hours.
class ProfessionSection extends ConsumerWidget {
  const ProfessionSection({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final type = context.type;
    final colors = context.colors;
    final selected = ref.watch(
      onboardingControllerProvider.select((s) => s.profession),
    );
    final country = ref.watch(
      onboardingControllerProvider.select((s) => s.countryCode),
    );
    final spain = country == spainCountryCode;
    final controller = ref.read(onboardingControllerProvider.notifier);
    final professions = professionsFor(country);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text.rich(
            key: const ValueKey('onboarding-profession-title'),
            TextSpan(
              text: l10n.onboardingProfessionTitle,
              children: [
                const TextSpan(text: ' '),
                TextSpan(
                  text: l10n.onboardingOptional,
                  style: type.meta.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            style: compact ? type.bodyStrong : type.title,
          ),
        ),
        if (!compact) ...[
          const SizedBox(height: Sp.xs),
          Text(
            l10n.onboardingProfessionHelp,
            style: type.body.copyWith(color: colors.textSecondary),
          ),
        ],
        SizedBox(height: compact ? Sp.s : Sp.m),
        if (compact) ...[
          // One row, scrolled sideways: the list of seven jobs took half of
          // the screen and pushed «Crear mi ciclo» below the fold.
          JobChips(
            professions: professions,
            selected: selected,
            spain: spain,
            onSelected: controller.selectProfession,
          ),
          if (selected != null)
            Padding(
              padding: const EdgeInsets.only(top: Sp.xs),
              child: Text(
                selected.hint(l10n, spain: spain),
                key: const ValueKey('onboarding-profession-hours'),
                style: type.meta,
              ),
            ),
        ] else
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: Sp.s),
            child: Column(
              children: [
                for (var i = 0; i < professions.length; i++) ...[
                  if (i > 0)
                    Divider(height: 1, thickness: 1, color: colors.border),
                  ChoiceRow(
                    key: ValueKey(
                      'onboarding-profession-${professions[i].name}',
                    ),
                    label: professions[i].label(l10n, spain: spain),
                    subtitle: professions[i].hint(l10n, spain: spain),
                    selected: selected == professions[i],
                    onTap: () => controller.selectProfession(professions[i]),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// The jobs as one row of chips that scrolls sideways, with a fade over each
/// edge where more jobs wait (the thin scrollbar is no sign that a row
/// scrolls; same cue as the cycle strip).
class JobChips extends StatefulWidget {
  const JobChips({
    super.key,
    required this.professions,
    required this.selected,
    required this.spain,
    required this.onSelected,
  });

  final List<Profession> professions;
  final Profession? selected;
  final bool spain;
  final ValueChanged<Profession> onSelected;

  @override
  State<JobChips> createState() => _JobChipsState();
}

class _JobChipsState extends State<JobChips> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Stack(
      children: [
        SingleChildScrollView(
          key: const ValueKey('onboarding-profession-chips'),
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final profession in widget.professions)
                  Padding(
                    padding: const EdgeInsets.only(right: Sp.s),
                    // A long name (Basque, Galician) wraps in the chip
                    // instead of making it wider than the screen.
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 200),
                      child: ChoicePill(
                        key: ValueKey(
                          'onboarding-profession-${profession.name}',
                        ),
                        label: profession.label(l10n, spain: widget.spain),
                        selected: widget.selected == profession,
                        onTap: () => widget.onSelected(profession),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        _fade(context, atStart: true),
        _fade(context, atStart: false),
      ],
    );
  }

  /// Shows at the start only once the row has moved, and at the end until it
  /// has reached it.
  Widget _fade(BuildContext context, {required bool atStart}) {
    final background = context.colors.background;
    return Positioned.directional(
      textDirection: Directionality.of(context),
      start: atStart ? 0 : null,
      end: atStart ? null : 0,
      top: 0,
      bottom: 0,
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
                  'onboarding-profession-fade-${atStart ? 'start' : 'end'}',
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
}
