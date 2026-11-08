import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/text_fold.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/choice_row.dart';
import '../../holidays/data/holiday_bundle_format.dart';
import '../../holidays/domain/holiday_country.dart';
import '../../holidays/domain/holiday_subdivision.dart';
import '../../holidays/domain/spanish_regions.dart';
import '../../holidays/presentation/holiday_pickers.dart';
import '../application/onboarding_controller.dart';
import '../application/onboarding_providers.dart';
import 'onboarding_widgets.dart';
import 'profession_step.dart';

/// The place step, optional («Paso N de M · Opcional»; the last one except
/// with a rotation, where it comes first): «¿Dónde trabajas?»,
/// the country (proposed from the phone's region) and, in Spain, the
/// community (a list of 19) and, optionally, the municipality (a search over
/// the bundled index, filtered by region); outside Spain a line says there
/// are no official holidays for that country yet and where to add one's
/// own. Under it, «¿A qué te dedicas?» ([ProfessionSection]), unless the
/// person uses a rotation (then it was asked on that screen). «Saltar»
/// keeps the country, so a phone outside Spain never gets Spain's holidays.
class PlaceStep extends ConsumerWidget {
  const PlaceStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final type = context.type;
    final state = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);
    final region = regionByCode(state.regionCode);
    final municipality = state.municipalityCode;
    final missingYears = municipality == null
        ? const <int>[]
        : ref.watch(localHolidaysMissingYearsProvider(municipality)).value ??
              const <int>[];
    final thisYear = state.start.year;
    final noteStyle = type.body.copyWith(color: context.colors.textSecondary);

    final country = ValueTile(
      key: const ValueKey('onboarding-country'),
      label: l10n.onboardingCountryLabel,
      placeholder: l10n.onboardingCountryLabel,
      value: holidayCountryLabel(context, state.countryCode),
      onTap: () async {
        final picked = await showCountryPicker(
          context,
          title: l10n.onboardingCountrySheetTitle,
          selected: state.countryCode,
        );
        if (picked != null) controller.selectCountry(picked);
      },
    );

    // «Paso 1 de 3 · Opcional»: the dots say the number, this says it can
    // be left.
    final step = state.stepNumber;
    final optional = Padding(
      padding: const EdgeInsets.only(bottom: Sp.xs),
      child: Text(
        step == null
            ? l10n.onboardingOptional
            : '${l10n.onboardingProgress(step, state.steps.length)} · '
                  '${l10n.onboardingOptional}',
        key: const ValueKey('onboarding-optional'),
        style: type.meta.copyWith(fontWeight: FontWeight.w600),
      ),
    );

    final jobAsked = state.path == OnboardingPath.rotation;

    Widget withJob(List<Widget> place) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        optional,
        ...place,
        // With a rotation the job was asked on that screen, before the list.
        if (!jobAsked) ...[
          const SizedBox(height: Sp.section + Sp.s),
          const ProfessionSection(),
        ],
      ],
    );

    if (!state.isSpain) {
      return withJob([
        StepHeader(
          title: l10n.onboardingPlaceTitle,
          titleKey: const ValueKey('onboarding-title'),
          help: l10n.onboardingPlaceHelpAbroad,
        ),
        country,
        // A country whose files list subdivisions (states, provinces,
        // cantons...): the same tile and sheet as in Ajustes › Festivos.
        if (holidaySubdivisionTitle(context, state.countryCode)
            case final title?) ...[
          const SizedBox(height: Sp.card),
          ValueTile(
            key: const ValueKey('onboarding-subdivision'),
            label: title,
            placeholder: l10n.holidaysSettingsRegionUnset,
            value: subdivisionName(state.regionCode),
            onTap: () async {
              final picked = await showSubdivisionPicker(
                context,
                countryCode: state.countryCode,
                selected: state.regionCode,
                clearLabel: l10n.holidaysSettingsRegionUnset,
              );
              if (picked != null) controller.selectRegion(picked.value);
            },
          ),
        ],
        Padding(
          padding: const EdgeInsets.only(top: Sp.m),
          child: Text(
            state.countryCode == otherCountryCode
                ? l10n.onboardingCountryNone
                : countryHasHolidayData(state.countryCode)
                ? l10n.onboardingCountryIncluded(
                    holidayCountryLabel(context, state.countryCode),
                  )
                : l10n.onboardingCountryNoData(
                    holidayCountryLabel(context, state.countryCode),
                  ),
            key: const ValueKey('onboarding-country-note'),
            style: noteStyle,
          ),
        ),
      ]);
    }

    return withJob([
      StepHeader(
        title: l10n.onboardingPlaceTitle,
        titleKey: const ValueKey('onboarding-title'),
        help: l10n.onboardingPlaceHelp,
      ),
      country,
      const SizedBox(height: Sp.card),
      ValueTile(
        key: const ValueKey('onboarding-region'),
        label: l10n.onboardingRegionLabel,
        placeholder: l10n.onboardingRegionPick,
        value: region?.name,
        onTap: () async {
          // The same sheet and list as Ajustes › Festivos (H-T10-3): the 19
          // in alphabetical order, the current one marked.
          final picked = await showRegionPicker(
            context,
            title: l10n.onboardingRegionSheetTitle,
            selected: region?.code,
          );
          final code = picked?.value;
          if (code != null) controller.selectRegion(code);
        },
      ),
      const SizedBox(height: Sp.card),
      ValueTile(
        key: const ValueKey('onboarding-municipality'),
        label: l10n.onboardingMunicipalityLabel,
        placeholder: region == null
            ? l10n.onboardingMunicipalityNeedsRegion
            : l10n.onboardingMunicipalityPick,
        value: state.municipalityName,
        onTap: region == null
            ? null
            : () async {
                final picked = await showAppSheet<Municipality>(
                  context: context,
                  builder: (_) => MunicipalitySheet(regionCode: region.code),
                );
                if (picked != null) {
                  controller.selectMunicipality(picked.code, name: picked.name);
                }
              },
        onClear: () => controller.selectMunicipality(null),
        clearTooltip: l10n.onboardingMunicipalityClear,
        clearKey: const ValueKey('onboarding-municipality-clear'),
      ),
      if (missingYears.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: Sp.m),
          child: Text(
            // This year missing: none at all for now. Only next year
            // missing (November, December): they have not come out yet.
            missingYears.contains(thisYear)
                ? l10n.onboardingLocalHolidaysMissing
                : l10n.onboardingLocalHolidaysMissingYear(
                    '${missingYears.first}',
                  ),
            key: const ValueKey('onboarding-local-missing'),
            style: noteStyle,
          ),
        ),
    ]);
  }
}

