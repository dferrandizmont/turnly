import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/app_card.dart';
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
/// title and no help line; to keep the rotation step short, the hours line
/// (subtitle) is shown only on the chosen row there, while in the normal form
/// it is shown on every row.
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
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: Sp.s),
          child: Column(
            children: [
              for (var i = 0; i < professions.length; i++) ...[
                if (i > 0)
                  Divider(height: 1, thickness: 1, color: colors.border),
                ChoiceRow(
                  key: ValueKey('onboarding-profession-${professions[i].name}'),
                  label: professions[i].label(l10n, spain: spain),
                  subtitle: (compact && selected != professions[i])
                      ? null
                      : professions[i].hint(l10n, spain: spain),
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
