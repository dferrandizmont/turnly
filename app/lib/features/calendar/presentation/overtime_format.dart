import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../../core/format/app_date_format.dart';
import '../../../core/format/app_formats.dart';
import '../../../core/format/money.dart';
import '../../../core/l10n/l10n.dart';
import '../../schedule/domain/schedule_domain.dart';
import '../../summary/presentation/summary_format.dart';

/// The name of an overtime type: the user's, or for a built-in type that was
/// never renamed, the app's in the current language.
String overtimeTypeName(AppLocalizations l10n, OvertimeType type) =>
    type.name ??
    switch (type.id) {
      otherWorkTypeId => l10n.overtimeTypeOtherWork,
      _ => l10n.overtimeTypeOvertime,
    };

String _localeOf(BuildContext context) =>
    AppFormats.maybeOf(context)?.localeName ??
    Localizations.localeOf(context).toString();

/// A multiplier in basis points as the reader writes it: 12500 -> «1,25»,
/// 15000 -> «1,5», 20000 -> «2».
String formatMultiplier(BuildContext context, int basisPoints) =>
    NumberFormat('0.####', _localeOf(context)).format(basisPoints / 10000);

/// Reads a multiplier typed by the user («1,25», «1.5», «2») into basis
/// points; `null` when it is not a number between 0,01 and 100 with at most
/// four decimals (what «Escribe un multiplicador entre 0,01 y 100» says).
int? parseMultiplier(String text) {
  final match = RegExp(r'^(\d{1,3})(?:[.,](\d{1,4}))?$')
      .firstMatch(text.trim());
  if (match == null) return null;
  final whole = int.parse(match.group(1)!);
  final fraction = (match.group(2) ?? '').padRight(4, '0');
  final value = whole * multiplierOne + int.parse(fraction);
  return value < minTypedMultiplierBasisPoints ||
          value > maxMultiplierBasisPoints
      ? null
      : value;
}

/// «Escribe un precio por hora entre 0 y 9.999,99 €»: what the rate fields
/// say when the text is empty, not an amount or above the highest rate.
String rateRangeMessage(BuildContext context) => context.l10n
    .overtimeRateOutOfRange(formatMoneyCents(context, maxHourlyRateCents));

/// «El máximo es 9.999,99 €»: what the rate fields say when the number pad
/// has no more room (the extra digits are refused, never cut).
String rateAtMaxMessage(BuildContext context) => context.l10n.overtimeRateAtMax(
  formatMoneyCents(context, maxHourlyRateCents),
);

/// The smallest multiplier the form takes: x0,01.
const int minTypedMultiplierBasisPoints = 100;

/// How [type] is paid, in a few words: «Como el turno», «Turno ×1,25»,
/// «18,00 € la hora», «Sin precio».
String overtimeRateSummary(BuildContext context, OvertimeType type) {
  final l10n = context.l10n;
  return switch (type.rateMode) {
    OvertimeRateMode.shift => l10n.overtimeRateShift,
    OvertimeRateMode.multiplier => l10n.overtimeRateMultiplierSummary(
      formatMultiplier(context, type.multiplierBasisPoints),
    ),
    OvertimeRateMode.fixed => l10n.overtimeRateFixedSummary(
      formatMoneyCents(context, type.hourlyRateCents ?? 0),
    ),
    OvertimeRateMode.none => l10n.overtimeRateNone,
  };
}

/// A clock minute (0-1439) in the person's time format.
String overtimeClock(BuildContext context, int minute) =>
    AppDateFormat.of(context)
        .time(DateTime(2000, 1, 1, minute ~/ 60, minute % 60));

/// «18:00–20:00» (the end the next day when the block crosses midnight).
String overtimeRange(BuildContext context, OvertimeBlock block) =>
    '${overtimeClock(context, block.startMinute)}–'
    '${overtimeClock(context, block.endMinute)}';

/// «2 h × 18,75 € = 37,50 €», or «2 h, sin precio» when [rateUnits] is null.
/// The rate is rounded to the minor unit for showing; the amount is the
/// exact one (`overtimeCentsFor`).
String overtimePreviewText(
  BuildContext context, {
  required int paidMinutes,
  required int? rateUnits,
}) {
  final l10n = context.l10n;
  final duration = formatHours(l10n, paidMinutes);
  if (rateUnits == null) return l10n.overtimePreviewUnpriced(duration);
  return l10n.overtimePreviewPriced(
    duration,
    formatMoneyCents(
      context,
      (rateUnits + multiplierOne ~/ 2) ~/ multiplierOne,
    ),
    formatMoneyCents(context, overtimeCentsFor(paidMinutes, rateUnits)),
  );
}

/// The sum of the day's extra hours for the day cell, as short as it reads:
/// «+2 h», and with minutes «+3:45» (3 h 45 min). A tenth of an hour
/// («+3.8 h») was wrong for 45 min and a character longer, so the mark had to
/// be drawn at about 7 pt (1.1.0 QA, F12).
String overtimeCellText(BuildContext context, int minutes) {
  final l10n = context.l10n;
  final hours = '${minutes ~/ 60}';
  if (minutes % 60 == 0) return l10n.dayCellOvertime(hours);
  return l10n.dayCellOvertimeClock(
    '$hours:${(minutes % 60).toString().padLeft(2, '0')}',
  );
}
