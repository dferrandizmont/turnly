import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/router.dart';
import '../../../alarms/presentation/alarms_settings_row.dart';
import '../../../import/presentation/import_icons.dart';
import '../../../share_link/presentation/share_link_settings_row.dart';
import '../../../widget/presentation/add_widget_row.dart';
import '../settings_widgets.dart';

/// «Avisos y widget» (design 6A): the shift alarms (until when they are
/// scheduled), the home-screen widget, the copy of the shifts to the
/// calendar of the phone and sharing them by link.
class AlertsSection extends StatelessWidget {
  const AlertsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SettingsSection(
      title: l10n.settingsSectionMore,
      children: [
        const AlarmsSettingsRow(),
        const AddWidgetSettingsRow(),
        SettingsRow(
          key: const ValueKey('settings-export-calendar'),
          icon: ImportIcons.exportData,
          title: l10n.calExportRowTitle,
          subtitle: l10n.calExportRowSubtitle,
          onTap: () => context.push(AppRoutes.settingsExport),
        ),
        const ShareLinkSettingsRow(),
      ],
    );
  }
}
