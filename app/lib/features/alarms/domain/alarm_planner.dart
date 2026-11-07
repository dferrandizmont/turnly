import 'package:timezone/timezone.dart' as tz;

import '../../schedule/domain/schedule_domain.dart';
import 'alarm_payload.dart';
import 'alarm_settings.dart';
import 'alarm_strings.dart';
import 'wall_clock.dart';

export 'alarm_payload.dart'
    show
        AlarmKind,
        AlarmPayload,
        alarmPayloadPrefix,
        alarmSnoozePayloadPrefix,
        alarmTestPayloadPrefix;

/// Pending alarms the app keeps scheduled. iOS allows 64 pending local
/// notifications per app; 60 leaves room for a few others.
const int maxPendingAlarms = 60;

const int _minutesPerDay = 1440;

/// Whether an alarm can exist for [type] at all: it has times and it is not
/// an absence (sick leave, vacation, personal days: nothing to wake up for).
/// The planner and the settings screen share it.
bool canShiftTypeRing(ShiftType type) =>
    type.hasTimes && type.category != ShiftCategory.absence;

/// Whether any alarm could really ring with [settings] over [shiftTypes]: the
/// global switch on and at least one type that can ring ([canShiftTypeRing])
/// with its own switch (or its pause notice) on. A switch left on in a type
/// that has since lost its times, or became an absence, does not count.
bool alarmsCanRing(AlarmSettings settings, Iterable<ShiftType> shiftTypes) =>
    settings.enabled &&
    shiftTypes.any(
      (t) => canShiftTypeRing(t) && settings.forShiftType(t.id).anyEnabled,
    );

/// One alarm to schedule: a wall-clock instant and its text.
///
/// The instant is a **wall-clock time** ([fireDate] plus [fireMinute] minutes
/// after 00:00), not an absolute instant: the scheduler reads it in the
/// device's time zone, so a 22:00 shift keeps ringing at 20:30 local on the
/// days the clocks change. It can fall on the day before the shift.
class PlannedAlarm {
  const PlannedAlarm({
    required this.id,
    required this.fireDate,
    required this.fireMinute,
    required this.shiftDate,
    required this.shiftTypeId,
    required this.title,
    required this.body,
    this.kind = AlarmKind.shift,
    this.shiftName = '',
    this.snoozeLabel,
    this.awakeLabel,
    this.sound,
    this.segment = 0,
  }) : assert(fireMinute >= 0 && fireMinute < _minutesPerDay);

  /// Deterministic (see [alarmIdFor]): planning twice gives the same id, so a
  /// reschedule replaces instead of duplicating.
  final int id;

  /// Day the alarm rings (may be the day before [shiftDate]).
  final CivilDate fireDate;

  /// Minutes after 00:00 of [fireDate], `0..1439`.
  final int fireMinute;

  /// Day the shift starts.
  final CivilDate shiftDate;
  final String shiftTypeId;
  final String title;
  final String body;

  /// Before the shift or the evening before.
  final AlarmKind kind;

  /// Name of the shift type (for the "next alarm" line).
  final String shiftName;

  /// Labels of the notification buttons (only the alarm before the shift
  /// has them); null = no buttons.
  final String? snoozeLabel;
  final String? awakeLabel;

  /// Custom sound (content URI) of the shift type, or null for the default.
  /// Only the alarms before a shift and the evening-before ones carry one;
  /// the scheduler picks the channel from it (`alarm_channels.dart`).
  final String? sound;

  /// 0 for the first (or only) part of the shift, 1 for the second part of a
  /// split shift. Travels in the payload so a snooze keeps the two apart.
  final int segment;

  /// Minutes of wall-clock time since the epoch day 0. This does not identify
  /// an instant during daylight-saving transitions; planning resolves the zone.
  int get wallMinutes => fireDate.epochDay * _minutesPerDay + fireMinute;

  /// Payload attached to the notification: marks it as ours (the scheduler
  /// only ever cancels notifications with the [alarmPayloadPrefix]) and
  /// carries what the notification buttons need (see [AlarmPayload]).
  String get payload => AlarmPayload(
    shiftTypeId: shiftTypeId,
    shiftDate: shiftDate,
    kind: kind,
    title: title,
    body: body,
    snoozeLabel: snoozeLabel,
    awakeLabel: awakeLabel,
    sound: sound,
    segment: segment,
  ).encode();

