import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../absences/presentation/absence_icons.dart';
import '../../application/preferences_controller.dart';
import '../settings_widgets.dart';
import '../withholding_sheet.dart';

/// «Horas y dinero» (P9): what the summary needs to turn the hours into an
/// estimate of the pay. For now the withholding for the net estimate; the
/// rate and the pluses of each shift are in «Mis turnos», the currency in
/// «Apariencia».
class MoneySection extends ConsumerWidget {
  const MoneySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final percent = ref.watch(
      preferencesProvider.select((p) => p.withholdingPercent),
    );
    return SettingsSection(
      title: l10n.moneySectionTitle,
      children: [
        SettingsRow(
          key: const ValueKey('settings-withholding'),
          icon: AbsenceIcons.money,
          title: l10n.moneyWithholdingTitle,
          subtitle: l10n.moneyWithholdingSubtitle,
          value: percent == 0
              ? l10n.moneyWithholdingNone
              : l10n.moneyWithholdingValue(percent),
          onTap: () => editWithholding(context, ref),
        ),
      ],
    );
  }
}
