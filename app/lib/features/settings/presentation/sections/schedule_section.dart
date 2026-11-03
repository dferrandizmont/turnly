import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/icons/app_icons.dart';
import '../../../../core/icons/selection_icons.dart';
import '../../../../core/icons/settings_icons.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/router.dart';
import '../../../calendar/application/schedule_controller.dart';
import '../../../calendars/application/calendars_controller.dart';
import '../../../absences/presentation/absence_icons.dart';
import '../../../device_events/application/device_events_providers.dart';
import '../../../import/presentation/import_icons.dart';
import '../../../patterns/application/post_night_provider.dart';
import '../../../swaps/presentation/swap_icons.dart';
import '../settings_widgets.dart';

/// «Mi calendario» (design 6A): the shift types (how many at the right),
/// the calendars (the one on screen), the rotations, the automatic saliente
/// and bringing shifts in from elsewhere.
class ScheduleSection extends ConsumerWidget {
  const ScheduleSection({super.key});

  /// The editor of the shift types (`/ajustes/turnos`) is a screen of its
  /// own; the path is pushed as a string so this section does not depend on
  /// how that route is registered.
  static const String shiftsPath = AppRoutes.shiftTypes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final calendars = ref.watch(calendarsControllerProvider).value?.calendars;
    final activeId = ref.watch(
      scheduleControllerProvider.select((s) => s.calendarId),
    );
    final shiftCount = ref.watch(
      scheduleControllerProvider.select((s) => s.palette.length),
    );
    final activeName = calendars
        ?.where((c) => c.id == activeId)
        .map((c) => c.name)
        .firstOrNull;
    // The calendars of the phone whose appointments are shown next to the
    // shifts (P6). Nothing chosen means the feature is off.
    final chosenCalendars =
        ref.watch(deviceEventsSettingsProvider).value?.calendarIds.length ?? 0;

    return SettingsSection(
      title: l10n.settingsSectionSchedule,
      children: [
        SettingsRow(
          key: const ValueKey('settings-shifts'),
          icon: SettingsIcons.shifts,
          title: l10n.settingsShiftsTitle,
          subtitle: l10n.settingsShiftsSubtitle,
          value: shiftCount > 0 ? '$shiftCount' : null,
          onTap: () => context.push(shiftsPath),
        ),
        SettingsRow(
          key: const ValueKey('settings-calendars'),
          icon: AppIcons.calendar,
          title: l10n.settingsCalendarsTitle,
          value: activeName,
          onTap: () => context.push(AppRoutes.settingsCalendars),
        ),
        SettingsRow(
          key: const ValueKey('settings-device-events'),
          icon: AppIcons.deviceEvents,
          title: l10n.devEventsRowTitle,
          subtitle: l10n.devEventsRowSubtitle,
          value: chosenCalendars > 0 ? '$chosenCalendars' : null,
          onTap: () => context.push(AppRoutes.settingsDeviceEvents),
        ),
        SettingsRow(
          key: const ValueKey('settings-runs'),
          icon: SelectionIcons.rotations,
          title: l10n.selectionRunsTitle,
          subtitle: l10n.selectionRunsSubtitle,
          onTap: () => context.push(AppRoutes.settingsRuns),
        ),
        SettingsRow(
          key: const ValueKey('settings-absences'),
          icon: AbsenceIcons.vacation,
          title: l10n.absenceRowTitle,
          subtitle: l10n.absenceRowSubtitle,
          onTap: () => context.push(AppRoutes.settingsAbsences),
        ),
        SettingsRow(
          key: const ValueKey('settings-swaps'),
          icon: SwapIcons.swaps,
          title: l10n.swapRowTitle,
          subtitle: l10n.swapRowSubtitle,
          onTap: () => context.push(AppRoutes.swaps),
        ),
        SettingsSwitchRow(
          key: const ValueKey('settings-post-night'),
          switchKey: const ValueKey('settings-post-night-switch'),
          icon: AppIcons.pattern,
          title: l10n.postNightAutoTitle,
          subtitle: l10n.postNightAutoHelp,
          value: ref.watch(postNightAutoProvider),
          // Same path as every other setting: a write that fails says so.
          onChanged: (value) => saveSetting(
            context,
            () => ref.read(postNightAutoProvider.notifier).set(value),
          ),
        ),
        SettingsRow(
          key: const ValueKey('settings-import'),
          icon: ImportIcons.importData,
          title: l10n.importRowTitle,
          subtitle: l10n.importRowSubtitle,
          onTap: () => context.push(AppRoutes.settingsImport),
        ),
      ],
    );
  }
}