  /// The same alarm ringing with [sound] (null = the default one); the
  /// scheduler uses it to drop a sound that is no longer there.
  PlannedAlarm withSound(String? sound) => PlannedAlarm(
    id: id,
    fireDate: fireDate,
    fireMinute: fireMinute,
    shiftDate: shiftDate,
    shiftTypeId: shiftTypeId,
    title: title,
    body: body,
    kind: kind,
    shiftName: shiftName,
    snoozeLabel: snoozeLabel,
    awakeLabel: awakeLabel,
    sound: sound,
    segment: segment,
  );

  PlannedAlarm _withId(int id) => PlannedAlarm(
    id: id,
    fireDate: fireDate,
    fireMinute: fireMinute,
    shiftDate: shiftDate,
    shiftTypeId: shiftTypeId,
    title: title,
    body: body,
    kind: kind,
    shiftName: shiftName,
    snoozeLabel: snoozeLabel,
    awakeLabel: awakeLabel,
    sound: sound,
    segment: segment,
  );

  @override
  bool operator ==(Object other) =>
      other is PlannedAlarm &&
      other.id == id &&
      other.fireDate == fireDate &&
      other.fireMinute == fireMinute &&
      other.shiftDate == shiftDate &&
      other.shiftTypeId == shiftTypeId &&
      other.title == title &&
      other.body == body &&
      other.kind == kind &&
      other.shiftName == shiftName &&
      other.snoozeLabel == snoozeLabel &&
      other.awakeLabel == awakeLabel &&
      other.sound == sound &&
      other.segment == segment;

  @override
  int get hashCode => Object.hash(
    id,
    fireDate,
    fireMinute,
    shiftDate,
    shiftTypeId,
    title,
    body,
    kind,
    shiftName,
    snoozeLabel,
    awakeLabel,
    sound,
    segment,
  );

  @override
  String toString() =>
      'PlannedAlarm($id, $fireDate ${_hhmm(fireMinute)} -> shift $shiftDate '
      '$shiftTypeId, ${kind.name})';
}

/// 31-bit id (Android notification ids are signed 32-bit) derived only from
/// what identifies the alarm: shift day, shift type, its position among that
/// day's shifts and the [kind] (so the alarm before a shift and the reminder
/// the evening before never share an id). FNV-1a, so it is the same on every
/// run and platform.
///
/// The kind joins the hashed text for every kind but [AlarmKind.shift]: the
/// alarms before a shift keep the ids they had before the other kinds
/// existed, so an update does not orphan the ones already scheduled.
///
/// The alarm before the **second segment** of a split shift (A12) adds
/// `|s2` (`segment: 1`); every other alarm hashes as before.
int alarmIdFor(
  CivilDate shiftDate,
  String shiftTypeId,
  int index, [
  AlarmKind kind = AlarmKind.shift,
  int segment = 0,
]) => fnv31(
  '${shiftDate.toIso()}|$shiftTypeId|$index'
  '${kind == AlarmKind.shift ? '' : '|${kind.name}'}'
  '${segment == 0 ? '' : '|s${segment + 1}'}',
);

