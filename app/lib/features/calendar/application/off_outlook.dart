import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../schedule/domain/schedule_domain.dart';
import 'schedule_controller.dart';

/// How far ahead the next day off is looked for (≈ four months): beyond it the
/// answer is «unknown», not «never».
const int kOffLookAheadDays = 120;

/// How far back the streak of worked days is counted.
const int kOffLookBackDays = 120;

/// The «Hoy» card only mentions the streak of worked days from this many on
/// (the texts are written for three or more).
const int kStreakShownFrom = 3;

/// The next day off from today (C1 of `docs/propuesta-mejoras.md`).
class NextOff {
  const NextOff({
    required this.date,
    required this.kind,
    required this.daysAway,
    required this.inferred,
  });

  final CivilDate date;

  /// [DayKind.rest] or [DayKind.absence] for a recorded day off;
  /// [DayKind.unrecorded] when [inferred].
  final DayKind kind;

  /// Days from today: 0 = today, 1 = tomorrow...
  final int daysAway;

  /// The day has nothing annotated but the calendar does have shifts after it
  /// (see [computeOffOutlook]), so it is taken as a day off.
  final bool inferred;

  @override
  bool operator ==(Object other) =>
      other is NextOff &&
      other.date == date &&
      other.kind == kind &&
      other.daysAway == daysAway &&
      other.inferred == inferred;

  @override
  int get hashCode => Object.hash(date, kind, daysAway, inferred);

  @override
  String toString() => 'NextOff($date, $kind, +$daysAway, inferred: $inferred)';
}

/// A Saturday and a Sunday both off.
class FreeWeekend {
  const FreeWeekend({required this.saturday, required this.sunday});

  final CivilDate saturday;
  final CivilDate sunday;

  @override
  bool operator ==(Object other) =>
      other is FreeWeekend &&
      other.saturday == saturday &&
      other.sunday == sunday;

  @override
  int get hashCode => Object.hash(saturday, sunday);

  @override
  String toString() => 'FreeWeekend($saturday, $sunday)';
}

/// What the «Hoy» card and the widget say about days off. Pure data derived
/// from one [Schedule] and «today» (see [computeOffOutlook]).
class OffOutlook {
  const OffOutlook({
    required this.today,
    required this.todayKind,
    this.nextOff,
    this.returnDate,
    this.freeWeekend,
    this.workedStreak = 0,
    this.workDaysLeft,
  });

  final CivilDate today;
  final DayKind todayKind;

  /// The first day off on or after today; `null` when there is none within
  /// [kOffLookAheadDays] (or nothing is annotated).
  final NextOff? nextOff;

  /// When today is a day off: the first day of work after today (where the
  /// person goes back to work); `null` when today is not off or there is no
  /// work day within the look-ahead.
  final CivilDate? returnDate;

  /// The next Saturday + Sunday that are both off, today onwards.
  final FreeWeekend? freeWeekend;

  /// Consecutive days of work ending today, today included; 0 when today is
  /// not a work day.
  final int workedStreak;

  /// Work days left after today before the next day off («te quedan 2»):
  /// only when today is a work day and a next day off is known; 0 when
  /// tomorrow is off.
  final int? workDaysLeft;

  /// Nothing to say about days off.
  bool get isEmpty => nextOff == null && freeWeekend == null;

  @override
  bool operator ==(Object other) =>
      other is OffOutlook &&
      other.today == today &&
      other.todayKind == todayKind &&
      other.nextOff == nextOff &&
      other.returnDate == returnDate &&
      other.freeWeekend == freeWeekend &&
      other.workedStreak == workedStreak &&
      other.workDaysLeft == workDaysLeft;

  @override
  int get hashCode => Object.hash(
    today,
    todayKind,
    nextOff,
    returnDate,
    freeWeekend,
    workedStreak,
    workDaysLeft,
  );
}

