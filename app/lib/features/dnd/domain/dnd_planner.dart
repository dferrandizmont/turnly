import 'package:timezone/timezone.dart' as tz;

import '../../alarms/domain/alarm_planner.dart' show fnv31;
import '../../alarms/domain/alarm_settings.dart';
import '../../alarms/domain/wall_clock.dart';
import '../../schedule/domain/schedule_domain.dart';
import 'dnd_settings.dart';

const int _minutesPerDay = 1440;

/// Days ahead that get planned: the same horizon as the shift alarms
/// ([AlarmSettings.defaultHorizonDays]), so both run out at the same time.
const int dndHorizonDays = AlarmSettings.defaultHorizonDays;

/// Whether the shifts of [type] may silence the phone: it has a schedule and
/// it is a working shift. A day off (rest) or an absence (vacation, sick
/// leave) is not worked, so nothing is silenced then.
bool canSilenceDuring(ShiftType type) =>
    type.hasTimes && type.category == ShiftCategory.work;

/// A silence window: the phone stays silenced from [start] to [end].
///
/// The instants are absolute: the phone is silenced exactly when the shift
/// starts and freed exactly when it ends, with the same daylight-saving
/// rules as the shift alarms (a wall-clock time, resolved in the zone of the
/// phone).
///
/// A window whose [start] is already past when it is handed to the device is
/// **active** ([isActiveAt]): the device silences the phone at once (an alarm
/// in the past never rings) and frees it at [end]. That is the contract of
/// `DndChannel.kt`.
class DndWindow {
  const DndWindow({
    required this.id,
    required this.start,
    required this.end,
    this.filter = DndFilter.priority,
    this.shiftTypeIds = const [],
  });

  /// Deterministic id (see [dndWindowId]): planning twice gives the same
  /// one, so a reschedule replaces the window instead of adding another.
  final int id;

  /// When the phone is silenced.
  final DateTime start;

  /// When it is freed (the mode it had before comes back).
  final DateTime end;

  /// The interruption filter the phone is put in while the window lasts.
  final DndFilter filter;

  /// The shifts the window covers. A shift split in two gives two windows
  /// (the break between them is not silenced); windows that overlap are
  /// merged into one.
  final List<String> shiftTypeIds;

  Duration get duration => end.difference(start);

  /// Whether the window is the one running at [moment]: it has begun and it
  /// has not ended yet. The device silences the phone at once for a window
  /// that is active (and frees it at [end]).
  bool isActiveAt(DateTime moment) =>
      !moment.isBefore(start) && moment.isBefore(end);

  @override
  bool operator ==(Object other) =>
      other is DndWindow &&
      other.id == id &&
      other.start == start &&
      other.end == end &&
      other.filter == filter &&
      other.shiftTypeIds.length == shiftTypeIds.length &&
      other.shiftTypeIds.toSet().containsAll(shiftTypeIds.toSet());

  @override
  int get hashCode => Object.hash(
    id,
    start,
    end,
    filter,
    Object.hashAllUnordered(shiftTypeIds),
  );

  @override
  String toString() =>
      'DndWindow($id, $start -> $end, ${filter.name}, '
      '${shiftTypeIds.join(',')})';
}

/// Id of a window: FNV-1a of its **start instant**, so the same plan gives
/// the same id and a reschedule replaces the window instead of adding
/// another.
///
/// Unlike the alarm ids (`alarmIdFor`, which hash the wall-clock time), this
/// one hashes the resolved instant: it changes when the zone or the
/// daylight-saving rules change (the same shift starts at another instant),
/// which is what the device needs, because it arms the window by instant.
int dndWindowId(DateTime start) =>
    fnv31('dnd:${start.toUtc().millisecondsSinceEpoch}');

