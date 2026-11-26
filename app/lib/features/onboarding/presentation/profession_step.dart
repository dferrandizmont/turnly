import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/choice_grid.dart';
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
          // The line of the usual hours keeps its room whether a job is
          // chosen or not: it appeared under the chips and pushed «Crear mi
          // ciclo» away from the finger (QA 0.12.1, N14).
          _HoursLine(
            hints: [for (final p in professions) p.hint(l10n, spain: spain)],
            shown: selected?.hint(l10n, spain: spain),
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

/// The usual hours of the chosen job, under the chips of the compact form. It
/// is as tall as the longest of the hours lines at the width and text size in
/// use, so choosing (or changing) a job moves nothing below it.
class _HoursLine extends StatelessWidget {
  const _HoursLine({required this.hints, required this.shown});

  final List<String> hints;
  final String? shown;

  @override
  Widget build(BuildContext context) {
    final style = context.type.meta;
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: Sp.xs),
      child: LayoutBuilder(
        builder: (context, box) {
          var height = 0.0;
          for (final hint in hints) {
            final painter = TextPainter(
              text: TextSpan(text: hint, style: style),
              textDirection: direction,
              textScaler: scaler,
            )..layout(maxWidth: box.maxWidth);
            if (painter.height > height) height = painter.height;
            painter.dispose();
          }
          return SizedBox(
            height: height,
            width: double.infinity,
            child: shown == null
                ? null
                : Text(
                    shown!,
                    key: const ValueKey('onboarding-profession-hours'),
                    style: style,
                  ),
          );
        },
      ),
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

  /// The widest a chip of the scrolling row gets before its name wraps: 200 dp
  /// for the name plus the place the chip keeps for its check.
  static const double _chipMaxWidth = 200 + IconSize.inline + Sp.s;

  /// One job. It keeps room for the check whether it is chosen or not
  /// (`reserveIcon`), so choosing it changes neither its width nor what is
  /// after it (QA 0.12.1, N14).
  Widget _chip(BuildContext context, Profession profession) => ChoicePill(
    key: ValueKey('onboarding-profession-${profession.name}'),
    label: profession.label(context.l10n, spain: widget.spain),
    selected: widget.selected == profession,
    reserveIcon: true,
    onTap: () => widget.onSelected(profession),
  );

  /// From this text size the chips wrap onto lines instead of scrolling
  /// sideways: at x2.0 only the edge of the next job showed after a swipe
  /// (QA 0.12.1, N12), and the step scrolls with pinned buttons anyway.
  static const double _wrapFrom = 1.5;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (MediaQuery.textScalerOf(context).scale(10) / 10 >= _wrapFrom) {
      // A chip may take the whole row: a long name keeps its words whole
      // instead of splitting at a fixed width (QA 0.12.1, Astra).
      return LayoutBuilder(
        builder: (context, box) => Wrap(
          key: const ValueKey('onboarding-profession-chips'),
          spacing: Sp.s,
          runSpacing: Sp.s,
          children: [
            for (final profession in widget.professions)
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: box.maxWidth),
                child: _chip(context, profession),
              ),
          ],
        ),
      );
    }
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
                    // instead of making it wider than the screen, but never
                    // inside a word: the chip is at least as wide as its
                    // longest word.
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: math.max(
                          _chipMaxWidth,
                          ChoiceGrid.minCellWidthFor(
                            context,
                            labels: [
                              profession.label(l10n, spain: widget.spain),
                            ],
                          ),
                        ),
                      ),
                      child: _chip(context, profession),
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
