import '../../../core/format/app_date_format.dart';
import '../../../l10n/app_localizations.dart';
import '../../schedule/domain/civil_date.dart';

/// Every user-visible text of the alarms, resolved before planning so the
/// planner and the scheduler stay free of `BuildContext` and of the
/// generated localizations class (tests build their own).
class AlarmStrings {
  const AlarmStrings({
    required this.title,
    required this.body,
    required this.channelName,
    required this.channelDescription,
    required this.dayBeforeTitle,
    required this.snoozeAction,
    required this.awakeAction,
    required this.testTitle,
    required this.testBody,
    required this.reminderTitle,
    required this.reminderEmptyBody,
    required this.reminderChannelName,
    required this.reminderChannelDescription,
    this.renewalTitle,
    this.renewalBody,
    this.pauseTitle,
    this.pauseChannelName,
    this.pauseChannelDescription,
    this.clock,
  });

  /// Filled from the ARB file of the current locale. [clock] writes a time
  /// of day the way the person chose in Ajustes (24 h or 12 h); without it
  /// times read "22:00".
  factory AlarmStrings.fromL10n(
    AppLocalizations l10n, {
    String Function(int minuteOfDay)? clock,
  }) => AlarmStrings(
    title: l10n.alarmTitle,
    body: l10n.alarmBody,
    channelName: l10n.alarmChannelName,
    channelDescription: l10n.alarmChannelDescription,
    dayBeforeTitle: l10n.alarmsNotifDayBeforeTitle,
    snoozeAction: l10n.alarmsNotifSnooze,
    awakeAction: l10n.alarmsNotifAwake,
    testTitle: l10n.alarmsNotifTestTitle,
    testBody: l10n.alarmsNotifTestBody,
    reminderTitle: l10n.alarmsReminderTitle,
    reminderEmptyBody: l10n.alarmsReminderEmptyBody,
    reminderChannelName: l10n.alarmsReminderChannelName,
    reminderChannelDescription: l10n.alarmsReminderChannelDescription,
    renewalTitle: l10n.alarmsRenewalTitle,
    renewalBody: (day) => l10n.alarmsRenewalBody(
      AppDateFormat(l10n.localeName)
          .weekdayDayMonth(DateTime(day.year, day.month, day.day)),
    ),
    pauseTitle: l10n.alarmsPauseTitle,
    pauseChannelName: l10n.alarmsPauseChannelName,
    pauseChannelDescription: l10n.alarmsPauseChannelDescription,
    clock: clock,
  );

  /// Empty texts, for computing a plan only to read its times (the "next
  /// alarm" line of the settings screen shows its own text).
  static const AlarmStrings blank = AlarmStrings(
    title: _blank2,
    body: _blank3,
    channelName: '',
    channelDescription: '',
    dayBeforeTitle: _blank2,
    snoozeAction: '',
    awakeAction: '',
    testTitle: '',
    testBody: '',
    reminderTitle: '',
    reminderEmptyBody: '',
    reminderChannelName: '',
    reminderChannelDescription: '',
  );

  /// Writes a time of day (minutes after midnight, 1440 wraps to 0) in the
  /// notifications: "22:00" or "10:00 PM". `null`: 24 h.
  final String Function(int minuteOfDay)? clock;

  /// [minuteOfDay] as the notifications write it (see [clock]).
  String time(int minuteOfDay) {
    final m = ((minuteOfDay % 1440) + 1440) % 1440;
    final custom = clock;
    if (custom != null) return custom(m);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(m ~/ 60)}:${two(m % 60)}';
  }

  /// "Turno de Noche a las 22:00": shift name and start time (see [time]).
  final String Function(String name, String start) title;

  /// Shift name and the two times ("22:00", "06:00").
  final String Function(String name, String start, String end) body;

  /// Title of the day-before reminder: "Mañana: turno de Noche a las 22:00".
  /// Its body is [body].
  final String Function(String name, String start) dayBeforeTitle;

  /// Android notification channel.
  final String channelName;
  final String channelDescription;

  /// Labels of the notification buttons: "Posponer 10 min" and "Ya estoy
  /// despierto".
  final String snoozeAction;
  final String awakeAction;

  /// The "Probar aviso" notification.
  final String testTitle;
  final String testBody;

  /// Reminder of a day's note: the title ("Recordatorio") and the body when
  /// the note has no text ("Tienes un recordatorio para hoy"); the body of a
  /// reminder is otherwise the first line of the note.
  final String reminderTitle;
  final String reminderEmptyBody;

  /// Android channel of the note reminders.
  final String reminderChannelName;
  final String reminderChannelDescription;

  /// The renewal notice (A1): its title and its body for the day of the last
  /// alarm («Tus avisos de turno llegan hasta el jueves 12 de noviembre…»).
  /// Null (test texts, [blank]) plans no renewal notice; [AlarmStrings.fromL10n]
  /// always sets both.
  final String? renewalTitle;
  final String Function(CivilDate lastDay)? renewalBody;

  /// The pause notice («Toca pausa», its body is the shift's [body]) and its
  /// Android channel. Null (test texts, [blank]) plans no pause notice;
  /// [AlarmStrings.fromL10n] always sets all three.
  final String? pauseTitle;
  final String? pauseChannelName;
  final String? pauseChannelDescription;
}

String _blank2(String a, String b) => '';
String _blank3(String a, String b, String c) => '';

/// The clock of the notifications for [format]: "22:00" or "10:00 PM"
/// (`AlarmStrings.clock`).
String Function(int minuteOfDay) alarmClock(AppDateFormat format) =>
    (minuteOfDay) => format.time(
      DateTime(2000, 1, 1, (minuteOfDay ~/ 60) % 24, minuteOfDay % 60),
    );
