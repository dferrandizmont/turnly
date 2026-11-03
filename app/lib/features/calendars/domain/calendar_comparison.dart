import '../../schedule/domain/schedule_domain.dart';
import 'calendar.dart';

/// Comparing two calendars (`docs/paridad.md` A4): the shifts of each one on
/// the same days, the days on which both are free and those with nothing
/// annotated in one of them. Pure Dart on top of two
/// [Schedule]s, read-only.
///
/// **A free day** (A6 of `docs/propuesta-mejoras.md`): a day the person has
/// annotated as not working, that is a [DayKind.rest] day (Libre, Saliente) or
/// a [DayKind.absence] day (Vacaciones, Baja, Libre disposición...). A day
/// with at least one work shift is busy, however short, and so is a day that
/// mixes an absence and a work shift.
///
/// **A day with nothing annotated is NOT free** ([DayKind.unrecorded]): the
/// person may simply not have filled it in (or the rotation has not started
/// or has ended), so claiming «libres los dos» would be a guess. The screen
/// shows those days as «sin anotar» (see [ComparedDay.hasUnrecorded]) instead
/// of mixing them with the real days off.
///
/// As everywhere in the engine, a shift belongs to the day it STARTS: the day
/// after a night shift is not busy by this definition even if the night ends
/// in its morning (the Saliente automático marks it as rest anyway).
bool isFreeDay(ResolvedDay day) => day.kind.isOff;

/// The two calendars to compare among [calendars] (non-archived, in order):
/// [firstId] and [secondId] when they exist and differ; otherwise the first
/// is the calendar on screen ([activeId]) and the second the next one in the
/// list (the first one again after the last). `null` with fewer than two
/// calendars: there is nothing to compare.
({Calendar first, Calendar second})? resolveComparePair(
  List<Calendar> calendars, {
  required String activeId,
  String? firstId,
  String? secondId,
}) {
  if (calendars.length < 2) return null;
  Calendar? byId(String? id) {
    for (final calendar in calendars) {
      if (calendar.id == id) return calendar;
    }
    return null;
  }

  final first = byId(firstId) ?? byId(activeId) ?? calendars.first;
  var second = byId(secondId);
  if (second == null || second.id == first.id) {
    final index = calendars.indexOf(first);
    second = calendars[(index + 1) % calendars.length];
  }
  return (first: first, second: second);
}

/// One day seen in both calendars.
class ComparedDay {
  const ComparedDay({required this.date, required this.a, required this.b});

  final CivilDate date;

  /// The day in the first and in the second calendar.
  final ResolvedDay a;
  final ResolvedDay b;

  DayKind get kindA => a.kind;
  DayKind get kindB => b.kind;

  bool get freeA => isFreeDay(a);
  bool get freeB => isFreeDay(b);

  /// Both calendars have the day annotated as not working: the days to meet.
  bool get bothFree => freeA && freeB;

  /// Nobody works that day but at least one calendar has nothing annotated,
  /// so it cannot be called free: «sin anotar». A day on which anybody works
  /// is busy, not unrecorded, whatever the other calendar has.
  bool get hasUnrecorded =>
      kindA != DayKind.work &&
      kindB != DayKind.work &&
      (kindA == DayKind.unrecorded || kindB == DayKind.unrecorded);
}

/// The days `[from, to]` (both included) in both schedules.
List<ComparedDay> compareDays(
  Schedule a,
  Schedule b,
  CivilDate from,
  CivilDate to,
) {
  final daysA = a.resolveRange(from, to);
  final daysB = b.resolveRange(from, to);
  return [
    for (var i = 0; i < daysA.length; i++)
      ComparedDay(date: daysA[i].date, a: daysA[i], b: daysB[i]),
  ];
}

/// The comparison of one calendar month.
class MonthComparison {
  const MonthComparison({required this.month, required this.days});

  /// First day of the month.
  final CivilDate month;

  /// Every day of the month, in order.
  final List<ComparedDay> days;

  /// The days of the month on which both calendars are free, in order.
  List<CivilDate> get commonFreeDays => [
    for (final day in days)
      if (day.bothFree) day.date,
  ];

  /// How many: «X días libres en común este mes».
  int get commonFreeCount => days.where((d) => d.bothFree).length;

  /// The days of the month with no work in either calendar but nothing
  /// annotated in at least one of them (A6), in order.
  List<CivilDate> get unrecordedDays => [
    for (final day in days)
      if (day.hasUnrecorded) day.date,
  ];

  /// How many: «N días sin anotar en alguno de los dos».
  int get unrecordedCount => days.where((d) => d.hasUnrecorded).length;
}

/// Compares the month that contains [anyDay].
MonthComparison compareMonth(Schedule a, Schedule b, CivilDate anyDay) {
  final first = anyDay.firstDayOfMonth;
  return MonthComparison(
    month: first,
    days: compareDays(a, b, first, first.lastDayOfMonth),
  );
}

