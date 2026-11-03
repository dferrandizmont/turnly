import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../calendar/application/schedule_controller.dart';
import '../../schedule/application/schedule_providers.dart';
import '../../schedule/domain/schedule_domain.dart';
import '../domain/calendar.dart';
import '../domain/calendar_comparison.dart';
import 'calendars_controller.dart';

/// The schedule of calendar [calendarId], read-only, for comparing
/// (`docs/paridad.md` A4). The calendar on screen is read from the editor
/// (its in-memory schedule is the freshest); any other is read from the
/// database after the writes already queued have finished. It never switches
/// the calendar on screen and never writes.
final compareScheduleProvider = FutureProvider.autoDispose
    .family<Schedule, String>((ref, calendarId) async {
      final current = ref.watch(scheduleControllerProvider);
      if (current.calendarId == calendarId) return current.schedule;
      await ref.read(scheduleControllerProvider.notifier).pendingWrites;
      final stored = await ref
          .read(scheduleRepositoryProvider)
          .load(calendarId);
      return stored.schedule;
    });

/// The comparison asked for (P12): the calendars (the rows of the grid, in
/// the order they were chosen) and the days of the range (the columns).
///
/// Two requests with the same calendars and the same days are equal, so they
/// share the same comparison. The request is the key of the comparison, so it
/// keeps a copy of the calendars: changing the list afterwards cannot break
/// the cache.
class CompareRequest {
  CompareRequest({
    required List<Calendar> calendars,
    required this.from,
    required this.to,
  }) : calendars = _capped(calendars);

  /// The comparison of the whole month that contains [month] (the month of
  /// the «Comparar» screen).
  CompareRequest.month({
    required List<Calendar> calendars,
    required CivilDate month,
  }) : calendars = _capped(calendars),
       from = month.firstDayOfMonth,
       to = month.lastDayOfMonth;

  /// The rows of the grid: between [minComparedCalendars] and
  /// [maxComparedCalendars] calendars, in the order they are shown. More than
  /// [maxComparedCalendars] are cut to the first ones (the grid does not fit
  /// more, and the provider should never build an out-of-range request).
  final List<Calendar> calendars;

  static List<Calendar> _capped(List<Calendar> calendars) => List.unmodifiable(
    calendars.length <= maxComparedCalendars
        ? calendars
        : calendars.sublist(0, maxComparedCalendars),
  );

  /// First day of the range, included.
  final CivilDate from;

  /// Last day of the range, included.
  final CivilDate to;

  /// How many calendars are compared.
  int get calendarCount => calendars.length;

  @override
  bool operator ==(Object other) {
    if (other is! CompareRequest) return false;
    if (other.from != from || other.to != to) return false;
    if (other.calendars.length != calendars.length) return false;
    for (var i = 0; i < calendars.length; i++) {
      if (other.calendars[i] != calendars[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(from, to, Object.hashAll(calendars));

  @override
  String toString() =>
      'CompareRequest(${calendars.map((c) => c.id).join(', ')}, '
      '${from.toIso()}..${to.toIso()})';
}

/// The comparison of the calendars of [request] (P12): the grid of N rows
/// and everything that can be said about it.
///
/// It reads the schedule of each calendar (the one on screen from the editor
/// in memory, the others from the database) and never writes anything, never
/// switches the calendar on screen.
final multiComparisonProvider = FutureProvider.autoDispose
    .family<MultiComparison, CompareRequest>((ref, request) async {
      final pending = <Future<Schedule>>[
        for (final calendar in request.calendars)
          ref.watch(compareScheduleProvider(calendar.id).future),
      ];
      final schedules = await Future.wait(pending);
      return compareCalendars(
        [
          for (var i = 0; i < request.calendars.length; i++)
            (calendar: request.calendars[i], schedule: schedules[i]),
        ],
        request.from,
        request.to,
      );
    });

/// The calendars picked in the comparison screen (P12): their ids, in the
/// order they were picked.
///
/// Two selections with the same ids in the same order are the same
/// selection, so the comparison is not recomputed for nothing. The ids are
/// copied: the selection is the key of the comparison.
class ComparedSelection {
  ComparedSelection(List<String> ids) : ids = List.unmodifiable(ids);

  /// The ids of the picked calendars, in the order they were picked. Empty
  /// when the person has not picked any yet.
  final List<String> ids;

  @override
  bool operator ==(Object other) =>
      other is ComparedSelection && listEquals(other.ids, ids);

  @override
  int get hashCode => Object.hashAll(ids);

  @override
  String toString() => 'ComparedSelection(${ids.join(', ')})';
}

/// The calendars to compare (P12): the ones picked in the screen, in the
/// order they were picked; with fewer than two, the valid pick first and then
/// the calendar on screen and the ones that follow it in the list. At most
/// [maxComparedCalendars].
///
/// Empty while the calendars are still being read.
final comparedCalendarsProvider =
    Provider.family<List<Calendar>, ComparedSelection>((ref, selection) {
      final state = ref.watch(calendarsControllerProvider).value;
      if (state == null) return const [];
      final activeId = ref.watch(
        scheduleControllerProvider.select((s) => s.calendarId),
      );
      return resolveComparedCalendars(
        state.calendars,
        activeId: activeId,
        selectedIds: selection.ids,
      );
    });