/// FNV-1a folded to 31 bits.
int fnv31(String text) {
  var hash = 0x811c9dc5;
  for (final unit in text.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash & 0x7FFFFFFF;
}

String _two(int n) => n.toString().padLeft(2, '0');

String _hhmm(int minuteOfDay) {
  final m = ((minuteOfDay % _minutesPerDay) + _minutesPerDay) % _minutesPerDay;
  return '${_two(m ~/ 60)}:${_two(m % 60)}';
}

/// The alarms to keep scheduled, soonest first, at most [maxPendingAlarms].
///
/// - Only shift types with alarm on (and the global switch on) and with
///   times; one alarm per shift, so a double shift rings twice. Absences
///   (`ShiftCategory.absence`) never ring.
/// - A split shift (A12) rings before its first segment and, unless the type
///   turned `secondSegment` off, again before the second one (same lead, own
///   id and text). The day-before notice is one per shift, as always.
/// - Fires `minutesBefore` before the shift starts, as a wall-clock time
///   (the previous day for early shifts; midnight-crossing shifts only
///   matter through their start).
/// - A type with `dayBefore` on also rings at `dayBeforeMinute` of the day
///   before each of its shifts (a wall-clock time too, so it keeps the same
///   local hour on the nights the clocks change).
/// - A type with its pause notice on (`AlarmTypeSettings.pause`, independent
///   of the alarm before the shift) also rings once in the middle of each of
///   its shifts: see [AlarmKind.pause] and `_planPause`. The global switch
///   is needed, "Sin alarma este día" silences it, and so does any absence
///   on that day.
/// - A shift on a day in `settings.skippedDates` makes no alarm of any kind.
/// - The reminder of a day's note (`DayEntry.noteReminderMinute`, A1) rings
///   at that wall-clock minute of that day. It is **independent of the
///   alarm switches** (global and per type: it is something the user asked
///   for on one day) and of "Sin alarma este día", and needs only the
///   notification permission, which the scheduler checks. [includeReminders]
///   false leaves them out (the "next alarm" line is about shifts).
/// - Only alarms after [now] and no later than [now] plus
///   `settings.horizonDays` days.
/// - Beyond [maxPendingAlarms] the **reminders go first** (they are few, the
///   user's own and cannot be recomputed from the rotation), nearest first;
///   the shift alarms fill the rest, nearest first. The result is sorted by
///   time. So a reminder inside the horizon is never dropped for a shift
///   alarm; only more than [maxPendingAlarms] reminders in the window (then
///   the nearest win) can push one out.
///
/// It never contains the renewal notice: [planAlarmSchedule] adds it.
List<PlannedAlarm> planAlarms({
  required Schedule schedule,
  required AlarmSettings settings,
  required DateTime now,
  required AlarmStrings strings,
  bool includeReminders = true,
  tz.Location? location,
}) => _plan(
  schedule: schedule,
  settings: settings,
  now: now,
  strings: strings,
  includeReminders: includeReminders,
  location: location,
  lookaheadDays: 0,
).alarms;

/// Days past the horizon in which a shift alarm still counts as "left out
/// by the horizon" (and so asks for the renewal notice). Two months: a long
/// holiday right after the horizon still gets its notice.
const int renewalLookaheadDays = 60;

/// Wall-clock minute (20:00) the renewal notice prefers, on the day before
/// the last alarm. Other minutes are tried around it (see
/// [planAlarmSchedule]).
const int renewalNoticeMinute = 20 * 60;

/// Closest a renewal notice may get to any planned alarm, so it never rings
/// on top of one (the default evening-before notice is also at 20:00).
const Duration renewalNoticeClearance = Duration(minutes: 10);

/// Id of the renewal notice: there is only ever one (moved to the next free
/// id in the unlikely case it collides with an alarm of the plan).
final int renewalNoticeId = fnv31('cuadrante.renewal');

/// What [planAlarmSchedule] decided: the alarms ([planAlarms]), the renewal
/// notice when one is due and how far the shift alarms reach.
class AlarmPlan {
  const AlarmPlan({
    required this.alarms,
    this.renewal,
    this.truncated = false,
    this.lastShiftAlarm,
    this.coveredUntil,
  });

  /// Nothing scheduled (alarms off, no permission).
  static const AlarmPlan empty = AlarmPlan(alarms: []);

  /// Exactly what [planAlarms] returns for the same input.
  final List<PlannedAlarm> alarms;

  /// The renewal notice ([AlarmKind.renewal]), or null when none is due.
  final PlannedAlarm? renewal;

  /// Whether shift alarms that would ring were left out of [alarms], by the
  /// horizon or by the cap of [maxPendingAlarms]. Only shift alarms count
  /// (before a shift and the evening before), not the note reminders.
  final bool truncated;

  /// The last shift alarm of [alarms] (before a shift or the evening
  /// before), or null when there is none.
  final PlannedAlarm? lastShiftAlarm;

  /// The instant [lastShiftAlarm] rings at, in the planning zone.
  final DateTime? coveredUntil;

  /// What goes to the scheduler: [alarms] and, when due, the [renewal].
  List<PlannedAlarm> get toSchedule => List.unmodifiable([...alarms, ?renewal]);
}

/// [planAlarms] plus the renewal notice and the coverage (A1, docs/alarmas.md
/// «Renovación»): what the app and the background renewal hand to the
/// scheduler.
///
/// The renewal notice is planned only when the shift alarms are on
/// (`settings.anyActive`), [strings] has its texts and the plan was cut
/// ([AlarmPlan.truncated]: an alarm within [renewalLookaheadDays] days past
/// the horizon, or one dropped by the cap). It rings on the day before the
/// last planned shift alarm, at [renewalNoticeMinute] (20:00 wall-clock
/// time, same daylight-saving rules as every alarm) or, when that is taken
/// or invalid, at the nearest half hour between 17:00 and 23:00 that is
/// after [now], before that last alarm and at least
/// [renewalNoticeClearance] away from every planned alarm. If no minute
/// fits, there is no notice. With no shift alarm in the window at all (a
/// long holiday) the end of the horizon takes the place of the last alarm.
AlarmPlan planAlarmSchedule({
  required Schedule schedule,
  required AlarmSettings settings,
  required DateTime now,
  required AlarmStrings strings,
  tz.Location? location,
}) => _plan(
  schedule: schedule,
  settings: settings,
  now: now,
  strings: strings,
  includeReminders: true,
  location: location,
  lookaheadDays: renewalLookaheadDays,
);

AlarmPlan _plan({
  required Schedule schedule,
  required AlarmSettings settings,
  required DateTime now,
  required AlarmStrings strings,
  required bool includeReminders,
  required tz.Location? location,
  required int lookaheadDays,
}) {
  final withShifts = settings.anyActive;
  if (!withShifts && !includeReminders) return AlarmPlan.empty;
  final zone =
      location ??
      (now is tz.TZDateTime ? now.location : defaultAlarmLocation());
  final localNow = tz.TZDateTime.from(now, zone);
  final today = CivilDate.fromDateTime(localNow);
  final lastDate = today.addDays(settings.horizonDays);
  final last = resolveWallClock(
    zone,
    lastDate.year,
    lastDate.month,
    lastDate.day,
    localNow.hour * 60 + localNow.minute,
  );

  final reminders = includeReminders
      ? _planReminders(schedule, strings)
      : <PlannedAlarm>[];
  // An alarm can ring up to a day before its shift, so shifts up to
  // horizon + 1 day ahead can still fall inside the window; the lookahead
  // only tells whether more would ring after it.
  final shiftAlarms = withShifts
      ? _planShiftAlarms(
          schedule,
          settings,
          today,
          strings,
          today.addDays(settings.horizonDays + 1 + lookaheadDays),
          zone,
        )
      : <PlannedAlarm>[];

  // Compare resolved instants, never raw wall minutes: a spring-gap 02:30
  // can still be future at 03:00, while a repeated 02:30 only rings once.
  final instants = {
    for (final alarm in [...reminders, ...shiftAlarms])
      alarm: resolveAlarmInstant(alarm, zone),
  };
  int byTime(PlannedAlarm a, PlannedAlarm b) {
    final c = instants[a]!.compareTo(instants[b]!);
    return c != 0 ? c : a.id.compareTo(b.id);
  }

  List<PlannedAlarm> soonest(List<PlannedAlarm> alarms, int count) =>
      (alarms
              .where(
                (a) => instants[a]!.isAfter(now) && !instants[a]!.isAfter(last),
              )
              .toList()
            ..sort(byTime))
          .take(count)
          .toList();

  final keptReminders = soonest(reminders, maxPendingAlarms);
  final keptShifts = soonest(
    shiftAlarms,
    maxPendingAlarms - keptReminders.length,
  );
  final kept = [...keptReminders, ...keptShifts]..sort(byTime);
  final alarms = List<PlannedAlarm>.unmodifiable(_withUniqueIds(kept));
  if (lookaheadDays == 0) return AlarmPlan(alarms: alarms);

  // Every future shift alarm that did not make it: past the horizon or
  // pushed out by the cap.
  final truncated =
      shiftAlarms.where((a) => instants[a]!.isAfter(now)).length >
      keptShifts.length;
  final lastShift = keptShifts.isEmpty ? null : keptShifts.last;
  PlannedAlarm? renewal;
  if (withShifts && truncated) {
    renewal = _renewalNotice(
      alarms: alarms,
      anchorDate: lastShift?.fireDate ?? lastDate,
      anchorInstant: lastShift == null ? last : instants[lastShift]!,
      now: now,
      zone: zone,
      strings: strings,
    );
  }
  return AlarmPlan(
    alarms: alarms,
    renewal: renewal,
    truncated: truncated,
    // The scheduled copy (its id may have moved to stay unique).
    lastShiftAlarm: lastShift == null
        ? null
        : alarms.lastWhere((a) => a.kind != AlarmKind.reminder),
    coveredUntil: lastShift == null ? null : instants[lastShift],
  );
}

/// The renewal notice for a plan whose last shift alarm rings on
/// [anchorDate] at [anchorInstant] (see [planAlarmSchedule]), or null when
/// [strings] has no renewal texts or no minute fits. Never throws: a notice
/// that cannot be built must not cost the alarms.
PlannedAlarm? _renewalNotice({
  required List<PlannedAlarm> alarms,
  required CivilDate anchorDate,
  required tz.TZDateTime anchorInstant,
  required DateTime now,
  required tz.Location zone,
  required AlarmStrings strings,
}) {
  final title = strings.renewalTitle;
  final body = strings.renewalBody;
  if (title == null || body == null) return null;
  try {
    final day = anchorDate.addDays(-1);
    final taken = [for (final a in alarms) resolveAlarmInstant(a, zone)];
    final used = {for (final a in alarms) a.id};
    // 20:00, then 19:30, 20:30, 19:00, 21:00... down to 17:00, up to 23:00.
    for (var step = 0; step <= 12; step++) {
      final offset = (step + 1) ~/ 2 * 30 * (step.isOdd ? -1 : 1);
      final minute = renewalNoticeMinute + offset;
      final at = resolveWallClock(zone, day.year, day.month, day.day, minute);
      if (!at.isAfter(now) || !at.isBefore(anchorInstant)) continue;
      if (taken.any((t) => t.difference(at).abs() < renewalNoticeClearance)) {
        continue;
      }
      var id = renewalNoticeId;
      while (used.contains(id)) {
        id = (id + 1) & 0x7FFFFFFF;
      }
      return PlannedAlarm(
        id: id,
        fireDate: day,
        fireMinute: minute,
        shiftDate: anchorDate,
        shiftTypeId: '',
        title: title,
        body: body(anchorDate),
        kind: AlarmKind.renewal,
      );
    }
  } catch (_) {
    // Texts or time zone failed: no notice, the alarms stay as planned.
  }
  return null;
}

List<PlannedAlarm> _planShiftAlarms(
  Schedule schedule,
  AlarmSettings settings,
  CivilDate today,
  AlarmStrings strings,
  CivilDate lastShiftDay,
  tz.Location zone,
) {
  final alarms = <PlannedAlarm>[];
  // A second segment can belong to yesterday's shift and start today.
  // Keep resolving that owner day; the plan filters by the alarm's fire time.
  for (final day in schedule.resolveRange(today.addDays(-1), lastShiftDay)) {
    if (settings.isSkipped(day.date)) continue;
    final dayStart = day.date.epochDay * _minutesPerDay;
    // Any absence on the day (vacation, sick leave...) silences the pause
    // notices of its other shifts: nobody is taking a break from work.
    final hasAbsence = day.shifts.any(
      (s) => s.category == ShiftCategory.absence,
    );
    for (var index = 0; index < day.shifts.length; index++) {
      final shift = day.shifts[index];
      final typeSettings = settings.forShiftType(shift.id);
      // Sick leave, vacation... are not shifts you go to: they never ring,
      // whatever was stored (a notification about them would put a health
      // absence on the lock screen).
      if (!typeSettings.anyEnabled || !canShiftTypeRing(shift)) continue;

      final startAbs = shift.startMinute!;
      final start = strings.time(startAbs);
      final body = strings.body(
        shift.name,
        start,
        strings.time(shift.endMinute!),
      );

      void add(
        AlarmKind kind,
        int wall,
        String title, {
        bool buttons = false,
        int segment = 0,
        String? text,
      }) {
        // Floor division: a negative offset lands on the day before.
        final fireEpochDay = (wall / _minutesPerDay).floor();
        alarms.add(
          PlannedAlarm(
            id: alarmIdFor(day.date, shift.id, index, kind, segment),
            fireDate: CivilDate.fromEpochDay(fireEpochDay),
            fireMinute: wall - fireEpochDay * _minutesPerDay,
            shiftDate: day.date,
            shiftTypeId: shift.id,
            title: title,
            body: text ?? body,
            kind: kind,
            shiftName: shift.name,
            snoozeLabel: buttons ? strings.snoozeAction : null,
            awakeLabel: buttons ? strings.awakeAction : null,
            // A pause notice is a plain notification: no custom sound.
            sound: kind == AlarmKind.pause ? null : shift.alarmSound,
            segment: segment,
          ),
        );
      }

      if (typeSettings.enabled) {
        add(
          AlarmKind.shift,
          dayStart + startAbs - typeSettings.minutesBefore,
          typeSettings.cleanLabel ?? strings.title(shift.name, start),
          buttons: true,
        );
        // A split shift (A12) rings again before its second segment, with the
        // same lead, unless the type opted out. The second segment may begin
        // after midnight: the wall-clock minute is counted from the shift's day.
        if (shift.hasSegment2 && typeSettings.secondSegment) {
          final second = ShiftOccurrence.allOf(day.date, shift).last;
          final start2 = strings.time(second.startMinuteAbs);
          add(
            AlarmKind.shift,
            dayStart + second.startMinuteAbs - typeSettings.minutesBefore,
            typeSettings.cleanLabel ?? strings.title(shift.name, start2),
            buttons: true,
            segment: 1,
            text: strings.body(
              shift.name,
              start2,
              strings.time(second.endMinuteAbs),
            ),
          );
        }
        if (typeSettings.dayBefore) {
          add(
            AlarmKind.dayBefore,
            dayStart - _minutesPerDay + typeSettings.dayBeforeMinute,
            strings.dayBeforeTitle(shift.name, start),
          );
        }
      }
      if (typeSettings.pause.enabled && !hasAbsence) {
        _planPause(shift, typeSettings.pause, day.date, strings, zone, add);
      }
    }
  }
  return alarms;
}

typedef _AddAlarm = void Function(
  AlarmKind kind,
  int wall,
  String title, {
  bool buttons,
  int segment,
  String? text,
});

/// The pause notice of one shift (docs/alarmas.md, «Aviso de pausa»), added
/// through [add] when it fits.
///
/// - The notice belongs to the **long segment** of a split shift (the first
///   one when both last the same) and to the only segment of any other.
/// - [PauseTiming.midShift] rings at the middle of that segment,
///   [PauseTiming.afterStart] `afterMinutes` after its start. Both are
///   wall-clock times counted from the start of the shift's day like every
///   alarm, so a night shift that crosses midnight rings after midnight and
///   the daylight-saving rules of `wall_clock.dart` apply.
/// - If the moment is not strictly inside the segment (an "after the start"
///   longer than the shift), or the clock change pushes it to the end of the
///   segment or past it, there is no notice.
/// - Without the texts of [strings] (`pauseTitle`) there is no notice.
/// - Its text is the shift's usual one («Noche: de 22:00 a 06:00», with the
///   times of the segment it belongs to), under the title «Toca pausa».
void _planPause(
  ShiftType shift,
  PauseAlertSettings pause,
  CivilDate date,
  AlarmStrings strings,
  tz.Location zone,
  _AddAlarm add,
) {
  final title = strings.pauseTitle;
  if (title == null) return;
  final segments = ShiftOccurrence.allOf(date, shift);
  var target = segments.first;
  for (final candidate in segments.skip(1)) {
    if (candidate.durationMinutes > target.durationMinutes) target = candidate;
  }
  final offset = pause.timing == PauseTiming.midShift
      ? target.durationMinutes ~/ 2
      : pause.afterMinutes;
  if (offset <= 0 || offset >= target.durationMinutes) return;

  final dayStart = date.epochDay * _minutesPerDay;
  tz.TZDateTime instantOf(int wall) {
    final epochDay = (wall / _minutesPerDay).floor();
    final day = CivilDate.fromEpochDay(epochDay);
    return resolveWallClock(
      zone,
      day.year,
      day.month,
      day.day,
      wall - epochDay * _minutesPerDay,
    );
  }

  final wall = dayStart + target.startMinuteAbs + offset;
  if (!instantOf(wall).isBefore(instantOf(dayStart + target.endMinuteAbs))) {
    return;
  }
  add(
    AlarmKind.pause,
    wall,
    title,
    segment: target.segment,
    text: strings.body(
      shift.name,
      strings.time(target.startMinuteAbs),
      strings.time(target.endMinuteAbs),
    ),
  );
}

/// The reminders of the notes inside the window, one per day with a
/// `noteReminderMinute`. The time is a wall-clock one like every alarm, so
/// the daylight-saving rules of `wall_clock.dart` apply (a minute that does
/// not exist rings at the next valid one, a repeated one rings the first
/// time).
List<PlannedAlarm> _planReminders(Schedule schedule, AlarmStrings strings) {
  final reminders = <PlannedAlarm>[];
  for (final MapEntry(key: date, value: entry) in schedule.entries.entries) {
    final minute = entry.noteReminderMinute;
    if (minute == null || !DayEntry.isReminderMinute(minute)) continue;
    reminders.add(
      PlannedAlarm(
        id: alarmIdFor(date, '', 0, AlarmKind.reminder),
        fireDate: date,
        fireMinute: minute,
        shiftDate: date,
        shiftTypeId: '',
        title: strings.reminderTitle,
        // On an absence day (sick leave...) the note's text stays off the
        // lock screen: the reminder still rings, with the generic body.
        body: _hidesNote(schedule, date)
            ? strings.reminderEmptyBody
            : reminderBody(entry.note) ?? strings.reminderEmptyBody,
        kind: AlarmKind.reminder,
      ),
    );
  }
  return reminders;
}

/// Whether the day resolves to any absence (sick leave, vacation...): its
/// note could be about health, and a notification body is on the lock screen.
bool _hidesNote(Schedule schedule, CivilDate date) => schedule
    .resolve(date)
    .shifts
    .any((shift) => shift.category == ShiftCategory.absence);

/// Longest body of a reminder, in characters (code points).
const int maxReminderBodyLength = 160;

/// The text of a reminder notification: the first non-blank line of [note],
/// trimmed, inner whitespace collapsed and cut at [maxReminderBodyLength]
/// characters (with an ellipsis). `null` when the note has no text.
String? reminderBody(String? note) {
  if (note == null) return null;
  for (final line in note.split(RegExp(r'[\r\n]+'))) {
    final text = line.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isEmpty) continue;
    final runes = text.runes.toList();
    if (runes.length <= maxReminderBodyLength) return text;
    return '${String.fromCharCodes(runes.take(maxReminderBodyLength - 1))}…';
  }
  return null;
}

/// The soonest alarm of the plan, or null when nothing will ring. About
/// **shifts**: the reminders of notes are not part of it.
PlannedAlarm? nextAlarm({
  required Schedule schedule,
  required AlarmSettings settings,
  required DateTime now,
  tz.Location? location,
}) => planAlarms(
  schedule: schedule,
  settings: settings,
  now: now,
  strings: AlarmStrings.blank,
  includeReminders: false,
  location: location,
).where((alarm) => alarm.kind != AlarmKind.pause).firstOrNull;

/// Two alarms hashing to the same id would silently replace each other:
/// move the later one to the next free id (deterministic, since the input
/// order is).
Iterable<PlannedAlarm> _withUniqueIds(Iterable<PlannedAlarm> sorted) sync* {
  final used = <int>{};
  for (final a in sorted) {
    var id = a.id;
    while (!used.add(id)) {
      id = (id + 1) & 0x7FFFFFFF;
    }
    yield id == a.id ? a : a._withId(id);
  }
}