// ---------------------------------------------------------------------------
// Comparing N calendars (P12)
// ---------------------------------------------------------------------------

/// How many calendars can be compared at once (P12): the grid shows one row
/// per calendar and six of them still fit on a phone.
const int maxComparedCalendars = 6;

/// The least a comparison needs: a calendar compared with itself is not
/// comparing anything.
const int minComparedCalendars = 2;

/// The calendars to compare among [calendars] (non-archived, in order),
/// between [minComparedCalendars] and [maxComparedCalendars].
///
/// * The ids of [selectedIds] come first, in the order they were picked: an
///   id that is not in [calendars] is dropped and a repeated one is kept only
///   once.
/// * With fewer than two valid ids the valid pick (if any) stays first and
///   the calendar on screen ([activeId]) is added next, followed by the ones
///   that come after it in the list, wrapping round at the end (the rule of
///   [resolveComparePair], so the two-calendar comparison and this one open
///   on the same pair). An explicit pick always wins over the screen.
/// * At most [maxComparedCalendars] calendars: the ones picked are the ones
///   that count, the rest are left out.
List<Calendar> resolveComparedCalendars(
  List<Calendar> calendars, {
  required String activeId,
  List<String> selectedIds = const [],
}) {
  if (calendars.isEmpty) return const [];
  final byId = {for (final calendar in calendars) calendar.id: calendar};
  final chosen = <Calendar>[];
  final taken = <String>{};

  for (final id in selectedIds) {
    if (chosen.length >= maxComparedCalendars) break;
    final calendar = byId[id];
    if (calendar == null || !taken.add(id)) continue;
    chosen.add(calendar);
  }
  if (chosen.length >= minComparedCalendars) return chosen;

  // Not enough picked: the calendar on screen first, then the ones that
  // follow it, wrapping round at the end.
  final index = calendars.indexWhere((calendar) => calendar.id == activeId);
  final ordered = index < 0
      ? calendars
      : [...calendars.sublist(index), ...calendars.sublist(0, index)];
  for (final calendar in ordered) {
    if (chosen.length >= minComparedCalendars) break;
    if (!taken.add(calendar.id)) continue;
    chosen.add(calendar);
  }
  return chosen;
}

/// Whether [date] is a weekend day: a Saturday or a Sunday. The same
/// definition the «Hoy» card uses for its free weekend.
bool isWeekendDay(CivilDate date) =>
    date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;

/// One day of the comparison of N calendars: the N cells of a column of the
/// grid, one per calendar, in the order of the calendars.
///
/// The rules are the ones of the two-calendar comparison: a day is free when
/// it is annotated as not working ([DayKind.rest] or [DayKind.absence]) and
/// **an empty day is not free** (A6): the person may simply not have filled
/// it in.
class MultiComparedDay {
  MultiComparedDay({required this.date, required List<ResolvedDay> days})
    : days = List.unmodifiable(days);

  final CivilDate date;

  /// One [ResolvedDay] per compared calendar, in the same order.
  final List<ResolvedDay> days;

  /// How many calendars are compared.
  int get calendarCount => days.length;

  /// The day as the calendar [index] has it.
  ResolvedDay dayOf(int index) => days[index];

  /// What the day is for the calendar [index] ([DayKind]).
  DayKind kindOf(int index) => days[index].kind;

  /// Whether the calendar [index] has that day free.
  bool isFree(int index) => isFreeDay(days[index]);

  /// Whether the calendar [index] works that day (any work shift, however
  /// short).
  bool isBusy(int index) => days[index].kind == DayKind.work;

  /// Everybody is free: the day is free in every calendar.
  bool get allFree => days.every(isFreeDay);

  /// Nobody works and at least one calendar has nothing annotated (A6): the
  /// day cannot be called free, it is «sin anotar».
  bool get hasUnrecorded =>
      !days.any((day) => day.kind == DayKind.work) &&
      days.any((day) => day.kind == DayKind.unrecorded);

  /// The calendars that work that day, by their index in the comparison
  /// («quién trabaja cada día»).
  List<int> get workingIndexes => [
    for (var i = 0; i < days.length; i++)
      if (isBusy(i)) i,
  ];

  /// The calendars that have that day free, by their index in the comparison.
  List<int> get freeIndexes => [
    for (var i = 0; i < days.length; i++)
      if (isFree(i)) i,
  ];
}

/// A Saturday and a Sunday on which every compared calendar is free.
class CommonFreeWeekend {
  const CommonFreeWeekend({required this.saturday, required this.sunday});

  final CivilDate saturday;
  final CivilDate sunday;

  @override
  bool operator ==(Object other) =>
      other is CommonFreeWeekend &&
      other.saturday == saturday &&
      other.sunday == sunday;

  @override
  int get hashCode => Object.hash(saturday, sunday);

  @override
  String toString() => 'CommonFreeWeekend(${saturday.toIso()}, ${sunday.toIso()})';
}

