import '../../calendar_export/domain/device_calendar_api.dart';

/// How the phone's calendar permission stands for the events shown next to the
/// shifts. Typed, so the screen writes the text (no strings here); nothing is
/// ever asked at start-up: only the screen's button calls `requestAccess`.
enum DeviceEventsPermission {
  /// Never asked.
  notAsked,

  /// Refused, or the system will not show the question again.
  denied,

  /// The system does not let the app use calendars (parental controls).
  restricted,

  /// Granted, but the phone has no calendar the app can read.
  noCalendars,

  /// Granted and there is at least one calendar to choose.
  granted,
}

/// The state shown for [access]. [hasCalendars] is whether the phone has any
/// calendar the app can read (`selectableCalendars`).
DeviceEventsPermission deviceEventsPermissionOf(
  CalendarAccess access, {
  required bool hasCalendars,
}) => switch (access) {
  CalendarAccess.granted =>
    hasCalendars
        ? DeviceEventsPermission.granted
        : DeviceEventsPermission.noCalendars,
  CalendarAccess.notDetermined => DeviceEventsPermission.notAsked,
  // «Add events only» (iOS 17) cannot read: for reading it is the same as a
  // refusal.
  CalendarAccess.writeOnly ||
  CalendarAccess.denied => DeviceEventsPermission.denied,
  CalendarAccess.restricted => DeviceEventsPermission.restricted,
};
