import 'package:collection/collection.dart';

import '../../schedule/domain/schedule_domain.dart';
import 'shift_swap.dart';
import 'swap_application.dart';

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
SwapSchedulePlan planSwapApplication(
  Schedule schedule,
  ShiftSwap swap, {
  Set<CivilDate> excluding = const {},
}) {
  final changes = <CivilDate, EntryChange>{};
  final before = <CivilDate, DayEntry?>{};
  var working = schedule;

  final given = _known(schedule, swap.givenShiftTypeIds);
  if (given.isNotEmpty && !excluding.contains(swap.date)) {
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
  if (swap.receivedShiftTypeIds != null &&
      returnDate != null &&
      !excluding.contains(returnDate)) {
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

  changes.removeWhere((_, change) => change.before == change.after);
  before.removeWhere((date, _) => !changes.containsKey(date));
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

/// Restore only days that still hold the recorded override. Keep records
/// for days changed since the swap and for legacy writes with no snapshot.
({ScheduleChange change, List<SwapApplicationRecord> skipped})
planRecordedSwapUndo(Schedule schedule, List<SwapApplicationRecord> records) {
  final before = <CivilDate, DayEntry>{};
  final skipped = <SwapApplicationRecord>[];
  for (final record in records) {
    final applied = record.appliedOverride;
    if (applied == null ||
        !const ListEquality<String>().equals(
          applied.shiftTypeIds,
          schedule.entries[record.date]?.shiftTypeIds,
        )) {
      skipped.add(record);
      continue;
    }
    before[record.date] = DayEntry(
      date: record.date,
      shiftTypeIds: _restorableIds(schedule, record.previousShiftTypeIds),
    );
  }
  return (change: planSwapUndo(schedule, before).change, skipped: skipped);
}

/// A day that another swap's application already holds on the calendar.
///
/// At most one applied swap per day: a swap is never applied over a day
/// another one wrote, so taking any of them off the calendar can only give
/// back what that swap itself replaced.
class SwapDayClaim {
  const SwapDayClaim({
    required this.date,
    required this.swapId,
    required this.colleague,
  });

  final CivilDate date;
  final String swapId;
  final String colleague;

  @override
  bool operator ==(Object other) =>
      other is SwapDayClaim &&
      other.date == date &&
      other.swapId == swapId &&
      other.colleague == colleague;

  @override
  int get hashCode => Object.hash(date, swapId, colleague);
}

/// Applying a swap was refused: [claim] says which day already holds
/// another applied swap. Nothing was written.
class SwapApplyConflict implements Exception {
  const SwapApplyConflict(this.claim);

  final SwapDayClaim claim;

  @override
  String toString() => 'SwapApplyConflict(${claim.date}, ${claim.swapId})';
}

/// What saving [swap] does to the calendar, computed the same way by the
/// sheet (to preview it) and by the save itself.
///
/// - With [moved] (the dates or shifts of an applied swap change), the days
///   in [records] come back first ([planRecordedSwapUndo]); the ones that
///   cannot are [skipped] and stay out of the new application.
/// - With [apply], the swap is applied on top ([applied]). [conflict] is the
///   first day it would write that another swap of the calendar already
///   holds ([claims]); such an application must be refused.
({
  ScheduleChange restoration,
  List<SwapApplicationRecord> skipped,
  SwapSchedulePlan? applied,
  SwapDayClaim? conflict,
})
planSwapSave(
  Schedule base,
  ShiftSwap swap, {
  required bool moved,
  required List<SwapApplicationRecord> records,
  required bool apply,
  Iterable<SwapDayClaim> claims = const [],
}) {
  final restored = moved ? planRecordedSwapUndo(base, records) : null;
  final skipped = restored?.skipped ?? const <SwapApplicationRecord>[];
  final restoration = restored?.change ?? const ScheduleChange();
  final applied = apply
      ? planSwapApplication(
          base.apply(restoration),
          swap,
          excluding: {for (final record in skipped) record.date},
        )
      : null;
  return (
    restoration: restoration,
    skipped: skipped,
    applied: applied,
    conflict: applied == null
        ? null
        : swapApplyConflictOf(applied, swap.id, claims),
  );
}

/// The first day of [plan] that another swap than [swapId] already holds.
SwapDayClaim? swapApplyConflictOf(
  SwapSchedulePlan plan,
  String swapId,
  Iterable<SwapDayClaim> claims,
) {
  final days = plan.days.toSet();
  final conflicts = [
    for (final claim in claims)
      if (claim.swapId != swapId && days.contains(claim.date)) claim,
  ]..sort((a, b) => a.date.compareTo(b.date));
  return conflicts.firstOrNull;
}

List<String>? _restorableIds(Schedule schedule, List<String>? ids) {
  if (ids == null || ids.isEmpty) return ids;
  final remaining = _known(schedule, ids);
  return remaining.isEmpty ? null : remaining;
}

extension SwapCalendarFields on ShiftSwap {
  bool movesCalendarDaysFrom(ShiftSwap other) {
    const same = ListEquality<String>();
    return date != other.date ||
        returnDate != other.returnDate ||
        !same.equals(givenShiftTypeIds, other.givenShiftTypeIds) ||
        !same.equals(receivedShiftTypeIds, other.receivedShiftTypeIds);
  }
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
  final original = before.containsKey(date) ? before[date] : base.entries[date];
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
  final entry = (schedule.entries[date] ?? DayEntry(date: date))
      .withShiftTypeIds(override);
  return entry.isEmpty ? null : entry;
}

/// Whether a change is on the calendar, as the calendar itself says.
enum SwapApplication {
  /// The change has no shifts that could be written to the calendar (a debt
  /// only, or shift types that do not exist any more).
  nothing,

  /// The change has shifts and the calendar is not as it says yet: applying
  /// it would change the calendar.
  pending,

  /// The calendar already is as the change says.
  applied,
}

/// The state of [swap] against [schedule].
///
/// It is read from the calendar, never stored: the change is applied when the
/// days are as the plan ([planSwapApplication]) leaves them, so it stays right
/// after a restore, an undo or an edit of those days by hand. Applying a
/// change that is [SwapApplication.applied] changes nothing, so it can never
/// be applied twice.
SwapApplication swapApplicationOf(
  Schedule schedule,
  ShiftSwap swap, {
  Set<CivilDate> excluding = const {},
}) {
  final given = _known(schedule, swap.givenShiftTypeIds);
  final received = _known(schedule, swap.receivedShiftTypeIds);
  final givenActive = swap.givenShiftTypeIds != null && given.isNotEmpty;
  final receivedActive =
      swap.receivedShiftTypeIds != null &&
      swap.returnDate != null &&
      (received.isNotEmpty || swap.receivedShiftTypeIds!.isEmpty);
  if (!givenActive && !receivedActive) return SwapApplication.nothing;
  return planSwapApplication(schedule, swap, excluding: excluding).isEmpty
      ? SwapApplication.applied
      : SwapApplication.pending;
}

/// The ids of the shift types that exist in [schedule] (the ones that do not
/// are ignored, as the engine ignores them).
List<String> _known(Schedule schedule, List<String>? ids) => [
  for (final id in ids ?? const <String>[])
    if (schedule.shiftTypeById(id) != null) id,
];

bool _sameIds(List<String> a, List<String> b) =>
    const ListEquality<String>().equals(a, b);