/// The silence windows of the next [horizonDays] days.
///
/// - Only the shift types with the silence on (and the global switch on)
///   and with a schedule; one window per **segment** of a shift, so the
///   break of a split shift is not silenced.
/// - Absences and days off never silence the phone ([canSilenceDuring]).
/// - The window of a shift that started yesterday and is still running (a
///   night shift) is planned too: its end has to free the phone.
/// - A window that already ended is not planned; one that has not started
///   yet is armed for its start; one that is running now ([DndWindow
///   .isActiveAt]) is planned with its real start, and the device silences
///   the phone at once.
/// - Overlapping or touching windows are merged into one: the phone is
///   silenced from the first start to the last end, and it is freed once.
List<DndWindow> planDndWindows({
  required Schedule schedule,
  required DndSettings settings,
  required DateTime now,
  tz.Location? location,
  int horizonDays = dndHorizonDays,
}) {
  if (!settings.anyActive) return const [];
  final zone =
      location ??
      (now is tz.TZDateTime ? now.location : defaultAlarmLocation());
  final today = CivilDate.fromDateTime(tz.TZDateTime.from(now, zone));
  final lastDay = today.addDays(horizonDays);

  final raw = <_RawWindow>[];
  // From yesterday: a shift that started the day before may still be
  // running, and the end of it has to free the phone.
  for (final day in schedule.resolveRange(today.addDays(-1), lastDay)) {
    for (final shift in day.shifts) {
      if (!canSilenceDuring(shift)) continue;
      if (!settings.isEnabledFor(shift.id)) continue;
      for (final occurrence in ShiftOccurrence.allOf(day.date, shift)) {
        final start = _instantAt(zone, day.date, occurrence.startMinuteAbs);
        final end = _instantAt(zone, day.date, occurrence.endMinuteAbs);
        // A window that already ended is not planned any more.
        if (!end.isAfter(now)) continue;
        raw.add(
          _RawWindow(start: start, end: end, shiftTypeId: shift.id),
        );
      }
    }
  }
  return _merge(raw, settings.filter);
}

/// The instant of the wall-clock time [minuteAbs] minutes after the
/// midnight of [date] in [zone] (the minute may go past the midnight, for a
/// shift that crosses it).
tz.TZDateTime _instantAt(tz.Location zone, CivilDate date, int minuteAbs) {
  final wall = date.epochDay * _minutesPerDay + minuteAbs;
  final epochDay = (wall / _minutesPerDay).floor();
  final minute = wall - epochDay * _minutesPerDay;
  final day = CivilDate.fromEpochDay(epochDay);
  return resolveWallClock(zone, day.year, day.month, day.day, minute);
}

/// A window before the overlapping ones are merged.
class _RawWindow {
  const _RawWindow({
    required this.start,
    required this.end,
    required this.shiftTypeId,
  });

  final DateTime start;
  final DateTime end;
  final String shiftTypeId;
}

/// Merges the windows that overlap or touch: the phone is silenced from the
/// first start to the last end and freed once.
List<DndWindow> _merge(List<_RawWindow> raw, DndFilter filter) {
  if (raw.isEmpty) return const [];
  final sorted = [...raw]
    ..sort((a, b) {
      final byStart = a.start.compareTo(b.start);
      return byStart != 0 ? byStart : a.end.compareTo(b.end);
    });
  final groups = <List<_RawWindow>>[];
  var current = <_RawWindow>[];
  DateTime? currentEnd;
  for (final window in sorted) {
    if (current.isEmpty || window.start.isAfter(currentEnd!)) {
      if (current.isNotEmpty) groups.add(current);
      current = [window];
      currentEnd = window.end;
      continue;
    }
    current.add(window);
    if (window.end.isAfter(currentEnd)) currentEnd = window.end;
  }
  if (current.isNotEmpty) groups.add(current);
  return [
    for (final group in groups)
      DndWindow(
        id: dndWindowId(group.first.start),
        start: group.first.start,
        end: _currentEndOf(group),
        filter: filter,
        shiftTypeIds: List.unmodifiable({for (final w in group) w.shiftTypeId}),
      ),
  ];
}

/// The latest end of a group of overlapping windows.
DateTime _currentEndOf(List<_RawWindow> group) {
  var end = group.first.end;
  for (final window in group) {
    if (window.end.isAfter(end)) end = window.end;
  }
  return end;
}
