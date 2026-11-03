import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../alarms/domain/wall_clock.dart' show resolveWallClock;
import '../../schedule/domain/schedule_domain.dart';
import 'ics_writer.dart';

/// Most days one `.ics` document covers: the subscription feed spans about
/// fourteen months (`shareFeedWindow`), the file export up to a year.
const int maxIcsDays = 450;

/// What happens to the absences (vacations, personal days, sick leave...)
/// in an `.ics`.
enum IcsAbsences {
  /// Left out. The default everywhere.
  hidden,

  /// One all-day event per day called [anonymousAbsenceLabel] («Ausencia»),
  /// with no name, code, type or reason: a sick leave and a vacation look
  /// the same. What the shared feed uses when the person asks for absences.
  anonymous,

  /// Like any other shift, with its name and code. Only for the file the
  /// person exports for themselves, when they ask for it.
  full,
}

/// The `.ics` events of [schedule] from [from] to [to] (both included).
///
/// - Work shifts with hours are timed events; a night shift ends on the next
///   day and a split shift (A12) gives one event per segment. The wall-clock
///   times are read in [location] (`resolveWallClock`: a time skipped in
///   March moves forward, a time repeated in October takes its first
///   occurrence) and written as UTC instants.
/// - Shifts without hours are all-day events.
/// - Rest («Libre», «Saliente») only with [includeRest].
/// - Absences follow [absences]; with [IcsAbsences.anonymous] a day with any
///   absence gives a single all-day event named [anonymousAbsenceLabel].
/// - **Notes never go out**, nor overtime, early leave or reminders.
///
/// The UID of each event is stable (calendar, day, position in the day,
/// segment and shift type, hashed), so a subscriber that refreshes, or a
/// calendar that imports the same file twice, keeps one copy of each shift.
/// The range is cut to [maxIcsDays].
List<IcsEvent> buildIcsEvents(
  Schedule schedule, {
  required String calendarId,
  required CivilDate from,
  required CivilDate to,
  required tz.Location location,
  bool includeRest = false,
  IcsAbsences absences = IcsAbsences.hidden,
  String anonymousAbsenceLabel = 'Ausencia',
}) {
  final out = <IcsEvent>[];
  if (to.isBefore(from)) return out;
  final last = to.differenceInDays(from) + 1 > maxIcsDays
      ? from.addDays(maxIcsDays - 1)
      : to;
  final calendarHash = _hash('calendar', calendarId);
  for (final day in schedule.resolveRange(from, last)) {
    final d = day.date;
    var anonymousDone = false;
    // Position among the shifts that are written, not among all the shifts
    // of the day: a hidden absence or rest day must not leave a gap in the
    // UIDs that tells there is something hidden.
    var index = 0;
    for (final shift in day.shifts) {
      if (shift.category == ShiftCategory.rest && !includeRest) continue;
      if (shift.category == ShiftCategory.absence) {
        switch (absences) {
          case IcsAbsences.hidden:
            continue;
          case IcsAbsences.anonymous:
            if (anonymousDone) continue;
            anonymousDone = true;
            out.add(
              IcsEvent.allDay(
                // Nothing of the type in the UID either: a template key such
                // as `vacation` would tell what the absence is.
                uid: '${IcsWriter.formatDate(d)}-absence-$calendarHash@turnly',
                summary: anonymousAbsenceLabel,
                date: d,
              ),
            );
            continue;
          case IcsAbsences.full:
            break;
        }
      }
      final position = index++;
      final typeHash = _hash('type', '$calendarId\u0000${shift.id}');
      String uid(int segment) =>
          '${IcsWriter.formatDate(d)}-$position-$segment-$typeHash@turnly';
      final summary = '${shift.name} · ${shift.code}';
      if (shift.hasTimes) {
        for (final o in ShiftOccurrence.allOf(d, shift)) {
          final start = resolveWallClock(
            location,
            d.year,
            d.month,
            d.day,
            o.startMinuteAbs,
          );
          var end = resolveWallClock(
            location,
            d.year,
            d.month,
            d.day,
            o.endMinuteAbs,
          );
          // Both ends in the hour skipped in March can only move forward;
          // never write an event that ends before it starts.
          if (end.isBefore(start)) end = start;
          out.add(
            IcsEvent.timed(
              uid: uid(o.segment),
              summary: summary,
              start: start,
              end: end,
              transparent: shift.category != ShiftCategory.work,
            ),
          );
        }
      } else {
        out.add(
          IcsEvent.allDay(
            uid: uid(0),
            summary: summary,
            date: d,
            transparent: shift.category != ShiftCategory.work,
          ),
        );
      }
    }
  }
  return out;
}

/// 16 hex digits of SHA-256 over a labelled value: enough to keep UIDs apart
/// without writing the ids themselves.
String _hash(String label, String value) => sha256
    .convert(utf8.encode('turnly-ics/$label:$value'))
    .toString()
    .substring(0, 16);
