import '../../calendar_export/data/calendar_exporter.dart'
    show exportCalendarName;
import '../../calendar_export/domain/device_calendar_api.dart';
import '../../calendar_export/domain/export_events.dart' show ExportTag;
import '../../schedule/domain/civil_date.dart';

/// Whether [calendar] is the one Turnly writes the shifts to: its events are
/// the shifts themselves and must never be shown again next to them.
bool isTurnlyCalendar(DeviceCalendarInfo calendar) =>
    calendar.name.trim() == exportCalendarName;

/// Whether [event] was written by Turnly (it carries its tag in the
/// description). The export can also write into a calendar of the person's, so
/// the tag — not only the calendar — is what tells the shifts apart.
bool isTurnlyEvent(DeviceEvent event) =>
    ExportTag.parse(event.description) != null;

/// The calendars of the phone the person can choose: everything the app can
/// read except the hidden ones and the one Turnly writes. Read-only calendars
/// are offered (reading them is fine).
Future<List<DeviceCalendarInfo>> selectableCalendars(
  DeviceCalendarApi api,
) async {
  final all = await api.calendars();
  return [
    for (final c in all)
      if (!c.hidden && !isTurnlyCalendar(c)) c,
  ];
}

/// The events of [calendarIds] that touch the month of [dayInMonth], as the
/// phone gives them. Turnly's own events and the cancelled ones are left out;
/// nothing is written.
Future<List<DeviceEvent>> readDeviceEventMonth(
  DeviceCalendarApi api, {
  required Iterable<String> calendarIds,
  required CivilDate dayInMonth,
}) async {
  final ids = calendarIds.toSet().toList(growable: false);
  if (ids.isEmpty) return const [];
  final first = CivilDate(dayInMonth.year, dayInMonth.month, 1);
  final after = first.lastDayOfMonth.addDays(1);
  final found = await api.events(
    DateTime(first.year, first.month, first.day),
    DateTime(after.year, after.month, after.day),
    calendarIds: ids,
  );
  return [
    for (final e in found)
      if (!e.cancelled && ids.contains(e.calendarId) && !isTurnlyEvent(e)) e,
  ];
}
