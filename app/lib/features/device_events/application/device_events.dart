import '../../calendar_export/domain/device_calendar_api.dart';
import '../../schedule/domain/civil_date.dart';
import '../data/device_events_reader.dart';
import '../domain/device_event_day.dart';
import '../domain/device_event_month.dart';
import '../domain/device_events_settings.dart';

/// The phone's events next to the shifts: reads them once per month and keeps
/// each month until [refresh].
///
/// Nothing is stored: this is only a cache. The screen asks for a month (or a
/// day) and, when the app comes back to the front, calls [refresh] so the next
/// read asks the phone again — its calendar may have changed while the app was
/// away. `DeviceEventsProvider`'s caller drops what it was showing after
/// [refresh] (see `refreshDeviceEvents`).
class DeviceEvents {
  DeviceEvents({required this.api, required this.loadSettings});

  final DeviceCalendarApi api;
  final Future<DeviceEventsSettings> Function() loadSettings;

  final Map<String, DeviceEventMonth> _months = {};
  final Map<String, ({int generation, Future<DeviceEventMonth> future})>
  _loading = {};
  List<DeviceCalendarInfo>? _calendars;

  /// Bumped by [refresh]: a read started before it is no longer the current
  /// one and must not write its (already old) month back into the cache.
  int _generation = 0;

  static String _keyOf(CivilDate day) => '${day.year}-${day.month}';

  /// The month that contains [dayInMonth], read once and kept. Two callers
  /// asking at the same time share one read.
  Future<DeviceEventMonth> month(CivilDate dayInMonth) {
    final first = CivilDate(dayInMonth.year, dayInMonth.month, 1);
    final key = _keyOf(first);
    final cached = _months[key];
    if (cached != null) return Future.value(cached);
    final generation = _generation;
    final running = _loading[key];
    if (running != null && running.generation == generation) {
      return running.future;
    }
    final future = _read(first, generation);
    _loading[key] = (generation: generation, future: future);
    return future;
  }

  /// The events of [date] alone.
  Future<DeviceEventDay> day(CivilDate date) async =>
      (await month(date)).day(date);

  /// The days of `[from, to]` (both included) that have something, in order.
  /// The months the range spans are read (and kept) one by one.
  Future<List<DeviceEventDay>> range(CivilDate from, CivilDate to) async {
    final out = <DeviceEventDay>[];
    if (to.isBefore(from)) return out;
    var first = CivilDate(from.year, from.month, 1);
    while (!first.isAfter(to)) {
      final load = await month(first);
      for (
        var date = first;
        !date.isAfter(first.lastDayOfMonth) && !date.isAfter(to);
        date = date.addDays(1)
      ) {
        if (date.isBefore(from)) continue;
        final day = load.days[date];
        if (day != null) out.add(day);
      }
      first = first.lastDayOfMonth.addDays(1);
    }
    return out;
  }

  /// Forgets every month read: the next [month] or [day] asks the phone
  /// again. The screen calls it when the app comes back to the front. A read
  /// that was already under way is left to finish but does not refill the
  /// cache: its generation is no longer the current one.
  void refresh() {
    _generation++;
    _months.clear();
    _loading.clear();
    _calendars = null;
  }

  Future<DeviceEventMonth> _read(CivilDate first, int generation) async {
    final key = _keyOf(first);
    void keep(DeviceEventMonth month) {
      if (generation == _generation) _months[key] = month;
    }

    try {
      // Without permission nothing can be read and `calendars()` would throw:
      // the normal state of someone who never granted it (or revoked it later
      // in the system settings) is an empty month, not an error.
      if (await api.access() != CalendarAccess.granted) {
        final empty = DeviceEventMonth.empty(first);
        keep(empty);
        return empty;
      }
      final settings = await loadSettings();
      final calendars = await _selectable();
      final byId = {for (final c in calendars) c.id: c};
      final ids = [
        for (final id in settings.calendarIds)
          if (byId.containsKey(id)) id,
      ];
      final grouped = ids.isEmpty
          ? DeviceEventMonth.empty(first)
          : groupMonthEvents(
              first,
              await readDeviceEventMonth(
                api,
                calendarIds: ids,
                dayInMonth: first,
              ),
              byId,
            );
      keep(grouped);
      return grouped;
    } on CalendarApiException {
      // The permission went away between the check and the read, or the
      // phone's calendar did not answer: show nothing instead of failing.
      final empty = DeviceEventMonth.empty(first);
      keep(empty);
      return empty;
    } finally {
      // Only drop our own in-flight entry: a [refresh] may have already put a
      // newer read for the same month in its place.
      if (_loading[key]?.generation == generation) _loading.remove(key);
    }
  }

  Future<List<DeviceCalendarInfo>> _selectable() async =>
      _calendars ??= await selectableCalendars(api);
}
