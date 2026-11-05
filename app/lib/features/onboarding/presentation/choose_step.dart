import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/icons/app_icons.dart';
import '../../../core/l10n/app_locales.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/router.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/choice_sheet.dart';
import '../../calendar/application/schedule_controller.dart';
import '../../calendar/presentation/shift_badge.dart';
import '../../calendar/presentation/shift_format.dart';
import '../../import/presentation/import_icons.dart';
import '../../patterns/domain/pattern_catalog.dart';
import '../../schedule/domain/schedule_domain.dart';
import '../../settings/application/preferences_controller.dart';
import '../../settings/domain/preferences.dart';
import '../../settings/presentation/settings_widgets.dart';
import '../application/onboarding_controller.dart';
import 'onboarding_widgets.dart';

/// The first question, «¿Cómo empiezas tu cuadrante?» (docs/diseno.md, 2A):
/// three cards that say what happens on each way (import, rotation, by
/// hand) and, under them, «Recuperar una copia de seguridad» for whoever
/// changes phones. The language is chosen here, before anything is written
/// in it (the factory catalogue is finalized in that language).
class ChooseStep extends ConsumerWidget {
  const ChooseStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final type = context.type;
    final controller = ref.read(onboardingControllerProvider.notifier);

    Future<void> restore() async {
      await context.push(AppRoutes.settingsBackup);
      // A restore that finished marks the first use as done and leaves the
      // person's data: nothing left to ask.
      if (!context.mounted) return;
      if (await controller.restoredMeanwhile() && context.mounted) {
        context.go(AppRoutes.home);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Align(
          alignment: AlignmentDirectional.centerEnd,
          child: OnboardingLanguageButton(),
        ),
        const SizedBox(height: Sp.s),
        StepHeader(
          title: l10n.onboardingChooseTitle,
          titleKey: const ValueKey('onboarding-title'),
          help: l10n.onboardingChooseHelp,
        ),
        _PathCard(
          key: const ValueKey('onboarding-path-import'),
          art: const _ImportArt(),
          title: l10n.onboardingPathImport,
          hint: l10n.onboardingPathImportHint,
          onTap: controller.chooseImport,
        ),
        const SizedBox(height: Sp.card),
        _PathCard(
          key: const ValueKey('onboarding-path-rotation'),
          art: const _RotationArt(),
          tag: l10n.onboardingPathRotationTag,
          title: l10n.onboardingPathRotation,
          hint: l10n.onboardingPathRotationHint,
          onTap: controller.chooseRotation,
        ),
        const SizedBox(height: Sp.card),
        _PathCard(
          key: const ValueKey('onboarding-path-paint'),
          art: const _PaintArt(),
          title: l10n.onboardingPathPaint,
          hint: l10n.onboardingPathPaintHint,
          onTap: controller.choosePaint,
        ),
        const SizedBox(height: Sp.section),
        Text(
          l10n.onboardingChooseLater,
          key: const ValueKey('onboarding-choose-later'),
          textAlign: TextAlign.center,
          style: type.meta,
        ),
        const SizedBox(height: Sp.s),
        Center(
          child: TextButton.icon(
            key: const ValueKey('onboarding-restore'),
            onPressed: restore,
            icon: Icon(ImportIcons.backupFile, size: IconSize.button),
            label: Text(l10n.onboardingRestore, textAlign: TextAlign.center),
          ),
        ),
      ],
    );
  }
}

/// One way to start: a drawing of what the person will see, the name, one
/// line of what happens and a chevron. [tag] marks the way most people take.
class _PathCard extends StatelessWidget {
  const _PathCard({
    super.key,
    required this.art,
    required this.title,
    required this.hint,
    required this.onTap,
    this.tag,
  });

  final Widget art;
  final String title;
  final String hint;
  final String? tag;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    return AppCard(
      onTap: onTap,
      semanticLabel: [?tag, title, hint].join('. '),
      // The label says it all once: the texts are not read again.
      child: ExcludeSemantics(
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surfaceRaised,
                borderRadius: Rad.innerRadius,
              ),
              child: SizedBox.square(
                dimension: Disc.badge,
                child: Center(child: art),
              ),
            ),
            const SizedBox(width: Sp.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (tag != null) ...[
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.accentSoft,
                        borderRadius: Rad.chipSmallRadius,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Sp.s,
                          vertical: Sp.hair,
                        ),
                        child: Text(
                          tag!,
                          style: type.caption.copyWith(
                            color: colors.accentText,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: Sp.xs),
                  ],
                  Text(title, style: type.bodyStrong),
                  const SizedBox(height: Sp.hair),
                  Text(hint, style: type.meta),
                ],
              ),
            ),
            const SizedBox(width: Sp.s),
            Icon(AppIcons.chevronRight, color: colors.textMuted),
          ],
        ),
      ),
    );
  }
}

/// «Importar mis turnos»: the import glyph in the accent.
class _ImportArt extends StatelessWidget {
  const _ImportArt();

