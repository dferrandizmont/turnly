import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'region_defaults.dart' show defaultCurrency;

/// The formats the person gets in the app, resolved once at the root
/// (`FormatsHost`, above the router) and read by every date, time and money
/// formatter through [AppDateFormat.of] and `formatMoney`:
///
/// - [localeName]: language of the app plus region of the phone ("es_MX",
///   "en_GB"), see `formatLocaleName`;
/// - [hour12]: whether times show as "10:00 PM" (true) or "22:00";
/// - [currency]: ISO 4217 code of the money ("EUR", "USD").
///
/// Without one in the tree (tests, the shared pictures) the formatters use
/// the locale of `Localizations`, a 24 h clock and the euro, which is what
/// the app did before these were preferences.
class AppFormats extends InheritedWidget {
  const AppFormats({
    super.key,
    required this.localeName,
    required this.hour12,
    required this.currency,
    required super.child,
  });

  final String localeName;
  final bool hour12;
  final String currency;

  /// The formats in force, or `null` outside [AppFormats]. Registers the
  /// caller to be rebuilt when they change.
  static AppFormats? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppFormats>();

  @override
  bool updateShouldNotify(AppFormats oldWidget) =>
      localeName != oldWidget.localeName ||
      hour12 != oldWidget.hour12 ||
      currency != oldWidget.currency;
}

/// Whether the clock of [locale] is a 12 h one by default ("h:mm a": en_US,
/// es_MX; not es_ES, en_GB). `false` when `intl` has no data for it.
bool localeUses12HourClock(String locale) {
  try {
    final pattern = DateFormat.jm(locale).pattern ?? '';
    return pattern.contains('a');
  } catch (_) {
    return false;
  }
}

/// The ISO 4217 code in force in [context] ("EUR" outside [AppFormats]).
String currencyOf(BuildContext context) =>
    AppFormats.maybeOf(context)?.currency ?? defaultCurrency;
