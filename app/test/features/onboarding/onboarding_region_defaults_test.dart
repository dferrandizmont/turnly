import 'package:cuadrante/core/bootstrap/bootstrap.dart';
import 'package:cuadrante/core/database/database_provider.dart';
import 'package:cuadrante/core/diagnostics/crash_reporting.dart';
import 'package:cuadrante/core/providers.dart';
import 'package:cuadrante/features/onboarding/application/onboarding_controller.dart';
import 'package:cuadrante/features/settings/application/preferences_controller.dart';
import 'package:cuadrante/features/settings/data/preferences_repository.dart';
import 'package:cuadrante/features/settings/domain/preferences.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/probes.dart';
import 'onboarding_support.dart';

/// A repository whose format write always fails (a read-only database, a full
/// disk): the country choice must not fail silently.
class _FailingPreferencesRepository extends PreferencesRepository {
  _FailingPreferencesRepository(super.db);

  @override
  Future<Preferences> applyRegionDefaults(String? region) =>
      Future<Preferences>.error(StateError('disk full'));
}

void main() {
  setUpAll(initializeLocale);

  testWidgets('a country whose formats cannot be written is reported', (
    tester,
  ) async {
    final reporter = RecordingCrashReporter();
    final app = await FirstLaunch.open(
      tester,
      overrides: [
        crashReporterProvider.overrideWithValue(reporter),
        preferencesRepositoryProvider.overrideWith(
          (ref) => _FailingPreferencesRepository(ref.watch(appDatabaseProvider)),
        ),
      ],
    );
    // The last step proposes a country; picking another one applies its
    // formats, and that write fails.
    await app.choosePath('paint');
    app.container.read(onboardingControllerProvider.notifier).selectCountry('US');
    await tester.pumpAndSettle();

    expect(reporter.errors, isNotEmpty);
    expect(reporter.errors.every((e) => e is RedactedError), isTrue);
  });
}
