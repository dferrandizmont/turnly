import 'package:collection/collection.dart';

import '../../calendar_export/domain/device_calendar_api.dart';
import '../../schedule/domain/civil_date.dart';
import 'device_event_day.dart';

/// One month of the phone's events, by day. Only the days with something are
/// kept; [day] answers for any other with an empty day, so the month cell can
/// ask without checking.
class DeviceEventMonth {
  const DeviceEventMonth({
    required this.year,
    required this.month,
    this.days = const {},
  });

  final int year;
  final int month;

  /// Days of the month that have at least one event.
  final Map<CivilDate, DeviceEventDay> days;

  static DeviceEventMonth empty(CivilDate day) =>
      DeviceEventMonth(year: day.year, month: day.month);

  bool get isEmpty => days.isEmpty;

  bool get isNotEmpty => !isEmpty;

  DeviceEventDay day(CivilDate date) =>
      days[date] ?? DeviceEventDay.empty(date);

  @override
  bool operator ==(Object other) =>
      other is DeviceEventMonth &&
      other.year == year &&
      other.month == month &&
      const MapEquality<CivilDate, DeviceEventDay>().equals(other.days, days);

  @override
  int get hashCode => Object.hash(
    year,
    month,
    const MapEquality<CivilDate, DeviceEventDay>().hash(days),
  );

  @override
  String toString() => 'DeviceEventMonth($year-$month, ${days.length} days)';
}

/// Whether [moment] is exactly midnight (the start of a day).
bool _atMidnight(DateTime moment) =>
    moment.hour == 0 &&
    moment.minute == 0 &&
    moment.second == 0 &&
    moment.millisecond == 0 &&
    moment.microsecond == 0;

/// The civil days [event] is shown on, clipped to `[from, to]` when given.
///
/// An all-day event covers whole days: the end is exclusive on Android and
/// inside the last day on iOS, and both give the same days. A timed event is
/// shown on its start day and, when it runs past midnight, on every day it
/// reaches; one that ends exactly at midnight does not reach the next day.
List<CivilDate> eventDays(DeviceEvent event, {CivilDate? from, CivilDate? to}) {
  final start = CivilDate.fromDateTime(event.start);
  CivilDate last;
  if (event.allDay) {
    var end = CivilDate.fromDateTime(event.end);
    if (!_atMidnight(event.end) || !event.end.isAfter(event.start)) {
      end = end.addDays(1);
    }
    if (!end.isAfter(start)) end = start.addDays(1);
    last = end.addDays(-1);
  } else {
    last = start;
    if (event.end.isAfter(event.start)) {
      var end = CivilDate.fromDateTime(event.end);
      if (_atMidnight(event.end)) end = end.addDays(-1);
      if (end.isAfter(last)) last = end;
    }
  }
  var first = start;
  if (from != null && first.isBefore(from)) first = from;
  if (to != null && last.isAfter(to)) last = to;
  final days = <CivilDate>[];
  for (var d = first; !d.isAfter(last); d = d.addDays(1)) {
    days.add(d);
  }
  return days;
}

/// [events] (already filtered to the chosen calendars and without what Turnly
/// wrote) grouped by day for the month of [dayInMonth], with the all-day
/// events first and the timed ones in time order. Cross-month continuations
/// are clipped to the month; [calendars] gives each event its calendar's name
/// and colour.
DeviceEventMonth groupMonthEvents(
  CivilDate dayInMonth,
  Iterable<DeviceEvent> events,
  Map<String, DeviceCalendarInfo> calendars,
) {
  final first = CivilDate(dayInMonth.year, dayInMonth.month, 1);
  final last = first.lastDayOfMonth;
  final allDay = <CivilDate, List<DeviceDayEvent>>{};
  final timed = <CivilDate, List<DeviceDayEvent>>{};
  for (final event in events) {
    final info = calendars[event.calendarId];
    for (final day in eventDays(event, from: first, to: last)) {
      final item = DeviceDayEvent(
        instanceId: event.instanceId,
        calendarId: event.calendarId,
        calendarName: info?.name ?? '',
        title: event.title,
        allDay: event.allDay,
        start: event.start,
        end: event.end,
        colorValue: event.colorValue ?? info?.colorValue,
      );
      (event.allDay ? allDay : timed).putIfAbsent(day, () => []).add(item);
    }
  }
  int byText(DeviceDayEvent a, DeviceDayEvent b) {
    final byTitle = a.title.compareTo(b.title);
    return byTitle != 0 ? byTitle : a.instanceId.compareTo(b.instanceId);
  }

  int byTime(DeviceDayEvent a, DeviceDayEvent b) {
    final byStart = a.start.compareTo(b.start);
    return byStart != 0 ? byStart : byText(a, b);
  }

  final days = <CivilDate, DeviceEventDay>{};
  for (final entry in allDay.entries) {
    days[entry.key] = DeviceEventDay(
      date: entry.key,
      allDay: entry.value..sort(byText),
    );
  }
  for (final entry in timed.entries) {
    final existing = days[entry.key];
    days[entry.key] = DeviceEventDay(
      date: entry.key,
      allDay: existing?.allDay ?? const [],
      timed: entry.value..sort(byTime),
    );
  }
  return DeviceEventMonth(
    year: first.year,
    month: first.month,
    days: Map.unmodifiable(days),
  );
}
