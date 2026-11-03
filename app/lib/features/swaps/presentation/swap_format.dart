import '../../../core/l10n/l10n.dart';
import '../domain/shift_swap.dart';
import '../domain/swap_ledger.dart';

/// «Me debe 2 turnos» / «Le debo 1 turno» / «Nada pendiente»: what one
/// colleague owes (or is owed) right now.
String swapBalanceText(AppLocalizations l10n, SwapBalance balance) {
  if (balance.theyOweMe > 0) {
    return l10n.swapBalanceTheyOwe(balance.theyOweMe);
  }
  if (balance.iOweThem > 0) return l10n.swapBalanceIOwe(balance.iOweThem);
  return l10n.swapBalanceEven;
}

/// The state of a change: pending (nobody paid it back yet), returned (the
/// favour came back but the item is still open) or settled (closed).
String swapStageText(AppLocalizations l10n, SwapStage stage) => switch (stage) {
  SwapStage.pending => l10n.swapStagePending,
  SwapStage.returned => l10n.swapStageReturned,
  SwapStage.settled => l10n.swapStageSettled,
};

/// «Me lo deben» / «Se lo debo»: who owes the shift.
String swapDirectionText(AppLocalizations l10n, SwapDirection direction) =>
    switch (direction) {
      SwapDirection.theyOwe => l10n.swapDirectionTheyOwe,
      SwapDirection.iOwe => l10n.swapDirectionIOwe,
    };