/// The comparison of N calendars over a range of days: the rows (the
/// calendars) and the columns (the days), plus everything that can be said
/// about them.
///
/// Read-only: it never changes a calendar nor a schedule.
class MultiComparison {
  MultiComparison({
    required List<Calendar> calendars,
    required this.from,
    required this.to,
    required List<MultiComparedDay> days,
  }) : calendars = List.unmodifiable(calendars),
       days = List.unmodifiable(days);

  /// The calendars compared, in the order of the rows of the grid.
  final List<Calendar> calendars;

  /// First day of the range, included.
  final CivilDate from;

  /// Last day of the range, included.
  final CivilDate to;

  /// Every day of the range, in order: the columns of the grid.
  final List<MultiComparedDay> days;

  /// How many calendars are compared: the number of rows of the grid.
  int get calendarCount => calendars.length;

  /// The days everybody is free, in order.
  List<CivilDate> get commonFreeDays => [
    for (final day in days)
      if (day.allFree) day.date,
  ];

  /// How many: «X días libres en común».
  int get commonFreeCount => days.where((day) => day.allFree).length;

  /// The days nobody works but some calendar has nothing annotated (A6), in
  /// order.
  List<CivilDate> get unrecordedDays => [
    for (final day in days)
      if (day.hasUnrecorded) day.date,
  ];

  /// How many: «N días sin anotar en alguno».
  int get unrecordedCount => days.where((day) => day.hasUnrecorded).length;

  /// The days the calendar [index] works, in order.
  List<CivilDate> busyDaysOf(int index) => [
    for (final day in days)
      if (day.isBusy(index)) day.date,
  ];

  /// The days the calendar [index] has free, in order.
  List<CivilDate> freeDaysOf(int index) => [
    for (final day in days)
      if (day.isFree(index)) day.date,
  ];

  /// The weekend days (Saturday and Sunday) everybody is free, in order.
  List<CivilDate> get commonFreeWeekendDays => [
    for (final day in days)
      if (day.allFree && isWeekendDay(day.date)) day.date,
  ];

  /// How many weekend days everybody is free.
  int get commonFreeWeekendCount => commonFreeWeekendDays.length;

  /// The complete weekends (Saturday and Sunday both free for everybody).
  /// A weekend whose Sunday is out of the range is not counted.
  List<CommonFreeWeekend> get commonFreeWeekends {
    final free = {for (final day in days) if (day.allFree) day.date};
    return [
      for (final day in days)
        if (day.allFree &&
            day.date.weekday == DateTime.saturday &&
            free.contains(day.date.addDays(1)))
          CommonFreeWeekend(
            saturday: day.date,
            sunday: day.date.addDays(1),
          ),
    ];
  }

  /// The same comparison restricted to the month that contains [anyDay]: the
  /// days of that month and nothing else. Empty when the range does not
  /// reach the month: then [from] and [to] are an empty range anchored at the
  /// start of the month, never an inverted pair.
  MultiComparison forMonth(CivilDate anyDay) {
    final monthStart = anyDay.firstDayOfMonth;
    final monthEnd = anyDay.lastDayOfMonth;
    var clippedFrom = from.isAfter(monthStart) ? from : monthStart;
    var clippedTo = to.isBefore(monthEnd) ? to : monthEnd;
    if (clippedFrom.isAfter(clippedTo)) {
      // The range does not reach the month: an empty range at its start.
      clippedFrom = monthStart;
      clippedTo = monthStart.addDays(-1);
    }
    return MultiComparison(
      calendars: calendars,
      from: clippedFrom,
      to: clippedTo,
      days: [
        for (final day in days)
          if (!day.date.isBefore(monthStart) && !day.date.isAfter(monthEnd))
            day,
      ],
    );
  }
}

/// Compares the calendars over `[from, to]`, both included.
///
/// Each row pairs a [Calendar] with its [Schedule], so there is no way to
/// pass two mismatched lists: the row is the calendar of the grid and the
/// schedule it is resolved from. Pure Dart on top of the [Schedule]s,
/// read-only.
MultiComparison compareCalendars(
  List<({Calendar calendar, Schedule schedule})> rows,
  CivilDate from,
  CivilDate to,
) {
  final resolved = [
    for (final row in rows) row.schedule.resolveRange(from, to),
  ];
  final count = resolved.isEmpty ? 0 : resolved.first.length;
  return MultiComparison(
    calendars: [for (final row in rows) row.calendar],
    from: from,
    to: to,
    days: [
      for (var i = 0; i < count; i++)
        MultiComparedDay(
          date: resolved.first[i].date,
          days: [for (final row in resolved) row[i]],
        ),
    ],
  );
}

/// Compares the calendars over the month that contains [anyDay].
MultiComparison compareCalendarMonth(
  List<({Calendar calendar, Schedule schedule})> rows,
  CivilDate anyDay,
) {
  final first = anyDay.firstDayOfMonth;
  return compareCalendars(rows, first, first.lastDayOfMonth);
}
