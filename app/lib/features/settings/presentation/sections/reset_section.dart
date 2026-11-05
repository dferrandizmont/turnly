import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/icons/app_icons.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/router.dart';
import '../settings_widgets.dart';

class ResetSection extends StatelessWidget {
  const ResetSection({super.key});

  @override
  Widget build(BuildContext context) => SettingsSection(
    children: [
      SettingsRow(
        key: const ValueKey('settings-reset'),
        icon: AppIcons.erase,
        title: context.l10n.resetTitle,
        destructive: true,
        onTap: () => context.push(AppRoutes.settingsReset),
      ),
    ],
  );
}
