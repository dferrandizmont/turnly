import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/money.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../absences/presentation/absence_icons.dart';
import '../../../calendar/application/schedule_controller.dart';
import '../../../calendar/presentation/overtime_types_sheet.dart';
import '../../../summary/application/summary_providers.dart';
import '../../../summary/domain/overtime_cap.dart';
import '../../../summary/presentation/pay_icons.dart';
import '../../../summary/presentation/pay_rules_sheets.dart';
import '../../../summary/presentation/pay_template_sheet.dart';
import '../../application/preferences_controller.dart';
import '../settings_widgets.dart';
import '../withholding_sheet.dart';

/// «Horas y dinero» (P9): what the summary needs to turn the hours into an
/// estimate of the pay. The withholding for the net estimate, the closing day
/// of the payroll month, the cap of the overtime, the overtime types and the
/// base hourly rate (schema v7) and the templates of pluses by sector
/// (propuestas 2 y 8); the rate and the pluses of each shift are in
/// «Mis turnos», the currency in «Apariencia».
class MoneySection extends ConsumerWidget {
  const MoneySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final percent = ref.watch(
      preferencesProvider.select((p) => p.withholdingPercent),
    );
    final rules = ref.watch(payRulesProvider).value;
    final closingDay = rules?.closingDay;
    final cap = rules?.overtimeCap;
    final baseRate = ref.watch(
      scheduleControllerProvider.select((s) => s.schedule.baseHourlyRateCents),
    );
    final overtimeTypes = ref.watch(
      scheduleControllerProvider.select((s) => s.schedule.overtimeTypes),
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
        SettingsRow(
          key: const ValueKey('settings-closing-day'),
          icon: PayIcons.closingDay,
          title: l10n.closingDayTitle,
          subtitle: l10n.closingDaySubtitle,
          value: closingDay == null
              ? l10n.closingDayNone
              : l10n.closingDayValue(closingDay),
          onTap: () => editClosingDay(context, ref),
        ),
        SettingsRow(
          key: const ValueKey('settings-overtime-cap'),
          icon: PayIcons.overtimeCap,
          title: l10n.overtimeCapTitle,
          subtitle: l10n.overtimeCapSubtitle,
          value: cap == null
              ? l10n.overtimeCapNone
              : cap.period == OvertimeCapPeriod.year
              ? l10n.overtimeCapValueYear(cap.hours)
              : l10n.overtimeCapValueMonth(cap.hours),
          onTap: () => editOvertimeCap(context, ref),
        ),
        // The extra hours (schema v7): their types and the base rate the
        // types «as the shift» use on a day without a priced shift.
        SettingsRow(
          key: const ValueKey('settings-overtime-types'),
          icon: PayIcons.overtimeCap,
          title: l10n.overtimeTypesTitle,
          value: l10n.overtimeTypesCount(
            overtimeTypes.where((t) => !t.archived).length,
          ),
          onTap: () => showOvertimeTypes(context),
        ),
        SettingsRow(
          key: const ValueKey('settings-overtime-base-rate'),
          icon: AbsenceIcons.money,
          title: l10n.overtimeBaseRateTitle,
          subtitle: l10n.overtimeBaseRateHelp,
          value: baseRate == null
              ? l10n.overtimeBaseRateNone
              : formatMoneyCents(context, baseRate),
          onTap: () => editOvertimeBaseRate(context),
        ),
        SettingsRow(
          key: const ValueKey('settings-pay-template'),
          icon: PayIcons.template,
          title: l10n.payTemplateTitle,
          subtitle: l10n.payTemplateSubtitle,
          onTap: () => openPayTemplate(context, ref),
        ),
      ],
    );
  }
}
