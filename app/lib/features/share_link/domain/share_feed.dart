import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../calendar_export/domain/ics_events.dart';
import '../../calendar_export/domain/ics_writer.dart';
import '../../import/domain/import_models.dart' show addMonths;
import '../../schedule/domain/schedule_domain.dart';

/// How often subscribers are told to look for changes (`REFRESH-INTERVAL`).
/// Google and Apple decide on their own in the end (hours to a day).
const Duration shareFeedRefresh = Duration(hours: 6);

/// Largest feed the app uploads; the worker refuses more (`MAX_BODY_BYTES`,
/// same value). About twice the densest realistic feed: fourteen months of
/// four events a day (morning, a split shift in two, night), measured in
/// `share_feed_test.dart` («a dense year»).
const int maxShareFeedBytes = 640 * 1024;

/// What the person chose to put in the feed. Everything is off by default:
/// only the work shifts go out.
class ShareFeedOptions {
  const ShareFeedOptions({
    this.includeRest = false,
    this.includeAbsences = false,
  });

  /// «Libre» and «Saliente» as all-day events.
  final bool includeRest;

  /// Absences as an all-day «Ausencia», **never** with the name, the code or
  /// the reason (a sick leave looks like a vacation). Off by default.
  final bool includeAbsences;

  @override
  bool operator ==(Object other) =>
      other is ShareFeedOptions &&
      other.includeRest == includeRest &&
      other.includeAbsences == includeAbsences;

  @override
  int get hashCode => Object.hash(includeRest, includeAbsences);
}

/// The days the feed covers on [today]: from the first day of the previous
/// month to the last day of the month twelve months ahead (about fourteen
/// months). It moves once a month, not every day, so an unchanged schedule
/// gives the same feed for weeks and nothing is uploaded.
(CivilDate, CivilDate) shareFeedWindow(CivilDate today) {
  final firstOfMonth = CivilDate(today.year, today.month, 1);
  final from = addMonths(firstOfMonth, -1);
  final to = addMonths(firstOfMonth, 13).addDays(-1);
  return (from, to);
}

/// The `.ics` the worker serves for one calendar.
///
/// What goes out: the name, code and times of the work shifts, the rest
/// days and an anonymous «Ausencia» only when [options] say so, and the
/// calendar's name as the feed's title. What never goes out: notes,
/// absence names or reasons, overtime, reminders, holidays, other
/// calendars. The filter lives in [buildIcsEvents] ([IcsAbsences.anonymous]
/// is the only absence mode used here) and is covered by the tests.
String buildShareFeed({
  required Schedule schedule,
  required String calendarId,
  required String calendarName,
  required CivilDate today,
  required tz.Location location,
  required ShareFeedOptions options,
  required String absenceLabel,
  required DateTime stamp,
}) {
  final (from, to) = shareFeedWindow(today);
  final events = buildIcsEvents(
    schedule,
    calendarId: calendarId,
    from: from,
    to: to,
    location: location,
    includeRest: options.includeRest,
    absences: options.includeAbsences
        ? IcsAbsences.anonymous
        : IcsAbsences.hidden,
    anonymousAbsenceLabel: absenceLabel,
  );
  return const IcsWriter().write(
    events: events,
    stamp: stamp,
    calendarName: calendarName,
    refreshInterval: shareFeedRefresh,
  );
}

/// Fixed `DTSTAMP` used to fingerprint a feed: two feeds with the same
/// events have the same fingerprint whatever the moment they were built.
final DateTime shareFingerprintStamp = DateTime.utc(2000);

/// SHA-256 (hex) of [feed]; build it with [shareFingerprintStamp].
String shareFeedFingerprint(String feed) =>
    sha256.convert(utf8.encode(feed)).toString();