  @override
  Widget build(BuildContext context) => Icon(
    ImportIcons.importData,
    size: IconSize.hero,
    color: context.colors.accentText,
  );
}

/// Shift types of the drawings, as the calendar shows them: colour and code
/// (never colour alone, even in a drawing). Missing ones are left out. Talks
/// the app's language while the first-use flow is open (see
/// [shiftTypeForFirstUse]).
List<ShiftType> _artShifts(Schedule schedule, List<String> ids) => [
  for (final id in ids) ?shiftTypeForFirstUse(schedule, id),
];

/// The badges of a small grid inside a [Disc.badge] square.
const double _artGap = Sp.hair;
const double _artCell = (Disc.badge - 2 * Sp.xs - 2 * _artGap) / 3;

/// «Usar una rotación»: a cycle in badges (mañana, tarde, noche, saliente,
/// libre, libre).
class _RotationArt extends ConsumerWidget {
  const _RotationArt();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedule = ref.watch(
      scheduleControllerProvider.select((s) => s.schedule),
    );
    final shifts = _artShifts(schedule, const [
      'morning',
      'afternoon',
      'night',
      'postNight',
      'rest',
      'rest',
    ]);
    if (shifts.isEmpty) {
      return Icon(AppIcons.pattern, color: context.colors.textPrimary);
    }
    return SizedBox(
      width: 3 * _artCell + 2 * _artGap,
      child: Wrap(
        spacing: _artGap,
        runSpacing: _artGap,
        children: [
          for (final shift in shifts) ShiftBadge(shift: shift, size: _artCell),
        ],
      ),
    );
  }
}

/// «Pintar a mano»: a few days of a month painted (the tint and bar of each
/// day) and the brush.
class _PaintArt extends ConsumerWidget {
  const _PaintArt();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final schedule = ref.watch(
      scheduleControllerProvider.select((s) => s.schedule),
    );
    final shifts = _artShifts(schedule, const [
      'morning',
      'morning',
      'rest',
      'night',
      'night',
      'postNight',
      'rest',
      'rest',
      'morning',
    ]);
    final brush = Icon(
      AppIcons.paint,
      size: IconSize.button,
      color: colors.textPrimary,
    );
    if (shifts.isEmpty) return brush;
    return SizedBox.square(
      dimension: 3 * _artCell + 2 * _artGap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Wrap(
            spacing: _artGap,
            runSpacing: _artGap,
            children: [
              for (final swatch in [
                for (final shift in shifts) shift.swatch(colors.brightness),
              ])
                SizedBox.square(
                  dimension: _artCell,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: swatch.tint,
                      border: Border(
                        bottom: BorderSide(color: swatch.bar, width: Sp.hair),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          PositionedDirectional(
            end: -Sp.xs,
            bottom: -Sp.xs,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surfaceRaised,
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(Sp.hair),
                child: brush,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The app language, top right of the first question: the same persisted
/// preference and the same sheet as Ajustes › Idioma. Chosen before the
/// provisional factory catalogue is finalized, so the shift names are
/// written in it.
class OnboardingLanguageButton extends ConsumerWidget {
  const OnboardingLanguageButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final selected = ref.watch(preferencesProvider.select((p) => p.language));
    String endonym(String code) => switch (code) {
      'ca' => l10n.languageNameCa,
      'gl' => l10n.languageNameGl,
      'eu' => l10n.languageNameEu,
      'en' => l10n.languageNameEn,
      _ => l10n.languageNameEs,
    };
    final system = resolveAppLocale(
      WidgetsBinding.instance.platformDispatcher.locales,
    );
    String name(AppLanguage language) => language == AppLanguage.system
        ? l10n.settingsLanguageSystem(endonym(system.languageCode))
        : endonym(language.name);
    // On the button, only the language in use: short enough for one line.
    final shown = endonym(
      selected == AppLanguage.system ? system.languageCode : selected.name,
    );

    Future<void> pick() async {
      final picked = await showChoiceSheet<AppLanguage>(
        context: context,
        title: l10n.settingsLanguageTitle,
        selected: selected,
        options: [
          for (final language in AppLanguage.values)
            if (language == AppLanguage.system ||
                appSupportedLocales.any((l) => l.languageCode == language.name))
              ChoiceOption(language, name(language)),
        ],
      );
      if (picked != null && context.mounted) {
        await saveSetting(
          context,
          () => ref.read(preferencesProvider.notifier).setLanguage(picked),
        );
      }
    }

    return Semantics(
      button: true,
      excludeSemantics: true,
      label: '${l10n.settingsLanguageTitle}: $shown',
      onTap: pick,
      child: TextButton(
        key: const ValueKey('onboarding-language'),
        onPressed: pick,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                '${l10n.settingsLanguageTitle}: $shown',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: Sp.xs),
            Icon(AppIcons.chevronRight, size: IconSize.inline),
          ],
        ),
      ),
    );
  }
}
