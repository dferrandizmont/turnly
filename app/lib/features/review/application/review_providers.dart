import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/providers.dart';
import '../../backup/application/backup_providers.dart'
    show restoreInProgressProvider;
import '../../calendar/application/schedule_controller.dart';
import '../../onboarding/application/onboarding_providers.dart';
import '../../schedule/domain/schedule_domain.dart';
import '../data/review_repository.dart';
import '../domain/review_policy.dart';

/// The App Store id of Turnly, for «Valorar Turnly» in Ajustes.
const String turnlyAppStoreId = '6832554552';

/// The store's review sheet, behind an interface so tests use a fake.
abstract class StoreReviewPlatform {
  Future<bool> isAvailable();
  Future<void> requestReview();
  Future<void> openStoreListing();
}

/// The `in_app_review` plugin: the system sheet on iOS (and Play's flow on
/// Android), or the store page of Turnly.
class PluginStoreReviewPlatform implements StoreReviewPlatform {
  const PluginStoreReviewPlatform();

  @override
  Future<bool> isAvailable() => InAppReview.instance.isAvailable();

  @override
  Future<void> requestReview() => InAppReview.instance.requestReview();

  @override
  Future<void> openStoreListing() =>
      InAppReview.instance.openStoreListing(appStoreId: turnlyAppStoreId);
}

final storeReviewPlatformProvider = Provider<StoreReviewPlatform>(
  (ref) => const PluginStoreReviewPlatform(),
);

final reviewRepositoryProvider = Provider<ReviewRepository>(
  (ref) => ReviewRepository(ref.watch(appDatabaseProvider)),
);

/// Set for the rest of the session once a restore or an import finished: the
/// person is checking their data, so no review is asked for then.
class ReviewQuiet extends Notifier<bool> {
  @override
  bool build() => false;

  // ignore: use_setters_to_change_properties
  void set(bool value) => state = value;
}

final reviewQuietProvider = NotifierProvider<ReviewQuiet, bool>(
  ReviewQuiet.new,
);

/// Records the days the app is opened and, at a success moment, asks the
/// store for a review when [ReviewPolicy] allows it. Nothing here ever shows
/// an error: a failure only means the question is not asked.
class ReviewService {
  ReviewService(this._ref);

  final Ref _ref;

  // Every read-modify-write of the counters runs one after another, so two
  // triggers (or an open and a request) can never work on a stale copy.
  Future<void> _tail = Future<void>.value();

  Future<T> _serial<T>(Future<T> Function() job) {
    final result = _tail.then((_) => job());
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  /// Counts today as a day the app was opened.
  Future<void> recordOpen() async {
    try {
      await _serial(() async {
        final repository = _ref.read(reviewRepositoryProvider);
        final today = CivilDate.fromDateTime(_ref.read(clockProvider)());
        final state = await repository.load();
        await repository.save(state.withOpenOn(today));
      });
    } on Object {
      // The counters are a convenience: a failed write changes nothing.
    }
  }

  /// A success moment (a rotation applied, a paint session that changed days
  /// ended): asks the store for a review if the policy says yes.
  Future<void> maybeAskAfterSuccess() async {
    try {
      final platform = _ref.read(storeReviewPlatformProvider);
      final asks = await _serial(_claimRequest);
      // The sheet itself is asked outside the queue: the request is already
      // written, so a second trigger sees it and an open is not held up.
      if (asks) await platform.requestReview();
    } on Object {
      // Silent by design.
    }
  }

  /// Decides and, if the answer is yes, writes the request. True when the
  /// store should be asked now.
  Future<bool> _claimRequest() async {
    final repository = _ref.read(reviewRepositoryProvider);
    final today = CivilDate.fromDateTime(_ref.read(clockProvider)());
    final version = _ref.read(appConfigProvider).appVersion;
    final state = await repository.load();
    final inFirstRun = !await _ref.read(onboardingRepositoryProvider).isDone();
    bool allowed() =>
        ReviewPolicy.shouldAsk(
          state: state,
          today: today,
          appVersion: version,
          hasShift: _hasShift(_ref.read(scheduleControllerProvider).schedule),
          inFirstRun: inFirstRun,
          afterRestoreOrImport: _ref.read(reviewQuietProvider),
        ) &&
        !_ref.read(restoreInProgressProvider);
    if (!allowed()) return false;
    if (!await _ref.read(storeReviewPlatformProvider).isAvailable()) {
      return false;
    }
    // A restore or an import may have started while the store answered.
    if (!allowed()) return false;
    // Written before asking: the store decides whether the sheet shows, and
    // a crash in between must not make us ask twice.
    await repository.save(state.withRequestOn(today, version));
    return true;
  }

  /// A rotation or a painted day exists in the active calendar.
  static bool _hasShift(Schedule schedule) =>
      schedule.runs.isNotEmpty ||
      schedule.entries.values.any((e) => e.shiftTypeIds?.isNotEmpty ?? false);

  /// «Valorar Turnly»: the store page of the app.
  Future<void> openStoreListing() async {
    try {
      await _ref.read(storeReviewPlatformProvider).openStoreListing();
    } on Object {
      // No store on this device: nothing to show.
    }
  }
}

final reviewServiceProvider = Provider<ReviewService>(ReviewService.new);