/// The search sheet over the municipalities of one region.
class MunicipalitySheet extends ConsumerStatefulWidget {
  const MunicipalitySheet({super.key, required this.regionCode});

  final String regionCode;

  @override
  ConsumerState<MunicipalitySheet> createState() => _MunicipalitySheetState();
}

class _MunicipalitySheetState extends ConsumerState<MunicipalitySheet> {
  final _controller = TextEditingController();
  List<(String, Municipality)>? _all;
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<(String, Municipality)> _folded(MunicipalityIndex index) => _all ??= [
    for (final m in index.inRegionByName(widget.regionCode))
      (foldSpanish(m.name), m),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final type = context.type;
    final colors = context.colors;
    final media = MediaQuery.of(context);
    final index = ref.watch(municipalityIndexProvider).value;
    final height = math.max(
      280.0,
      media.size.height * 0.85 - media.viewInsets.bottom,
    );

    final folded = index == null
        ? const <(String, Municipality)>[]
        : _folded(index);
    final needle = foldSpanish(_query.trim());
    final matches = needle.isEmpty
        ? [for (final e in folded) e.$2]
        : [
            for (final e in folded)
              if (e.$1.startsWith(needle)) e.$2,
            for (final e in folded)
              if (!e.$1.startsWith(needle) && e.$1.contains(needle)) e.$2,
          ];

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: SizedBox(
          height: height,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(Sp.page, 0, Sp.page, Sp.m),
                child: Semantics(
                  header: true,
                  child: Text(
                    l10n.onboardingMunicipalitySheetTitle,
                    style: type.headline,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(Sp.page, 0, Sp.page, Sp.s),
                child: TextField(
                  key: const ValueKey('onboarding-municipality-search'),
                  controller: _controller,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: l10n.onboardingMunicipalitySearch,
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              Expanded(
                child: matches.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(Sp.page),
                        child: Text(
                          index == null ? '' : l10n.onboardingMunicipalityNone,
                          style: type.body.copyWith(color: colors.textMuted),
                        ),
                      )
                    : ListView.builder(
                        itemCount: matches.length,
                        itemBuilder: (context, i) {
                          final m = matches[i];
                          // Same row as the community sheet, at the same x.
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: Sp.page,
                            ),
                            child: ChoiceRow(
                              key: ValueKey('municipality-${m.code}'),
                              label: m.name,
                              onTap: () => Navigator.pop(context, m),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
