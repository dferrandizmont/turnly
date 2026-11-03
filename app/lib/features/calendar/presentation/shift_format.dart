import 'dart:ui' show Brightness;

import '../../../core/format/app_date_format.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/shift_swatch.dart';
import '../../schedule/domain/schedule_domain.dart';

DateTime _clock(int minute) =>
    DateTime(2000, 1, 1, (minute ~/ 60) % 24, minute % 60);

String _compact(int minute, bool hour12) =>
    AppDateFormat.compactClock(minute, hour12: hour12);

String capitalize(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

extension ShiftTypeFormat on ShiftType {
  /// Bar, tint, disc and ink of this shift in [brightness] (derived from the
  /// stored colour at paint time). [outOfMonth] is the variant of the days
  /// of the neighbouring months.
  ShiftSwatch swatch(Brightness brightness, {bool outOfMonth = false}) =>
      ShiftSwatch.forColor(colorValue, brightness, outOfMonth: outOfMonth);

  /// Range "22:00–06:00" ("10:00 PM–6:00 AM" on the 12 h clock), or null for shifts without schedule. A split
  /// shift (A12) gives both ranges: "09:00–13:00 · 17:00–21:00".
  String? timeRange(AppDateFormat format) {
    if (!hasTimes) return null;
    final first = format.timeRange(_clock(startMinute!), _clock(endMinute!));
    if (!hasSegment2) return first;
    final second = format.timeRange(
      _clock(segment2StartMinute!),
      _clock(segment2EndMinute!),
    );
    return '$first · $second';
  }

  /// Cell form "22–06" (minutes only when they are not :00: "07:30–15"), or
  /// null for shifts without schedule. A split shift gives both ranges
  /// joined by a slash: "09–13/17–21" (the cell only shows it when it fits).
  /// On the 12 h clock ([hour12]) the hours carry a letter: "10p–6a",
  /// "7:30a–3p" (see [AppDateFormat.compactClock]); it is as wide as the 24 h
  /// form, so the cell keeps its room.
  String? compactTimeRange({bool hour12 = false}) =>
      _compactRanges('/', hour12);

  /// The start of the first range in the cell form: "09" (or "09:30" when
  /// the minutes are not :00; "9a" / "9:30a" on the 12 h clock), or null for
  /// shifts without schedule. It is what the cell says of a split shift
  /// whose two ranges do not fit: the cell always has a code and a time
  /// (H-T22-9).
  String? compactStart({bool hour12 = false}) =>
      hasTimes ? _compact(startMinute!, hour12) : null;

  /// [compactStart] without the minutes ("09", "9a"): what is left of the
  /// start in a very narrow cell.
  String? compactStartHour({bool hour12 = false}) => hasTimes
      ? AppDateFormat.compactClockHour(startMinute!, hour12: hour12)
      : null;

  /// The start of each range of a split shift in the cell form: "09/17", or
  /// null for a shift with a single range. It is what the cell says of a
  /// split shift whose two full ranges do not fit: the cell tells that the
  /// shift has two segments without shrinking the code (H-T23-1).
  String? compactSplitStarts({bool hour12 = false}) {
    if (!hasTimes || !hasSegment2) return null;
    return '${_compact(startMinute!, hour12)}/'
        '${_compact(segment2StartMinute!, hour12)}';
  }

  /// Like [compactTimeRange], but a split shift's ranges are joined by
  /// " · " ("09–13 · 17–21"), as the widget and its lock screen line show
  /// them.
  String? compactTimeLabel({bool hour12 = false}) =>
      _compactRanges(' · ', hour12);

  String? _compactRanges(String separator, bool hour12) {
    if (!hasTimes) return null;
    final first =
        '${_compact(startMinute!, hour12)}–${_compact(endMinute!, hour12)}';
    if (!hasSegment2) return first;
    return '$first$separator${_compact(segment2StartMinute!, hour12)}–'
        '${_compact(segment2EndMinute!, hour12)}';
  }

  /// "Noche 22:00–06:00", or just the name when it has no schedule.
  String nameWithTimes(AppLocalizations l10n, AppDateFormat format) {
    final times = timeRange(format);
    return times == null ? name : l10n.calendarShiftWithTimes(name, times);
  }

  /// Spoken form: "Noche de 22:00 a 06:00" ("Partido de 09:00 a 13:00 y de
  /// 17:00 a 21:00" for a split shift).
  String spoken(AppLocalizations l10n, AppDateFormat format) {
    if (!hasTimes) return name;
    final start = format.time(_clock(startMinute!));
    final end = format.time(_clock(endMinute!));
    if (!hasSegment2) return l10n.daySemanticsShift(name, start, end);
    return l10n.daySemanticsShiftSplit(
      name,
      start,
      end,
      format.time(_clock(segment2StartMinute!)),
      format.time(_clock(segment2EndMinute!)),
    );
  }
}

/// "Noche 22:00–06:00 + Tarde 14:00–22:00", or "Sin turno".
String shiftsLine(
  AppLocalizations l10n,
  AppDateFormat format,
  List<ShiftType> shifts,
) => shifts.isEmpty
    ? l10n.calendarNoShift
    : shifts.map((s) => s.nameWithTimes(l10n, format)).join(' + ');

/// "3 h 40 min", "40 min", "2 h", "1 d 8 h" (minutes are dropped from a day
/// on). [minutes] is a whole number of minutes, at least 1.
String durationText(AppLocalizations l10n, int minutes) {
  final days = minutes ~/ 1440;
  final hours = (minutes % 1440) ~/ 60;
  final rest = minutes % 60;
  if (days > 0) {
    return hours == 0
        ? l10n.durationDays(days)
        : l10n.durationDaysHours(days, hours);
  }
  if (hours > 0) {
    return rest == 0
        ? l10n.durationHours(hours)
        : l10n.durationHoursMinutes(hours, rest);
  }
  return l10n.durationMinutes(minutes);
}
