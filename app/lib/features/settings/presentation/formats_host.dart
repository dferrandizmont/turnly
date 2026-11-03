import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/app_formats.dart';
import '../../../core/format/region_defaults.dart';
import '../application/preferences_controller.dart';

/// The phone's preferred languages, read fresh on every build (the app is
/// rebuilt when the phone's languages change). Tests override it.
final phoneLocalesProvider = Provider<List<Locale> Function()>(
  (ref) =>
      () => WidgetsBinding.instance.platformDispatcher.locales,
);

/// Resolves the formats of the person (language of the app plus region of
/// the phone, 24 h or 12 h clock, currency) and offers them to the whole app
/// as [AppFormats]. Mounted once in `MaterialApp.builder`, below the
/// localizations, above everything that formats a date, a time or an amount.
class FormatsHost extends ConsumerWidget {
  const FormatsHost({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeFormat = ref.watch(
      preferencesProvider.select((p) => p.timeFormat),
    );
    final currency = ref.watch(preferencesProvider.select((p) => p.currency));
    final language = Localizations.localeOf(context).languageCode;
    final localeName = formatLocaleName(
      language,
      ref.read(phoneLocalesProvider)(),
    );
    final hour12 = timeFormat.resolve(
      phoneUses24Hour: MediaQuery.alwaysUse24HourFormatOf(context),
      localeUses12Hour: localeUses12HourClock(localeName),
    );
    return AppFormats(
      localeName: localeName,
      hour12: hour12,
      currency: currency,
      child: child,
    );
  }
}
