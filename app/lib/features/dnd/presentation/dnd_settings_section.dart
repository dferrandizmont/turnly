import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/icons/app_icons.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/app_callout.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/choice_sheet.dart';
import '../../settings/presentation/settings_widgets.dart';
import '../application/dnd_providers.dart';
import '../domain/dnd_settings.dart';

/// Ajustes › Alarmas: «No molestar durante el turno» (P13).
///
/// Android only: on iOS Focus is not programmable by apps, so the section is
/// not shown at all. It holds the global switch, the interruption filter the
/// phone is put in while a shift lasts and the state of the «Acceso a No
/// molestar» permission, with the button that opens the system screen.
class DndSettingsSection extends ConsumerWidget {
  const DndSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(dndSupportedProvider)) return const SizedBox.shrink();
    final settings = ref.watch(dndSettingsProvider).value;
    if (settings == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: Sp.section),
        SettingsSection(
          title: l10n.dndSection,
          children: [
            SettingsSwitchRow(
              key: const ValueKey('dnd-master'),
              switchKey: const ValueKey('dnd-master-switch'),
              icon: AppIcons.silence,
              title: l10n.dndMasterTitle,
              subtitle: l10n.dndMasterHelp,
              value: settings.enabled,
              onChanged: (on) => saveSetting(
                context,
                () => ref.read(dndSettingsProvider.notifier).setEnabled(on),
              ),
            ),
            if (settings.enabled)
              SettingsRow(
                key: const ValueKey('dnd-filter'),
                icon: AppIcons.bell,
                title: l10n.dndFilterTitle,
                value: dndFilterLabel(l10n, settings.filter),
                onTap: () => _pickFilter(context, ref, settings.filter),
              ),
          ],
        ),
        if (settings.enabled) ...[
          const SizedBox(height: Sp.section),
          const _DndPermissionCard(),
        ],
      ],
    );
  }

  Future<void> _pickFilter(
    BuildContext context,
    WidgetRef ref,
    DndFilter current,
  ) async {
    final l10n = context.l10n;
    final picked = await showChoiceSheet<DndFilter>(
      context: context,
      title: l10n.dndFilterSheetTitle,
      selected: current,
      options: [
        for (final filter in dndFilterChoicesFor(current))
          ChoiceOption(filter, dndFilterLabel(l10n, filter)),
      ],
    );
    if (picked == null || !context.mounted) return;
    await saveSetting(
      context,
      () => ref.read(dndSettingsProvider.notifier).setFilter(picked),
    );
  }
}

/// The filters the user can pick, in order. [DndFilter.all] is only offered
/// when it is the stored one (a copy may bring it): with it the phone is not
/// silenced at all, so it is not a choice to make on purpose.
List<DndFilter> dndFilterChoicesFor(DndFilter current) => [
  if (current == DndFilter.all) DndFilter.all,
  DndFilter.priority,
  DndFilter.alarms,
  DndFilter.none,
];

/// The name of an interruption filter, as the picker and the row show it.
String dndFilterLabel(AppLocalizations l10n, DndFilter filter) =>
    switch (filter) {
      DndFilter.all => l10n.dndFilterAll,
      DndFilter.priority => l10n.dndFilterPriority,
      DndFilter.alarms => l10n.dndFilterAlarms,
      DndFilter.none => l10n.dndFilterNone,
    };

/// What the OS allows: the green "all set" card, or the explanation of the
/// «Acceso a No molestar» with the button that opens the system screen. The
/// state is re-read when the user comes back (the Alarmas screen invalidates
/// [dndPermissionProvider] on resume).
class _DndPermissionCard extends ConsumerWidget {
  const _DndPermissionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = context.colors;
    final permission = ref.watch(dndPermissionProvider).value;
    if (permission == null || permission == DndPermission.unsupported) {
      return const SizedBox.shrink();
    }
    if (permission == DndPermission.granted) {
      // A row of the settings family, not a callout: the title reads at the
      // row's own size (never louder than the section headings) and the disc
      // sits centred with the two lines of text (H-T13-2). The state is read
      // out as one label.
      return Semantics(
        key: const ValueKey('dnd-permission-ok'),
        container: true,
        excludeSemantics: true,
        label: '${l10n.dndPermOkTitle}. ${l10n.dndPermOkBody}',
        child: AppCard(
          padding: EdgeInsets.zero,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: SettingsRow.minHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Sp.l,
                vertical: Sp.m,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: Disc.m,
                    height: Disc.m,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.successContainer,
                      borderRadius: Rad.squareRadius(Disc.m),
                    ),
                    child: Icon(
                      AppIcons.check,
                      size: IconSize.button,
                      fill: 1,
                      color: colors.success,
                    ),
                  ),
                  const SizedBox(width: Sp.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.dndPermOkTitle,
                          style: SettingsRow.titleStyle(context),
                        ),
                        Text(
                          l10n.dndPermOkBody,
                          style: SettingsRow.subtitleStyle(context),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return AppCallout(
      key: const ValueKey('dnd-permission-denied'),
      icon: AppIcons.silence,
      tone: TonePair(colors.dangerContainer, colors.danger),
      title: l10n.dndPermTitle,
      message: l10n.dndPermBody,
      primaryKey: const ValueKey('dnd-permission-open'),
      primaryLabel: l10n.dndPermOpen,
      onPrimary: () async {
        await ref.read(dndChannelProvider).openPermissionSettings();
        ref.invalidate(dndPermissionProvider);
      },
    );
  }
}
