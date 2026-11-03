import 'dart:async';

import 'package:flutter/widgets.dart' show WidgetsBinding;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/providers.dart';
import '../../holidays/application/holidays_provider.dart';
import '../../holidays/data/holiday_bundle_format.dart';
import '../../holidays/domain/holiday_place.dart';
import '../../holidays/domain/spanish_regions.dart';
import '../../schedule/domain/civil_date.dart';
import '../data/onboarding_repository.dart';

final onboardingRepositoryProvider = Provider<OnboardingRepository>(
  (ref) => OnboardingRepository(ref.watch(appDatabaseProvider)),
);

/// What `bootstrapApp` decided before the first frame (`main` overrides it).
/// Left `null` (tests, the QA harness) the first-use flow is not shown.
final initialOnboardingProvider = Provider<OnboardingStatus?>((ref) => null);

/// The municipalities of the bundle, for the picker of step 2. `null` when
/// the bundle has no index (the step then offers the community only).
final municipalityIndexProvider = FutureProvider<MunicipalityIndex?>(
  (ref) => ref.watch(holidayBundleLoaderProvider).loadMunicipalities(),
);

/// The phone's region (the country of its first preferred locale that has
/// one; `PlatformDispatcher.locale` is the first of them on a phone), from
/// which a fresh install proposes the country of its holidays. `null` when
/// the phone says nothing.
final systemCountryCodeProvider = Provider<String?>((ref) {
  try {
    final dispatcher = WidgetsBinding.instance.platformDispatcher;
    for (final locale in [...dispatcher.locales, dispatcher.locale]) {
      final code = locale.countryCode;
      if (code != null && code.isNotEmpty) return code;
    }
  } catch (_) {
    // No binding (plain unit tests): nothing to propose from.
  }
  return null;
});

/// The years whose local holidays matter in the first-use flow: this year,
/// and the next one too in November and December (when the person will soon
/// need them), the same years Ajustes › Festivos looks at.
List<int> localHolidayYears(CivilDate today) => [
  today.year,
  if (today.month >= 11) today.year + 1,
];

/// The years of [localHolidayYears] for which the bundle has no local
/// holidays of the municipality [code] (INE), so step 2 can tell the person
/// when they have to add them themselves. Empty when every year is covered.
///
/// Having some year is not enough: Barcelona has 2026 but not 2027 yet, and
/// in December that is what matters (A5).
final localHolidaysMissingYearsProvider = FutureProvider.autoDispose
    .family<List<int>, String>((ref, code) async {
      final region = regionOfMunicipality(code);
      final today = CivilDate.fromDateTime(ref.watch(clockProvider)());
      final rows = await ref
          .watch(holidayRepositoryProvider)
          .entriesFor(
            HolidayPlace(regionCode: region?.code, municipalityCode: code),
          );
      final covered = {
        for (final e in rows)
          if (isBundledLocalOf(e, code)) e.date.year,
      };
      return [
        for (final year in localHolidayYears(today))
          if (!covered.contains(year)) year,
      ];
    });

/// The tip on the month screen about painting and the pattern button: waiting
/// from the end of the first-use flow until the person closes it. Remembered
/// (`onboarding.tipPending`).
class OnboardingTip extends Notifier<bool> {
  @override
  bool build() {
    final initial = ref.read(initialOnboardingProvider);
    if (initial != null) return initial.tipPending;
    unawaited(_load());
    return false;
  }

  Future<void> _load({bool sync = false}) async {
    try {
      final stored = await ref
          .read(onboardingRepositoryProvider)
          .isTipPending();
      // At start only a stored `true` matters (the initial state is false);
      // a reload follows the stored value both ways.
      if (ref.mounted && (stored || sync)) state = stored;
    } catch (_) {
      // No readable database (previews): no tip.
    }
  }

  /// Reads the stored flag again (a restore replaced the settings table; the
  /// device's own flag is kept by it).
  Future<void> reload() => _load(sync: true);

  /// The flow has just finished: show the tip.
  void show() => state = true;

  /// Closes the tip for good.
  Future<void> dismiss() async {
    state = false;
    try {
      await ref.read(onboardingRepositoryProvider).setTipPending(false);
    } catch (_) {
      // Worst case it comes back once on the next launch.
    }
  }
}

final onboardingTipProvider = NotifierProvider<OnboardingTip, bool>(
  OnboardingTip.new,
);
