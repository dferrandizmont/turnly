/// Why «Mantener al día» switched itself off. The export screen (and a notice
/// at the time) says so until the user turns it on again or dismisses it.
enum CalendarSyncNotice {
  /// The calendar permission was taken away (or is only «add events»).
  permission,

  /// The phone calendar the events went to is gone, read-only or hidden now.
  calendarGone,

  /// The Turnly calendar the shifts came from was deleted.
  sourceGone,
}

/// How many days before today the continuous export keeps up to date.
const int calendarSyncPastDays = 7;

/// How many days after today the continuous export keeps up to date.
const int calendarSyncFutureDays = 90;

/// «Mantener al día» (C8): the continuous export to a calendar of the phone.
///
/// One JSON row of the `settings` table. It records what to keep current (the
/// app calendar, the phone calendar and the options chosen on the export
/// screen), not the events themselves: those are found again by their tag.
class CalendarSyncSettings {
  const CalendarSyncSettings({
    this.enabled = false,
    this.deviceCalendarId,
    this.deviceCalendarName,
    this.appCalendarId,
    this.includeRest = false,
    this.includeAbsences = false,
    this.notice,
    this.lastSyncAt,
    this.lastFailed = 0,
  });

  static const CalendarSyncSettings off = CalendarSyncSettings();

  final bool enabled;

  /// The calendar of the phone the events are kept in.
  final String? deviceCalendarId;

  /// Its name when «Mantener al día» was turned on: ids are numbers the
  /// system hands out, so a settings row that came from another phone must
  /// not point at an unrelated calendar.
  final String? deviceCalendarName;

  /// The Turnly calendar whose shifts are exported.
  final String? appCalendarId;

  /// Also keep the days off (Libre, Saliente).
  final bool includeRest;

  /// Also keep absences (vacations, sick leave...). Off by default: the
  /// calendar chosen may be synced to an account, and a sick leave must never
  /// travel there unless the user says so.
  final bool includeAbsences;

  /// Why it was switched off by itself, until the user sees it.
  final CalendarSyncNotice? notice;

  /// When the last pass finished (local time).
  final DateTime? lastSyncAt;

  /// Events the last pass could not write; the next pass repeats them.
  final int lastFailed;

  /// On and with everything it needs.
  bool get active =>
      enabled &&
      deviceCalendarId != null &&
      deviceCalendarId!.isNotEmpty &&
      appCalendarId != null &&
      appCalendarId!.isNotEmpty;

  CalendarSyncSettings copyWith({
    bool? enabled,
    String? deviceCalendarId,
    String? deviceCalendarName,
    String? appCalendarId,
    bool? includeRest,
    bool? includeAbsences,
    CalendarSyncNotice? notice,
    bool clearNotice = false,
    DateTime? lastSyncAt,
    int? lastFailed,
  }) => CalendarSyncSettings(
    enabled: enabled ?? this.enabled,
    deviceCalendarId: deviceCalendarId ?? this.deviceCalendarId,
    deviceCalendarName: deviceCalendarName ?? this.deviceCalendarName,
    appCalendarId: appCalendarId ?? this.appCalendarId,
    includeRest: includeRest ?? this.includeRest,
    includeAbsences: includeAbsences ?? this.includeAbsences,
    notice: clearNotice ? null : notice ?? this.notice,
    lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    lastFailed: lastFailed ?? this.lastFailed,
  );

  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'deviceCalendarId': deviceCalendarId,
    'deviceCalendarName': deviceCalendarName,
    'appCalendarId': appCalendarId,
    'includeRest': includeRest,
    'includeAbsences': includeAbsences,
    'notice': notice?.name,
    'lastSyncAt': lastSyncAt?.toIso8601String(),
    'lastFailed': lastFailed,
  };

  /// Reads what [toJson] wrote. Anything unreadable falls back to the
  /// default (off): a bad row never blocks the app.
  factory CalendarSyncSettings.fromJson(Map<String, Object?> json) {
    String? text(String key) {
      final value = json[key];
      return value is String && value.isNotEmpty ? value : null;
    }

    return CalendarSyncSettings(
      enabled: json['enabled'] == true,
      deviceCalendarId: text('deviceCalendarId'),
      deviceCalendarName: text('deviceCalendarName'),
      appCalendarId: text('appCalendarId'),
      includeRest: json['includeRest'] == true,
      includeAbsences: json['includeAbsences'] == true,
      notice: CalendarSyncNotice.values
          .where((n) => n.name == json['notice'])
          .firstOrNull,
      lastSyncAt: DateTime.tryParse(text('lastSyncAt') ?? ''),
      lastFailed: json['lastFailed'] is int ? json['lastFailed']! as int : 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CalendarSyncSettings &&
      other.enabled == enabled &&
      other.deviceCalendarId == deviceCalendarId &&
      other.deviceCalendarName == deviceCalendarName &&
      other.appCalendarId == appCalendarId &&
      other.includeRest == includeRest &&
      other.includeAbsences == includeAbsences &&
      other.notice == notice &&
      other.lastSyncAt == lastSyncAt &&
      other.lastFailed == lastFailed;

  @override
  int get hashCode => Object.hash(
    enabled,
    deviceCalendarId,
    deviceCalendarName,
    appCalendarId,
    includeRest,
    includeAbsences,
    notice,
    lastSyncAt,
    lastFailed,
  );
}
