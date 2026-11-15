import 'dart:async';

import 'package:cuadrante/core/config.dart';
import 'package:cuadrante/core/database/app_database.dart';
import 'package:cuadrante/core/database/database_provider.dart';
import 'package:cuadrante/core/providers.dart';
import 'package:cuadrante/features/backup/application/backup_providers.dart'
    show restoreInProgressProvider;
import 'package:cuadrante/features/backup/data/backup_repository.dart';
import 'package:cuadrante/features/calendar/application/schedule_controller.dart';
import 'package:cuadrante/features/onboarding/data/onboarding_repository.dart';
import 'package:cuadrante/features/review/application/review_providers.dart';
import 'package:cuadrante/features/review/data/review_repository.dart';
import 'package:cuadrante/features/review/domain/review_policy.dart';
import 'package:cuadrante/features/schedule/domain/schedule_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_storage.dart';

class _FakePlatform implements StoreReviewPlatform {
  bool available = true;
  bool fails = false;
  int requests = 0;
  int listings = 0;

  /// When set, [isAvailable] waits for it (a store that answers late).
  Completer<void>? gate;

  @override
  Future<bool> isAvailable() async {
    await gate?.future;
    return available;
  }

  @override
  Future<void> requestReview() async {
    requests++;
    if (fails) throw StateError('no store');
  }

  @override
  Future<void> openStoreListing() async {
    listings++;
    if (fails) throw StateError('no store');
  }
}

class _FakeSchedule extends ScheduleController {
  _FakeSchedule(this._schedule);

  final Schedule _schedule;

  @override
  ScheduleState build() => ScheduleState(schedule: _schedule);
}

