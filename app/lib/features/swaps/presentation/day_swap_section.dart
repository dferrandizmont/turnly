import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/icons/app_icons.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/buttons.dart';
import '../../schedule/domain/schedule_domain.dart';
import '../../summary/presentation/summary_format.dart';
import '../application/swaps_controller.dart';
import '../domain/shift_swap.dart';
import 'swap_format.dart';
import 'swap_sheet.dart';
import 'swap_stage_badge.dart';

/// The name of the section inside «Más opciones» of the day detail, from the
/// ARB files.
String swapDaySectionName(AppLocalizations l10n) => l10n.swapDaySection;

/// The section of the day detail for [date] (P4): the change of shift of
/// that day, or the button to note one.
Widget swapDaySection(BuildContext context, CivilDate date) =>
    SwapDaySection(date: date);

/// «Cambio de turno» inside «Más opciones» of the day detail: the changes
/// that touch the day (the one of that day and the ones that come back on
/// it) and a button to note a new one.
///
/// The section does not write the calendar: it opens the sheet, which saves
/// the change; applying it to the days is an action of the swap book.
class SwapDaySection extends ConsumerWidget {
  const SwapDaySection({super.key, required this.date});

  final CivilDate date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = context.colors;
    final type = context.type;
    final swaps = ref.watch(swapsOfDayProvider(date));

    return Column(
      key: const ValueKey('day-swap-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: Sp.l),
        Semantics(
          header: true,
          child: Text(
            l10n.swapDaySection.toUpperCase(),
            style: type.label.copyWith(color: colors.textMuted),
          ),
        ),
        const SizedBox(height: Sp.s),
        if (swaps.isEmpty)
          Text(
            l10n.swapDayEmpty,
            key: const ValueKey('day-swap-empty'),
            style: type.body.copyWith(color: colors.textSecondary),
          )
        else
          for (final swap in swaps) _DaySwapRow(swap: swap),
        const SizedBox(height: Sp.s),
        SecondaryButton(
          key: const ValueKey('day-swap-add'),
          icon: AppIcons.add,
          label: l10n.swapDayAdd,
          onPressed: () => showSwapSheet(context, date: date),
        ),
      ],
    );
  }
}

/// One change of the day: with whom, who owes it and its state. It opens
/// the sheet to edit it.
class _DaySwapRow extends StatelessWidget {
  const _DaySwapRow({required this.swap});

  final ShiftSwap swap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final type = context.type;
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.s),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${swap.colleague} · ${swapDirectionText(l10n, swap.direction)}',
                  key: ValueKey('day-swap-who-${swap.id}'),
                  style: type.bodyStrong,
                ),
                if (swap.returnDate != null)
                  Text(
                    formatRangeDate(l10n.localeName, swap.returnDate!),
                    style: type.meta.copyWith(color: colors.textSecondary),
                  ),
              ],
            ),
          ),
          const SizedBox(width: Sp.s),
          SwapStageBadge(stage: swap.stage, swapId: swap.id),
          IconButton(
            key: ValueKey('day-swap-edit-${swap.id}'),
            tooltip: l10n.swapEditTooltip(swap.colleague),
            icon: Icon(AppIcons.edit, size: IconSize.inline),
            onPressed: () => showSwapSheet(context, swap: swap),
          ),
        ],
      ),
    );
  }
}
