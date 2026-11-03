import '../../../core/format/app_date_format.dart';
import '../../../core/l10n/l10n.dart';
import '../domain/device_event_day.dart';

/// When an event happens: its range («09:00–10:00») or «Todo el día» when it
/// lasts the whole day (its dates are floating, so there is no time to show).
String deviceEventTimeText(
  AppLocalizations l10n,
  AppDateFormat format,
  DeviceDayEvent event,
) => event.allDay
    ? l10n.devEventsAllDay
    : format.timeRange(event.start, event.end);

/// How many appointments of the phone: «1 cita» / «3 citas». It is also what
/// the day cell says out loud when it marks a day with appointments.
String deviceEventCountText(AppLocalizations l10n, int count) =>
    l10n.devEventsCount(count);

/// The label the reader of screen hears for one appointment: its time, its
/// title and the calendar it comes from (when it has one).
String deviceEventSemantics(
  AppLocalizations l10n,
  AppDateFormat format,
  DeviceDayEvent event,
) {
  final time = deviceEventTimeText(l10n, format, event);
  final calendar = event.calendarName.trim();
  return calendar.isEmpty
      ? l10n.devEventsEventSemantics(time, event.title)
      : l10n.devEventsEventWithCalendarSemantics(time, event.title, calendar);
}
