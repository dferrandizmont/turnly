/// The money of a period: what it is worth before and after the withholding
/// (P9, fila 25 de `docs/paridad-pago.md`).
///
/// The withholding is a percentage the user sets (0 to 100): the app does not
/// know the payroll of anybody, so the net is an estimate of the estimate.
/// Everything is in the minor unit of the currency of the preferences (cents
/// with 2 decimals, whole units with 0).
library;

/// The money left of [grossCents] after withholding [withholdingPercent] per
/// cent (0 to 100). Rounded to the cent, half away from zero.
///
/// A gross of 0 stays 0; a withholding of 100 leaves nothing; a percentage
/// outside 0-100 is cut to it (the preferences never store one, but a
/// hand-edited file could).
int netCentsFrom(int grossCents, int withholdingPercent) {
  final percent = withholdingPercent < 0
      ? 0
      : (withholdingPercent > 100 ? 100 : withholdingPercent);
  if (percent == 0) return grossCents;
  final keep = 100 - percent;
  if (keep <= 0) return 0;
  final product = grossCents * keep;
  // Half away from zero (Dart's `~/` cuts towards zero).
  return (product + (product >= 0 ? 50 : -50)) ~/ 100;
}

/// What a period is worth: the gross and the net.
///
/// The gross is `null` when there is nothing to show (no rate, no plus and no
/// extra amount in the period); the net is `null` with it.
class EarningsEstimate {
  const EarningsEstimate({
    required this.grossCents,
    this.withholdingPercent = 0,
  });

  /// The estimate before the withholding; `null` when there is none.
  final int? grossCents;

  /// The percentage of the withholding (0 = none).
  final int withholdingPercent;

  /// The estimate after the withholding; `null` without a gross.
  int? get netCents =>
      grossCents == null ? null : netCentsFrom(grossCents!, withholdingPercent);

  /// Whether there is something to show.
  bool get hasMoney => grossCents != null;

  /// The same estimate with another withholding.
  EarningsEstimate withWithholding(int percent) =>
      EarningsEstimate(grossCents: grossCents, withholdingPercent: percent);

  @override
  bool operator ==(Object other) =>
      other is EarningsEstimate &&
      other.grossCents == grossCents &&
      other.withholdingPercent == withholdingPercent;

  @override
  int get hashCode => Object.hash(grossCents, withholdingPercent);

  @override
  String toString() =>
      'EarningsEstimate(${grossCents ?? '-'} gross, $withholdingPercent %)';
}

/// The estimate of [grossCents] with a withholding of [withholdingPercent].
EarningsEstimate earningsEstimate(
  int? grossCents, {
  int withholdingPercent = 0,
}) => EarningsEstimate(
  grossCents: grossCents,
  withholdingPercent: withholdingPercent,
);
