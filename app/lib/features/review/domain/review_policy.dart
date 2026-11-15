import '../../schedule/domain/civil_date.dart';

/// What the app remembers to decide whether to ask for a store review. Only
/// counters and civil dates: nothing about the person's shifts or data.
class ReviewState {
  const ReviewState({
    this.firstLaunch,
    this.lastOpenDay,
    this.openDays = 0,
    this.requestCount = 0,
    this.lastRequestDay,
    this.lastRequestVersion,
  });

  static const ReviewState empty = ReviewState();

  /// The first day the app was opened (`null` until it is first recorded).
  final CivilDate? firstLaunch;

  /// The latest day the app was opened, to count each day only once.
  final CivilDate? lastOpenDay;

  /// How many distinct civil days the app has been opened on.
  final int openDays;

  /// How many times the store was asked to show its review sheet.
  final int requestCount;
  final CivilDate? lastRequestDay;
  final String? lastRequestVersion;

  /// Counts [today] as an open day (once per day) and fixes the first launch.
  /// A clock that goes back never counts the same day twice.
  ReviewState withOpenOn(CivilDate today) {
    final last = lastOpenDay;
    final isNewDay = last == null || today.isAfter(last);
    return ReviewState(
      firstLaunch: firstLaunch ?? today,
      lastOpenDay: isNewDay ? today : last,
      openDays: isNewDay ? openDays + 1 : openDays,
      requestCount: requestCount,
      lastRequestDay: lastRequestDay,
      lastRequestVersion: lastRequestVersion,
    );
  }

  ReviewState withRequestOn(CivilDate today, String version) => ReviewState(
    firstLaunch: firstLaunch,
    lastOpenDay: lastOpenDay,
    openDays: openDays,
    requestCount: requestCount + 1,
    lastRequestDay: today,
    lastRequestVersion: version,
  );

  Map<String, Object?> toJson() => {
    'firstLaunch': firstLaunch?.toIso(),
    'lastOpenDay': lastOpenDay?.toIso(),
    'openDays': openDays,
    'requestCount': requestCount,
    'lastRequestDay': lastRequestDay?.toIso(),
    'lastRequestVersion': lastRequestVersion,
  };

  /// A missing or malformed field falls back to "nothing recorded": a bad
  /// value never blocks the app, it only delays the question.
  factory ReviewState.fromJson(Map<String, Object?> json) {
    CivilDate? date(Object? v) {
      if (v is! String) return null;
      try {
        return CivilDate.parse(v);
      } on Object {
        return null;
      }
    }

    int count(Object? v) => v is int && v >= 0 ? v : 0;
    final version = json['lastRequestVersion'];
    return ReviewState(
      firstLaunch: date(json['firstLaunch']),
      lastOpenDay: date(json['lastOpenDay']),
      openDays: count(json['openDays']),
      requestCount: count(json['requestCount']),
      lastRequestDay: date(json['lastRequestDay']),
      lastRequestVersion: version is String ? version : null,
    );
  }
}

/// When Turnly may ask for a store review. Pure: the caller gives the facts.
///
/// The rules (all must hold):
/// - the app was first opened at least [minDaysSinceFirstLaunch] days ago;
/// - it was opened on at least [minOpenDays] distinct days;
/// - the person has at least one shift in the active calendar;
/// - not in the first-use flow and not right after a restore or an import;
/// - fewer than [maxRequests] requests so far, none yet for this app version
///   and at least [minDaysBetweenRequests] days since the last one.
abstract final class ReviewPolicy {
  static const int minDaysSinceFirstLaunch = 7;
  static const int minOpenDays = 5;
  static const int minDaysBetweenRequests = 90;
  static const int maxRequests = 3;

  static bool shouldAsk({
    required ReviewState state,
    required CivilDate today,
    required String appVersion,
    required bool hasShift,
    required bool inFirstRun,
    required bool afterRestoreOrImport,
  }) {
    if (inFirstRun || afterRestoreOrImport || !hasShift) return false;
    final first = state.firstLaunch;
    if (first == null ||
        today.differenceInDays(first) < minDaysSinceFirstLaunch) {
      return false;
    }
    if (state.openDays < minOpenDays) return false;
    if (state.requestCount >= maxRequests) return false;
    if (state.requestCount > 0 && state.lastRequestVersion == appVersion) {
      return false;
    }
    final last = state.lastRequestDay;
    if (last != null && today.differenceInDays(last) < minDaysBetweenRequests) {
      return false;
    }
    return true;
  }
}
