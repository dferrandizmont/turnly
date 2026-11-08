import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/choice_pill.dart';
import '../../holidays/domain/holiday_country.dart';
import '../application/onboarding_controller.dart';
import '../domain/profession.dart';
import 'onboarding_widgets.dart';

/// «¿A qué te dedicas? Opcional»: one pill per job of the country (Spain: the
/// Spanish sector's list; elsewhere a neutral one), and under them the usual
/// hours of the one chosen. It only sets the hours of the shift types (and
/// which rotations come first); tapping the chosen one again leaves none.
///
/// It is asked on the rotation screen when the person uses a rotation (so
/// «Lo habitual en tu trabajo» is already ordered there), and in the place
/// step on the other ways. The [compact] form (the rotation screen) has a smaller
/// title and no help line.
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
        Wrap(
          spacing: Sp.s,
          runSpacing: Sp.s,
          children: [
            for (final profession in professionsFor(country))
              ChoicePill(
                key: ValueKey('onboarding-profession-${profession.name}'),
                label: profession.label(l10n, spain: spain),
                selected: selected == profession,
                radius: Rad.inputRadius,
                onTap: () => controller.selectProfession(profession),
              ),
          ],
        ),
        if (selected != null)
          Padding(
            padding: const EdgeInsets.only(top: Sp.m),
            child: Text(
              selected.hint(l10n, spain: spain),
              key: const ValueKey('onboarding-profession-hint'),
              style: type.body.copyWith(color: colors.textSecondary),
            ),
          ),
      ],
    );
  }
}
