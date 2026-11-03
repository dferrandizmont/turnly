import 'schedule.dart';
import 'shift_type.dart';

/// What a day IS for the person, whatever shifts it has (ola 1, C1 and A6 of
/// `docs/propuesta-mejoras.md`). One classification for everything that asks
/// «is this a day off?»: the next day off of the «Hoy» card and the widget, and
/// the comparison of two calendars.
///
/// Precedence when a day has several shifts (a shift belongs to the day it
/// STARTS, as everywhere in the engine):
/// `work` > `absence` > `rest` > `unrecorded`.
///
/// - [work]: at least one shift of the `work` category, however short, also
///   when it is mixed with an absence or a rest shift.
/// - [absence]: no work, at least one shift of the `absence` category
///   (vacation, sick leave, personal days...). Not working that day.
/// - [rest]: only shifts of the `rest` category (Libre, Saliente...).
/// - [unrecorded]: no shift at all. A note, overtime or a reminder alone do
///   not record a day. It is NOT the same as a day off: the person may simply
///   not have annotated it (or the rotation has not started or has ended).
enum DayKind {
  work,
  rest,
  absence,
  unrecorded;

  /// Not working that day: [rest] or [absence]. [unrecorded] is not off.
  bool get isOff => this == rest || this == absence;

  /// A shift is annotated, whatever its category.
  bool get isRecorded => this != unrecorded;
}

/// Classification of the shifts of a day (see [DayKind]).
DayKind dayKindOf(Iterable<ShiftType> shifts) {
  var absence = false;
  var rest = false;
  for (final shift in shifts) {
    switch (shift.category) {
      case ShiftCategory.work:
        return DayKind.work;
      case ShiftCategory.absence:
        absence = true;
      case ShiftCategory.rest:
        rest = true;
    }
  }
  if (absence) return DayKind.absence;
  if (rest) return DayKind.rest;
  return DayKind.unrecorded;
}

extension ResolvedDayKind on ResolvedDay {
  /// See [DayKind].
  DayKind get kind => dayKindOf(shifts);
}
