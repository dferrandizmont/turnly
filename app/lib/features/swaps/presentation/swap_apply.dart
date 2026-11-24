import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../calendar/application/schedule_controller.dart';
import '../../schedule/domain/schedule_domain.dart';
import '../../summary/presentation/summary_format.dart';
import '../application/swaps_controller.dart';
import '../domain/shift_swap.dart';
import '../domain/swap_schedule_plan.dart';

/// A notice of the swap screens, with an action («Deshacer», «Aplicar») when
/// there is something to do about it.
void showSwapNotice(
  ScaffoldMessengerState messenger,
  String message, {
  SnackBarAction? action,
}) => messenger
  ..hideCurrentSnackBar()
  ..showSnackBar(
    appSnackBar(
      context: messenger.context,
      content: Text(message),
      action: action,
    ),
  );

void showSwapUndoNotice(
  ScaffoldMessengerState messenger,
  AppLocalizations l10n,
  ScheduleController schedule,
  String message,
  ScheduleChange step,
) => showSwapNotice(
  messenger,
  message,
  action: SnackBarAction(
    label: l10n.undo,
    onPressed: () => schedule.undoIfLast(step),
  ),
);

/// The dates whose shift was kept. With [removalRefused] (a «Quitar y
/// devolver» that one date stopped) it also says that the swap is still in
/// the book and that none of its dates were touched.
void showSkippedSwapDays(
  ScaffoldMessengerState messenger,
  AppLocalizations l10n,
  ScheduleController schedule,
  List<CivilDate> days, {
  ScheduleChange? step,
  bool removalRefused = false,
}) {
  final message = [
    for (final day in days)
      l10n.swapRestoreSkipped(formatRangeDate(l10n.localeName, day)),
    if (removalRefused) l10n.swapRemoveKept,
  ].join('\n');
  if (step == null) {
    showSwapNotice(messenger, message);
  } else {
    showSwapUndoNotice(messenger, l10n, schedule, message, step);
  }
}

/// Applies the swap from the card or the save notice. An in-flight tap does
/// not replace the notice or its Undo action.
Future<void> applySwapToCalendar({
  required ScaffoldMessengerState messenger,
  required AppLocalizations l10n,
  required SwapsController controller,
  required ScheduleController schedule,
  required ShiftSwap swap,
}) async {
  if (controller.isBusy(swap.id)) return;
  try {
    final step = await controller.applyToCalendar(swap);
    if (!messenger.mounted) return;
    if (step == null) {
      showSwapNotice(messenger, l10n.swapNothingToApply);
    } else {
      showSwapUndoNotice(messenger, l10n, schedule, l10n.swapApplied, step);
    }
  } on SwapApplyConflict catch (conflict) {
    if (messenger.mounted) {
      showSwapNotice(messenger, swapConflictMessage(l10n, conflict.claim));
    }
  } catch (_) {
    if (messenger.mounted) showSwapNotice(messenger, l10n.swapSaveFailed);
  }
}

/// Why a swap cannot be applied: [claim]'s day already holds another one.
String swapConflictMessage(AppLocalizations l10n, SwapDayClaim claim) =>
    l10n.swapApplyConflict(
      formatRangeDate(l10n.localeName, claim.date),
      claim.colleague,
    );

/// True also restores the calendar. False removes the ledger entry only.
Future<bool?> confirmSwapRemoval(
  BuildContext context,
  ShiftSwap swap, {
  required bool hasRecords,
  required bool confirmUnapplied,
}) async {
  final l10n = context.l10n;
  final date = formatRangeDate(l10n.localeName, swap.date);
  if (hasRecords) {
    return showConfirmDialogWithAlternative(
      context,
      title: l10n.swapRemoveTitle,
      body: l10n.swapRemoveAppliedBody,
      confirmLabel: l10n.swapRemoveAndRestore,
      alternativeLabel: l10n.swapRemoveOnly,
      destructive: true,
    );
  }
  if (!confirmUnapplied) return false;
  return await showConfirmDialog(
        context,
        title: l10n.swapRemoveTitle,
        body: l10n.swapRemoveBody(swap.colleague, date),
        confirmLabel: l10n.swapRemoveConfirm,
        destructive: true,
        scrollable: true,
        confirmKey: const ValueKey('swap-remove-confirm'),
      )
      ? false
      : null;
}