/// Next day off, next free weekend and streak of work from [today]
/// (C1 of `docs/propuesta-mejoras.md`; the rules are in `docs/motor-de-turnos.md`,
/// «Días libres»). Pure; «today» is passed in, never read from the clock.
///
/// - A day off is a [DayKind.rest] or [DayKind.absence] day (`DayKind.isOff`).
/// - **A day with nothing annotated** ([DayKind.unrecorded]) counts as off
///   only when the calendar has something annotated AFTER it within the
///   look-ahead (a gap between annotated days: many people only paint their
///   work days). Past the last annotated day it does NOT count: the calendar
///   knows nothing beyond that point, and claiming «libras» there would be a
///   guess. Consequently an empty calendar, or a rotation that has ended,
///   says nothing.
/// - The search covers [lookAhead] days after today; the streak looks back up
///   to [lookBack] days. The weekend must be Saturday and Sunday both off and
///   not before today.
OffOutlook computeOffOutlook(
  Schedule schedule,
  CivilDate today, {
  int lookAhead = kOffLookAheadDays,
  int lookBack = kOffLookBackDays,
}) => computeOffOutlookWith(
  (date) => schedule.resolve(date).kind,
  today,
  lookAhead: lookAhead,
  lookBack: lookBack,
);

/// [computeOffOutlook] over any source of day kinds (the widget builder
/// passes a memoised one, since it asks for 60 consecutive «todays»).
OffOutlook computeOffOutlookWith(
  DayKind Function(CivilDate date) kindOf,
  CivilDate today, {
  int lookAhead = kOffLookAheadDays,
  int lookBack = kOffLookBackDays,
}) {
  final kinds = <DayKind>[
    for (var i = 0; i <= lookAhead; i++) kindOf(today.addDays(i)),
  ];
  final lastRecorded = kinds.lastIndexWhere((k) => k.isRecorded);

  // Off, and whether it is only inferred from an unannotated gap.
  (bool off, bool inferred) offAt(int i) {
    final kind = kinds[i];
    if (kind.isOff) return (true, false);
    if (kind == DayKind.unrecorded && i < lastRecorded) return (true, true);
    return (false, false);
  }

  NextOff? nextOff;
  for (var i = 0; i < kinds.length; i++) {
    final (off, inferred) = offAt(i);
    if (!off) continue;
    nextOff = NextOff(
      date: today.addDays(i),
      kind: kinds[i],
      daysAway: i,
      inferred: inferred,
    );
    break;
  }

  CivilDate? returnDate;
  if (offAt(0).$1) {
    final back = kinds.indexOf(DayKind.work);
    if (back > 0) returnDate = today.addDays(back);
  }

  FreeWeekend? weekend;
  for (var i = 0; i + 1 < kinds.length; i++) {
    final date = today.addDays(i);
    if (date.weekday != DateTime.saturday) continue;
    if (offAt(i).$1 && offAt(i + 1).$1) {
      weekend = FreeWeekend(saturday: date, sunday: date.addDays(1));
      break;
    }
  }

  var streak = 0;
  if (kinds.first == DayKind.work) {
    streak = 1;
    for (var back = 1; back <= lookBack; back++) {
      if (kindOf(today.addDays(-back)) != DayKind.work) break;
      streak++;
    }
  }

  return OffOutlook(
    today: today,
    todayKind: kinds.first,
    nextOff: nextOff,
    returnDate: returnDate,
    freeWeekend: weekend,
    workedStreak: streak,
    workDaysLeft: streak > 0 && nextOff != null ? nextOff.daysAway - 1 : null,
  );
}

/// [computeOffOutlook] for the calendar on screen, with «today» from the app
/// clock (`minuteClockProvider`, built on `clockProvider`); it is only
/// recomputed when the schedule changes or the day rolls over.
final offOutlookProvider = Provider<OffOutlook>((ref) {
  final schedule = ref.watch(
    scheduleControllerProvider.select((s) => s.schedule),
  );
  final today = ref.watch(
    minuteClockProvider.select((now) => CivilDate.fromDateTime(now)),
  );
  return computeOffOutlook(schedule, today);
});