void main() {
  late AppDatabase db;
  late _FakePlatform platform;
  late DateTime now;

  setUp(() {
    db = openMemoryDatabase();
    platform = _FakePlatform();
    now = DateTime(2026, 10, 1, 12);
  });
  tearDown(() => db.close());

  ProviderContainer containerWith({bool hasShift = true}) {
    final schedule = Schedule(
      entries: hasShift
          ? {
              const CivilDate(2026, 10, 3): DayEntry(
                date: const CivilDate(2026, 10, 3),
                shiftTypeIds: const ['morning'],
              ),
            }
          : const {},
    );
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => now),
        appConfigProvider.overrideWithValue(
          const AppConfig(appVersion: '1.2.0'),
        ),
        storeReviewPlatformProvider.overrideWithValue(platform),
        scheduleControllerProvider.overrideWith(() => _FakeSchedule(schedule)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Opens the app on [days] consecutive days from 1 Oct (some of them twice).
  Future<void> openDays(ProviderContainer c, int days) async {
    final service = c.read(reviewServiceProvider);
    for (var i = 0; i < days; i++) {
      now = DateTime(2026, 10, 1 + i, 9);
      await service.recordOpen();
      await service.recordOpen();
    }
  }

  Future<ReviewState> stored() => ReviewRepository(db).load();

  test('records each open day once and keeps the first launch', () async {
    final c = containerWith();
    await openDays(c, 3);
    final state = await stored();
    expect(state.openDays, 3);
    expect(state.firstLaunch, const CivilDate(2026, 10, 1));
  });

  test('asks once the policy allows it, and writes the request', () async {
    await OnboardingRepository(db).markDone();
    final c = containerWith();
    await openDays(c, 5);
    now = DateTime(2026, 10, 9, 12);
    await c.read(reviewServiceProvider).maybeAskAfterSuccess();
    expect(platform.requests, 1);
    final state = await stored();
    expect(state.requestCount, 1);
    expect(state.lastRequestVersion, '1.2.0');

    // The same version never asks twice.
    await c.read(reviewServiceProvider).maybeAskAfterSuccess();
    expect(platform.requests, 1);
  });

  test('does not ask on the first days', () async {
    await OnboardingRepository(db).markDone();
    final c = containerWith();
    await openDays(c, 5); // 1..5 Oct: only 4 days since the first launch
    await c.read(reviewServiceProvider).maybeAskAfterSuccess();
    expect(platform.requests, 0);
  });

  test('does not ask during the first-use flow', () async {
    final c = containerWith();
    await openDays(c, 5);
    now = DateTime(2026, 10, 9, 12);
    await c.read(reviewServiceProvider).maybeAskAfterSuccess();
    expect(platform.requests, 0);
  });

  test('does not ask without a shift', () async {
    await OnboardingRepository(db).markDone();
    final c = containerWith(hasShift: false);
    await openDays(c, 5);
    now = DateTime(2026, 10, 9, 12);
    await c.read(reviewServiceProvider).maybeAskAfterSuccess();
    expect(platform.requests, 0);
  });

  test('does not ask after a restore or an import', () async {
    await OnboardingRepository(db).markDone();
    final c = containerWith();
    await openDays(c, 5);
    now = DateTime(2026, 10, 9, 12);
    c.read(reviewQuietProvider.notifier).set(true);
    await c.read(reviewServiceProvider).maybeAskAfterSuccess();
    expect(platform.requests, 0);
  });

  test('a store that is not available is not asked, nor counted', () async {
    await OnboardingRepository(db).markDone();
    platform.available = false;
    final c = containerWith();
    await openDays(c, 5);
    now = DateTime(2026, 10, 9, 12);
    await c.read(reviewServiceProvider).maybeAskAfterSuccess();
    expect(platform.requests, 0);
    expect((await stored()).requestCount, 0);
  });

  test('a failing store is swallowed silently', () async {
    await OnboardingRepository(db).markDone();
    platform.fails = true;
    final c = containerWith();
    await openDays(c, 5);
    now = DateTime(2026, 10, 9, 12);
    await c.read(reviewServiceProvider).maybeAskAfterSuccess();
    await c.read(reviewServiceProvider).openStoreListing();
    expect(platform.requests, 1);
    expect(platform.listings, 1);
  });

  Future<ProviderContainer> readyContainer() async {
    await OnboardingRepository(db).markDone();
    final c = containerWith();
    await openDays(c, 5);
    now = DateTime(2026, 10, 9, 12);
    return c;
  }

  test('two simultaneous success moments ask only once', () async {
    final c = await readyContainer();
    final service = c.read(reviewServiceProvider);
    await Future.wait([
      service.maybeAskAfterSuccess(),
      service.maybeAskAfterSuccess(),
    ]);
    expect(platform.requests, 1);
    expect((await stored()).requestCount, 1);
  });

  test('an open recorded meanwhile does not erase the request', () async {
    final c = await readyContainer();
    final service = c.read(reviewServiceProvider);
    platform.gate = Completer<void>();
    final asking = service.maybeAskAfterSuccess();
    final opening = service.recordOpen();
    await Future<void>.delayed(Duration.zero);
    platform.gate!.complete();
    await Future.wait([asking, opening]);
    final state = await stored();
    expect(platform.requests, 1);
    expect(state.requestCount, 1);
    expect(state.lastRequestVersion, '1.2.0');
    expect(state.openDays, 6);
  });

  test(
    'a restore or import that starts while the store answers wins',
    () async {
      final c = await readyContainer();
      platform.gate = Completer<void>();
      final asking = c.read(reviewServiceProvider).maybeAskAfterSuccess();
      await Future<void>.delayed(Duration.zero);
      c.read(reviewQuietProvider.notifier).set(true);
      platform.gate!.complete();
      await asking;
      expect(platform.requests, 0);
      expect((await stored()).requestCount, 0);
    },
  );

  test('a restore in progress while the store answers wins', () async {
    final c = await readyContainer();
    platform.gate = Completer<void>();
    final asking = c.read(reviewServiceProvider).maybeAskAfterSuccess();
    await Future<void>.delayed(Duration.zero);
    c.read(restoreInProgressProvider.notifier).set(true);
    platform.gate!.complete();
    await asking;
    expect(platform.requests, 0);
  });

  test('the counters are a device setting: a backup never carries them', () {
    expect(isDeviceSetting(reviewStateKey), isTrue);
  });
}
