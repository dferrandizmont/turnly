import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/app_date_format.dart';
import '../../../core/icons/settings_icons.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/router.dart';
import '../../settings/presentation/settings_widgets.dart';
import '../../calendar/application/schedule_controller.dart';
import '../application/alarm_providers.dart';
import '../domain/alarm_planner.dart';

/// The "Alarmas" row of the main Settings screen: Activadas / Desactivadas
/// and, while shift alarms are handed to the phone, until when («Avisos
/// hasta el mar 17 nov», design 6A); opens `/ajustes/alarmas`.
class AlarmsSettingsRow extends ConsumerWidget {
  const AlarmsSettingsRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(alarmSettingsProvider).value;
    final palette = ref.watch(
      scheduleControllerProvider.select((s) => s.palette),
    );
    final on = settings != null && alarmsCanRing(settings, palette);
    final until = on ? ref.watch(alarmsScheduledUntilProvider) : null;
    return SettingsRow(
      key: const ValueKey('settings-alarms'),
      icon: SettingsIcons.alarms,
      title: l10n.settingsAlarmsTitle,
      subtitle: until == null
          ? null
          : l10n.settingsAlarmsUntil(
              AppDateFormat.of(context).shortDate(until.toLocal()),
            ),
      value: settings == null
          ? null
          : (on ? l10n.alarmsRowOn : l10n.alarmsRowOff),
      onTap: () => context.push(AppRoutes.settingsAlarms),
    );
  }
}
