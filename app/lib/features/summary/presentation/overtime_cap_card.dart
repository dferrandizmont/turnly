import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/app_callout.dart';
import '../../../core/widgets/app_card.dart';
import '../../absences/presentation/absence_icons.dart';
import '../application/summary_providers.dart';
import '../domain/overtime_cap.dart';
import 'pay_icons.dart';
import 'summary_format.dart';
import 'summary_stat_row.dart';

/// «Tope de horas extra» (propuesta 8): the overtime noted in the period next
/// to the cap the user set, and a warning from 80 % of it on. The warning is
/// never only a colour: it has its icon and says it in words. Nothing shows
/// without a cap.
class OvertimeCapCard extends ConsumerWidget {
  const OvertimeCapCard({super.key, required this.query});

  final OvertimeCapQuery query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(overtimeCapStatusProvider(query));
    if (status == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final colors = context.colors;
    final type = context.type;
    final yearly = status.cap.period == OvertimeCapPeriod.year;
    final used = formatHours(l10n, status.usedMinutes);
    final cap = formatHours(l10n, status.capMinutes);
    final left = formatHours(l10n, status.leftMinutes);
    final excess = formatHours(l10n, status.excessMinutes);

    final Widget? warning = switch (status.level) {
      OvertimeCapLevel.ok => null,
      OvertimeCapLevel.near => AppCallout(
        key: const ValueKey('summary-overtime-cap-near'),
        icon: AbsenceIcons.warning,
        title: l10n.overtimeCapNear(left),
      ),
      OvertimeCapLevel.reached => AppCallout(
        key: const ValueKey('summary-overtime-cap-reached'),
        icon: AbsenceIcons.warning,
        tone: TonePair(colors.dangerContainer, colors.danger),
        title: l10n.overtimeCapReached,
      ),
      OvertimeCapLevel.over => AppCallout(
        key: const ValueKey('summary-overtime-cap-over'),
        icon: AbsenceIcons.warning,
        tone: TonePair(colors.dangerContainer, colors.danger),
        title: l10n.overtimeCapOver(excess),
      ),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.card),
      child: AppCard(
        key: const ValueKey('summary-overtime-cap'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Row(
                children: [
                  Icon(
                    PayIcons.overtimeCap,
                    size: IconSize.inline,
                    color: colors.textMuted,
                  ),
                  const SizedBox(width: Sp.xs),
                  Expanded(
                    child: Text(
                      l10n.overtimeCapTitle.toUpperCase(),
                      style: type.label.copyWith(color: colors.textMuted),
                    ),
                  ),
                ],
              ),
            ),
            SummaryStatRow(
              id: 'summary-overtime-cap-used',
              label: yearly
                  ? l10n.overtimeCapUsedYear
                  : l10n.overtimeCapUsedMonth,
              value: l10n.overtimeCapOf(used, cap),
              detail: status.level == OvertimeCapLevel.ok
                  ? l10n.overtimeCapLeft(left)
                  : null,
            ),
            if (warning != null) ...[const SizedBox(height: Sp.s), warning],
          ],
        ),
      ),
    );
  }
}
