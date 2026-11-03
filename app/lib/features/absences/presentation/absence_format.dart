import 'package:intl/intl.dart';

import '../../../core/l10n/l10n.dart';

/// «22 días», «1 día», «0,5 días»: [days] as the balances show them (steps of
/// a quarter of a day, so at most two decimals).
String absenceDaysText(AppLocalizations l10n, double days) =>
    l10n.absenceDays(days);

/// [absenceDaysText] with its sign for an adjustment: «+2 días», «−1 día».
String absenceSignedDaysText(AppLocalizations l10n, double days) {
  if (days == 0) return absenceDaysText(l10n, 0);
  final sign = days < 0 ? '−' : '+';
  return '$sign${absenceDaysText(l10n, days.abs())}';
}

/// The bare number of [days] in the language of the app («12,5»), for the big
/// figure of a card. A negative amount keeps its sign.
String absenceNumberText(AppLocalizations l10n, double days) {
  final text = NumberFormat.decimalPattern(l10n.localeName).format(days.abs());
  return days < 0 ? '−$text' : text;
}

/// Reads the days a person typed: «22», «0,5», «-1» (a comma or a dot; the
/// minus only when [allowNegative]). `null` when it is not a number or it is
/// not a whole number of quarters of a day.
double? parseAbsenceDays(String text, {bool allowNegative = false}) {
  final trimmed = text.trim().replaceAll(',', '.').replaceAll('−', '-');
  if (!RegExp(
    allowNegative ? r'^-?\d{1,4}(\.\d{1,2})?$' : r'^\d{1,4}(\.\d{1,2})?$',
  ).hasMatch(trimmed)) {
    return null;
  }
  final value = double.tryParse(trimmed);
  if (value == null) return null;
  return (value * 4) == (value * 4).roundToDouble() ? value : null;
}

/// A number of days to put back in a text field («12», «0,5», «-1»).
String absenceDaysInput(double days) {
  if (days == days.roundToDouble()) return '${days.round()}';
  return '$days'.replaceAll('.', ',');
}

/// «−2 días» or «3 días»: the days left to plan, which can be negative.
String absenceSignedLeft(AppLocalizations l10n, double days) => days < 0
    ? '−${absenceDaysText(l10n, days.abs())}'
    : absenceDaysText(l10n, days);
