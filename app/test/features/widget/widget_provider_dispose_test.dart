import 'dart:async';

import 'package:cuadrante/core/diagnostics/crash_reporting.dart';
import 'package:cuadrante/core/providers.dart';
import 'package:cuadrante/features/calendars/application/calendars_providers.dart';
import 'package:cuadrante/features/calendars/data/calendars_repository.dart';
import 'package:cuadrante/features/widget/application/widget_providers.dart';
import 'package:cuadrante/features/widget/data/widget_publisher.dart';
import 'package:cuadrante/features/widget/domain/widget_strings.dart';
import 'package:cuadrante/features/widget/domain/widget_sync_planner.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/test_storage.dart';

class _DelayedPrimary extends CalendarsRepository {
  _DelayedPrimary(super.database, this.started, this.result);

  final Completer<void> started;
  final Completer<String> result;

  @override
  Future<String> primaryId() {
    started.complete();
    return result.future;
  }
}

class _Reporter extends NoopCrashReporter {
  final errors = <Object>[];

  @override
  Future<void> record(
    Object error,
    StackTrace? stack, {
    required bool fatal,
  }) async {
    errors.add(error);
  }
}

void main() {
  // Q26: leaving the app can dispose the provider while either platform or
  // database work is in flight. Test both a late value and a late failure.
  for (final stage in ['primary calendar', 'time zone']) {
    for (final fails in [false, true]) {
      test(
        'dispose during $stage, then ${fails ? 'fail' : 'complete'}',
        () async {
          final storage = await TestStorage.open(now: harnessNow);
          addTearDown(storage.close);
          final started = Completer<void>();
          final result = Completer<String>();
          final reporter = _Reporter();
          final publisher = FakeWidgetPublisher();
          final container = ProviderContainer(
            overrides: [
              ...storage.overrides,
              clockProvider.overrideWithValue(() => harnessNow),
              crashReporterProvider.overrideWithValue(reporter),
              widgetPublisherProvider.overrideWithValue(publisher),
              if (stage == 'primary calendar')
                calendarsRepositoryProvider.overrideWithValue(
                  _DelayedPrimary(storage.database, started, result),
                ),
              widgetTimeZoneProvider.overrideWithValue(() {
                started.complete();
                return result.future;
              }),
            ],
          );
          var disposed = false;
          addTearDown(() {
            if (!disposed) container.dispose();
          });
          final service = container.read(widgetSyncProvider)
            ..strings = WidgetStrings.es;
          final run = service.request(WidgetSyncTrigger.appStart);
          await started.future;
          container.dispose();
          disposed = true;
          if (fails) {
            result.completeError(StateError('late failure'));
          } else {
            result.complete(
              stage == 'primary calendar' ? 'main' : 'Europe/Madrid',
            );
          }
          await expectLater(run, completes);
          await service.flush();
          expect(service.runs, 0);
          expect(publisher.published, isEmpty);
          expect(publisher.reloadCount, 0);
          expect(reporter.errors, isEmpty);
        },
      );
    }
  }
}
