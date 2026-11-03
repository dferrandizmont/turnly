import 'package:collection/collection.dart';

import '../../schedule/domain/schedule_domain.dart';
import 'shift_swap.dart';

/// What applying a change to the calendar does to the days it touches.
///
/// The plan is pure: it says which days change and how, without writing
/// anything. The application writes it as **one** undo step, so the usual
/// «Deshacer» takes the whole change back.
class SwapSchedulePlan {
  const SwapSchedulePlan({required this.change, required this.before});

  /// The change to apply (one undo step).
  final ScheduleChange change;

  /// What the days had before, to put them back when undoing.
  final Map<CivilDate, DayEntry?> before;

  /// Nothing changes: the calendar already is as the change says.
  bool get isEmpty => change.isEmpty;

  /// The days the change touches.
  List<CivilDate> get days => change.patch.changes.keys.toList();
}

/// The calendar changes of a swap, as the screen applies them.
///
/// - The day I gave away ([ShiftSwap.date]) loses the shifts I gave: the
///   colleague works them. What is left of the day stays.
/// - The day I receive ([ShiftSwap.returnDate]) gets the shifts the colleague
///   gives me: they replace the ones that day had.
///
/// A day that already is as it should be is left out, and so is the whole
/// plan when nothing changes. The shift types that do not exist any more are
/// ignored (the engine ignores them too), and a side whose types are all
/// unknown leaves its day alone.
SwapSchedulePlan planSwapApplication(Schedule schedule, ShiftSwap swap) {
  final changes = <CivilDate, EntryChange>{};
  final before = <CivilDate, DayEntry?>{};
  var working = schedule;

  final given = _known(schedule, swap.givenShiftTypeIds);
  if (swap.givenShiftTypeIds != null && given.isNotEmpty) {
    final change = _planGivenDay(
      schedule,
      working,
      swap.date,
      given,
      changes,
      before,
    );
    if (change != null) working = working.apply(change);
  }

  final received = _known(schedule, swap.receivedShiftTypeIds);
  final returnDate = swap.returnDate;
  if (swap.receivedShiftTypeIds != null && returnDate != null) {
    final wanted = swap.receivedShiftTypeIds!;
    if (received.isNotEmpty || wanted.isEmpty) {
      _planReceivedDay(
        schedule,
        working,
        returnDate,
        received,
        changes,
        before,
      );
    }
  }

  return SwapSchedulePlan(
    change: ScheduleChange(patch: EntriesPatch(changes)),
    before: Map.unmodifiable(before),
  );
}

/// The change that puts the days of [before] back as they were.
///
/// Only the shifts of each day come back: a note, a reminder, extra hours or
/// an extra amount added to the day **after** the change was applied stay (the
/// change never touched them). A day left with nothing is removed.
///
/// Nothing changes when the days already are as they were (the change was
/// undone with the usual «Deshacer», for instance).
SwapSchedulePlan planSwapUndo(
  Schedule schedule,
  Map<CivilDate, DayEntry?> before,
) {
  final changes = <CivilDate, EntryChange>{};
  for (final MapEntry(key: date, value: entry) in before.entries) {
    final current = schedule.entries[date];
    final restored = (current ?? DayEntry(date: date)).withShiftTypeIds(
      entry?.shiftTypeIds,
    );
    final after = restored.isEmpty ? null : restored;
    if (current == after) continue;
    changes[date] = EntryChange(current, after);
  }
  return SwapSchedulePlan(
    change: ScheduleChange(patch: EntriesPatch(changes)),
    before: Map.unmodifiable(before),
  );
}

/// The day I gave: the shifts I gave are not mine any more.
ScheduleChange? _planGivenDay(
  Schedule base,
  Schedule working,
  CivilDate date,
  List<String> given,
  Map<CivilDate, EntryChange> changes,
  Map<CivilDate, DayEntry?> before,
) {
  final current = working.resolve(date).shiftIds;
  final remaining = [
    for (final id in current)
      if (!given.contains(id)) id,
  ];
  if (_sameIds(remaining, current)) return null;
  final after = _entryWithShifts(working, date, remaining);
  final original = base.entries[date];
  changes[date] = EntryChange(original, after);
  before.putIfAbsent(date, () => original);
  return ScheduleChange(patch: EntriesPatch({date: changes[date]!}));
}

/// The day I receive: the shifts the colleague gives me.
void _planReceivedDay(
  Schedule base,
  Schedule working,
  CivilDate date,
  List<String> received,
  Map<CivilDate, EntryChange> changes,
  Map<CivilDate, DayEntry?> before,
) {
  final current = working.resolve(date).shiftIds;
  if (_sameIds(current, received)) return;
  final after = _entryWithShifts(working, date, received);
  final original = before.containsKey(date)
      ? before[date]
      : base.entries[date];
  changes[date] = EntryChange(original, after);
  before.putIfAbsent(date, () => base.entries[date]);
}

/// The entry of [date] with its shifts replaced by [ids], normalized like
/// the engine does: an override equal to what the rotation gives is not
/// stored, and an entry left with nothing is not stored either.
DayEntry? _entryWithShifts(
  Schedule schedule,
  CivilDate date,
  List<String> ids,
) {
  final pattern = schedule.resolvePattern(date).shiftIds;
  final override = _sameIds(ids, pattern) ? null : ids;
  final entry =
      (schedule.entries[date] ?? DayEntry(date: date)).withShiftTypeIds(
        override,
      );
  return entry.isEmpty ? null : entry;
}

/// The ids of the shift types that exist in [schedule] (the ones that do not
/// are ignored, as the engine ignores them).
List<String> _known(Schedule schedule, List<String>? ids) => [
  for (final id in ids ?? const <String>[])
    if (schedule.shiftTypeById(id) != null) id,
];

bool _sameIds(List<String> a, List<String> b) =>
    const ListEquality<String>().equals(a, b);
