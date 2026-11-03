import 'package:collection/collection.dart';

import '../../schedule/domain/civil_date.dart';

/// One event of the phone, on one day.
class DeviceDayEvent {
  const DeviceDayEvent({
    required this.instanceId,
    required this.calendarId,
    required this.calendarName,
    required this.title,
    required this.allDay,
    required this.start,
    required this.end,
    this.colorValue,
  });

  /// Unique per occurrence (a recurring event gives one per day).
  final String instanceId;
  final String calendarId;

  /// Name of the phone calendar it comes from.
  final String calendarName;
  final String title;

  /// All-day events are floating dates: [start] is midnight of their first
  /// day and [end] is the exclusive end.
  final bool allDay;

  /// Local wall clock. A timed event that runs past midnight ends on the next
  /// day.
  final DateTime start;
  final DateTime end;

  /// ARGB of the event, or of its calendar when the event has none.
  final int? colorValue;

  @override
  bool operator ==(Object other) =>
      other is DeviceDayEvent &&
      other.instanceId == instanceId &&
      other.calendarId == calendarId &&
      other.calendarName == calendarName &&
      other.title == title &&
      other.allDay == allDay &&
      other.start == start &&
      other.end == end &&
      other.colorValue == colorValue;

  @override
  int get hashCode => Object.hash(
    instanceId,
    calendarId,
    calendarName,
    title,
    allDay,
    start,
    end,
    colorValue,
  );

  @override
  String toString() {
    final when = allDay ? 'all day' : '$start - $end';
    return 'DeviceDayEvent($calendarName, $title, $when)';
  }
}

/// Everything the phone shows on one day, ready for the month cell and the day
/// pane: the all-day events first, then the timed ones in order.
class DeviceEventDay {
  const DeviceEventDay({
    required this.date,
    this.allDay = const [],
    this.timed = const [],
  });

  final CivilDate date;

  /// Ordered by title, then by id (the order is stable).
  final List<DeviceDayEvent> allDay;

  /// Ordered by start, then by title and id.
  final List<DeviceDayEvent> timed;

  static DeviceEventDay empty(CivilDate date) => DeviceEventDay(date: date);

  bool get isEmpty => allDay.isEmpty && timed.isEmpty;

  bool get isNotEmpty => !isEmpty;

  int get count => allDay.length + timed.length;

  /// The all-day events first, then the timed ones in time order.
  List<DeviceDayEvent> get events => [...allDay, ...timed];

  @override
  bool operator ==(Object other) =>
      other is DeviceEventDay &&
      other.date == date &&
      const ListEquality<DeviceDayEvent>().equals(other.allDay, allDay) &&
      const ListEquality<DeviceDayEvent>().equals(other.timed, timed);

  @override
  int get hashCode => Object.hash(
    date,
    const ListEquality<DeviceDayEvent>().hash(allDay),
    const ListEquality<DeviceDayEvent>().hash(timed),
  );

  @override
  String toString() => 'DeviceEventDay($date, $count events)';
}
